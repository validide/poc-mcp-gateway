# API Key Authentication Ideas for MCP Gateway

## Problem

Secure the MCP gateway using API keys. Duende IdentityServer doesn't natively support
API keys, but we need a way to link them to clients and issue JWTs that the gateway
and backends already understand.

---

## Option 1: AgentGateway Native `apiKey` Policy (simplest)

AgentGateway has first-class API key support. Add it under `policies` on any route:

```yaml
- name: placeholder-apikey
  matches:
  - path:
      pathPrefix: /placeholder-apikey
  backends:
  - mcp:
      targets:
      - name: jsonplaceholder
        mcp:
          host: http://jsonplaceholder-mcp:8001/mcp
  policies:
    apiKey:
      mode: strict
      keys:
      - key: sk-demo-client-alpha
        metadata:
          client: alpha
          role: reader
      - key: sk-demo-client-beta
        metadata:
          client: beta
          role: admin
```

- Clients send the key via the `x-api-key` header
- `mode: strict` = reject if no valid key; `optional` = allow anonymous; `permissive` = log-only
- Each key carries arbitrary metadata (client name, role, etc.) that downstream policies
  and request transformations can reference
- Can coexist alongside `mcpAuthentication` (accept either JWT or API key)

**Pros:** Zero additional infrastructure, one config change.
**Cons:** Keys are static in the config file (no self-service rotation, no central management).

---

## Option 2: Nginx-Level API Key Validation

Validate API keys at the nginx reverse proxy layer:

```nginx
map $http_x_api_key $api_key_valid {
    default         0;
    "sk-client-alpha"  1;
    "sk-client-beta"   1;
}

location /some-route/ {
    if ($api_key_valid = 0) {
        return 401 '{"error": "invalid API key"}';
    }
    proxy_pass http://gateway;
}
```

**Pros:** Layer before the gateway, protects public routes without touching gateway config.
**Cons:** Crude — no metadata, no per-key policies.

---

## Option 3: Duende Extension Grant (API Key → JWT inside IDP)

Duende supports custom grant types via `IExtensionGrantValidator`. Register a grant type
like `api_key`:

```csharp
public class ApiKeyGrantValidator : IExtensionGrantValidator
{
    public string GrantType => "api_key";

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        var apiKey = context.Request.Raw.Get("api_key");

        // Look up key -> client mapping (DB, config, etc.)
        var mapping = await _store.FindByApiKey(apiKey);
        if (mapping == null)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant);
            return;
        }

        context.Result = new GrantValidationResult(
            subject: mapping.ClientId,
            authenticationMethod: GrantType,
            claims: mapping.AdditionalClaims
        );
    }
}
```

Caller exchanges the key for a JWT:

```
POST /connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=api_key&api_key=sk-demo-client-alpha&scope=mcp:tools
```

Registration:

```csharp
isBuilder.AddExtensionGrantValidator<ApiKeyGrantValidator>();
```

Client in `Config.cs`:

```csharp
new Client
{
    ClientId = "apikey-client-alpha",
    AllowedGrantTypes = { "api_key" },
    RequireClientSecret = false,   // key IS the secret
    AllowedScopes = { "mcp:tools" }
}
```

**Pros:** Standard token endpoint, full IdentityServer token lifecycle (expiry, refresh,
audiences), gateway `mcpAuthentication` stays unchanged.
**Cons:** Two-step flow — client exchanges API key for JWT, then calls gateway with JWT.

---

## Option 4: Custom Secret Parser (API Key as Client Auth Method)

Make the API key an alternative way to authenticate an existing client via Duende's
`ISecretParser` + `ISecretValidator`:

```csharp
public class ApiKeySecretParser : ISecretParser
{
    public Task<ParsedSecret?> ParseAsync(HttpContext context)
    {
        var apiKey = context.Request.Headers["X-API-Key"].FirstOrDefault();
        if (string.IsNullOrEmpty(apiKey))
            return Task.FromResult<ParsedSecret?>(null);

        return Task.FromResult<ParsedSecret?>(new ParsedSecret
        {
            Id = LookupClientId(apiKey),  // map key -> client_id
            Credential = apiKey,
            Type = "ApiKey"
        });
    }
}

public class ApiKeySecretValidator : ISecretValidator
{
    public Task<SecretValidationResult> ValidateAsync(
        IEnumerable<Secret> secrets, ParsedSecret parsedSecret)
    {
        if (parsedSecret.Type != "ApiKey")
            return Task.FromResult(new SecretValidationResult { Success = false });

        var match = secrets.Any(s =>
            s.Type == "ApiKey" && s.Value == parsedSecret.Credential.ToString().Sha256());

        return Task.FromResult(new SecretValidationResult { Success = match });
    }
}
```

Caller uses the standard `client_credentials` flow:

```
POST /connect/token
X-API-Key: sk-demo-client-alpha
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&scope=mcp:tools
```

**Pros:** Standard client_credentials flow stays standard; API key is just an alternative
auth method. No changes to gateway config.
**Cons:** More plumbing (two interfaces). Caller still needs to know it's a token endpoint.

---

## Option 5: Duende Reference Tokens as "API Keys"

Duende supports reference tokens — opaque strings validated via introspection:

1. Set `AccessTokenType = AccessTokenType.Reference` on a client
2. Issue a long-lived token via `client_credentials`
3. Treat that opaque token as an "API key" the caller uses repeatedly

**Catch:** AgentGateway's `mcpAuthentication` validates JWTs locally via JWKS, not
reference tokens via introspection. Would need an introspection proxy in front, or
switch back to JWT with a long `AccessTokenLifetime`.

---

## Option 6: Gateway `extAuthz` + IDP Endpoint (recommended)

**Transparent API key → JWT exchange at the gateway level.** The client sends only an
API key; the gateway handles the token exchange via AgentGateway's external authorization
policy, calling an endpoint built into the existing IdentityServer.

### Flow

```
Client                    Gateway                   IDP (ext-authz)           Backend MCP
  |                         |                            |                        |
  |-- X-API-Key: sk-... --> |                            |                        |
  |                         |-- X-API-Key: sk-... ------>|                        |
  |                         |                            | validate key           |
  |                         |                            | map -> client_id/secret|
  |                         |                            | mint JWT               |
  |                         |<-- 200 + Authorization ----|                        |
  |                         |                            |                        |
  |                         |-- Authorization: Bearer -------------------------------->|
  |                         |                                                     |
  |<-- tool result ---------|<----------------------------------------------------|
```

### Gateway Config

```yaml
- name: inspector-apikey
  matches:
  - path:
      pathPrefix: /inspector-apikey
  backends:
  - mcp:
      targets:
      - name: inspector
        mcp:
          host: http://inspector-csharp-mcp:8080/mcp
  policies:
    extAuthz:
    - host: idp:5000
      protocol:
        http:
          path: '"/connect/apikey-exchange"'
          includeResponseHeaders:
          - authorization
      includeRequestHeaders:
      - x-api-key
      timeout: 2s
```

No `backendAuth` needed — `extAuthz` injects the `Authorization` header itself.

### IDP Endpoint

Add a minimal endpoint to IdentityServer (`HostingExtensions.cs`) that:

1. Reads the `X-API-Key` header
2. Looks up the mapped client in the EF config store
3. Mints a token using Duende's internal `ITokenCreationService`
4. Returns it in the `Authorization` response header

API key -> client mapping can be stored as:
- `ClientSecret` with `Type = "ApiKey"` (cleanest — uses existing Duende model)
- `ClientProperty` (same pattern as DCR `origin=dcr` tag)
- Separate table

### Design Decisions

| Decision | Options |
|---|---|
| **Where to store keys** | `ClientSecret` with `Type = "ApiKey"` (cleanest) vs. `ClientProperty` vs. separate table |
| **Token minting** | `ITokenCreationService` directly (fast, skips token endpoint) vs. internal HTTP call to `/connect/token` (full pipeline with events/logging) |
| **Token caching** | ext-authz is called on every request; cache the JWT keyed by API key until near-expiry |
| **Key format** | Prefixed like `sk-{clientId}-{random}` for client hint without DB lookup |

### Advantages

- **Client just sends `X-API-Key`** — no OAuth flow, no two-step exchange
- **Backend receives a standard JWT** — inspector shows decoded claims as usual
- **All managed in one place** — API keys live in the same DB as clients
- **Gateway is stateless** — delegates all auth decisions to IDP via ext-authz
- **Cacheable** — same API key = same JWT until expiry

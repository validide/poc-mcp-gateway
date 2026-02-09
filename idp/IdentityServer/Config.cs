// ============================================================================
// IdentityServer Configuration Concepts
// ============================================================================
//
// IdentityResources
//   Represent claims about the user's identity (user ID, name, email).
//   Each IdentityResource maps to a set of claims included in the ID token
//   when a client requests the corresponding scope.
//   - OpenId  -> the "sub" (subject/user ID) claim. Required for OpenID Connect.
//   - Profile -> name, family_name, given_name, etc.
//   - Email   -> email, email_verified
//   These are user-centric -- they describe *who the user is*.
//
// ApiScopes
//   Define a permission or capability that a client can request.
//   Here, "mcp:tools" means "access to MCP tools."
//   Scopes are labels on access tokens that APIs can check.
//   A scope by itself doesn't belong to any particular API -- it's just
//   a named permission.
//
// ApiResources
//   Represent a protected API -- an actual service that validates incoming
//   tokens. Each one has a logical name (the URL) and a display name.
//   These correspond to the "aud" (audience) claim in the access token,
//   letting the API verify the token was intended for it.
//
// The link: ApiResource.Scopes <-> ApiScopes
//   The Scopes property on each ApiResource declares which scopes are valid
//   for that API. When a client requests "mcp:tools", the resulting access
//   token can be used against any API resource that lists "mcp:tools" in
//   its scopes.
//
//   In this config, all MCP backends share the single "mcp:tools" scope,
//   meaning a client with one access token containing "mcp:tools" can call
//   any of them. For finer-grained control, define distinct scopes like
//   "mcp:placeholder", "mcp:weather", etc., and assign each to its
//   respective ApiResource.
//
// Summary flow:
//   Client requests scope "mcp:tools"
//   -> IdentityServer issues a token with that scope and the relevant audience
//   -> the MCP API validates the token has the right scope and audience
// ============================================================================

using Duende.IdentityServer.Models;

namespace IdentityServer;

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    ];

    public static IEnumerable<ApiResource> ApiResources =>
    [
        new("https://gateway.localhost:8080/placeholder/mcp", "JSONPlaceholder MCP")
        {
            Scopes = { "mcp:tools" }
        },
        new("https://gateway.localhost:8080/weather/mcp", "Weather MCP")
        {
            Scopes = { "mcp:tools" }
        },
        new("https://gateway.localhost:8080/mixed/mcp", "Mixed MCP")
        {
            Scopes = { "mcp:tools" }
        },
        new("https://gateway.localhost:8080/b2b/dev/docs/mcp", "B2B Dev Docs MCP")
        {
            Scopes = { "mcp:tools" }
        },
        new("https://gateway.localhost:8080/b2c/travel/booking/mcp", "B2C Travel Booking MCP")
        {
            Scopes = { "mcp:tools" }
        },
    ];

    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new("mcp:tools")
    ];

    public static IEnumerable<Client> Clients =>
    [
        new Client
        {
            ClientId = "gateway-admin-ui",
            ClientName = "MCP Gateway Admin UI",
            ClientSecrets = { new Secret("gateway-admin-secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = false,
            RedirectUris = { "https://gateway-ui.localhost:8080/oauth2/callback" },
            PostLogoutRedirectUris = { "https://gateway-ui.localhost:8080/" },
            AllowedScopes = { "openid", "profile", "email" },
            AlwaysIncludeUserClaimsInIdToken = true,
            Enabled = true
        }
    ];
}

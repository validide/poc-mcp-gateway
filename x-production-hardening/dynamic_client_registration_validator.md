# DynamicClientRegistrationValidator with Duende IdentityServer — Should You Use It?

## What It Is

The `DynamicClientRegistrationValidator` is Duende's default implementation of `IDynamicClientRegistrationValidator`. It validates metadata supplied during [Dynamic Client Registration (DCR)](https://docs.duendesoftware.com/identityserver/configuration/dcr/) — the process by which OAuth clients programmatically register themselves at runtime instead of being manually configured. It runs [14 sequential validation steps](https://docs.duendesoftware.com/identityserver/reference/dcr/validation/) (grant types, redirect URIs, scopes, secrets, token properties, etc.).

---

## Reasons TO Use It

1. **Scalability for AI/MCP workloads** — Duende explicitly positions DCR as the mechanism for [MCP and AI agent scenarios](https://duendesoftware.com/blog/20251202-the-secure-gateway-to-ai-duende-identityserver-and-dynamic-client-registration-for-mcp). When teams use code-generation tools, each developer may need 1-2 clients — DCR automates this.

2. **Standards-compliant** — Built on [RFC 7591](https://docs.duendesoftware.com/identityserver/configuration/dcr/) and OpenID Connect DCR 1.0, so it inherits pre-vetted threat models.

3. **Extensible by design** — You are encouraged to **extend** `DynamicClientRegistrationValidator` and override specific virtual methods rather than rewrite validation from scratch. Each of the 14 steps can be overridden independently.

4. **Separation of concerns** — Validation (what the client requests) is separated from processing (what the server generates, like client IDs and secrets), keeping responsibilities clean.

5. **Eliminates manual registration bottleneck** — No more hand-configuring each client in large-scale ecosystems (microservices, mobile apps, partner APIs).

6. **Centralizes security** — All client registration flows through your identity provider, so policy is enforced in one place rather than scattered across services.

---

## Reasons NOT to Use It (or to be very careful)

1. **Unauthorized registration is the #1 risk** — Duende's own docs warn: without proper safeguards, **anyone with access to the DCR endpoint can register clients**. If you don't implement robust authorization, you've created an open door.

2. **Authorization is NOT enabled by default** — The docs say authentication/authorization is "not strictly required" but "recommended". This opt-in nature means it's easy to deploy DCR insecurely if you skip this step.

3. **Licensing restriction** — DCR is only available to **Business and Enterprise** license holders. If you're on a Community or Starter license, you can't use it.

4. **Operational complexity at scale** — More dynamic clients means more token management, more monitoring, and a larger attack surface to watch.

5. **Network exposure** — If you co-host the Configuration API with IdentityServer (instead of [separating them](https://docs.duendesoftware.com/identityserver/configuration/dcr/)), you lose the ability to restrict network access to the DCR endpoint independently.

6. **Evolving standards** — Duende themselves note that standards like the **OAuth Client ID Metadata Document** may eventually replace DCR, so the landscape is still shifting.

7. **No known CVEs specific to DCR validation**, but Duende IdentityServer has had [general security patches](https://duendesoftware.com/blog/20240731-security-patch) (e.g., CVE-2024-39694 for open redirects), so staying updated is essential.

---

## Best Practices If You Use It

| Practice | Why |
|---|---|
| **Always protect the DCR endpoint** with OAuth (JWT-bearer + scopes like `IdentityServer.Configuration`) | Prevents unauthorized registration |
| **Host Configuration API separately** from IdentityServer | Network-level isolation, read-only access for IS |
| **Extend `DynamicClientRegistrationValidator`**, don't replace it | Get the 14 built-in checks for free, customize only what you need |
| **Use software statements** (signed JWTs) for trust between registering systems | Adds a cryptographic trust layer |
| **Monitor DCR activity** for suspicious patterns | Detect abuse early |
| **Keep human-in-the-loop** for sensitive resource exposure | Especially important for AI/MCP scenarios |

---

## Verdict

**Use it if** you have a Business/Enterprise license and need to onboard clients at scale (especially for MCP/AI agent scenarios). The `DynamicClientRegistrationValidator` is well-designed and extensible.

**Don't use it if** you only have a handful of static clients, can't invest in properly securing the DCR endpoint, or are on a lower-tier license. Manual registration is simpler and has a smaller attack surface for small deployments.

The biggest pitfall is deploying DCR **without proper authorization** on the endpoint — that's the scenario Duende warns about most prominently.

---

## Sources

- [Dynamic Client Registration (DCR) — Duende Docs](https://docs.duendesoftware.com/identityserver/configuration/dcr/)
- [DynamicClientRegistrationValidator — Validation Reference](https://docs.duendesoftware.com/identityserver/reference/dcr/validation/)
- [DCR for MCP and AI — Duende Blog](https://duendesoftware.com/blog/20251202-the-secure-gateway-to-ai-duende-identityserver-and-dynamic-client-registration-for-mcp)
- [IdentityServer 6.3 and DCR — Duende Blog](https://duendesoftware.com/blog/20230510-dcr/)
- [Security Patch CVE-2024-39694 — Duende Blog](https://duendesoftware.com/blog/20240731-security-patch)
- [Duende IdentityServer Snyk Vulnerabilities](https://security.snyk.io/package/nuget/duende.identityserver)

using Duende.IdentityServer.Configuration.Models.DynamicClientRegistration;
using Duende.IdentityServer.Configuration.RequestProcessing;
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Entities;
using Microsoft.EntityFrameworkCore;

namespace IdentityServer;

/// <summary>
/// Custom DCR processor that decorates Duende's default <see cref="DynamicClientRegistrationRequestProcessor"/>.
///
/// Two problems arise with the default behaviour when MCP clients register dynamically:
///
/// 1. **Security** – Any anonymous caller can register a client and immediately obtain tokens.
///    We mitigate this by disabling newly registered clients so an admin must approve them first
///    via the Client Approval page before the client can participate in token flows.
///
/// 2. **Missing scopes** – Duende's default processor only persists scopes that the caller
///    explicitly requests. The MCP Inspector (in normal, non-debug mode) omits scopes from
///    the DCR request, so the client ends up with <c>AllowedScopes = []</c> and subsequent
///    authorization requests for e.g. <c>scope=mcp:tools</c> fail.
///    We fix this by defaulting to all scopes defined on enabled API resources when the
///    client registers without any.
/// </summary>
public class CustomDynamicClientRegistrationRequestProcessor : IDynamicClientRegistrationRequestProcessor
{
    /// <summary>
    /// Property key/value pair used to tag clients created via DCR so that other components
    /// (e.g. <see cref="DcrCleanupService"/>) can distinguish them from statically configured clients.
    /// </summary>
    public const string OriginPropertyKey = "origin";
    public const string OriginPropertyValue = "dcr";

    private readonly DynamicClientRegistrationRequestProcessor _inner;
    private readonly ConfigurationDbContext _configDb;
    private readonly ILogger<CustomDynamicClientRegistrationRequestProcessor> _logger;

    public CustomDynamicClientRegistrationRequestProcessor(
        DynamicClientRegistrationRequestProcessor inner,
        ConfigurationDbContext configDb,
        ILogger<CustomDynamicClientRegistrationRequestProcessor> logger)
    {
        _inner = inner;
        _configDb = configDb;
        _logger = logger;
    }

    public async Task<IDynamicClientRegistrationResponse> ProcessAsync(DynamicClientRegistrationContext context)
    {
        // Delegate to Duende's built-in processor first – it generates the client_id, hashes the
        // secret, maps the DCR metadata to a Client entity, and persists everything to the store.
        var response = await _inner.ProcessAsync(context);

        // Re-load the persisted entity so we can post-process it.
        // We include Properties (to tag it) and AllowedScopes (to back-fill defaults if empty).
        var clientId = context.Client.ClientId;
        var entity = await _configDb.Clients
            .Include(c => c.Properties)
            .Include(c => c.AllowedScopes)
            .FirstOrDefaultAsync(c => c.ClientId == clientId);

        if (entity is not null)
        {
            // Disable the client so it cannot obtain tokens until an administrator explicitly
            // approves it. This prevents open self-service registration from being abused.
            entity.Enabled = false;

            // Tag the client so cleanup jobs and UI pages can identify DCR-originated clients
            // without relying on naming conventions or other heuristics.
            entity.Properties.Add(new ClientProperty
            {
                Key = OriginPropertyKey,
                Value = OriginPropertyValue
            });

            // When the caller did not request any scopes (e.g. MCP Inspector in normal mode),
            // default to every scope defined on enabled API resources. This ensures the client
            // can request scopes like "mcp:tools" once approved, matching the behaviour of
            // debug-mode registrations that explicitly include scopes in the DCR payload.
            if (entity.AllowedScopes == null || !entity.AllowedScopes.Any())
            {
                var resourceScopes = await _configDb.ApiResources
                    .Where(ar => ar.Enabled)
                    .Include(ar => ar.Scopes)
                    .SelectMany(ar => ar.Scopes.Select(s => s.Scope))
                    .Distinct()
                    .ToListAsync();

                entity.AllowedScopes ??= new List<ClientScope>();
                foreach (var scope in resourceScopes)
                {
                    entity.AllowedScopes.Add(new ClientScope { Scope = scope });
                }
            }

            await _configDb.SaveChangesAsync();
            _logger.LogInformation("DCR: Client {ClientId} registered as disabled (pending approval)", clientId);
        }

        return response;
    }
}

using Duende.IdentityServer.EntityFramework.DbContexts;
using Microsoft.EntityFrameworkCore;

namespace IdentityServer;

/// <summary>
/// Background service that periodically cleans up DCR clients:
/// 1. Unapproved (disabled) clients older than 1 hour
/// 2. Approved (enabled) clients with no active grants past their refresh token lifetime
/// </summary>
public class DcrCleanupService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<DcrCleanupService> _logger;
    private static readonly TimeSpan CleanupInterval = TimeSpan.FromMinutes(15);
    private static readonly TimeSpan UnapprovedMaxAge = TimeSpan.FromHours(1);

    public DcrCleanupService(IServiceScopeFactory scopeFactory, ILogger<DcrCleanupService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(CleanupInterval, stoppingToken);

            try
            {
                await CleanupUnapprovedClients(stoppingToken);
                await CleanupAbandonedClients(stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "Error during DCR client cleanup");
            }
        }
    }

    /// <summary>
    /// Remove disabled DCR clients that were never approved within the allowed window.
    /// </summary>
    private async Task CleanupUnapprovedClients(CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var configDb = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();

        var cutoff = DateTime.UtcNow - UnapprovedMaxAge;

        var staleClients = await configDb.Clients
            .Include(c => c.AllowedScopes)
            .Include(c => c.RedirectUris)
            .Include(c => c.AllowedGrantTypes)
            .Include(c => c.ClientSecrets)
            .Include(c => c.Properties)
            .Include(c => c.Claims)
            .Include(c => c.PostLogoutRedirectUris)
            .Include(c => c.AllowedCorsOrigins)
            .Include(c => c.IdentityProviderRestrictions)
            .Where(c => !c.Enabled && c.Created < cutoff
                && c.Properties.Any(p =>
                    p.Key == CustomDynamicClientRegistrationRequestProcessor.OriginPropertyKey
                    && p.Value == CustomDynamicClientRegistrationRequestProcessor.OriginPropertyValue))
            .ToListAsync(ct);

        if (staleClients.Count == 0) return;

        foreach (var client in staleClients)
        {
            _logger.LogInformation(
                "Removing unapproved DCR client {ClientId} (registered {Created})",
                client.ClientId, client.Created);
        }

        configDb.Clients.RemoveRange(staleClients);
        await configDb.SaveChangesAsync(ct);

        _logger.LogInformation("Cleaned up {Count} unapproved DCR client(s)", staleClients.Count);
    }

    /// <summary>
    /// Remove enabled DCR clients that have no active persisted grants (refresh tokens, etc.)
    /// and whose refresh token lifetime has elapsed since creation.
    /// IdentityServer's token cleanup removes expired grants, so zero rows means no active sessions.
    /// </summary>
    private async Task CleanupAbandonedClients(CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var configDb = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();
        var grantDb = scope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>();

        var now = DateTime.UtcNow;

        // Find enabled DCR clients
        var dcrClients = await configDb.Clients
            .Include(c => c.AllowedScopes)
            .Include(c => c.RedirectUris)
            .Include(c => c.AllowedGrantTypes)
            .Include(c => c.ClientSecrets)
            .Include(c => c.Properties)
            .Include(c => c.Claims)
            .Include(c => c.PostLogoutRedirectUris)
            .Include(c => c.AllowedCorsOrigins)
            .Include(c => c.IdentityProviderRestrictions)
            .Where(c => c.Enabled
                && c.Properties.Any(p =>
                    p.Key == CustomDynamicClientRegistrationRequestProcessor.OriginPropertyKey
                    && p.Value == CustomDynamicClientRegistrationRequestProcessor.OriginPropertyValue))
            .ToListAsync(ct);

        if (dcrClients.Count == 0) return;

        // Get client IDs that still have active (non-expired) persisted grants
        var activeClientIds = await grantDb.PersistedGrants
            .Where(g => g.Expiration == null || g.Expiration > now)
            .Select(g => g.ClientId)
            .Distinct()
            .ToListAsync(ct);

        var activeSet = new HashSet<string>(activeClientIds, StringComparer.OrdinalIgnoreCase);

        var abandoned = dcrClients
            .Where(c =>
            {
                // Skip clients that still have active grants
                if (activeSet.Contains(c.ClientId))
                    return false;

                // Use the client's own refresh token lifetime as the grace period.
                // Default AbsoluteRefreshTokenLifetime is 2592000s (30 days).
                var lifetime = c.AbsoluteRefreshTokenLifetime > 0
                    ? TimeSpan.FromSeconds(c.AbsoluteRefreshTokenLifetime)
                    : TimeSpan.FromDays(30);

                // Only remove if enough time has passed for all tokens to have expired
                return c.Created + lifetime < now;
            })
            .ToList();

        if (abandoned.Count == 0) return;

        foreach (var client in abandoned)
        {
            _logger.LogInformation(
                "Removing abandoned DCR client {ClientId} (registered {Created}, no active grants)",
                client.ClientId, client.Created);
        }

        configDb.Clients.RemoveRange(abandoned);
        await configDb.SaveChangesAsync(ct);

        _logger.LogInformation("Cleaned up {Count} abandoned DCR client(s)", abandoned.Count);
    }
}

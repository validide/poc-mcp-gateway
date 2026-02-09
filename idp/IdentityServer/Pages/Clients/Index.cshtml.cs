using Duende.IdentityServer.EntityFramework.DbContexts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace IdentityServer.Pages.Clients;

[SecurityHeaders]
[Authorize]
public class Index : PageModel
{
    /// <summary>
    /// Matches the threshold in <see cref="DcrCleanupService"/> – unapproved clients older
    /// than this are considered expired and will be cleaned up on the next sweep.
    /// </summary>
    private static readonly TimeSpan UnapprovedMaxAge = TimeSpan.FromHours(1);

    private readonly ConfigurationDbContext _configDb;
    private readonly ILogger<Index> _logger;

    public Index(ConfigurationDbContext configDb, ILogger<Index> logger)
    {
        _configDb = configDb;
        _logger = logger;
    }

    public ViewModel View { get; set; } = default!;

    [BindProperty] public int ClientDbId { get; set; }

    public async Task OnGet()
    {
        var now = DateTime.UtcNow;
        var cutoff = now - UnapprovedMaxAge;

        var clients = await _configDb.Clients
            .Include(c => c.AllowedScopes)
            .Include(c => c.RedirectUris)
            .Include(c => c.AllowedGrantTypes)
            .OrderByDescending(c => c.Created)
            .ToListAsync();

        View = new ViewModel
        {
            Clients = clients.Select(c => new ClientViewModel
            {
                Id = c.Id,
                ClientId = c.ClientId,
                ClientName = c.ClientName ?? c.ClientId,
                ClientUri = c.ClientUri,
                RedirectUris = c.RedirectUris.Select(r => r.RedirectUri),
                AllowedGrantTypes = c.AllowedGrantTypes.Select(g => g.GrantType),
                AllowedScopes = c.AllowedScopes.Select(s => s.Scope),
                Created = c.Created,
                Status = c.Enabled
                    ? c.Created < cutoff
                        ? ClientStatus.Expired
                        : ClientStatus.Active
                    : ClientStatus.PendingApproval
            })
        };
    }

    public async Task<IActionResult> OnPostApprove()
    {
        var client = await _configDb.Clients.FindAsync(ClientDbId);
        if (client is not null)
        {
            client.Enabled = true;
            await _configDb.SaveChangesAsync();
            _logger.LogInformation("Client {ClientId} approved and enabled", client.ClientId);
        }

        return RedirectToPage("/Clients/Index");
    }

    public async Task<IActionResult> OnPostDisable()
    {
        var client = await _configDb.Clients.FindAsync(ClientDbId);
        if (client is not null)
        {
            client.Enabled = false;
            await _configDb.SaveChangesAsync();
            _logger.LogInformation("Client {ClientId} disabled", client.ClientId);
        }

        return RedirectToPage("/Clients/Index");
    }

    public async Task<IActionResult> OnPostDelete()
    {
        var client = await _configDb.Clients
            .Include(c => c.AllowedScopes)
            .Include(c => c.RedirectUris)
            .Include(c => c.AllowedGrantTypes)
            .Include(c => c.ClientSecrets)
            .Include(c => c.Properties)
            .Include(c => c.Claims)
            .Include(c => c.PostLogoutRedirectUris)
            .Include(c => c.AllowedCorsOrigins)
            .Include(c => c.IdentityProviderRestrictions)
            .FirstOrDefaultAsync(c => c.Id == ClientDbId);

        if (client is not null)
        {
            _configDb.Clients.Remove(client);
            await _configDb.SaveChangesAsync();
            _logger.LogInformation("Client {ClientId} deleted", client.ClientId);
        }

        return RedirectToPage("/Clients/Index");
    }
}

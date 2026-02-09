using Duende.IdentityServer.EntityFramework.DbContexts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace IdentityServer.Pages.ClientApproval;

[SecurityHeaders]
[Authorize]
public class Index : PageModel
{
    private readonly ConfigurationDbContext _configDb;
    private readonly ILogger<Index> _logger;

    public Index(ConfigurationDbContext configDb, ILogger<Index> logger)
    {
        _configDb = configDb;
        _logger = logger;
    }

    public ViewModel View { get; set; } = default!;

    [BindProperty] public int ClientDbId { get; set; }
    [BindProperty] public string? ReturnUrl { get; set; }

    [FromQuery(Name = "returnUrl")]
    public string? QueryReturnUrl { get; set; }

    public async Task<IActionResult> OnGet()
    {
        // When there's no returnUrl this page is accessed directly – redirect
        // to the unified Clients page which now shows all statuses.
        if (string.IsNullOrEmpty(QueryReturnUrl))
        {
            return RedirectToPage("/Clients/Index");
        }

        var disabledClients = await _configDb.Clients
            .Include(c => c.AllowedScopes)
            .Include(c => c.RedirectUris)
            .Include(c => c.AllowedGrantTypes)
            .Where(c => !c.Enabled)
            .OrderByDescending(c => c.Created)
            .ToListAsync();

        View = new ViewModel
        {
            ReturnUrl = QueryReturnUrl,
            PendingClients = disabledClients.Select(c => new PendingClientViewModel
            {
                Id = c.Id,
                ClientId = c.ClientId,
                ClientName = c.ClientName ?? c.ClientId,
                ClientUri = c.ClientUri,
                RedirectUris = c.RedirectUris.Select(r => r.RedirectUri),
                AllowedGrantTypes = c.AllowedGrantTypes.Select(g => g.GrantType),
                AllowedScopes = c.AllowedScopes.Select(s => s.Scope),
                Created = c.Created
            })
        };

        return Page();
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

        // If we came from an OAuth authorize request, redirect back to continue the flow
        if (!string.IsNullOrEmpty(ReturnUrl) && Uri.IsWellFormedUriString(ReturnUrl, UriKind.Absolute))
        {
            return Redirect(ReturnUrl);
        }

        return RedirectToPage("/Clients/Index");
    }

    public async Task<IActionResult> OnPostDeny()
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
            _logger.LogInformation("Client {ClientId} denied and deleted", client.ClientId);
        }

        return RedirectToPage("/Clients/Index");
    }
}

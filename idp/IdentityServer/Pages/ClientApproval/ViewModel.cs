namespace IdentityServer.Pages.ClientApproval;

public class ViewModel
{
    public IEnumerable<PendingClientViewModel> PendingClients { get; set; } = Enumerable.Empty<PendingClientViewModel>();
    public string? ReturnUrl { get; set; }
}

public class PendingClientViewModel
{
    public int Id { get; set; }
    public string? ClientId { get; set; }
    public string? ClientName { get; set; }
    public string? ClientUri { get; set; }
    public IEnumerable<string> RedirectUris { get; set; } = Enumerable.Empty<string>();
    public IEnumerable<string> AllowedGrantTypes { get; set; } = Enumerable.Empty<string>();
    public IEnumerable<string> AllowedScopes { get; set; } = Enumerable.Empty<string>();
    public DateTime Created { get; set; }
}

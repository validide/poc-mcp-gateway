namespace IdentityServer.Pages.Clients;

public enum ClientStatus
{
    PendingApproval,
    Active,
    Expired
}

public class ViewModel
{
    public IEnumerable<ClientViewModel> Clients { get; set; } = Enumerable.Empty<ClientViewModel>();
}

public class ClientViewModel
{
    public int Id { get; set; }
    public string? ClientId { get; set; }
    public string? ClientName { get; set; }
    public string? ClientUri { get; set; }
    public IEnumerable<string> RedirectUris { get; set; } = Enumerable.Empty<string>();
    public IEnumerable<string> AllowedGrantTypes { get; set; } = Enumerable.Empty<string>();
    public IEnumerable<string> AllowedScopes { get; set; } = Enumerable.Empty<string>();
    public DateTime Created { get; set; }
    public ClientStatus Status { get; set; }
}

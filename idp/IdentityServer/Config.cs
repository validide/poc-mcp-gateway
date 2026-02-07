using Duende.IdentityServer.Models;

namespace IdentityServer;

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources =>
    [
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
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
        }
    ];
    public static IEnumerable<ApiScope> ApiScopes =>
    [
        new("mcp:tools")
    ];
}

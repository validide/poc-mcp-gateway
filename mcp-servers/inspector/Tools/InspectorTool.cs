using System.ComponentModel;
using System.IdentityModel.Tokens.Jwt;
using System.Text.Json;
using ModelContextProtocol.Server;

namespace InspectorMcp.Tools;

[McpServerToolType]
public static class InspectorTool
{
    [McpServerTool(Name = "inspect")]
    [Description("Returns all incoming HTTP request details including headers, method, path, query, remote IP, and decoded JWT claims if an Authorization header is present.")]
    public static string Inspect()
    {
        var request = RequestSnapshot.Current;
        if (request is null)
        {
            return JsonSerializer.Serialize(new { error = "No request snapshot available" });
        }

        var result = new Dictionary<string, object?>
        {
            ["timestamp"] = request.Timestamp.ToString("o"),
            ["method"] = request.Method,
            ["path"] = request.Path,
            ["queryString"] = request.QueryString,
            ["scheme"] = request.Scheme,
            ["host"] = request.Host,
            ["remoteIp"] = request.RemoteIp,
            ["headers"] = request.Headers,
        };

        // Decode JWT if Authorization header is present
        if (request.Headers.TryGetValue("Authorization", out var authHeader) && !string.IsNullOrEmpty(authHeader))
        {
            var token = authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                ? authHeader["Bearer ".Length..].Trim()
                : null;

            if (token is not null)
            {
                try
                {
                    var handler = new JwtSecurityTokenHandler();
                    if (handler.CanReadToken(token))
                    {
                        var jwt = handler.ReadJwtToken(token);
                        result["jwt"] = new Dictionary<string, object?>
                        {
                            ["issuer"] = jwt.Issuer,
                            ["subject"] = jwt.Subject,
                            ["audiences"] = jwt.Audiences.ToList(),
                            ["issuedAt"] = jwt.IssuedAt.ToString("o"),
                            ["expires"] = jwt.ValidTo.ToString("o"),
                            ["claims"] = jwt.Claims.Select(c => new { c.Type, c.Value }).ToList(),
                        };
                    }
                }
                catch
                {
                    result["jwt"] = new { error = "Failed to decode JWT token" };
                }
            }
        }

        return JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true });
    }
}

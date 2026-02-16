namespace InspectorMcp;

/// <summary>
/// Captures HTTP request info in middleware so it's available to MCP tools
/// even when HttpContext is no longer in scope. Uses AsyncLocal to survive
/// across DI scope boundaries.
/// </summary>
public class RequestSnapshot
{
    private static readonly AsyncLocal<RequestSnapshot?> _current = new();

    public static RequestSnapshot? Current => _current.Value;

    public DateTimeOffset Timestamp { get; init; }
    public string Method { get; init; } = "";
    public string Path { get; init; } = "";
    public string? QueryString { get; init; }
    public string Scheme { get; init; } = "";
    public string Host { get; init; } = "";
    public string? RemoteIp { get; init; }
    public Dictionary<string, string> Headers { get; init; } = new();

    public static void CaptureFrom(HttpContext context)
    {
        var headers = new Dictionary<string, string>();
        foreach (var header in context.Request.Headers)
        {
            headers[header.Key] = header.Value.ToString();
        }

        _current.Value = new RequestSnapshot
        {
            Timestamp = DateTimeOffset.UtcNow,
            Method = context.Request.Method,
            Path = context.Request.Path.Value ?? "",
            QueryString = context.Request.QueryString.Value,
            Scheme = context.Request.Scheme,
            Host = context.Request.Host.Value,
            RemoteIp = context.Connection.RemoteIpAddress?.ToString(),
            Headers = headers,
        };
    }
}

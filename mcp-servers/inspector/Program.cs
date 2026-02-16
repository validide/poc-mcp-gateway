using InspectorMcp;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddMcpServer()
    .WithHttpTransport()
    .WithToolsFromAssembly();

var app = builder.Build();

// Capture request info into AsyncLocal before the MCP middleware processes it
app.Use(async (context, next) =>
{
    RequestSnapshot.CaptureFrom(context);
    await next();
});

app.MapMcp("/mcp");
app.MapGet("/health", () => Results.Ok("healthy"));
app.Run();

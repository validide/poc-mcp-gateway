using System.Globalization;
using Duende.IdentityServer;
using Duende.IdentityServer.Configuration;
using Duende.IdentityServer.Configuration.EntityFramework;
using Duende.IdentityServer.Configuration.RequestProcessing;
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Interfaces;
using Microsoft.AspNetCore.Http.Extensions;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using Serilog.Filters;

namespace IdentityServer;

internal static class HostingExtensions
{
    public static WebApplicationBuilder ConfigureLogging(this WebApplicationBuilder builder)
    {
        // Write most logs to the console but diagnostic data to a file.
        // See https://docs.duendesoftware.com/identityserver/diagnostics/data
        builder.Host.UseSerilog((ctx, lc) =>
        {
            lc.WriteTo.Logger(consoleLogger =>
            {
                consoleLogger.WriteTo.Console(
                    outputTemplate:
                    "[{Timestamp:HH:mm:ss} {Level}] {SourceContext}{NewLine}{Message:lj}{NewLine}{Exception}{NewLine}",
                    formatProvider: CultureInfo.InvariantCulture);
                if (builder.Environment.IsDevelopment())
                {
                    consoleLogger.Filter.ByExcluding(Matching.FromSource("Duende.IdentityServer.Diagnostics.Summary"));
                }
            });
            if (builder.Environment.IsDevelopment())
            {
                lc.WriteTo.Logger(fileLogger =>
                {
                    fileLogger
                        .WriteTo.File("./diagnostics/diagnostic.log", rollingInterval: RollingInterval.Day,
                            fileSizeLimitBytes: 1024 * 1024 * 10, // 10 MB
                            rollOnFileSizeLimit: true,
                            outputTemplate:
                            "[{Timestamp:HH:mm:ss} {Level}] {SourceContext}{NewLine}{Message:lj}{NewLine}{Exception}{NewLine}",
                            formatProvider: CultureInfo.InvariantCulture)
                        .Filter
                        .ByIncludingOnly(Matching.FromSource("Duende.IdentityServer.Diagnostics.Summary"));
                }).Enrich.FromLogContext().ReadFrom.Configuration(ctx.Configuration);
            }
        });
        return builder;
    }

    public static WebApplication ConfigureServices(this WebApplicationBuilder builder)
    {
        builder.Services.AddRazorPages();

        // Trust nginx forwarded headers so the IdP knows external traffic is HTTPS
        builder.Services.Configure<ForwardedHeadersOptions>(options =>
        {
            options.ForwardedHeaders = Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.All;
            options.KnownIPNetworks.Clear();
            options.KnownProxies.Clear();
        });

        var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

        var isBuilder = builder.Services.AddIdentityServer(options =>
                    {
                        // Fixed issuer so tokens are valid regardless of whether the request
                        // arrived via nginx (public) or direct container-to-container (internal)
                        options.IssuerUri = "https://idp.localhost:8080";

                        options.Events.RaiseErrorEvents = true;
                        options.Events.RaiseInformationEvents = true;
                        options.Events.RaiseFailureEvents = true;
                        options.Events.RaiseSuccessEvents = true;

                        // Advertise the DCR endpoint in discovery
                        options.Discovery.DynamicClientRegistration.RegistrationEndpointMode =
                            RegistrationEndpointMode.Inferred;

                        // Use a large chunk size for diagnostic logs in development where it will be redirected to a local file
                        if (builder.Environment.IsDevelopment())
                        {
                            options.Diagnostics.ChunkSize = 1024 * 1024 * 10; // 10 MB
                        }
                    })
                    .AddTestUsers(TestUsers.Users)
                    .AddLicenseSummary();

        isBuilder.AddConfigurationStore(options =>
        {
            options.ConfigureDbContext = b =>
                b.UseSqlite(connectionString, sql => sql.MigrationsAssembly(typeof(Program).Assembly.GetName().Name));
        });

        isBuilder.AddOperationalStore(options =>
        {
            options.ConfigureDbContext = b =>
                b.UseSqlite(connectionString, sql => sql.MigrationsAssembly(typeof(Program).Assembly.GetName().Name));
            options.EnableTokenCleanup = true;
        });

        // DCR with EF-backed client store — registered clients start disabled
        builder.Services
            .AddIdentityServerConfiguration(options => { })
            .AddClientConfigurationStore();

        builder.Services.AddScoped<IConfigurationDbContext>(sp =>
            sp.GetRequiredService<ConfigurationDbContext>());

        // Decorate the default processor so newly registered clients are disabled and get default scopes
        builder.Services.AddScoped<DynamicClientRegistrationRequestProcessor>();
        builder.Services.AddScoped<IDynamicClientRegistrationRequestProcessor, CustomDynamicClientRegistrationRequestProcessor>();

        // Background cleanup of unapproved DCR clients older than 1 hour
        builder.Services.AddHostedService<DcrCleanupService>();

        builder.Services.AddAuthentication()
            .AddOpenIdConnect("oidc", "Sign-in with demo.duendesoftware.com", options =>
            {
                options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
                options.SignOutScheme = IdentityServerConstants.SignoutScheme;
                options.SaveTokens = true;

                options.Authority = "https://demo.duendesoftware.com";
                options.ClientId = "interactive.confidential";
                options.ClientSecret = "secret";
                options.ResponseType = "code";

                options.TokenValidationParameters = new TokenValidationParameters
                {
                    NameClaimType = "name",
                    RoleClaimType = "role"
                };
            });

        return builder.Build();
    }

    public static WebApplication ConfigurePipeline(this WebApplication app)
    {
        // Must be first — rewrites scheme/host/port from X-Forwarded-* headers
        // before any middleware generates URLs (e.g., OIDC discovery, redirects)
        app.UseForwardedHeaders();

        app.UseSerilogRequestLogging();

        if (app.Environment.IsDevelopment())
        {
            app.UseDeveloperExceptionPage();
        }

        app.UseStaticFiles();
        app.UseRouting();

        // Intercept /connect/authorize for disabled clients — redirect to approval page
        // instead of letting IdentityServer return "unauthorized_client"
        app.Use(async (context, next) =>
        {
            if (context.Request.Path.StartsWithSegments("/connect/authorize")
                && context.Request.Query.TryGetValue("client_id", out var clientIdValues))
            {
                var clientId = clientIdValues.ToString();
                var configDb = context.RequestServices.GetRequiredService<ConfigurationDbContext>();
                var client = await configDb.Clients.AsNoTracking()
                    .FirstOrDefaultAsync(c => c.ClientId == clientId);

                if (client is { Enabled: false })
                {
                    var returnUrl = context.Request.GetEncodedUrl();
                    var approvalUrl = $"/ClientApproval?returnUrl={Uri.EscapeDataString(returnUrl)}";
                    context.Response.Redirect(approvalUrl);
                    return;
                }
            }

            await next();
        });

        app.UseIdentityServer();
        app.UseAuthorization();

        app.MapRazorPages()
            .RequireAuthorization();

        app.MapDynamicClientRegistration();

        return app;
    }
}

using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace IdentityServer;

public static class SeedData
{
    public static void EnsureSeedData(WebApplication app)
    {
        using var scope = app.Services.GetRequiredService<IServiceScopeFactory>().CreateScope();

        // Run migrations
        scope.ServiceProvider.GetRequiredService<PersistedGrantDbContext>().Database.Migrate();

        var configContext = scope.ServiceProvider.GetRequiredService<ConfigurationDbContext>();
        configContext.Database.Migrate();

        // Enable WAL mode for better concurrent access from Config API
        configContext.Database.ExecuteSqlRaw("PRAGMA journal_mode=WAL;");

        SeedConfigurationData(configContext);
    }

    private static void SeedConfigurationData(ConfigurationDbContext context)
    {
        if (!context.Clients.Any())
        {
            Log.Information("Seeding clients");
            foreach (var client in Config.Clients)
            {
                context.Clients.Add(client.ToEntity());
            }
            context.SaveChanges();
        }
        else
        {
            // Ensure static clients from Config are present even when DCR-created clients exist
            foreach (var client in Config.Clients)
            {
                if (!context.Clients.Any(c => c.ClientId == client.ClientId))
                {
                    Log.Information("Seeding missing client: {ClientId}", client.ClientId);
                    context.Clients.Add(client.ToEntity());
                }
            }
            context.SaveChanges();
        }

        if (!context.IdentityResources.Any())
        {
            Log.Information("Seeding identity resources");
            foreach (var resource in Config.IdentityResources)
            {
                context.IdentityResources.Add(resource.ToEntity());
            }
            context.SaveChanges();
        }

        if (!context.ApiScopes.Any())
        {
            Log.Information("Seeding API scopes");
            foreach (var scope in Config.ApiScopes)
            {
                context.ApiScopes.Add(scope.ToEntity());
            }
            context.SaveChanges();
        }

        if (!context.ApiResources.Any())
        {
            Log.Information("Seeding API resources");
            foreach (var resource in Config.ApiResources)
            {
                context.ApiResources.Add(resource.ToEntity());
            }
            context.SaveChanges();
        }
    }
}

using CircleChat.Infrastructure.Persistence;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace CircleChat.IntegrationTests;

public class BootstrapTestFactory : WebApplicationFactory<Program>
{
    private readonly string _dbName = Guid.NewGuid().ToString();
    public const string ValidBootstrapSecret = "TestRenderBootstrapSecret2026_XYZ!";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("UseInMemoryDatabase", "true");
        builder.UseSetting("InMemoryDatabaseName", _dbName);
        builder.UseSetting("Bootstrap:Secret", ValidBootstrapSecret);
    }

    protected override IHost CreateHost(IHostBuilder builder)
    {
        var host = base.CreateHost(builder);

        // Ensure the database is created with exactly ZERO users and ZERO invitations
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.Database.EnsureCreated();
        }

        return host;
    }
}

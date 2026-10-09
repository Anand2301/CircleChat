using CircleChat.Domain.Entities;
using CircleChat.Infrastructure.Persistence;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace CircleChat.IntegrationTests;

public class CircleChatTestFactory : WebApplicationFactory<Program>
{
    private readonly string _dbName = Guid.NewGuid().ToString();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("UseInMemoryDatabase", "true");
        builder.UseSetting("InMemoryDatabaseName", _dbName);
    }

    protected override IHost CreateHost(IHostBuilder builder)
    {
        var host = base.CreateHost(builder);

        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.Database.EnsureCreated();

            if (!db.Users.Any(u => u.Id == "system"))
            {
                var admin = new ApplicationUser
                {
                    Id = "system",
                    UserName = "admin@circlechat.test",
                    Email = "admin@circlechat.test",
                    DisplayName = "Admin",
                    FullName = "CircleChat Admin",
                    CreatedAt = DateTime.UtcNow
                };
                db.Users.Add(admin);
            }

            if (!db.Invitations.Any(i => i.Code == "CC-INVITE123"))
            {
                db.Invitations.Add(new Invitation
                {
                    Code = "CC-INVITE123",
                    CreatedById = "system",
                    MaxUses = 10,
                    UsedCount = 0,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                });
            }
            db.SaveChanges();
        }

        return host;
    }
}

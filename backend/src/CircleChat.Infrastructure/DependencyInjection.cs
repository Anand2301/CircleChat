using CircleChat.Application.Common.Interfaces;
using CircleChat.Domain.Entities;
using CircleChat.Infrastructure.Persistence;
using CircleChat.Infrastructure.Services;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Text;

namespace CircleChat.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Initialize Firebase Admin SDK for push notifications if configured
        InitializeFirebase(configuration);

        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? "Host=localhost;Port=5432;Database=CircleChat;Username=postgres;Password=postgres";

        if (configuration.GetValue<bool>("UseInMemoryDatabase"))
        {
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseInMemoryDatabase(configuration["InMemoryDatabaseName"] ?? "TestDb"));
        }
        else
        {
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseNpgsql(connectionString, b => b.MigrationsAssembly(typeof(ApplicationDbContext).Assembly.FullName)));
        }

        services.AddScoped<IApplicationDbContext>(provider =>
            provider.GetRequiredService<ApplicationDbContext>());

        // Identity Configuration
        services.AddIdentityCore<ApplicationUser>(options =>
        {
            options.Password.RequireDigit = false;
            options.Password.RequireLowercase = false;
            options.Password.RequireUppercase = false;
            options.Password.RequireNonAlphanumeric = false;
            options.Password.RequiredLength = 6;
            options.User.RequireUniqueEmail = true;
        })
        .AddEntityFrameworkStores<ApplicationDbContext>();

        // Core Infrastructure Services
        services.AddScoped<ITokenService, TokenService>();
        services.AddScoped<ICurrentUserService, CurrentUserService>();
        services.AddSingleton<IPresenceService, PresenceService>();
        services.AddScoped<IFileStorage, FirebaseFileStorage>();
        services.AddScoped<IPushNotificationService, FirebasePushNotificationService>();

        return services;
    }

    private static void InitializeFirebase(IConfiguration configuration)
    {
        if (FirebaseApp.DefaultInstance != null) return;

        try
        {
            GoogleCredential? credential = null;

            // 1. Direct JSON from environment variable or configuration
            var credentialsJson = Environment.GetEnvironmentVariable("FIREBASE_SERVICE_ACCOUNT_JSON")
                ?? Environment.GetEnvironmentVariable("FIREBASE_CREDENTIALS_JSON")
                ?? configuration["Firebase:CredentialsJson"];

            if (!string.IsNullOrWhiteSpace(credentialsJson))
            {
                string jsonString = credentialsJson.Trim();
                if (!jsonString.StartsWith("{") && !jsonString.StartsWith("["))
                {
                    try
                    {
                        var bytes = Convert.FromBase64String(jsonString);
                        jsonString = Encoding.UTF8.GetString(bytes);
                    }
                    catch
                    {
                        // Treat as raw string
                    }
                }

                credential = GoogleCredential.FromJson(jsonString);
            }

            // 2. File path from environment variable or configuration
            if (credential == null)
            {
                var credentialsPath = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS")
                    ?? Environment.GetEnvironmentVariable("FIREBASE_CREDENTIALS_PATH")
                    ?? configuration["Firebase:CredentialsPath"];

                if (!string.IsNullOrWhiteSpace(credentialsPath) && File.Exists(credentialsPath))
                {
                    credential = GoogleCredential.FromFile(credentialsPath);
                }
            }

            // 3. Default application credentials
            if (credential == null)
            {
                try
                {
                    credential = GoogleCredential.GetApplicationDefault();
                }
                catch
                {
                    // No default credentials found
                }
            }

            if (credential != null)
            {
                var projectId = configuration["Firebase:ProjectId"];
                var options = new AppOptions { Credential = credential };
                if (!string.IsNullOrWhiteSpace(projectId))
                {
                    options.ProjectId = projectId;
                }

                FirebaseApp.Create(options);
                Console.WriteLine("[Firebase] Admin SDK initialized successfully for push notifications.");
            }
            else
            {
                Console.WriteLine("[Firebase] No credentials configured. Push notifications will run in dev/fallback mode.");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Firebase] Initialization warning: {ex.Message}. Push notifications will run in dev/fallback mode.");
        }
    }
}

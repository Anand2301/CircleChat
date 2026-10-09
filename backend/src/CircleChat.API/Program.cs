using System.Text;
using CircleChat.API.Hubs;
using CircleChat.API.Middleware;
using CircleChat.Application.Common.Interfaces;
using CircleChat.Domain.Entities;
using CircleChat.Infrastructure;
using CircleChat.Infrastructure.Persistence;
using FastEndpoints;
using FastEndpoints.Swagger;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// 1. Serilog Setup
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .WriteTo.File("logs/circlechat-.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Host.UseSerilog();

// 2. Services Configuration
builder.Services.AddHttpContextAccessor();
builder.Services.AddInfrastructureServices(builder.Configuration);
builder.Services.AddScoped<ISignalRNotifier, SignalRNotifier>();

// 3. Authentication & JWT
var jwtSecret = builder.Configuration["Jwt:Secret"] ?? "default_very_secure_secret_key_at_least_32_characters_long_123456";
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "CircleChatAPI";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "CircleChatClients";
var key = Encoding.UTF8.GetBytes(jwtSecret);

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(key),
        ValidateIssuer = true,
        ValidIssuer = jwtIssuer,
        ValidateAudience = true,
        ValidAudience = jwtAudience,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.FromMinutes(1)
    };

    // Extract token for SignalR WebSockets
    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs/chat"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        }
    };
});

builder.Services.AddAuthorization();

// 4. FastEndpoints & Swagger
builder.Services.AddFastEndpoints();
builder.Services.SwaggerDocument(o =>
{
    o.DocumentSettings = s =>
    {
        s.Title = "CircleChat API";
        s.Version = "v1";
        s.Description = "Private, invite-only real-time chat application API";
    };
});

// 5. SignalR
builder.Services.AddSignalR();

// 6. CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.SetIsOriginAllowed(_ => true)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

var app = builder.Build();

// 7. Pipeline Configuration
app.UseMiddleware<GlobalExceptionMiddleware>();
app.UseSerilogRequestLogging();

app.UseCors("AllowAll");

// Serve static upload directory if exists
var uploadsPath = Path.Combine(app.Environment.ContentRootPath, "wwwroot", "uploads");
Directory.CreateDirectory(uploadsPath);
app.UseStaticFiles();

app.UseAuthentication();
app.UseAuthorization();

app.UseFastEndpoints();
app.UseSwaggerGen();

app.MapHub<ChatHub>("/hubs/chat");

// Apply database migrations on startup if running against a relational database
using (var scope = app.Services.CreateScope())
{
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        if (db.Database.IsRelational())
        {
            await db.Database.MigrateAsync();
            Log.Information("Database migrations applied successfully on startup.");
        }
    }
    catch (Exception ex)
    {
        Log.Warning("Database migration on startup skipped or failed: {Message}", ex.Message);
    }
}

app.Run();

// Required for IntegrationTests WebApplicationFactory
public partial class Program { }

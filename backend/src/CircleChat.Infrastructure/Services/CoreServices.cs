using System.Collections.Concurrent;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using CircleChat.Application.Common.Interfaces;
using CircleChat.Domain.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace CircleChat.Infrastructure.Services;

public class TokenService : ITokenService
{
    private readonly IConfiguration _configuration;

    public TokenService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public string GenerateAccessToken(ApplicationUser user)
    {
        var secret = _configuration["Jwt:Secret"] ?? "default_very_secure_secret_key_at_least_32_characters_long_123456";
        var issuer = _configuration["Jwt:Issuer"] ?? "CircleChatAPI";
        var audience = _configuration["Jwt:Audience"] ?? "CircleChatClients";
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id),
            new(ClaimTypes.Email, user.Email ?? string.Empty),
            new(ClaimTypes.Name, user.DisplayName ?? user.UserName ?? string.Empty),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: DateTime.UtcNow.AddHours(24),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public string GenerateRefreshToken()
    {
        var randomBytes = new byte[64];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(randomBytes);
        return Convert.ToBase64String(randomBytes);
    }

    public string HashToken(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToHexString(bytes);
    }
}

public class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUserService(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public string? UserId =>
        _httpContextAccessor.HttpContext?.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;

    public bool IsAuthenticated => !string.IsNullOrEmpty(UserId);
}

public class PresenceService : IPresenceService
{
    // UserId -> Set of active ConnectionIds
    private static readonly ConcurrentDictionary<string, ConcurrentDictionary<string, byte>> ActiveConnections = new();

    public Task SetUserOnlineAsync(string userId, string connectionId)
    {
        var connections = ActiveConnections.GetOrAdd(userId, _ => new ConcurrentDictionary<string, byte>());
        connections.TryAdd(connectionId, 0);
        return Task.CompletedTask;
    }

    public Task SetUserOfflineAsync(string userId, string connectionId)
    {
        if (ActiveConnections.TryGetValue(userId, out var connections))
        {
            connections.TryRemove(connectionId, out _);
            if (connections.IsEmpty)
            {
                ActiveConnections.TryRemove(userId, out _);
            }
        }
        return Task.CompletedTask;
    }

    public Task<bool> IsUserOnlineAsync(string userId)
    {
        var isOnline = ActiveConnections.TryGetValue(userId, out var connections) && !connections.IsEmpty;
        return Task.FromResult(isOnline);
    }

    public Task<IReadOnlyDictionary<string, bool>> GetUsersOnlineStatusAsync(IEnumerable<string> userIds)
    {
        var result = new Dictionary<string, bool>();
        foreach (var userId in userIds)
        {
            result[userId] = ActiveConnections.TryGetValue(userId, out var connections) && !connections.IsEmpty;
        }
        return Task.FromResult<IReadOnlyDictionary<string, bool>>(result);
    }
}

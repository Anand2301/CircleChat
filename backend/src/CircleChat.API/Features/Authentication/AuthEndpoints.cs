using System.Security.Claims;
using CircleChat.Application.Common.Interfaces;
using CircleChat.Application.DTOs;
using CircleChat.Application.Validation;
using CircleChat.Domain.Entities;
using FastEndpoints;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace CircleChat.API.Features.Authentication;

public class RegisterEndpoint : Endpoint<RegisterRequest, ApiResponse<AuthResponse>>
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly IApplicationDbContext _dbContext;
    private readonly ITokenService _tokenService;

    public RegisterEndpoint(
        UserManager<ApplicationUser> userManager,
        IApplicationDbContext dbContext,
        ITokenService tokenService)
    {
        _userManager = userManager;
        _dbContext = dbContext;
        _tokenService = tokenService;
    }

    public override void Configure()
    {
        Post("/api/auth/register");
        AllowAnonymous();
        Validator<RegisterRequestValidator>();
    }

    public override async Task HandleAsync(RegisterRequest req, CancellationToken ct)
    {
        // 1. Validate invitation code
        var invitation = await _dbContext.Invitations
            .FirstOrDefaultAsync(i => i.Code == req.InvitationCode, ct);

        if (invitation == null || !invitation.IsValid)
        {
            await SendResultAsync(TypedResults.BadRequest(
                ApiResponse<AuthResponse>.Fail("Invalid, inactive, or expired invitation code.")));
            return;
        }

        // 2. Check if user with email already exists
        var existingUser = await _userManager.FindByEmailAsync(req.Email);
        if (existingUser != null)
        {
            await SendResultAsync(TypedResults.BadRequest(
                ApiResponse<AuthResponse>.Fail("A user with this email address already exists.")));
            return;
        }

        // 3. Create user
        var user = new ApplicationUser
        {
            UserName = req.Email,
            Email = req.Email,
            FullName = req.FullName,
            DisplayName = req.DisplayName,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        var result = await _userManager.CreateAsync(user, req.Password);
        if (!result.Succeeded)
        {
            var errors = result.Errors.Select(e => e.Description).ToList();
            await SendResultAsync(TypedResults.BadRequest(
                ApiResponse<AuthResponse>.Fail("Failed to register user.", 400, errors)));
            return;
        }

        // 4. Update invitation usage
        invitation.UsedCount++;
        if (invitation.MaxUses > 0 && invitation.UsedCount >= invitation.MaxUses)
        {
            invitation.IsActive = false;
        }

        // 5. Generate tokens
        var accessToken = _tokenService.GenerateAccessToken(user);
        var rawRefreshToken = _tokenService.GenerateRefreshToken();
        var refreshTokenHash = _tokenService.HashToken(rawRefreshToken);

        var refreshTokenEntity = new RefreshToken
        {
            UserId = user.Id,
            TokenHash = refreshTokenHash,
            ExpiresAt = DateTime.UtcNow.AddDays(30)
        };
        _dbContext.RefreshTokens.Add(refreshTokenEntity);

        await _dbContext.SaveChangesAsync(ct);

        var response = new AuthResponse
        {
            AccessToken = accessToken,
            RefreshToken = rawRefreshToken,
            ExpiresAt = DateTime.UtcNow.AddHours(24),
            User = new UserProfileDto
            {
                Id = user.Id,
                Email = user.Email,
                FullName = user.FullName,
                DisplayName = user.DisplayName,
                Bio = user.Bio,
                ProfileImageUrl = user.ProfileImageUrl,
                IsOnline = true,
                CreatedAt = user.CreatedAt
            }
        };

        await SendOkAsync(ApiResponse<AuthResponse>.Ok(response, "Registration successful."), ct);
    }
}

public class LoginEndpoint : Endpoint<LoginRequest, ApiResponse<AuthResponse>>
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly IApplicationDbContext _dbContext;
    private readonly ITokenService _tokenService;

    public LoginEndpoint(
        UserManager<ApplicationUser> userManager,
        IApplicationDbContext dbContext,
        ITokenService tokenService)
    {
        _userManager = userManager;
        _dbContext = dbContext;
        _tokenService = tokenService;
    }

    public override void Configure()
    {
        Post("/api/auth/login");
        AllowAnonymous();
        Validator<LoginRequestValidator>();
    }

    public override async Task HandleAsync(LoginRequest req, CancellationToken ct)
    {
        var user = await _userManager.FindByEmailAsync(req.Email);
        if (user == null || !user.IsActive)
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var isPasswordValid = await _userManager.CheckPasswordAsync(user, req.Password);
        if (!isPasswordValid)
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var accessToken = _tokenService.GenerateAccessToken(user);
        var rawRefreshToken = _tokenService.GenerateRefreshToken();
        var refreshTokenHash = _tokenService.HashToken(rawRefreshToken);

        var refreshTokenEntity = new RefreshToken
        {
            UserId = user.Id,
            TokenHash = refreshTokenHash,
            ExpiresAt = DateTime.UtcNow.AddDays(30)
        };
        _dbContext.RefreshTokens.Add(refreshTokenEntity);
        await _dbContext.SaveChangesAsync(ct);

        var response = new AuthResponse
        {
            AccessToken = accessToken,
            RefreshToken = rawRefreshToken,
            ExpiresAt = DateTime.UtcNow.AddHours(24),
            User = new UserProfileDto
            {
                Id = user.Id,
                Email = user.Email ?? string.Empty,
                FullName = user.FullName,
                DisplayName = user.DisplayName,
                Bio = user.Bio,
                ProfileImageUrl = user.ProfileImageUrl,
                IsOnline = true,
                LastSeenAt = user.LastSeenAt,
                CreatedAt = user.CreatedAt
            }
        };

        await SendOkAsync(ApiResponse<AuthResponse>.Ok(response, "Login successful."), ct);
    }
}

public class RefreshTokenEndpoint : Endpoint<RefreshTokenRequest, ApiResponse<AuthResponse>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ITokenService _tokenService;
    private readonly UserManager<ApplicationUser> _userManager;

    public RefreshTokenEndpoint(
        IApplicationDbContext dbContext,
        ITokenService tokenService,
        UserManager<ApplicationUser> userManager)
    {
        _dbContext = dbContext;
        _tokenService = tokenService;
        _userManager = userManager;
    }

    public override void Configure()
    {
        Post("/api/auth/refresh");
        AllowAnonymous();
    }

    public override async Task HandleAsync(RefreshTokenRequest req, CancellationToken ct)
    {
        var tokenHash = _tokenService.HashToken(req.RefreshToken);
        var existingToken = await _dbContext.RefreshTokens
            .Include(rt => rt.User)
            .FirstOrDefaultAsync(rt => rt.TokenHash == tokenHash, ct);

        if (existingToken == null || !existingToken.IsActive)
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        // Revoke the old refresh token (Token Rotation)
        existingToken.RevokedAt = DateTime.UtcNow;

        var user = existingToken.User;
        var newAccessToken = _tokenService.GenerateAccessToken(user);
        var newRawRefreshToken = _tokenService.GenerateRefreshToken();
        var newHash = _tokenService.HashToken(newRawRefreshToken);

        _dbContext.RefreshTokens.Add(new RefreshToken
        {
            UserId = user.Id,
            TokenHash = newHash,
            ExpiresAt = DateTime.UtcNow.AddDays(30)
        });

        await _dbContext.SaveChangesAsync(ct);

        var response = new AuthResponse
        {
            AccessToken = newAccessToken,
            RefreshToken = newRawRefreshToken,
            ExpiresAt = DateTime.UtcNow.AddHours(24),
            User = new UserProfileDto
            {
                Id = user.Id,
                Email = user.Email ?? string.Empty,
                FullName = user.FullName,
                DisplayName = user.DisplayName,
                Bio = user.Bio,
                ProfileImageUrl = user.ProfileImageUrl,
                IsOnline = true,
                CreatedAt = user.CreatedAt
            }
        };

        await SendOkAsync(ApiResponse<AuthResponse>.Ok(response, "Token refreshed successfully."), ct);
    }
}

public class LogoutEndpoint : Endpoint<RefreshTokenRequest, ApiResponse<string>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ITokenService _tokenService;

    public LogoutEndpoint(IApplicationDbContext dbContext, ITokenService tokenService)
    {
        _dbContext = dbContext;
        _tokenService = tokenService;
    }

    public override void Configure()
    {
        Post("/api/auth/logout");
    }

    public override async Task HandleAsync(RefreshTokenRequest req, CancellationToken ct)
    {
        if (!string.IsNullOrEmpty(req.RefreshToken))
        {
            var hash = _tokenService.HashToken(req.RefreshToken);
            var token = await _dbContext.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash, ct);
            if (token != null)
            {
                token.RevokedAt = DateTime.UtcNow;
                await _dbContext.SaveChangesAsync(ct);
            }
        }

        await SendOkAsync(ApiResponse<string>.Ok("Logged out successfully."), ct);
    }
}

public class ChangePasswordEndpoint : Endpoint<ChangePasswordRequest, ApiResponse<string>>
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ICurrentUserService _currentUser;

    public ChangePasswordEndpoint(UserManager<ApplicationUser> userManager, ICurrentUserService currentUser)
    {
        _userManager = userManager;
        _currentUser = currentUser;
    }

    public override void Configure()
    {
        Post("/api/auth/change-password");
    }

    public override async Task HandleAsync(ChangePasswordRequest req, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (string.IsNullOrEmpty(userId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var user = await _userManager.FindByIdAsync(userId);
        if (user == null)
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var result = await _userManager.ChangePasswordAsync(user, req.CurrentPassword, req.NewPassword);
        if (!result.Succeeded)
        {
            var errors = result.Errors.Select(e => e.Description).ToList();
            await SendResultAsync(TypedResults.BadRequest(ApiResponse<string>.Fail("Failed to change password.", 400, errors)));
            return;
        }

        await SendOkAsync(ApiResponse<string>.Ok("Password changed successfully."), ct);
    }
}

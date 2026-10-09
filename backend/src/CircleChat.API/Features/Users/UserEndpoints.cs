using CircleChat.Application.Common.Interfaces;
using CircleChat.Application.DTOs;
using CircleChat.Application.Validation;
using FastEndpoints;
using Microsoft.EntityFrameworkCore;

namespace CircleChat.API.Features.Users;

public class GetProfileEndpoint : EndpointWithoutRequest<ApiResponse<UserProfileDto>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly IPresenceService _presenceService;

    public GetProfileEndpoint(
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser,
        IPresenceService presenceService)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
        _presenceService = presenceService;
    }

    public override void Configure()
    {
        Get("/api/users/me");
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (string.IsNullOrEmpty(userId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var user = await _dbContext.Users.FindAsync(new object[] { userId }, ct);
        if (user == null)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<UserProfileDto>.Fail("User profile not found.", 404)));
            return;
        }

        var isOnline = await _presenceService.IsUserOnlineAsync(user.Id);

        var dto = new UserProfileDto
        {
            Id = user.Id,
            Email = user.Email ?? string.Empty,
            FullName = user.FullName,
            DisplayName = user.DisplayName,
            Bio = user.Bio,
            ProfileImageUrl = user.ProfileImageUrl,
            IsOnline = isOnline,
            LastSeenAt = user.LastSeenAt,
            CreatedAt = user.CreatedAt
        };

        await SendOkAsync(ApiResponse<UserProfileDto>.Ok(dto), ct);
    }
}

public class UpdateProfileEndpoint : Endpoint<UpdateProfileRequest, ApiResponse<UserProfileDto>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly IPresenceService _presenceService;

    public UpdateProfileEndpoint(
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser,
        IPresenceService presenceService)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
        _presenceService = presenceService;
    }

    public override void Configure()
    {
        Put("/api/users/me");
        Validator<UpdateProfileRequestValidator>();
    }

    public override async Task HandleAsync(UpdateProfileRequest req, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (string.IsNullOrEmpty(userId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var user = await _dbContext.Users.FindAsync(new object[] { userId }, ct);
        if (user == null)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<UserProfileDto>.Fail("User profile not found.", 404)));
            return;
        }

        user.DisplayName = req.DisplayName;
        user.Bio = req.Bio;
        if (!string.IsNullOrEmpty(req.ProfileImageUrl))
        {
            user.ProfileImageUrl = req.ProfileImageUrl;
        }
        user.UpdatedAt = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync(ct);

        var isOnline = await _presenceService.IsUserOnlineAsync(user.Id);

        var dto = new UserProfileDto
        {
            Id = user.Id,
            Email = user.Email ?? string.Empty,
            FullName = user.FullName,
            DisplayName = user.DisplayName,
            Bio = user.Bio,
            ProfileImageUrl = user.ProfileImageUrl,
            IsOnline = isOnline,
            LastSeenAt = user.LastSeenAt,
            CreatedAt = user.CreatedAt
        };

        await SendOkAsync(ApiResponse<UserProfileDto>.Ok(dto, "Profile updated successfully."), ct);
    }
}

public class SearchUsersEndpoint : EndpointWithoutRequest<ApiResponse<List<UserSearchResultDto>>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly IPresenceService _presenceService;

    public SearchUsersEndpoint(
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser,
        IPresenceService presenceService)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
        _presenceService = presenceService;
    }

    public override void Configure()
    {
        Get("/api/users/search");
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var query = Query<string>("q", false)?.Trim().ToLowerInvariant() ?? string.Empty;
        var currentUserId = _currentUser.UserId;

        var usersQuery = _dbContext.Users
            .Where(u => u.IsActive && u.Id != currentUserId);

        if (!string.IsNullOrEmpty(query))
        {
            usersQuery = usersQuery.Where(u =>
                u.DisplayName.ToLower().Contains(query) ||
                u.FullName.ToLower().Contains(query) ||
                (u.Email != null && u.Email.ToLower().Contains(query)));
        }

        var users = await usersQuery
            .OrderBy(u => u.DisplayName)
            .Take(30)
            .Select(u => new
            {
                u.Id,
                u.DisplayName,
                u.FullName,
                Email = u.Email ?? string.Empty,
                u.ProfileImageUrl
            })
            .ToListAsync(ct);

        var userIds = users.Select(u => u.Id).ToList();
        var onlineMap = await _presenceService.GetUsersOnlineStatusAsync(userIds);

        var result = users.Select(u => new UserSearchResultDto
        {
            Id = u.Id,
            DisplayName = u.DisplayName,
            FullName = u.FullName,
            Email = u.Email,
            ProfileImageUrl = u.ProfileImageUrl,
            IsOnline = onlineMap.TryGetValue(u.Id, out var isOnline) && isOnline
        }).ToList();

        await SendOkAsync(ApiResponse<List<UserSearchResultDto>>.Ok(result), ct);
    }
}

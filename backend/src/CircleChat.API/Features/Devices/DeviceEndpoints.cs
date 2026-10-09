using CircleChat.Application.Common.Interfaces;
using CircleChat.Application.DTOs;
using CircleChat.Domain.Entities;
using FastEndpoints;
using Microsoft.EntityFrameworkCore;

namespace CircleChat.API.Features.Devices;

public class RegisterDeviceEndpoint : Endpoint<RegisterDeviceRequest, ApiResponse<string>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;

    public RegisterDeviceEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
    }

    public override void Configure()
    {
        Post("/api/devices");
    }

    public override async Task HandleAsync(RegisterDeviceRequest req, CancellationToken ct)
    {
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var cleanToken = req.DeviceToken.Trim();
        var existing = await _dbContext.Devices
            .FirstOrDefaultAsync(d => d.DeviceToken == cleanToken, ct);

        if (existing != null)
        {
            existing.UserId = currentUserId;
            existing.Platform = req.Platform;
            existing.LastSeenAt = DateTime.UtcNow;
            existing.IsActive = true;
        }
        else
        {
            _dbContext.Devices.Add(new Device
            {
                UserId = currentUserId,
                DeviceToken = cleanToken,
                Platform = req.Platform,
                CreatedAt = DateTime.UtcNow,
                LastSeenAt = DateTime.UtcNow,
                IsActive = true
            });
        }

        await _dbContext.SaveChangesAsync(ct);
        await SendOkAsync(ApiResponse<string>.Ok("Device registered successfully."), ct);
    }
}

public class RemoveDeviceEndpoint : EndpointWithoutRequest<ApiResponse<string>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;

    public RemoveDeviceEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
    }

    public override void Configure()
    {
        Delete("/api/devices/{token}");
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var token = Route<string>("token");
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var device = await _dbContext.Devices
            .FirstOrDefaultAsync(d => d.DeviceToken == token && d.UserId == currentUserId, ct);

        if (device != null)
        {
            device.IsActive = false;
            await _dbContext.SaveChangesAsync(ct);
        }

        await SendOkAsync(ApiResponse<string>.Ok("Device unregistered successfully."), ct);
    }
}

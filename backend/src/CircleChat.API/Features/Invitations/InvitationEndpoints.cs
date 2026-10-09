using System.Security.Cryptography;
using CircleChat.Application.Common.Interfaces;
using CircleChat.Application.DTOs;
using CircleChat.Domain.Entities;
using FastEndpoints;
using Microsoft.EntityFrameworkCore;

namespace CircleChat.API.Features.Invitations;

public class CreateInvitationEndpoint : Endpoint<CreateInvitationRequest, ApiResponse<InvitationDto>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;

    public CreateInvitationEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
    }

    public override void Configure()
    {
        Post("/api/invitations");
    }

    public override async Task HandleAsync(CreateInvitationRequest req, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (string.IsNullOrEmpty(userId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var codeBytes = new byte[8];
        RandomNumberGenerator.Fill(codeBytes);
        var code = "CC-" + Convert.ToHexString(codeBytes)[..8].ToUpperInvariant();

        var invitation = new Invitation
        {
            Code = code,
            CreatedById = userId,
            MaxUses = req.MaxUses > 0 ? req.MaxUses : 1,
            ExpiresAt = req.ExpirationDays.HasValue ? DateTime.UtcNow.AddDays(req.ExpirationDays.Value) : null,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.Invitations.Add(invitation);
        await _dbContext.SaveChangesAsync(ct);

        var user = await _dbContext.Users.FindAsync(new object[] { userId }, ct);

        var dto = new InvitationDto
        {
            Id = invitation.Id,
            Code = invitation.Code,
            CreatedById = userId,
            CreatedByDisplayName = user?.DisplayName ?? "Admin",
            ExpiresAt = invitation.ExpiresAt,
            MaxUses = invitation.MaxUses,
            UsedCount = 0,
            IsActive = true,
            CreatedAt = invitation.CreatedAt,
            IsValid = true
        };

        await SendOkAsync(ApiResponse<InvitationDto>.Ok(dto, "Invitation created successfully."), ct);
    }
}

public class ValidateInvitationEndpoint : EndpointWithoutRequest<ApiResponse<InvitationDto>>
{
    private readonly IApplicationDbContext _dbContext;

    public ValidateInvitationEndpoint(IApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public override void Configure()
    {
        Get("/api/invitations/validate/{code}");
        AllowAnonymous();
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var code = Route<string>("code");
        if (string.IsNullOrWhiteSpace(code))
        {
            await SendResultAsync(TypedResults.BadRequest(ApiResponse<InvitationDto>.Fail("Invitation code is required.")));
            return;
        }

        var invitation = await _dbContext.Invitations
            .Include(i => i.CreatedBy)
            .FirstOrDefaultAsync(i => i.Code == code, ct);

        if (invitation == null)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<InvitationDto>.Fail("Invitation not found.", 404)));
            return;
        }

        var dto = new InvitationDto
        {
            Id = invitation.Id,
            Code = invitation.Code,
            CreatedById = invitation.CreatedById,
            CreatedByDisplayName = invitation.CreatedBy?.DisplayName ?? "Admin",
            ExpiresAt = invitation.ExpiresAt,
            MaxUses = invitation.MaxUses,
            UsedCount = invitation.UsedCount,
            IsActive = invitation.IsActive,
            CreatedAt = invitation.CreatedAt,
            IsValid = invitation.IsValid
        };

        await SendOkAsync(ApiResponse<InvitationDto>.Ok(dto), ct);
    }
}

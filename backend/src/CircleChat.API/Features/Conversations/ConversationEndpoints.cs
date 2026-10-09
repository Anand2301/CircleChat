using CircleChat.Application.Common.Interfaces;
using CircleChat.Application.DTOs;
using CircleChat.Application.Validation;
using CircleChat.Domain.Entities;
using CircleChat.Domain.Enums;
using FastEndpoints;
using Microsoft.EntityFrameworkCore;

namespace CircleChat.API.Features.Conversations;

public class CreateDirectConversationEndpoint : Endpoint<CreateDirectConversationRequest, ApiResponse<ConversationDto>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly IPresenceService _presenceService;

    public CreateDirectConversationEndpoint(
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
        Post("/api/conversations/direct");
    }

    public override async Task HandleAsync(CreateDirectConversationRequest req, CancellationToken ct)
    {
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        if (currentUserId == req.OtherUserId)
        {
            await SendResultAsync(TypedResults.BadRequest(ApiResponse<ConversationDto>.Fail("Cannot create a direct conversation with yourself.")));
            return;
        }

        var otherUser = await _dbContext.Users.FindAsync(new object[] { req.OtherUserId }, ct);
        if (otherUser == null || !otherUser.IsActive)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<ConversationDto>.Fail("Target user not found.", 404)));
            return;
        }

        // Check if direct conversation already exists between these 2 users
        var existingConvId = await _dbContext.ConversationMembers
            .Where(m => (m.UserId == currentUserId || m.UserId == req.OtherUserId) && m.Conversation.Type == ConversationType.Direct && m.IsActive)
            .GroupBy(m => m.ConversationId)
            .Where(g => g.Count() == 2)
            .Select(g => g.Key)
            .FirstOrDefaultAsync(ct);

        if (existingConvId != Guid.Empty)
        {
            var existingConv = await GetConversationDto(existingConvId, currentUserId, ct);
            await SendOkAsync(ApiResponse<ConversationDto>.Ok(existingConv, "Direct conversation already exists."), ct);
            return;
        }

        var conv = new Conversation
        {
            Type = ConversationType.Direct,
            CreatedById = currentUserId,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        conv.Members.Add(new ConversationMember
        {
            UserId = currentUserId,
            Role = MemberRole.Owner,
            JoinedAt = DateTime.UtcNow,
            IsActive = true
        });

        conv.Members.Add(new ConversationMember
        {
            UserId = req.OtherUserId,
            Role = MemberRole.Member,
            JoinedAt = DateTime.UtcNow,
            IsActive = true
        });

        _dbContext.Conversations.Add(conv);
        await _dbContext.SaveChangesAsync(ct);

        var dto = await GetConversationDto(conv.Id, currentUserId, ct);
        await SendOkAsync(ApiResponse<ConversationDto>.Ok(dto, "Direct conversation created."), ct);
    }

    private async Task<ConversationDto> GetConversationDto(Guid conversationId, string currentUserId, CancellationToken ct)
    {
        var conv = await _dbContext.Conversations
            .Include(c => c.Members).ThenInclude(m => m.User)
            .Include(c => c.Messages.OrderByDescending(m => m.CreatedAt).Take(1))
            .FirstAsync(c => c.Id == conversationId, ct);

        var otherMember = conv.Members.FirstOrDefault(m => m.UserId != currentUserId);
        var isOnline = otherMember != null && await _presenceService.IsUserOnlineAsync(otherMember.UserId);

        return new ConversationDto
        {
            Id = conv.Id,
            Type = conv.Type,
            Name = conv.Type == ConversationType.Direct ? otherMember?.User?.DisplayName : conv.Name,
            ImageUrl = conv.Type == ConversationType.Direct ? otherMember?.User?.ProfileImageUrl : null,
            CreatedAt = conv.CreatedAt,
            UpdatedAt = conv.UpdatedAt,
            Members = conv.Members.Select(m => new ConversationMemberDto
            {
                UserId = m.UserId,
                DisplayName = m.User.DisplayName,
                ProfileImageUrl = m.User.ProfileImageUrl,
                Role = m.Role,
                JoinedAt = m.JoinedAt,
                IsOnline = m.UserId == otherMember?.UserId ? isOnline : false
            }).ToList()
        };
    }
}

public class CreateGroupConversationEndpoint : Endpoint<CreateGroupConversationRequest, ApiResponse<ConversationDto>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;

    public CreateGroupConversationEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
    }

    public override void Configure()
    {
        Post("/api/conversations/group");
        Validator<CreateGroupConversationRequestValidator>();
    }

    public override async Task HandleAsync(CreateGroupConversationRequest req, CancellationToken ct)
    {
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var conv = new Conversation
        {
            Type = ConversationType.Group,
            Name = req.Name,
            Description = req.Description,
            CreatedById = currentUserId,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        // Add creator as Owner
        conv.Members.Add(new ConversationMember
        {
            UserId = currentUserId,
            Role = MemberRole.Owner,
            JoinedAt = DateTime.UtcNow,
            IsActive = true
        });

        // Add invited members
        var distinctIds = req.MemberUserIds.Distinct().Where(id => id != currentUserId).ToList();
        var existingUsers = await _dbContext.Users.Where(u => distinctIds.Contains(u.Id) && u.IsActive).ToListAsync(ct);

        foreach (var user in existingUsers)
        {
            conv.Members.Add(new ConversationMember
            {
                UserId = user.Id,
                Role = MemberRole.Member,
                JoinedAt = DateTime.UtcNow,
                IsActive = true
            });
        }

        _dbContext.Conversations.Add(conv);
        await _dbContext.SaveChangesAsync(ct);

        var dto = new ConversationDto
        {
            Id = conv.Id,
            Type = conv.Type,
            Name = conv.Name,
            Description = conv.Description,
            CreatedAt = conv.CreatedAt,
            UpdatedAt = conv.UpdatedAt,
            Members = conv.Members.Select(m => new ConversationMemberDto
            {
                UserId = m.UserId,
                Role = m.Role,
                JoinedAt = m.JoinedAt
            }).ToList()
        };

        await SendOkAsync(ApiResponse<ConversationDto>.Ok(dto, "Group created successfully."), ct);
    }
}

public class GetConversationsEndpoint : EndpointWithoutRequest<ApiResponse<List<ConversationDto>>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly IPresenceService _presenceService;

    public GetConversationsEndpoint(
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
        Get("/api/conversations");
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var conversations = await _dbContext.ConversationMembers
            .Where(m => m.UserId == currentUserId && m.IsActive)
            .Include(m => m.Conversation).ThenInclude(c => c.Members).ThenInclude(cm => cm.User)
            .Include(m => m.Conversation).ThenInclude(c => c.Messages.OrderByDescending(msg => msg.CreatedAt).Take(1))
            .OrderByDescending(m => m.Conversation.UpdatedAt)
            .Select(m => m.Conversation)
            .ToListAsync(ct);

        var allOtherUserIds = conversations
            .SelectMany(c => c.Members.Where(cm => cm.UserId != currentUserId).Select(cm => cm.UserId))
            .Distinct()
            .ToList();

        var onlineMap = await _presenceService.GetUsersOnlineStatusAsync(allOtherUserIds);

        var result = new List<ConversationDto>();

        foreach (var conv in conversations)
        {
            var otherMember = conv.Type == ConversationType.Direct
                ? conv.Members.FirstOrDefault(m => m.UserId != currentUserId)
                : null;

            var lastMsg = conv.Messages.FirstOrDefault();
            MessageDto? lastMessageDto = null;
            if (lastMsg != null)
            {
                var sender = conv.Members.FirstOrDefault(m => m.UserId == lastMsg.SenderId)?.User;
                lastMessageDto = new MessageDto
                {
                    Id = lastMsg.Id,
                    ConversationId = lastMsg.ConversationId,
                    SenderId = lastMsg.SenderId,
                    SenderDisplayName = sender?.DisplayName ?? "Someone",
                    Content = lastMsg.DeletedAt.HasValue ? "This message was deleted." : lastMsg.Content,
                    MessageType = lastMsg.MessageType,
                    CreatedAt = lastMsg.CreatedAt,
                    IsDeleted = lastMsg.DeletedAt.HasValue
                };
            }

            var unreadCount = await _dbContext.Messages
                .Where(m => m.ConversationId == conv.Id && m.SenderId != currentUserId && m.DeletedAt == null &&
                            !_dbContext.MessageReads.Any(r => r.MessageId == m.Id && r.UserId == currentUserId))
                .CountAsync(ct);

            result.Add(new ConversationDto
            {
                Id = conv.Id,
                Type = conv.Type,
                Name = conv.Type == ConversationType.Direct ? otherMember?.User?.DisplayName : conv.Name,
                Description = conv.Description,
                ImageUrl = conv.Type == ConversationType.Direct ? otherMember?.User?.ProfileImageUrl : null,
                CreatedAt = conv.CreatedAt,
                UpdatedAt = conv.UpdatedAt,
                LastMessage = lastMessageDto,
                UnreadCount = unreadCount,
                Members = conv.Members.Select(m => new ConversationMemberDto
                {
                    UserId = m.UserId,
                    DisplayName = m.User?.DisplayName ?? string.Empty,
                    ProfileImageUrl = m.User?.ProfileImageUrl,
                    Role = m.Role,
                    JoinedAt = m.JoinedAt,
                    IsOnline = onlineMap.TryGetValue(m.UserId, out var isOnline) && isOnline
                }).ToList()
            });
        }

        await SendOkAsync(ApiResponse<List<ConversationDto>>.Ok(result), ct);
    }
}

public class GetConversationEndpoint : EndpointWithoutRequest<ApiResponse<ConversationDto>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly IPresenceService _presenceService;

    public GetConversationEndpoint(
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
        Get("/api/conversations/{id}");
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var convId = Route<Guid>("id");
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var isMember = await _dbContext.ConversationMembers
            .AnyAsync(m => m.ConversationId == convId && m.UserId == currentUserId && m.IsActive, ct);

        if (!isMember)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<ConversationDto>.Fail("Conversation not found or access denied.", 404)));
            return;
        }

        var conv = await _dbContext.Conversations
            .Include(c => c.Members).ThenInclude(m => m.User)
            .FirstOrDefaultAsync(c => c.Id == convId, ct);

        if (conv == null)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<ConversationDto>.Fail("Conversation not found.", 404)));
            return;
        }

        var otherMember = conv.Type == ConversationType.Direct ? conv.Members.FirstOrDefault(m => m.UserId != currentUserId) : null;
        var userIds = conv.Members.Select(m => m.UserId).ToList();
        var onlineMap = await _presenceService.GetUsersOnlineStatusAsync(userIds);

        var dto = new ConversationDto
        {
            Id = conv.Id,
            Type = conv.Type,
            Name = conv.Type == ConversationType.Direct ? otherMember?.User?.DisplayName : conv.Name,
            Description = conv.Description,
            ImageUrl = conv.Type == ConversationType.Direct ? otherMember?.User?.ProfileImageUrl : null,
            CreatedAt = conv.CreatedAt,
            UpdatedAt = conv.UpdatedAt,
            Members = conv.Members.Select(m => new ConversationMemberDto
            {
                UserId = m.UserId,
                DisplayName = m.User?.DisplayName ?? string.Empty,
                ProfileImageUrl = m.User?.ProfileImageUrl,
                Role = m.Role,
                JoinedAt = m.JoinedAt,
                IsOnline = onlineMap.TryGetValue(m.UserId, out var isOnline) && isOnline
            }).ToList()
        };

        await SendOkAsync(ApiResponse<ConversationDto>.Ok(dto), ct);
    }
}

public class AddMemberEndpoint : Endpoint<AddMemberRequest, ApiResponse<string>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;

    public AddMemberEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
    }

    public override void Configure()
    {
        Post("/api/conversations/{id}/members");
    }

    public override async Task HandleAsync(AddMemberRequest req, CancellationToken ct)
    {
        var convId = Route<Guid>("id");
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var callerMember = await _dbContext.ConversationMembers
            .FirstOrDefaultAsync(m => m.ConversationId == convId && m.UserId == currentUserId && m.IsActive, ct);

        if (callerMember == null || (callerMember.Role != MemberRole.Admin && callerMember.Role != MemberRole.Owner))
        {
            await SendResultAsync(TypedResults.Forbid());
            return;
        }

        var existing = await _dbContext.ConversationMembers
            .FirstOrDefaultAsync(m => m.ConversationId == convId && m.UserId == req.UserId, ct);

        if (existing != null)
        {
            existing.IsActive = true;
            existing.Role = req.Role;
            existing.LeftAt = null;
        }
        else
        {
            _dbContext.ConversationMembers.Add(new ConversationMember
            {
                ConversationId = convId,
                UserId = req.UserId,
                Role = req.Role,
                JoinedAt = DateTime.UtcNow,
                IsActive = true
            });
        }

        await _dbContext.SaveChangesAsync(ct);
        await SendOkAsync(ApiResponse<string>.Ok("Member added successfully."), ct);
    }
}

public class RemoveMemberEndpoint : EndpointWithoutRequest<ApiResponse<string>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;

    public RemoveMemberEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
    }

    public override void Configure()
    {
        Delete("/api/conversations/{id}/members/{userId}");
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var convId = Route<Guid>("id");
        var targetUserId = Route<string>("userId");
        var currentUserId = _currentUser.UserId;

        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var callerMember = await _dbContext.ConversationMembers
            .FirstOrDefaultAsync(m => m.ConversationId == convId && m.UserId == currentUserId && m.IsActive, ct);

        if (callerMember == null || (callerMember.Role != MemberRole.Admin && callerMember.Role != MemberRole.Owner))
        {
            await SendResultAsync(TypedResults.Forbid());
            return;
        }

        var targetMember = await _dbContext.ConversationMembers
            .FirstOrDefaultAsync(m => m.ConversationId == convId && m.UserId == targetUserId, ct);

        if (targetMember != null)
        {
            targetMember.IsActive = false;
            targetMember.LeftAt = DateTime.UtcNow;
            await _dbContext.SaveChangesAsync(ct);
        }

        await SendOkAsync(ApiResponse<string>.Ok("Member removed successfully."), ct);
    }
}

public class LeaveConversationEndpoint : EndpointWithoutRequest<ApiResponse<string>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;

    public LeaveConversationEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
    }

    public override void Configure()
    {
        Post("/api/conversations/{id}/leave");
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var convId = Route<Guid>("id");
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var member = await _dbContext.ConversationMembers
            .FirstOrDefaultAsync(m => m.ConversationId == convId && m.UserId == currentUserId, ct);

        if (member != null)
        {
            member.IsActive = false;
            member.LeftAt = DateTime.UtcNow;
            await _dbContext.SaveChangesAsync(ct);
        }

        await SendOkAsync(ApiResponse<string>.Ok("Left conversation successfully."), ct);
    }
}

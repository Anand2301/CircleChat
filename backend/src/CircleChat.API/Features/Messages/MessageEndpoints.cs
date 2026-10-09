using CircleChat.Application.Common.Interfaces;
using CircleChat.Application.DTOs;
using CircleChat.Application.Validation;
using CircleChat.Domain.Entities;
using CircleChat.Domain.Enums;
using FastEndpoints;
using Microsoft.EntityFrameworkCore;

namespace CircleChat.API.Features.Messages;

public class GetMessagesEndpoint : EndpointWithoutRequest<ApiResponse<List<MessageDto>>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;

    public GetMessagesEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
    }

    public override void Configure()
    {
        Get("/api/conversations/{id}/messages");
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

        // Validate conversation membership
        var isMember = await _dbContext.ConversationMembers
            .AnyAsync(m => m.ConversationId == convId && m.UserId == currentUserId && m.IsActive, ct);

        if (!isMember)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<List<MessageDto>>.Fail("Conversation not found or access denied.", 404)));
            return;
        }

        var beforeCursor = Query<Guid?>("before", false);
        var limit = Math.Clamp(Query<int?>("limit", false) ?? 50, 1, 100);

        DateTime? cursorCreatedAt = null;
        if (beforeCursor.HasValue)
        {
            var cursorMsg = await _dbContext.Messages.FindAsync(new object[] { beforeCursor.Value }, ct);
            if (cursorMsg != null)
            {
                cursorCreatedAt = cursorMsg.CreatedAt;
            }
        }

        var query = _dbContext.Messages
            .Where(m => m.ConversationId == convId);

        if (cursorCreatedAt.HasValue && beforeCursor.HasValue)
        {
            query = query.Where(m => m.CreatedAt < cursorCreatedAt.Value ||
                                     (m.CreatedAt == cursorCreatedAt.Value && m.Id < beforeCursor.Value));
        }

        var messages = await query
            .OrderByDescending(m => m.CreatedAt)
            .ThenByDescending(m => m.Id)
            .Take(limit)
            .Include(m => m.Sender)
            .Include(m => m.ReplyToMessage).ThenInclude(r => r!.Sender)
            .Include(m => m.Attachments)
            .Include(m => m.Reactions).ThenInclude(r => r.User)
            .Include(m => m.Reads)
            .ToListAsync(ct);

        var dtos = messages.Select(m => MapToDto(m, currentUserId)).ToList();
        await SendOkAsync(ApiResponse<List<MessageDto>>.Ok(dtos), ct);
    }

    private static MessageDto MapToDto(Message m, string currentUserId)
    {
        var isDeleted = m.DeletedAt != null;
        var hasOtherReads = m.Reads.Any(r => r.UserId != m.SenderId);

        return new MessageDto
        {
            Id = m.Id,
            ConversationId = m.ConversationId,
            SenderId = m.SenderId,
            SenderDisplayName = m.Sender?.DisplayName ?? "User",
            SenderProfileImageUrl = m.Sender?.ProfileImageUrl,
            Content = isDeleted ? "This message was deleted." : m.Content,
            MessageType = m.MessageType,
            ReplyToMessageId = m.ReplyToMessageId,
            ReplyToMessage = m.ReplyToMessage != null ? new MessageDto
            {
                Id = m.ReplyToMessage.Id,
                SenderDisplayName = m.ReplyToMessage.Sender?.DisplayName ?? "User",
                Content = m.ReplyToMessage.DeletedAt != null ? "This message was deleted." : m.ReplyToMessage.Content
            } : null,
            CreatedAt = m.CreatedAt,
            UpdatedAt = m.UpdatedAt,
            IsDeleted = isDeleted,
            DeliveryStatus = hasOtherReads ? 2 : 1, // 1 = Delivered, 2 = Read
            Reactions = m.Reactions.Select(r => new MessageReactionDto
            {
                Id = r.Id,
                UserId = r.UserId,
                DisplayName = r.User?.DisplayName ?? "User",
                Reaction = r.Reaction,
                CreatedAt = r.CreatedAt
            }).ToList(),
            Attachments = m.Attachments.Select(a => new AttachmentDto
            {
                Id = a.Id,
                FileName = a.FileName,
                StoragePath = a.StoragePath,
                DownloadUrl = a.StoragePath,
                ContentType = a.ContentType,
                FileSize = a.FileSize
            }).ToList()
        };
    }
}

public class SendMessageEndpoint : Endpoint<SendMessageRequest, ApiResponse<MessageDto>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly ISignalRNotifier _notifier;
    private readonly IPushNotificationService _pushService;

    public SendMessageEndpoint(
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser,
        ISignalRNotifier notifier,
        IPushNotificationService pushService)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
        _notifier = notifier;
        _pushService = pushService;
    }

    public override void Configure()
    {
        Post("/api/conversations/{id}/messages");
        Validator<SendMessageRequestValidator>();
    }

    public override async Task HandleAsync(SendMessageRequest req, CancellationToken ct)
    {
        var convId = Route<Guid>("id");
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        // 1. Validate conversation membership
        var isMember = await _dbContext.ConversationMembers
            .AnyAsync(m => m.ConversationId == convId && m.UserId == currentUserId && m.IsActive, ct);

        if (!isMember)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<MessageDto>.Fail("Conversation not found or access denied.", 404)));
            return;
        }

        // 2. Validate optional reply message
        if (req.ReplyToMessageId.HasValue)
        {
            var replyExists = await _dbContext.Messages
                .AnyAsync(m => m.Id == req.ReplyToMessageId.Value && m.ConversationId == convId, ct);

            if (!replyExists)
            {
                req.ReplyToMessageId = null;
            }
        }

        // 3. Create message
        var message = new Message
        {
            ConversationId = convId,
            SenderId = currentUserId,
            Content = req.Content.Trim(),
            MessageType = req.MessageType,
            ReplyToMessageId = req.ReplyToMessageId,
            CreatedAt = DateTime.UtcNow
        };

        // Attach existing uploaded attachments if any
        if (req.AttachmentIds != null && req.AttachmentIds.Count > 0)
        {
            var attachments = await _dbContext.Attachments
                .Where(a => req.AttachmentIds.Contains(a.Id))
                .ToListAsync(ct);

            foreach (var att in attachments)
            {
                att.MessageId = message.Id;
            }
        }

        _dbContext.Messages.Add(message);

        // Update conversation UpdatedAt
        var conv = await _dbContext.Conversations.FindAsync(new object[] { convId }, ct);
        if (conv != null)
        {
            conv.UpdatedAt = DateTime.UtcNow;
        }

        await _dbContext.SaveChangesAsync(ct);

        // Load details for DTO
        var sender = await _dbContext.Users.FindAsync(new object[] { currentUserId }, ct);
        var replyMsg = req.ReplyToMessageId.HasValue
            ? await _dbContext.Messages.Include(m => m.Sender).FirstOrDefaultAsync(m => m.Id == req.ReplyToMessageId.Value, ct)
            : null;

        var messageDto = new MessageDto
        {
            Id = message.Id,
            ConversationId = message.ConversationId,
            SenderId = currentUserId,
            SenderDisplayName = sender?.DisplayName ?? "Me",
            SenderProfileImageUrl = sender?.ProfileImageUrl,
            Content = message.Content,
            MessageType = message.MessageType,
            ReplyToMessageId = message.ReplyToMessageId,
            ReplyToMessage = replyMsg != null ? new MessageDto
            {
                Id = replyMsg.Id,
                SenderDisplayName = replyMsg.Sender?.DisplayName ?? "User",
                Content = replyMsg.Content
            } : null,
            CreatedAt = message.CreatedAt,
            DeliveryStatus = 0
        };

        // 4. Real-time broadcast via SignalR
        await _notifier.NotifyNewMessageAsync(convId, messageDto);

        // 5. Firebase Cloud Messaging (Push notifications to other conversation members)
        var recipientUserIds = await _dbContext.ConversationMembers
            .Where(m => m.ConversationId == convId && m.UserId != currentUserId && m.IsActive)
            .Select(m => m.UserId)
            .ToListAsync(ct);

        var deviceTokens = await _dbContext.Devices
            .Where(d => recipientUserIds.Contains(d.UserId) && d.IsActive)
            .Select(d => d.DeviceToken)
            .ToListAsync(ct);

        if (deviceTokens.Any())
        {
            var preview = message.MessageType == MessageType.Text
                ? (message.Content.Length > 80 ? message.Content[..80] + "..." : message.Content)
                : $"Sent a {message.MessageType.ToString().ToLower()}";

            var pushData = new Dictionary<string, string>
            {
                { "conversationId", convId.ToString() },
                { "messageId", message.Id.ToString() }
            };

            await _pushService.SendMulticastNotificationAsync(
                deviceTokens,
                sender?.DisplayName ?? "CircleChat",
                preview,
                pushData,
                ct);
        }

        await SendOkAsync(ApiResponse<MessageDto>.Ok(messageDto), ct);
    }
}

public class EditMessageEndpoint : Endpoint<EditMessageRequest, ApiResponse<string>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly ISignalRNotifier _notifier;

    public EditMessageEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser, ISignalRNotifier notifier)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
        _notifier = notifier;
    }

    public override void Configure()
    {
        Put("/api/messages/{id}");
        Validator<EditMessageRequestValidator>();
    }

    public override async Task HandleAsync(EditMessageRequest req, CancellationToken ct)
    {
        var msgId = Route<Guid>("id");
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var message = await _dbContext.Messages.FindAsync(new object[] { msgId }, ct);
        if (message == null || message.DeletedAt != null)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<string>.Fail("Message not found.", 404)));
            return;
        }

        if (message.SenderId != currentUserId)
        {
            await SendResultAsync(TypedResults.Forbid());
            return;
        }

        message.Content = req.Content.Trim();
        message.UpdatedAt = DateTime.UtcNow;
        await _dbContext.SaveChangesAsync(ct);

        await _notifier.NotifyMessageEditedAsync(message.ConversationId, message.Id, message.Content, message.UpdatedAt.Value);
        await SendOkAsync(ApiResponse<string>.Ok("Message updated successfully."), ct);
    }
}

public class DeleteMessageEndpoint : EndpointWithoutRequest<ApiResponse<string>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly ISignalRNotifier _notifier;

    public DeleteMessageEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser, ISignalRNotifier notifier)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
        _notifier = notifier;
    }

    public override void Configure()
    {
        Delete("/api/messages/{id}");
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var msgId = Route<Guid>("id");
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var message = await _dbContext.Messages.FindAsync(new object[] { msgId }, ct);
        if (message == null)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<string>.Fail("Message not found.", 404)));
            return;
        }

        if (message.SenderId != currentUserId)
        {
            await SendResultAsync(TypedResults.Forbid());
            return;
        }

        message.DeletedAt = DateTime.UtcNow;
        await _dbContext.SaveChangesAsync(ct);

        await _notifier.NotifyMessageDeletedAsync(message.ConversationId, message.Id);
        await SendOkAsync(ApiResponse<string>.Ok("Message deleted."), ct);
    }
}

public class AddReactionEndpoint : Endpoint<AddReactionRequest, ApiResponse<string>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly ISignalRNotifier _notifier;

    public AddReactionEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser, ISignalRNotifier notifier)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
        _notifier = notifier;
    }

    public override void Configure()
    {
        Post("/api/messages/{id}/reactions");
    }

    public override async Task HandleAsync(AddReactionRequest req, CancellationToken ct)
    {
        var msgId = Route<Guid>("id");
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var message = await _dbContext.Messages.FindAsync(new object[] { msgId }, ct);
        if (message == null || message.DeletedAt != null)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<string>.Fail("Message not found.", 404)));
            return;
        }

        var isMember = await _dbContext.ConversationMembers
            .AnyAsync(m => m.ConversationId == message.ConversationId && m.UserId == currentUserId && m.IsActive, ct);

        if (!isMember)
        {
            await SendResultAsync(TypedResults.Forbid());
            return;
        }

        var cleanReaction = req.Reaction.Trim();
        var existing = await _dbContext.MessageReactions
            .FirstOrDefaultAsync(r => r.MessageId == msgId && r.UserId == currentUserId && r.Reaction == cleanReaction, ct);

        if (existing == null)
        {
            _dbContext.MessageReactions.Add(new MessageReaction
            {
                MessageId = msgId,
                UserId = currentUserId,
                Reaction = cleanReaction,
                CreatedAt = DateTime.UtcNow
            });
            await _dbContext.SaveChangesAsync(ct);
            await _notifier.NotifyReactionUpdatedAsync(message.ConversationId, message.Id, cleanReaction, currentUserId, true);
        }

        await SendOkAsync(ApiResponse<string>.Ok("Reaction added."), ct);
    }
}

public class RemoveReactionEndpoint : EndpointWithoutRequest<ApiResponse<string>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly ISignalRNotifier _notifier;

    public RemoveReactionEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser, ISignalRNotifier notifier)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
        _notifier = notifier;
    }

    public override void Configure()
    {
        Delete("/api/messages/{id}/reactions/{reaction}");
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var msgId = Route<Guid>("id");
        var reactionStr = Route<string>("reaction") ?? string.Empty;
        var currentUserId = _currentUser.UserId;

        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var message = await _dbContext.Messages.FindAsync(new object[] { msgId }, ct);
        if (message == null)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<string>.Fail("Message not found.", 404)));
            return;
        }

        var reaction = await _dbContext.MessageReactions
            .FirstOrDefaultAsync(r => r.MessageId == msgId && r.UserId == currentUserId && r.Reaction == reactionStr, ct);

        if (reaction != null)
        {
            _dbContext.MessageReactions.Remove(reaction);
            await _dbContext.SaveChangesAsync(ct);
            await _notifier.NotifyReactionUpdatedAsync(message.ConversationId, message.Id, reactionStr, currentUserId, false);
        }

        await SendOkAsync(ApiResponse<string>.Ok("Reaction removed."), ct);
    }
}

public class MarkMessageReadEndpoint : EndpointWithoutRequest<ApiResponse<string>>
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly ISignalRNotifier _notifier;

    public MarkMessageReadEndpoint(IApplicationDbContext dbContext, ICurrentUserService currentUser, ISignalRNotifier notifier)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
        _notifier = notifier;
    }

    public override void Configure()
    {
        Post("/api/messages/{id}/read");
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var msgId = Route<Guid>("id");
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        var message = await _dbContext.Messages.FindAsync(new object[] { msgId }, ct);
        if (message == null)
        {
            await SendResultAsync(TypedResults.NotFound(ApiResponse<string>.Fail("Message not found.", 404)));
            return;
        }

        var alreadyRead = await _dbContext.MessageReads
            .AnyAsync(r => r.MessageId == msgId && r.UserId == currentUserId, ct);

        if (!alreadyRead)
        {
            var now = DateTime.UtcNow;
            _dbContext.MessageReads.Add(new MessageRead
            {
                MessageId = msgId,
                UserId = currentUserId,
                ReadAt = now
            });
            await _dbContext.SaveChangesAsync(ct);
            await _notifier.NotifyMessageReadAsync(message.ConversationId, message.Id, currentUserId, now);
        }

        await SendOkAsync(ApiResponse<string>.Ok("Marked as read."), ct);
    }
}

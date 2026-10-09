using System.Security.Claims;
using CircleChat.Application.Common.Interfaces;
using CircleChat.Domain.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace CircleChat.API.Hubs;

[Authorize]
public class ChatHub : Hub
{
    private readonly IPresenceService _presenceService;
    private readonly IApplicationDbContext _dbContext;

    public ChatHub(IPresenceService presenceService, IApplicationDbContext dbContext)
    {
        _presenceService = presenceService;
        _dbContext = dbContext;
    }

    private string? CurrentUserId => Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;

    public override async Task OnConnectedAsync()
    {
        var userId = CurrentUserId;
        if (!string.IsNullOrEmpty(userId))
        {
            await _presenceService.SetUserOnlineAsync(userId, Context.ConnectionId);
            await Groups.AddToGroupAsync(Context.ConnectionId, $"user_{userId}");

            // Notify all clients of online presence
            await Clients.Others.SendAsync("UserPresenceChanged", userId, true, DateTime.UtcNow);
        }

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = CurrentUserId;
        if (!string.IsNullOrEmpty(userId))
        {
            await _presenceService.SetUserOfflineAsync(userId, Context.ConnectionId);
            var isStillOnline = await _presenceService.IsUserOnlineAsync(userId);
            if (!isStillOnline)
            {
                var now = DateTime.UtcNow;
                var user = await _dbContext.Users.FindAsync(userId);
                if (user != null)
                {
                    user.LastSeenAt = now;
                    await _dbContext.SaveChangesAsync();
                }

                await Clients.Others.SendAsync("UserPresenceChanged", userId, false, now);
            }
        }

        await base.OnDisconnectedAsync(exception);
    }

    public async Task JoinConversation(Guid conversationId)
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return;

        // Verify membership
        var isMember = await _dbContext.ConversationMembers
            .AnyAsync(m => m.ConversationId == conversationId && m.UserId == userId && m.IsActive);

        if (isMember)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"conv_{conversationId}");
        }
    }

    public async Task LeaveConversation(Guid conversationId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"conv_{conversationId}");
    }

    public async Task StartTyping(Guid conversationId)
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return;

        var displayName = Context.User?.FindFirst(ClaimTypes.Name)?.Value ?? "Someone";
        await Clients.Group($"conv_{conversationId}").SendAsync("UserTyping", conversationId, userId, displayName, true);
    }

    public async Task StopTyping(Guid conversationId)
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return;

        var displayName = Context.User?.FindFirst(ClaimTypes.Name)?.Value ?? "Someone";
        await Clients.Group($"conv_{conversationId}").SendAsync("UserTyping", conversationId, userId, displayName, false);
    }
}

public class SignalRNotifier : ISignalRNotifier
{
    private readonly IHubContext<ChatHub> _hubContext;

    public SignalRNotifier(IHubContext<ChatHub> hubContext)
    {
        _hubContext = hubContext;
    }

    public Task NotifyNewMessageAsync(Guid conversationId, object messageDto) =>
        _hubContext.Clients.Group($"conv_{conversationId}").SendAsync("ReceiveMessage", messageDto);

    public Task NotifyMessageEditedAsync(Guid conversationId, Guid messageId, string newContent, DateTime updatedAt) =>
        _hubContext.Clients.Group($"conv_{conversationId}").SendAsync("MessageEdited", messageId, newContent, updatedAt);

    public Task NotifyMessageDeletedAsync(Guid conversationId, Guid messageId) =>
        _hubContext.Clients.Group($"conv_{conversationId}").SendAsync("MessageDeleted", messageId);

    public Task NotifyReactionUpdatedAsync(Guid conversationId, Guid messageId, string reaction, string userId, bool added) =>
        _hubContext.Clients.Group($"conv_{conversationId}").SendAsync("ReactionUpdated", messageId, reaction, userId, added);

    public Task NotifyUserTypingAsync(Guid conversationId, string userId, string displayName, bool isTyping) =>
        _hubContext.Clients.Group($"conv_{conversationId}").SendAsync("UserTyping", conversationId, userId, displayName, isTyping);

    public Task NotifyPresenceChangedAsync(string userId, bool isOnline, DateTime? lastSeenAt) =>
        _hubContext.Clients.All.SendAsync("UserPresenceChanged", userId, isOnline, lastSeenAt);

    public Task NotifyMessageReadAsync(Guid conversationId, Guid messageId, string userId, DateTime readAt) =>
        _hubContext.Clients.Group($"conv_{conversationId}").SendAsync("MessageRead", messageId, userId, readAt);
}

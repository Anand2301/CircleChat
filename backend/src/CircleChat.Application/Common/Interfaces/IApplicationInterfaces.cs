using CircleChat.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace CircleChat.Application.Common.Interfaces;

public interface IApplicationDbContext
{
    DbSet<ApplicationUser> Users { get; }
    DbSet<Conversation> Conversations { get; }
    DbSet<ConversationMember> ConversationMembers { get; }
    DbSet<Message> Messages { get; }
    DbSet<MessageRead> MessageReads { get; }
    DbSet<MessageReaction> MessageReactions { get; }
    DbSet<Attachment> Attachments { get; }
    DbSet<RefreshToken> RefreshTokens { get; }
    DbSet<Device> Devices { get; }
    DbSet<Invitation> Invitations { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
    Task<Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction> BeginTransactionAsync(CancellationToken cancellationToken = default);
    bool IsRelational();
    Task<int> ExecuteSqlRawAsync(string sql, CancellationToken cancellationToken = default);
}

public interface ITokenService
{
    string GenerateAccessToken(ApplicationUser user);
    string GenerateRefreshToken();
    string HashToken(string token);
}

public interface ICurrentUserService
{
    string? UserId { get; }
    bool IsAuthenticated { get; }
}

public interface IFileStorage
{
    Task<(string storagePath, string downloadUrl)> UploadFileAsync(
        Stream stream,
        string fileName,
        string contentType,
        string folder,
        CancellationToken cancellationToken = default);

    Task DeleteFileAsync(string storagePath, CancellationToken cancellationToken = default);
}

public interface IPresenceService
{
    Task SetUserOnlineAsync(string userId, string connectionId);
    Task SetUserOfflineAsync(string userId, string connectionId);
    Task<bool> IsUserOnlineAsync(string userId);
    Task<IReadOnlyDictionary<string, bool>> GetUsersOnlineStatusAsync(IEnumerable<string> userIds);
}

public interface IPushNotificationService
{
    Task SendNotificationAsync(
        string deviceToken,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CancellationToken cancellationToken = default);

    Task SendMulticastNotificationAsync(
        IEnumerable<string> deviceTokens,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CancellationToken cancellationToken = default);
}

public interface ISignalRNotifier
{
    Task NotifyNewMessageAsync(Guid conversationId, object messageDto);
    Task NotifyMessageEditedAsync(Guid conversationId, Guid messageId, string newContent, DateTime updatedAt);
    Task NotifyMessageDeletedAsync(Guid conversationId, Guid messageId);
    Task NotifyReactionUpdatedAsync(Guid conversationId, Guid messageId, string reaction, string userId, bool added);
    Task NotifyUserTypingAsync(Guid conversationId, string userId, string displayName, bool isTyping);
    Task NotifyPresenceChangedAsync(string userId, bool isOnline, DateTime? lastSeenAt);
    Task NotifyMessageReadAsync(Guid conversationId, Guid messageId, string userId, DateTime readAt);
}

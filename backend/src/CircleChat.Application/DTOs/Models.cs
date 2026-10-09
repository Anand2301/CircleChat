using CircleChat.Domain.Enums;

namespace CircleChat.Application.DTOs;

public class ApiResponse<T>
{
    public bool Success { get; set; } = true;
    public int StatusCode { get; set; } = 200;
    public string? Message { get; set; }
    public T? Data { get; set; }
    public List<string>? Errors { get; set; }

    public static ApiResponse<T> Ok(T data, string? message = null) =>
        new() { Success = true, StatusCode = 200, Message = message, Data = data };

    public static ApiResponse<T> Fail(string message, int statusCode = 400, List<string>? errors = null) =>
        new() { Success = false, StatusCode = statusCode, Message = message, Errors = errors };
}

public class AuthResponse
{
    public string AccessToken { get; set; } = string.Empty;
    public string RefreshToken { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public string? InitialInvitationCode { get; set; }
    public UserProfileDto User { get; set; } = null!;
}

public class LoginRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class RegisterRequest
{
    public string InvitationCode { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string ConfirmPassword { get; set; } = string.Empty;
}

public class BootstrapRegisterRequest
{
    public string BootstrapSecret { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string ConfirmPassword { get; set; } = string.Empty;
    public string? InitialInvitationCode { get; set; }
}

public class RefreshTokenRequest
{
    public string RefreshToken { get; set; } = string.Empty;
}

public class ChangePasswordRequest
{
    public string CurrentPassword { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}

public class UserProfileDto
{
    public string Id { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? Bio { get; set; }
    public string? ProfileImageUrl { get; set; }
    public bool IsOnline { get; set; }
    public DateTime? LastSeenAt { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class UpdateProfileRequest
{
    public string DisplayName { get; set; } = string.Empty;
    public string? Bio { get; set; }
    public string? ProfileImageUrl { get; set; }
}

public class UserSearchResultDto
{
    public string Id { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? ProfileImageUrl { get; set; }
    public bool IsOnline { get; set; }
}

public class ConversationMemberDto
{
    public string UserId { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? ProfileImageUrl { get; set; }
    public MemberRole Role { get; set; }
    public DateTime JoinedAt { get; set; }
    public bool IsOnline { get; set; }
}

public class ConversationDto
{
    public Guid Id { get; set; }
    public ConversationType Type { get; set; }
    public string? Name { get; set; }
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public MessageDto? LastMessage { get; set; }
    public int UnreadCount { get; set; }
    public List<ConversationMemberDto> Members { get; set; } = new();
}

public class CreateDirectConversationRequest
{
    public string OtherUserId { get; set; } = string.Empty;
}

public class CreateGroupConversationRequest
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public List<string> MemberUserIds { get; set; } = new();
}

public class UpdateGroupRequest
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }
}

public class AddMemberRequest
{
    public string UserId { get; set; } = string.Empty;
    public MemberRole Role { get; set; } = MemberRole.Member;
}

public class AttachmentDto
{
    public Guid Id { get; set; }
    public string FileName { get; set; } = string.Empty;
    public string StoragePath { get; set; } = string.Empty;
    public string DownloadUrl { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long FileSize { get; set; }
}

public class MessageReactionDto
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Reaction { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

public class MessageDto
{
    public Guid Id { get; set; }
    public Guid ConversationId { get; set; }
    public string SenderId { get; set; } = string.Empty;
    public string SenderDisplayName { get; set; } = string.Empty;
    public string? SenderProfileImageUrl { get; set; }
    public string Content { get; set; } = string.Empty;
    public MessageType MessageType { get; set; }
    public Guid? ReplyToMessageId { get; set; }
    public MessageDto? ReplyToMessage { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public bool IsDeleted { get; set; }
    public int DeliveryStatus { get; set; } // 0 = Sent, 1 = Delivered, 2 = Read
    public List<MessageReactionDto> Reactions { get; set; } = new();
    public List<AttachmentDto> Attachments { get; set; } = new();
}

public class SendMessageRequest
{
    public string Content { get; set; } = string.Empty;
    public MessageType MessageType { get; set; } = MessageType.Text;
    public Guid? ReplyToMessageId { get; set; }
    public List<Guid>? AttachmentIds { get; set; }
}

public class EditMessageRequest
{
    public string Content { get; set; } = string.Empty;
}

public class AddReactionRequest
{
    public string Reaction { get; set; } = string.Empty;
}

public class RegisterDeviceRequest
{
    public string DeviceToken { get; set; } = string.Empty;
    public DevicePlatform Platform { get; set; } = DevicePlatform.Android;
}

public class CreateInvitationRequest
{
    public int MaxUses { get; set; } = 1;
    public int? ExpirationDays { get; set; } = 7;
}

public class InvitationDto
{
    public Guid Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string CreatedById { get; set; } = string.Empty;
    public string CreatedByDisplayName { get; set; } = string.Empty;
    public DateTime? ExpiresAt { get; set; }
    public int MaxUses { get; set; }
    public int UsedCount { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public bool IsValid { get; set; }
}

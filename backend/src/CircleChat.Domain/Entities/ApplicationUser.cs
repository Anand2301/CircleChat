using Microsoft.AspNetCore.Identity;

namespace CircleChat.Domain.Entities;

public class ApplicationUser : IdentityUser
{
    public string FullName { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? Bio { get; set; }
    public string? ProfileImageUrl { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? LastSeenAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation collections
    public ICollection<ConversationMember> ConversationMemberships { get; set; } = new List<ConversationMember>();
    public ICollection<Message> Messages { get; set; } = new List<Message>();
    public ICollection<MessageRead> MessageReads { get; set; } = new List<MessageRead>();
    public ICollection<MessageReaction> MessageReactions { get; set; } = new List<MessageReaction>();
    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
    public ICollection<Device> Devices { get; set; } = new List<Device>();
    public ICollection<Invitation> CreatedInvitations { get; set; } = new List<Invitation>();
}

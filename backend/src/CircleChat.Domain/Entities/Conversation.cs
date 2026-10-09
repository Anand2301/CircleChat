using CircleChat.Domain.Enums;

namespace CircleChat.Domain.Entities;

public class Conversation
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public ConversationType Type { get; set; }
    public string? Name { get; set; }
    public string? Description { get; set; }
    public string CreatedById { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation
    public ApplicationUser CreatedBy { get; set; } = null!;
    public ICollection<ConversationMember> Members { get; set; } = new List<ConversationMember>();
    public ICollection<Message> Messages { get; set; } = new List<Message>();
}

public class ConversationMember
{
    public Guid ConversationId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public MemberRole Role { get; set; } = MemberRole.Member;
    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LeftAt { get; set; }
    public bool IsActive { get; set; } = true;

    // Navigation
    public Conversation Conversation { get; set; } = null!;
    public ApplicationUser User { get; set; } = null!;
}

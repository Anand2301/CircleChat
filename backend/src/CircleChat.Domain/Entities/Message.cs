using CircleChat.Domain.Enums;

namespace CircleChat.Domain.Entities;

public class Message
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ConversationId { get; set; }
    public string SenderId { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public MessageType MessageType { get; set; } = MessageType.Text;
    public Guid? ReplyToMessageId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }

    // Navigation
    public Conversation Conversation { get; set; } = null!;
    public ApplicationUser Sender { get; set; } = null!;
    public Message? ReplyToMessage { get; set; }
    public ICollection<MessageRead> Reads { get; set; } = new List<MessageRead>();
    public ICollection<MessageReaction> Reactions { get; set; } = new List<MessageReaction>();
    public ICollection<Attachment> Attachments { get; set; } = new List<Attachment>();
}

public class MessageRead
{
    public Guid MessageId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public DateTime ReadAt { get; set; } = DateTime.UtcNow;

    // Navigation
    public Message Message { get; set; } = null!;
    public ApplicationUser User { get; set; } = null!;
}

public class MessageReaction
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid MessageId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string Reaction { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation
    public Message Message { get; set; } = null!;
    public ApplicationUser User { get; set; } = null!;
}

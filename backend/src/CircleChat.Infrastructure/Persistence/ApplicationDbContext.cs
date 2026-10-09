using CircleChat.Application.Common.Interfaces;
using CircleChat.Domain.Entities;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace CircleChat.Infrastructure.Persistence;

public class ApplicationDbContext : IdentityDbContext<ApplicationUser>, IApplicationDbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<Conversation> Conversations => Set<Conversation>();
    public DbSet<ConversationMember> ConversationMembers => Set<ConversationMember>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<MessageRead> MessageReads => Set<MessageRead>();
    public DbSet<MessageReaction> MessageReactions => Set<MessageReaction>();
    public DbSet<Attachment> Attachments => Set<Attachment>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<Invitation> Invitations => Set<Invitation>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // Conversation
        builder.Entity<Conversation>(entity =>
        {
            entity.HasKey(c => c.Id);
            entity.Property(c => c.Name).HasMaxLength(128);
            entity.Property(c => c.Description).HasMaxLength(512);

            entity.HasOne(c => c.CreatedBy)
                .WithMany()
                .HasForeignKey(c => c.CreatedById)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // ConversationMember
        builder.Entity<ConversationMember>(entity =>
        {
            entity.HasKey(cm => new { cm.ConversationId, cm.UserId });

            entity.HasOne(cm => cm.Conversation)
                .WithMany(c => c.Members)
                .HasForeignKey(cm => cm.ConversationId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(cm => cm.User)
                .WithMany(u => u.ConversationMemberships)
                .HasForeignKey(cm => cm.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(cm => new { cm.UserId, cm.IsActive });
        });

        // Message
        builder.Entity<Message>(entity =>
        {
            entity.HasKey(m => m.Id);
            entity.Property(m => m.Content).IsRequired();

            entity.HasOne(m => m.Conversation)
                .WithMany(c => c.Messages)
                .HasForeignKey(m => m.ConversationId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(m => m.Sender)
                .WithMany(u => u.Messages)
                .HasForeignKey(m => m.SenderId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(m => m.ReplyToMessage)
                .WithMany()
                .HasForeignKey(m => m.ReplyToMessageId)
                .OnDelete(DeleteBehavior.SetNull);

            // Composite indexes for performance & pagination
            entity.HasIndex(m => new { m.ConversationId, m.CreatedAt });
            entity.HasIndex(m => new { m.ConversationId, m.CreatedAt, m.Id });
        });

        // MessageRead
        builder.Entity<MessageRead>(entity =>
        {
            entity.HasKey(mr => new { mr.MessageId, mr.UserId });

            entity.HasOne(mr => mr.Message)
                .WithMany(m => m.Reads)
                .HasForeignKey(mr => mr.MessageId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(mr => mr.User)
                .WithMany(u => u.MessageReads)
                .HasForeignKey(mr => mr.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(mr => new { mr.MessageId, mr.UserId });
        });

        // MessageReaction
        builder.Entity<MessageReaction>(entity =>
        {
            entity.HasKey(mr => mr.Id);
            entity.Property(mr => mr.Reaction).HasMaxLength(16).IsRequired();

            entity.HasOne(mr => mr.Message)
                .WithMany(m => m.Reactions)
                .HasForeignKey(mr => mr.MessageId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(mr => mr.User)
                .WithMany(u => u.MessageReactions)
                .HasForeignKey(mr => mr.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(mr => new { mr.MessageId, mr.UserId, mr.Reaction }).IsUnique();
        });

        // Attachment
        builder.Entity<Attachment>(entity =>
        {
            entity.HasKey(a => a.Id);
            entity.Property(a => a.FileName).HasMaxLength(256).IsRequired();
            entity.Property(a => a.StoragePath).HasMaxLength(512).IsRequired();
            entity.Property(a => a.ContentType).HasMaxLength(128).IsRequired();

            entity.HasOne(a => a.Message)
                .WithMany(m => m.Attachments)
                .HasForeignKey(a => a.MessageId)
                .IsRequired(false)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // RefreshToken
        builder.Entity<RefreshToken>(entity =>
        {
            entity.HasKey(rt => rt.Id);
            entity.Property(rt => rt.TokenHash).HasMaxLength(128).IsRequired();

            entity.HasOne(rt => rt.User)
                .WithMany(u => u.RefreshTokens)
                .HasForeignKey(rt => rt.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(rt => rt.TokenHash);
        });

        // Device
        builder.Entity<Device>(entity =>
        {
            entity.HasKey(d => d.Id);
            entity.Property(d => d.DeviceToken).HasMaxLength(512).IsRequired();

            entity.HasOne(d => d.User)
                .WithMany(u => u.Devices)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(d => new { d.UserId, d.DeviceToken });
        });

        // Invitation
        builder.Entity<Invitation>(entity =>
        {
            entity.HasKey(i => i.Id);
            entity.Property(i => i.Code).HasMaxLength(32).IsRequired();

            entity.HasOne(i => i.CreatedBy)
                .WithMany(u => u.CreatedInvitations)
                .HasForeignKey(i => i.CreatedById)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(i => i.Code).IsUnique();
        });
    }

    public Task<IDbContextTransaction> BeginTransactionAsync(CancellationToken cancellationToken = default)
        => Database.BeginTransactionAsync(cancellationToken);

    public bool IsRelational()
        => Database.IsRelational();

    public Task<int> ExecuteSqlRawAsync(string sql, CancellationToken cancellationToken = default)
        => Database.ExecuteSqlRawAsync(sql, cancellationToken);
}

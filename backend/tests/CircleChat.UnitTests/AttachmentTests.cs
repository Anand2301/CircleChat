using CircleChat.Application.DTOs;
using CircleChat.Application.Validation;
using CircleChat.Domain.Entities;
using FluentAssertions;
using Xunit;

namespace CircleChat.UnitTests;

public class AttachmentTests
{
    [Fact]
    public void Attachment_CanBeCreated_WithoutMessageId()
    {
        var attachment = new Attachment
        {
            FileName = "photo.jpg",
            StoragePath = "https://firebasestorage.googleapis.com/v0/b/bucket/o/photo.jpg",
            ContentType = "image/jpeg",
            FileSize = 1024,
            MessageId = null
        };

        attachment.MessageId.Should().BeNull();
        attachment.FileName.Should().Be("photo.jpg");
        attachment.FileSize.Should().Be(1024);
    }

    [Fact]
    public void Attachment_CanBeAssociated_WithMessageLater()
    {
        var attachment = new Attachment
        {
            FileName = "document.pdf",
            StoragePath = "attachments/document.pdf",
            ContentType = "application/pdf",
            FileSize = 2048,
            MessageId = null
        };

        var messageId = Guid.NewGuid();
        attachment.MessageId = messageId;

        attachment.MessageId.Should().Be(messageId);
    }

    [Fact]
    public void SendMessageValidator_WithAttachmentsAndEmptyContent_Passes()
    {
        var validator = new SendMessageRequestValidator();
        var request = new SendMessageRequest
        {
            Content = "",
            AttachmentIds = new List<Guid> { Guid.NewGuid() }
        };

        var result = validator.Validate(request);
        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void SendMessageValidator_WithNeitherContentNorAttachments_Fails()
    {
        var validator = new SendMessageRequestValidator();
        var request = new SendMessageRequest
        {
            Content = "   ",
            AttachmentIds = null
        };

        var result = validator.Validate(request);
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.ErrorMessage.Contains("at least one attachment"));
    }
}

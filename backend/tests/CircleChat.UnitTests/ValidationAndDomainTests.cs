using CircleChat.Application.DTOs;
using CircleChat.Application.Validation;
using CircleChat.Domain.Entities;
using CircleChat.Domain.Enums;
using FluentAssertions;
using Xunit;

namespace CircleChat.UnitTests;

public class ValidationAndDomainTests
{
    [Fact]
    public void Invitation_WhenValid_ReturnsTrue()
    {
        var invitation = new Invitation
        {
            Code = "CC-TEST1234",
            IsActive = true,
            ExpiresAt = DateTime.UtcNow.AddDays(7),
            MaxUses = 5,
            UsedCount = 2
        };

        invitation.IsValid.Should().BeTrue();
    }

    [Fact]
    public void Invitation_WhenExpired_ReturnsFalse()
    {
        var invitation = new Invitation
        {
            Code = "CC-EXPIRED",
            IsActive = true,
            ExpiresAt = DateTime.UtcNow.AddDays(-1),
            MaxUses = 5,
            UsedCount = 0
        };

        invitation.IsValid.Should().BeFalse();
    }

    [Fact]
    public void Invitation_WhenMaxUsesReached_ReturnsFalse()
    {
        var invitation = new Invitation
        {
            Code = "CC-FULL",
            IsActive = true,
            MaxUses = 3,
            UsedCount = 3
        };

        invitation.IsValid.Should().BeFalse();
    }

    [Fact]
    public void RegisterValidator_WhenValidRequest_PassesValidation()
    {
        var validator = new RegisterRequestValidator();
        var request = new RegisterRequest
        {
            InvitationCode = "CC-VALID12",
            FullName = "John Doe",
            DisplayName = "John",
            Email = "john@example.com",
            Password = "Password123!",
            ConfirmPassword = "Password123!"
        };

        var result = validator.Validate(request);
        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void RegisterValidator_WhenPasswordsMismatch_FailsValidation()
    {
        var validator = new RegisterRequestValidator();
        var request = new RegisterRequest
        {
            InvitationCode = "CC-VALID12",
            FullName = "John Doe",
            DisplayName = "John",
            Email = "john@example.com",
            Password = "Password123!",
            ConfirmPassword = "DifferentPassword"
        };

        var result = validator.Validate(request);
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "ConfirmPassword");
    }

    [Fact]
    public void SendMessageValidator_WhenEmptyContentAndNoAttachments_FailsValidation()
    {
        var validator = new SendMessageRequestValidator();
        var request = new SendMessageRequest
        {
            Content = "",
            AttachmentIds = null
        };

        var result = validator.Validate(request);
        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void SendMessageValidator_WhenContentPresent_PassesValidation()
    {
        var validator = new SendMessageRequestValidator();
        var request = new SendMessageRequest
        {
            Content = "Hello from CircleChat!",
            MessageType = MessageType.Text
        };

        var result = validator.Validate(request);
        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void CreateGroupValidator_WhenNameTooShort_FailsValidation()
    {
        var validator = new CreateGroupConversationRequestValidator();
        var request = new CreateGroupConversationRequest
        {
            Name = "A"
        };

        var result = validator.Validate(request);
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Fact]
    public void RefreshToken_ExpiryAndRevocation_EvaluatesProperly()
    {
        var token = new RefreshToken
        {
            UserId = "user-123",
            TokenHash = "abc123hash",
            ExpiresAt = DateTime.UtcNow.AddMinutes(-5),
            CreatedAt = DateTime.UtcNow.AddDays(-1),
            RevokedAt = null
        };

        token.IsExpired.Should().BeTrue();
        token.IsActive.Should().BeFalse();

        var activeToken = new RefreshToken
        {
            UserId = "user-123",
            TokenHash = "abc123hash",
            ExpiresAt = DateTime.UtcNow.AddDays(7),
            CreatedAt = DateTime.UtcNow,
            RevokedAt = null
        };

        activeToken.IsExpired.Should().BeFalse();
        activeToken.IsActive.Should().BeTrue();

        activeToken.RevokedAt = DateTime.UtcNow;
        activeToken.IsRevoked.Should().BeTrue();
        activeToken.IsActive.Should().BeFalse();
    }

    [Fact]
    public void BootstrapValidator_WhenValidRequest_PassesValidation()
    {
        var validator = new BootstrapRegisterRequestValidator();
        var request = new BootstrapRegisterRequest
        {
            BootstrapSecret = "RenderSuperSecretKey2026!",
            FullName = "First Founder",
            DisplayName = "Founder",
            Email = "founder@circlechat.test",
            Password = "SecurePassword123!",
            ConfirmPassword = "SecurePassword123!",
            InitialInvitationCode = "CC-FOUNDER2026"
        };

        var result = validator.Validate(request);
        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void BootstrapValidator_WhenSecretMissing_FailsValidation()
    {
        var validator = new BootstrapRegisterRequestValidator();
        var request = new BootstrapRegisterRequest
        {
            BootstrapSecret = "",
            FullName = "First Founder",
            DisplayName = "Founder",
            Email = "founder@circlechat.test",
            Password = "SecurePassword123!",
            ConfirmPassword = "SecurePassword123!"
        };

        var result = validator.Validate(request);
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "BootstrapSecret");
    }

    [Fact]
    public void BootstrapValidator_WhenPasswordsMismatch_FailsValidation()
    {
        var validator = new BootstrapRegisterRequestValidator();
        var request = new BootstrapRegisterRequest
        {
            BootstrapSecret = "RenderSuperSecretKey2026!",
            FullName = "First Founder",
            DisplayName = "Founder",
            Email = "founder@circlechat.test",
            Password = "SecurePassword123!",
            ConfirmPassword = "WrongPassword123!"
        };

        var result = validator.Validate(request);
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "ConfirmPassword");
    }

    [Fact]
    public void BootstrapValidator_WhenPasswordTooShort_FailsValidation()
    {
        var validator = new BootstrapRegisterRequestValidator();
        var request = new BootstrapRegisterRequest
        {
            BootstrapSecret = "RenderSuperSecretKey2026!",
            FullName = "First Founder",
            DisplayName = "Founder",
            Email = "founder@circlechat.test",
            Password = "123",
            ConfirmPassword = "123"
        };

        var result = validator.Validate(request);
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Password");
    }
}

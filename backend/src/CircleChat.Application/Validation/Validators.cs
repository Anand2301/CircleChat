using CircleChat.Application.DTOs;
using FluentValidation;

namespace CircleChat.Application.Validation;

public class RegisterRequestValidator : AbstractValidator<RegisterRequest>
{
    public RegisterRequestValidator()
    {
        RuleFor(x => x.InvitationCode)
            .NotEmpty().WithMessage("Invitation code is required.")
            .MaximumLength(32);

        RuleFor(x => x.FullName)
            .NotEmpty().WithMessage("Full name is required.")
            .MaximumLength(100);

        RuleFor(x => x.DisplayName)
            .NotEmpty().WithMessage("Display name is required.")
            .MinimumLength(2)
            .MaximumLength(50);

        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required.")
            .EmailAddress().WithMessage("A valid email address is required.");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Password is required.")
            .MinimumLength(6).WithMessage("Password must be at least 6 characters.");

        RuleFor(x => x.ConfirmPassword)
            .Equal(x => x.Password).WithMessage("Passwords do not match.");
    }
}

public class BootstrapRegisterRequestValidator : AbstractValidator<BootstrapRegisterRequest>
{
    public BootstrapRegisterRequestValidator()
    {
        RuleFor(x => x.BootstrapSecret)
            .NotEmpty().WithMessage("Bootstrap secret is required.");

        RuleFor(x => x.FullName)
            .NotEmpty().WithMessage("Full name is required.")
            .MaximumLength(100);

        RuleFor(x => x.DisplayName)
            .NotEmpty().WithMessage("Display name is required.")
            .MinimumLength(2)
            .MaximumLength(50);

        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required.")
            .EmailAddress().WithMessage("A valid email address is required.");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Password is required.")
            .MinimumLength(6).WithMessage("Password must be at least 6 characters.");

        RuleFor(x => x.ConfirmPassword)
            .Equal(x => x.Password).WithMessage("Passwords do not match.");

        RuleFor(x => x.InitialInvitationCode)
            .MaximumLength(32).WithMessage("Initial invitation code must not exceed 32 characters.")
            .When(x => !string.IsNullOrEmpty(x.InitialInvitationCode));
    }
}

public class LoginRequestValidator : AbstractValidator<LoginRequest>
{
    public LoginRequestValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required.")
            .EmailAddress().WithMessage("A valid email address is required.");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Password is required.");
    }
}

public class UpdateProfileRequestValidator : AbstractValidator<UpdateProfileRequest>
{
    public UpdateProfileRequestValidator()
    {
        RuleFor(x => x.DisplayName)
            .NotEmpty().WithMessage("Display name is required.")
            .MinimumLength(2)
            .MaximumLength(50);

        RuleFor(x => x.Bio)
            .MaximumLength(500);
    }
}

public class CreateGroupConversationRequestValidator : AbstractValidator<CreateGroupConversationRequest>
{
    public CreateGroupConversationRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Group name is required.")
            .MinimumLength(2)
            .MaximumLength(100);

        RuleFor(x => x.Description)
            .MaximumLength(500);
    }
}

public class SendMessageRequestValidator : AbstractValidator<SendMessageRequest>
{
    public SendMessageRequestValidator()
    {
        RuleFor(x => x)
            .Must(x => !string.IsNullOrWhiteSpace(x.Content) || (x.AttachmentIds != null && x.AttachmentIds.Count > 0))
            .WithMessage("A message must contain text or at least one attachment.");

        RuleFor(x => x.Content)
            .MaximumLength(4000).WithMessage("Message content cannot exceed 4000 characters.");
    }
}

public class EditMessageRequestValidator : AbstractValidator<EditMessageRequest>
{
    public EditMessageRequestValidator()
    {
        RuleFor(x => x.Content)
            .NotEmpty().WithMessage("Message content cannot be empty.")
            .MaximumLength(4000).WithMessage("Message content cannot exceed 4000 characters.");
    }
}

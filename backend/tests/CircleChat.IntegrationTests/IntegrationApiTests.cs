using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using CircleChat.Application.DTOs;
using FluentAssertions;
using Xunit;

namespace CircleChat.IntegrationTests;

public class IntegrationApiTests : IClassFixture<CircleChatTestFactory>
{
    private readonly HttpClient _client;

    public IntegrationApiTests(CircleChatTestFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Register_WithValidInvite_ReturnsSuccessAndTokens()
    {
        var email = $"alice_{Guid.NewGuid():N}@circlechat.test";
        var request = new RegisterRequest
        {
            InvitationCode = "CC-INVITE123",
            FullName = "Alice Smith",
            DisplayName = "Alice",
            Email = email,
            Password = "Password123!",
            ConfirmPassword = "Password123!"
        };

        var response = await _client.PostAsJsonAsync("/api/auth/register", request);
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadFromJsonAsync<ApiResponse<AuthResponse>>();
        content.Should().NotBeNull();
        content!.Success.Should().BeTrue();
        content.Data.Should().NotBeNull();
        content.Data!.AccessToken.Should().NotBeNullOrEmpty();
        content.Data.RefreshToken.Should().NotBeNullOrEmpty();
        content.Data.User.Email.Should().Be(email);
    }

    [Fact]
    public async Task Register_WithInvalidInvite_ReturnsBadRequest()
    {
        var request = new RegisterRequest
        {
            InvitationCode = "CC-NONEXISTENT",
            FullName = "Fake User",
            DisplayName = "Fake",
            Email = $"fake_{Guid.NewGuid():N}@circlechat.test",
            Password = "Password123!",
            ConfirmPassword = "Password123!"
        };

        var response = await _client.PostAsJsonAsync("/api/auth/register", request);
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Login_WithRegisteredCredentials_ReturnsTokenAndProfile()
    {
        var email = $"bob_{Guid.NewGuid():N}@circlechat.test";
        var regRequest = new RegisterRequest
        {
            InvitationCode = "CC-INVITE123",
            FullName = "Bob Jones",
            DisplayName = "Bob",
            Email = email,
            Password = "Password123!",
            ConfirmPassword = "Password123!"
        };
        await _client.PostAsJsonAsync("/api/auth/register", regRequest);

        var loginRequest = new LoginRequest
        {
            Email = email,
            Password = "Password123!"
        };

        var response = await _client.PostAsJsonAsync("/api/auth/login", loginRequest);
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadFromJsonAsync<ApiResponse<AuthResponse>>();
        content.Should().NotBeNull();
        content!.Success.Should().BeTrue();
        content.Data!.AccessToken.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task GetProfile_WithoutToken_ReturnsUnauthorized()
    {
        var response = await _client.GetAsync("/api/users/me");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetProfile_WithBearerToken_ReturnsProfile()
    {
        var email = $"charlie_{Guid.NewGuid():N}@circlechat.test";
        var regRequest = new RegisterRequest
        {
            InvitationCode = "CC-INVITE123",
            FullName = "Charlie Brown",
            DisplayName = "Charlie",
            Email = email,
            Password = "Password123!",
            ConfirmPassword = "Password123!"
        };
        var regResponse = await _client.PostAsJsonAsync("/api/auth/register", regRequest);
        var regData = await regResponse.Content.ReadFromJsonAsync<ApiResponse<AuthResponse>>();

        var requestMessage = new HttpRequestMessage(HttpMethod.Get, "/api/users/me");
        requestMessage.Headers.Authorization = new AuthenticationHeaderValue("Bearer", regData!.Data!.AccessToken);

        var response = await _client.SendAsync(requestMessage);
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadFromJsonAsync<ApiResponse<UserProfileDto>>();
        content.Should().NotBeNull();
        content!.Data!.DisplayName.Should().Be("Charlie");
    }

    [Fact]
    public async Task ValidateInvitation_ValidCode_ReturnsOk()
    {
        var response = await _client.GetAsync("/api/invitations/validate/CC-INVITE123");
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var content = await response.Content.ReadFromJsonAsync<ApiResponse<InvitationDto>>();
        content!.Data!.IsValid.Should().BeTrue();
    }
}

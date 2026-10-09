using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using CircleChat.Application.DTOs;
using CircleChat.Domain.Enums;
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

    [Fact]
    public async Task SendMessage_And_GetMessagesWithAfterCursor_RecoversNewerMessages()
    {
        // 1. Register User A
        var emailA = $"userA_{Guid.NewGuid():N}@circlechat.test";
        var regA = await _client.PostAsJsonAsync("/api/auth/register", new RegisterRequest
        {
            InvitationCode = "CC-INVITE123",
            FullName = "User A",
            DisplayName = "UserA",
            Email = emailA,
            Password = "Password123!",
            ConfirmPassword = "Password123!"
        });
        var authA = (await regA.Content.ReadFromJsonAsync<ApiResponse<AuthResponse>>())!.Data!;

        // 2. Register User B
        var emailB = $"userB_{Guid.NewGuid():N}@circlechat.test";
        var regB = await _client.PostAsJsonAsync("/api/auth/register", new RegisterRequest
        {
            InvitationCode = "CC-INVITE123",
            FullName = "User B",
            DisplayName = "UserB",
            Email = emailB,
            Password = "Password123!",
            ConfirmPassword = "Password123!"
        });
        var authB = (await regB.Content.ReadFromJsonAsync<ApiResponse<AuthResponse>>())!.Data!;

        // 3. User A creates direct conversation with User B
        var createConvReq = new HttpRequestMessage(HttpMethod.Post, "/api/conversations/direct")
        {
            Content = JsonContent.Create(new CreateDirectConversationRequest { OtherUserId = authB.User.Id })
        };
        createConvReq.Headers.Authorization = new AuthenticationHeaderValue("Bearer", authA.AccessToken);
        var convRes = await _client.SendAsync(createConvReq);
        convRes.StatusCode.Should().Be(HttpStatusCode.OK);
        var conv = (await convRes.Content.ReadFromJsonAsync<ApiResponse<ConversationDto>>())!.Data!;

        // 4. User A sends first message
        var sendMsg1Req = new HttpRequestMessage(HttpMethod.Post, $"/api/conversations/{conv.Id}/messages")
        {
            Content = JsonContent.Create(new SendMessageRequest { Content = "Hello 1", MessageType = 0 })
        };
        sendMsg1Req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", authA.AccessToken);
        var msg1Res = await _client.SendAsync(sendMsg1Req);
        msg1Res.StatusCode.Should().Be(HttpStatusCode.OK);
        var msg1 = (await msg1Res.Content.ReadFromJsonAsync<ApiResponse<MessageDto>>())!.Data!;

        // 5. User A sends second message
        var sendMsg2Req = new HttpRequestMessage(HttpMethod.Post, $"/api/conversations/{conv.Id}/messages")
        {
            Content = JsonContent.Create(new SendMessageRequest { Content = "Hello 2", MessageType = 0 })
        };
        sendMsg2Req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", authA.AccessToken);
        var msg2Res = await _client.SendAsync(sendMsg2Req);
        msg2Res.StatusCode.Should().Be(HttpStatusCode.OK);
        var msg2 = (await msg2Res.Content.ReadFromJsonAsync<ApiResponse<MessageDto>>())!.Data!;

        // 6. User B fetches messages after msg1 (simulating missed-message recovery on reconnect)
        var getReq = new HttpRequestMessage(HttpMethod.Get, $"/api/conversations/{conv.Id}/messages?after={msg1.Id}");
        getReq.Headers.Authorization = new AuthenticationHeaderValue("Bearer", authB.AccessToken);
        var getRes = await _client.SendAsync(getReq);
        getRes.StatusCode.Should().Be(HttpStatusCode.OK);
        var missedMessages = (await getRes.Content.ReadFromJsonAsync<ApiResponse<List<MessageDto>>>())!.Data!;

        missedMessages.Should().HaveCount(1);
        missedMessages.First().Id.Should().Be(msg2.Id);
        missedMessages.First().Content.Should().Be("Hello 2");
    }

    [Fact]
    public async Task DeviceRegistration_AndUnregistration_Succeeds()
    {
        // 1. Register a test user
        var email = $"dev_{Guid.NewGuid():N}@circlechat.test";
        var regRes = await _client.PostAsJsonAsync("/api/auth/register", new RegisterRequest
        {
            InvitationCode = "CC-INVITE123",
            FullName = "Device Test User",
            DisplayName = "DeviceUser",
            Email = email,
            Password = "Password123!",
            ConfirmPassword = "Password123!"
        });
        regRes.StatusCode.Should().Be(HttpStatusCode.OK);
        var auth = (await regRes.Content.ReadFromJsonAsync<ApiResponse<AuthResponse>>())!.Data!;

        // 2. Register a device token
        var testToken = $"fcm_token_{Guid.NewGuid():N}";
        var regDevReq = new HttpRequestMessage(HttpMethod.Post, "/api/devices")
        {
            Content = JsonContent.Create(new RegisterDeviceRequest
            {
                DeviceToken = testToken,
                Platform = DevicePlatform.Android
            })
        };
        regDevReq.Headers.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        var regDevRes = await _client.SendAsync(regDevReq);
        regDevRes.StatusCode.Should().Be(HttpStatusCode.OK);

        // 3. Unregister the device token
        var delDevReq = new HttpRequestMessage(HttpMethod.Delete, $"/api/devices/{testToken}");
        delDevReq.Headers.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        var delDevRes = await _client.SendAsync(delDevReq);
        delDevRes.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}

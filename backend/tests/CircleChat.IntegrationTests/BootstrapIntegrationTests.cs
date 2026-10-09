using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using CircleChat.Application.DTOs;
using CircleChat.Domain.Entities;
using CircleChat.Infrastructure.Persistence;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CircleChat.IntegrationTests;

public class BootstrapIntegrationTests : IClassFixture<BootstrapTestFactory>
{
    private readonly BootstrapTestFactory _factory;
    private readonly HttpClient _client;

    public BootstrapIntegrationTests(BootstrapTestFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Bootstrap_WithInvalidSecret_FailsWithBadRequest()
    {
        var request = new BootstrapRegisterRequest
        {
            BootstrapSecret = "IncorrectSecret123!",
            FullName = "First Admin",
            DisplayName = "Admin",
            Email = $"founder_{Guid.NewGuid():N}@circlechat.test",
            Password = "Password123!",
            ConfirmPassword = "Password123!"
        };

        var response = await _client.PostAsJsonAsync("/api/auth/bootstrap", request);
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var content = await response.Content.ReadFromJsonAsync<ApiResponse<AuthResponse>>();
        content.Should().NotBeNull();
        content!.Success.Should().BeFalse();
        content.Message.Should().Contain("Invalid bootstrap secret");
    }

    [Fact]
    public async Task Bootstrap_Lifecycle_FullFlow_Succeeds()
    {
        // 1. Verify initially 0 users and 0 invitations
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var userCount = await db.Users.CountAsync();
            userCount.Should().Be(0, "Database must be empty before bootstrap");
        }

        // 2. Perform first-user bootstrap with valid secret
        var founderEmail = $"founder_{Guid.NewGuid():N}@circlechat.test";
        var bootstrapReq = new BootstrapRegisterRequest
        {
            BootstrapSecret = BootstrapTestFactory.ValidBootstrapSecret,
            FullName = "Founder User",
            DisplayName = "Founder",
            Email = founderEmail,
            Password = "SecurePassword123!",
            ConfirmPassword = "SecurePassword123!",
            InitialInvitationCode = "CC-FOUNDER999"
        };

        var bootstrapRes = await _client.PostAsJsonAsync("/api/auth/bootstrap", bootstrapReq);
        bootstrapRes.StatusCode.Should().Be(HttpStatusCode.OK);

        var bootstrapContent = await bootstrapRes.Content.ReadFromJsonAsync<ApiResponse<AuthResponse>>();
        bootstrapContent.Should().NotBeNull();
        bootstrapContent!.Success.Should().BeTrue();
        bootstrapContent.Data.Should().NotBeNull();
        bootstrapContent.Data!.AccessToken.Should().NotBeNullOrEmpty();
        bootstrapContent.Data.RefreshToken.Should().NotBeNullOrEmpty();
        bootstrapContent.Data.InitialInvitationCode.Should().Be("CC-FOUNDER999");
        bootstrapContent.Data.User.Email.Should().Be(founderEmail);

        var founderId = bootstrapContent.Data.User.Id;
        var founderToken = bootstrapContent.Data.AccessToken;

        // Verify in DB that invitation has the real CreatedById
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var invitation = await db.Invitations.FirstOrDefaultAsync(i => i.Code == "CC-FOUNDER999");
            invitation.Should().NotBeNull();
            invitation!.CreatedById.Should().Be(founderId);
            invitation.IsActive.Should().BeTrue();
            invitation.MaxUses.Should().Be(50);
        }

        // 3. Subsequent bootstrap attempt MUST fail because a user now exists
        var secondBootstrapReq = new BootstrapRegisterRequest
        {
            BootstrapSecret = BootstrapTestFactory.ValidBootstrapSecret,
            FullName = "Second User",
            DisplayName = "Second",
            Email = $"second_{Guid.NewGuid():N}@circlechat.test",
            Password = "SecurePassword123!",
            ConfirmPassword = "SecurePassword123!"
        };

        var secondBootstrapRes = await _client.PostAsJsonAsync("/api/auth/bootstrap", secondBootstrapReq);
        secondBootstrapRes.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var secondBootstrapContent = await secondBootstrapRes.Content.ReadFromJsonAsync<ApiResponse<AuthResponse>>();
        secondBootstrapContent.Should().NotBeNull();
        secondBootstrapContent!.Success.Should().BeFalse();
        secondBootstrapContent.Message.Should().Contain("only permitted when no users exist");

        // 4. Normal user registration with invalid invitation code MUST fail
        var invalidRegReq = new RegisterRequest
        {
            InvitationCode = "CC-INVALID_CODE",
            FullName = "Stranger",
            DisplayName = "Stranger",
            Email = $"stranger_{Guid.NewGuid():N}@circlechat.test",
            Password = "Password123!",
            ConfirmPassword = "Password123!"
        };
        var invalidRegRes = await _client.PostAsJsonAsync("/api/auth/register", invalidRegReq);
        invalidRegRes.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        // 5. Normal user registration using the bootstrap-generated invitation code MUST SUCCEED
        var memberEmail = $"member_{Guid.NewGuid():N}@circlechat.test";
        var validRegReq = new RegisterRequest
        {
            InvitationCode = "CC-FOUNDER999",
            FullName = "Circle Member",
            DisplayName = "Member",
            Email = memberEmail,
            Password = "MemberPassword123!",
            ConfirmPassword = "MemberPassword123!"
        };
        var validRegRes = await _client.PostAsJsonAsync("/api/auth/register", validRegReq);
        validRegRes.StatusCode.Should().Be(HttpStatusCode.OK);

        var validRegContent = await validRegRes.Content.ReadFromJsonAsync<ApiResponse<AuthResponse>>();
        validRegContent.Should().NotBeNull();
        validRegContent!.Success.Should().BeTrue();
        validRegContent.Data!.User.Email.Should().Be(memberEmail);

        // Verify invitation usage incremented
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var invitation = await db.Invitations.FirstOrDefaultAsync(i => i.Code == "CC-FOUNDER999");
            invitation!.UsedCount.Should().Be(1);
        }

        // 6. Bootstrap user can create additional invitations via POST /api/invitations
        var newInviteClient = _factory.CreateClient();
        newInviteClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", founderToken);

        var createInviteReq = new CreateInvitationRequest
        {
            MaxUses = 5,
            ExpirationDays = 14
        };
        var createInviteRes = await newInviteClient.PostAsJsonAsync("/api/invitations", createInviteReq);
        createInviteRes.StatusCode.Should().Be(HttpStatusCode.OK);

        var createInviteContent = await createInviteRes.Content.ReadFromJsonAsync<ApiResponse<InvitationDto>>();
        createInviteContent.Should().NotBeNull();
        createInviteContent!.Success.Should().BeTrue();
        createInviteContent.Data.Should().NotBeNull();
        createInviteContent.Data!.Code.Should().StartWith("CC-");
        createInviteContent.Data.CreatedById.Should().Be(founderId);
    }

    [Fact]
    public async Task Bootstrap_ConcurrentRequests_OnlyOneSucceeds()
    {
        // Use a dedicated factory instance to test concurrent race condition on an empty DB
        using var dedicatedFactory = new BootstrapTestFactory();
        var client = dedicatedFactory.CreateClient();

        const int concurrentCount = 5;
        var requests = Enumerable.Range(1, concurrentCount).Select(i => new BootstrapRegisterRequest
        {
            BootstrapSecret = BootstrapTestFactory.ValidBootstrapSecret,
            FullName = $"Concurrent User {i}",
            DisplayName = $"User{i}",
            Email = $"concurrent_{i}_{Guid.NewGuid():N}@circlechat.test",
            Password = "Password123!",
            ConfirmPassword = "Password123!",
            InitialInvitationCode = $"CC-RACE{i}"
        }).ToList();

        // Fire all requests concurrently
        var tasks = requests.Select(req => client.PostAsJsonAsync("/api/auth/bootstrap", req));
        var responses = await Task.WhenAll(tasks);

        var successCount = responses.Count(r => r.StatusCode == HttpStatusCode.OK);
        var badRequestCount = responses.Count(r => r.StatusCode == HttpStatusCode.BadRequest);

        // Exactly one request must succeed and all other concurrent requests must be rejected
        successCount.Should().Be(1, "Exactly one concurrent bootstrap request must succeed");
        badRequestCount.Should().Be(concurrentCount - 1, "All competing concurrent requests must be rejected");

        // Verify only 1 user exists in the database
        using (var scope = dedicatedFactory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var totalUsers = await db.Users.CountAsync();
            totalUsers.Should().Be(1, "Database must have exactly one user registered");
        }
    }
}

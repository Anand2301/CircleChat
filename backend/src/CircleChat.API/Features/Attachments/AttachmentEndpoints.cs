using CircleChat.Application.Common.Interfaces;
using CircleChat.Application.DTOs;
using CircleChat.Domain.Entities;
using CircleChat.Domain.Enums;
using FastEndpoints;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CircleChat.API.Features.Attachments;

public class UploadAttachmentEndpoint : EndpointWithoutRequest<ApiResponse<AttachmentDto>>
{
    private readonly IFileStorage _fileStorage;
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly ILogger<UploadAttachmentEndpoint> _logger;

    public UploadAttachmentEndpoint(
        IFileStorage fileStorage,
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser,
        ILogger<UploadAttachmentEndpoint> logger)
    {
        _fileStorage = fileStorage;
        _dbContext = dbContext;
        _currentUser = currentUser;
        _logger = logger;
    }

    public override void Configure()
    {
        Post("/api/attachments/upload");
        AllowFileUploads();
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var currentUserId = _currentUser.UserId;
        if (string.IsNullOrEmpty(currentUserId))
        {
            await SendResultAsync(TypedResults.Unauthorized());
            return;
        }

        if (Files.Count == 0 || Files[0].Length == 0)
        {
            await SendResultAsync(TypedResults.BadRequest(ApiResponse<AttachmentDto>.Fail("No file uploaded or file is empty.")));
            return;
        }

        var file = Files[0];
        const long maxSizeBytes = 50 * 1024 * 1024; // 50MB max limit
        if (file.Length > maxSizeBytes)
        {
            await SendResultAsync(TypedResults.BadRequest(ApiResponse<AttachmentDto>.Fail("File size exceeds 50MB limit.")));
            return;
        }

        try
        {
            using var stream = file.OpenReadStream();
            var (storagePath, downloadUrl) = await _fileStorage.UploadFileAsync(
                stream,
                file.FileName,
                file.ContentType,
                "attachments",
                ct);

            var attachment = new Attachment
            {
                FileName = Path.GetFileName(file.FileName),
                StoragePath = downloadUrl,
                ContentType = string.IsNullOrWhiteSpace(file.ContentType) ? "application/octet-stream" : file.ContentType,
                FileSize = file.Length,
                CreatedAt = DateTime.UtcNow,
                MessageId = null // Uploaded before message is sent
            };

            _dbContext.Attachments.Add(attachment);
            await _dbContext.SaveChangesAsync(ct);

            var dto = new AttachmentDto
            {
                Id = attachment.Id,
                FileName = attachment.FileName,
                StoragePath = storagePath,
                DownloadUrl = attachment.StoragePath,
                ContentType = attachment.ContentType,
                FileSize = attachment.FileSize
            };

            _logger.LogInformation("Attachment {AttachmentId} uploaded by user {UserId}. File: {FileName}",
                attachment.Id, currentUserId, attachment.FileName);

            await SendOkAsync(ApiResponse<AttachmentDto>.Ok(dto, "File uploaded successfully."), ct);
        }
        catch (InvalidOperationException opEx)
        {
            _logger.LogWarning(opEx, "Invalid file upload attempt by user {UserId}: {Message}", currentUserId, opEx.Message);
            await SendResultAsync(TypedResults.BadRequest(ApiResponse<AttachmentDto>.Fail(opEx.Message)));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error uploading attachment for user {UserId}", currentUserId);
            await SendResultAsync(TypedResults.StatusCode(StatusCodes.Status500InternalServerError));
        }
    }
}

public class GetAttachmentDownloadEndpoint : EndpointWithoutRequest
{
    private readonly IApplicationDbContext _dbContext;
    private readonly IFileStorage _fileStorage;
    private readonly ILogger<GetAttachmentDownloadEndpoint> _logger;

    public GetAttachmentDownloadEndpoint(
        IApplicationDbContext dbContext,
        IFileStorage fileStorage,
        ILogger<GetAttachmentDownloadEndpoint> logger)
    {
        _dbContext = dbContext;
        _fileStorage = fileStorage;
        _logger = logger;
    }

    public override void Configure()
    {
        Get("/api/attachments/{id}/download");
        AllowAnonymous();
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var id = Route<Guid>("id");
        var attachment = await _dbContext.Attachments.FindAsync(new object[] { id }, ct);
        if (attachment == null)
        {
            await SendNotFoundAsync(ct);
            return;
        }

        // If stored as full cloud URL (e.g. Firebase Cloud Storage), redirect
        if (attachment.StoragePath.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
            attachment.StoragePath.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            await SendRedirectAsync(attachment.StoragePath, allowRemoteRedirects: true);
            return;
        }

        var fileResult = await _fileStorage.GetFileAsync(attachment.StoragePath, ct);
        if (fileResult == null)
        {
            _logger.LogWarning("Attachment file for {AttachmentId} not found in local storage: {Path}", id, attachment.StoragePath);
            await SendNotFoundAsync(ct);
            return;
        }

        HttpContext.Response.Headers.CacheControl = "public, max-age=31536000, immutable";
        await SendStreamAsync(
            fileResult.Value.Stream,
            fileName: attachment.FileName,
            fileLengthBytes: fileResult.Value.Stream.Length,
            contentType: attachment.ContentType,
            cancellation: ct);
    }
}

public class GetAttachmentFileEndpoint : EndpointWithoutRequest
{
    private readonly IFileStorage _fileStorage;
    private readonly ILogger<GetAttachmentFileEndpoint> _logger;

    public GetAttachmentFileEndpoint(IFileStorage fileStorage, ILogger<GetAttachmentFileEndpoint> logger)
    {
        _fileStorage = fileStorage;
        _logger = logger;
    }

    public override void Configure()
    {
        Get("/api/attachments/file/{fileName}");
        AllowAnonymous();
    }

    public override async Task HandleAsync(CancellationToken ct)
    {
        var rawFileName = Route<string>("fileName") ?? string.Empty;
        var cleanFileName = Path.GetFileName(rawFileName);
        var storagePath = $"attachments/{cleanFileName}";

        var fileResult = await _fileStorage.GetFileAsync(storagePath, ct);
        if (fileResult == null)
        {
            await SendNotFoundAsync(ct);
            return;
        }

        HttpContext.Response.Headers.CacheControl = "public, max-age=31536000, immutable";
        await SendStreamAsync(
            fileResult.Value.Stream,
            fileName: fileResult.Value.FileName,
            fileLengthBytes: fileResult.Value.Stream.Length,
            contentType: fileResult.Value.ContentType,
            cancellation: ct);
    }
}

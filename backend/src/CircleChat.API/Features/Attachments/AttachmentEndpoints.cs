using CircleChat.Application.Common.Interfaces;
using CircleChat.Application.DTOs;
using CircleChat.Domain.Entities;
using CircleChat.Domain.Enums;
using FastEndpoints;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace CircleChat.API.Features.Attachments;

public class UploadAttachmentEndpoint : EndpointWithoutRequest<ApiResponse<AttachmentDto>>
{
    private readonly IFileStorage _fileStorage;
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;

    public UploadAttachmentEndpoint(
        IFileStorage fileStorage,
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser)
    {
        _fileStorage = fileStorage;
        _dbContext = dbContext;
        _currentUser = currentUser;
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

        if (Files.Count == 0)
        {
            await SendResultAsync(TypedResults.BadRequest(ApiResponse<AttachmentDto>.Fail("No file uploaded.")));
            return;
        }

        var file = Files[0];
        if (file.Length > 50 * 1024 * 1024) // 50MB max limit
        {
            await SendResultAsync(TypedResults.BadRequest(ApiResponse<AttachmentDto>.Fail("File size exceeds 50MB limit.")));
            return;
        }

        using var stream = file.OpenReadStream();
        var (storagePath, downloadUrl) = await _fileStorage.UploadFileAsync(
            stream,
            file.FileName,
            file.ContentType,
            "attachments",
            ct);

        var attachment = new Attachment
        {
            FileName = file.FileName,
            StoragePath = downloadUrl,
            ContentType = file.ContentType,
            FileSize = file.Length,
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.Attachments.Add(attachment);
        await _dbContext.SaveChangesAsync(ct);

        var dto = new AttachmentDto
        {
            Id = attachment.Id,
            FileName = attachment.FileName,
            StoragePath = attachment.StoragePath,
            DownloadUrl = attachment.StoragePath,
            ContentType = attachment.ContentType,
            FileSize = attachment.FileSize
        };

        await SendOkAsync(ApiResponse<AttachmentDto>.Ok(dto, "File uploaded successfully."), ct);
    }
}

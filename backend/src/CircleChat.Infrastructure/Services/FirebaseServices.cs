using CircleChat.Application.Common.Interfaces;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CircleChat.Infrastructure.Services;

public class FirebaseFileStorage : IFileStorage
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<FirebaseFileStorage> _logger;
    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".png", ".gif", ".webp",
        ".pdf", ".docx", ".txt", ".mp3", ".wav", ".mp4", ".mov"
    };

    public FirebaseFileStorage(IConfiguration configuration, ILogger<FirebaseFileStorage> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<(string storagePath, string downloadUrl)> UploadFileAsync(
        Stream stream,
        string fileName,
        string contentType,
        string folder,
        CancellationToken cancellationToken = default)
    {
        // 1. Sanitize file name & prevent path traversal
        var cleanFileName = Path.GetFileName(fileName);
        var extension = Path.GetExtension(cleanFileName);

        if (!AllowedExtensions.Contains(extension))
        {
            throw new InvalidOperationException($"File type '{extension}' is not supported.");
        }

        var uniqueFileName = $"{Guid.NewGuid():N}{extension}";
        var storagePath = $"{folder.Trim('/')}/{uniqueFileName}";

        // 2. Storage handling
        var bucketName = _configuration["Firebase:StorageBucket"] ?? "csharp-dsa-masterclass.firebasestorage.app";

        try
        {
            // Local dev storage fallback if Google Cloud Storage credentials are not explicitly supplied locally
            var uploadsDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", folder.Trim('/'));
            Directory.CreateDirectory(uploadsDir);
            var localFilePath = Path.Combine(uploadsDir, uniqueFileName);

            using (var fileStream = new FileStream(localFilePath, FileMode.Create, FileAccess.Write, FileShare.None, 4096, true))
            {
                await stream.CopyToAsync(fileStream, cancellationToken);
            }

            var serverBaseUrl = _configuration["Server:BaseUrl"] ?? "http://localhost:5000";
            var downloadUrl = $"{serverBaseUrl}/uploads/{folder.Trim('/')}/{uniqueFileName}";

            _logger.LogInformation("Saved file {StoragePath} with URL: {DownloadUrl}", storagePath, downloadUrl);
            return (storagePath, downloadUrl);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to upload file {FileName} to storage", cleanFileName);
            throw;
        }
    }

    public Task DeleteFileAsync(string storagePath, CancellationToken cancellationToken = default)
    {
        try
        {
            var localFilePath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", storagePath.Replace('/', Path.DirectorySeparatorChar));
            if (File.Exists(localFilePath))
            {
                File.Delete(localFilePath);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting file {StoragePath}", storagePath);
        }
        return Task.CompletedTask;
    }
}

public class FirebasePushNotificationService : IPushNotificationService
{
    private readonly ILogger<FirebasePushNotificationService> _logger;

    public FirebasePushNotificationService(ILogger<FirebasePushNotificationService> logger)
    {
        _logger = logger;
    }

    public async Task SendNotificationAsync(
        string deviceToken,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(deviceToken)) return;

        try
        {
            if (FirebaseApp.DefaultInstance != null)
            {
                var message = new FirebaseAdmin.Messaging.Message
                {
                    Token = deviceToken,
                    Notification = new Notification { Title = title, Body = body },
                    Data = data ?? new Dictionary<string, string>()
                };
                var response = await FirebaseMessaging.DefaultInstance.SendAsync(message, cancellationToken);
                _logger.LogInformation("Push notification sent: {Response}", response);
            }
            else
            {
                _logger.LogInformation("[Dev Notification] To: {Token} | Title: {Title} | Body: {Body}", deviceToken, title, body);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to deliver push notification to device {Token}", deviceToken);
        }
    }

    public async Task SendMulticastNotificationAsync(
        IEnumerable<string> deviceTokens,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CancellationToken cancellationToken = default)
    {
        var tokenList = deviceTokens.Where(t => !string.IsNullOrWhiteSpace(t)).ToList();
        if (!tokenList.Any()) return;

        try
        {
            if (FirebaseApp.DefaultInstance != null)
            {
                var message = new MulticastMessage
                {
                    Tokens = tokenList,
                    Notification = new Notification { Title = title, Body = body },
                    Data = data ?? new Dictionary<string, string>()
                };
                var response = await FirebaseMessaging.DefaultInstance.SendEachForMulticastAsync(message, cancellationToken);
                _logger.LogInformation("Multicast push notification sent. Success: {SuccessCount}, Failures: {FailureCount}",
                    response.SuccessCount, response.FailureCount);
            }
            else
            {
                _logger.LogInformation("[Dev Multicast Notification] To {Count} devices | Title: {Title} | Body: {Body}",
                    tokenList.Count, title, body);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send multicast push notifications");
        }
    }
}

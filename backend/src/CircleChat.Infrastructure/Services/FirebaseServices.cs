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
    private static readonly System.Net.Http.HttpClient _httpClient = new();
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

    private string ResolveServerBaseUrl()
    {
        var configured = _configuration["Server:BaseUrl"];
        if (!string.IsNullOrWhiteSpace(configured) && !configured.Contains("localhost"))
        {
            return configured.TrimEnd('/');
        }

        var envUrl = Environment.GetEnvironmentVariable("SERVER_BASE_URL");
        if (!string.IsNullOrWhiteSpace(envUrl))
        {
            return envUrl.TrimEnd('/');
        }

        var isRender = Environment.GetEnvironmentVariable("RENDER") != null;
        if (isRender)
        {
            return "https://circlechat-49kc.onrender.com";
        }

        return (configured ?? "http://localhost:5000").TrimEnd('/');
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

        if (string.IsNullOrWhiteSpace(extension) || !AllowedExtensions.Contains(extension))
        {
            throw new InvalidOperationException($"File type '{extension}' is not supported.");
        }

        var uniqueFileName = $"{Guid.NewGuid():N}{extension}";
        var storagePath = $"{folder.Trim('/')}/{uniqueFileName}";
        var bucketName = _configuration["Firebase:StorageBucket"] ?? "csharp-dsa-masterclass.firebasestorage.app";

        // 2. Try durable Firebase Cloud Storage if Firebase is configured
        if (FirebaseApp.DefaultInstance != null)
        {
            try
            {
                var credential = FirebaseApp.DefaultInstance.Options?.Credential as GoogleCredential;
                if (credential != null)
                {
                    var scopedCredential = credential.CreateScoped("https://www.googleapis.com/auth/devstorage.full_control");
                    var accessToken = await scopedCredential.UnderlyingCredential.GetAccessTokenForRequestAsync(
                        "https://firebasestorage.googleapis.com/", cancellationToken);

                    if (!string.IsNullOrEmpty(accessToken))
                    {
                        var downloadToken = Guid.NewGuid().ToString("N");
                        var uploadUrl = $"https://firebasestorage.googleapis.com/v0/b/{bucketName}/o?name={Uri.EscapeDataString(storagePath)}&uploadType=media";

                        using var memoryStream = new MemoryStream();
                        if (stream.CanSeek)
                        {
                            stream.Seek(0, SeekOrigin.Begin);
                        }
                        await stream.CopyToAsync(memoryStream, cancellationToken);
                        memoryStream.Seek(0, SeekOrigin.Begin);

                        using var content = new System.Net.Http.ByteArrayContent(memoryStream.ToArray());
                        content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(
                            string.IsNullOrWhiteSpace(contentType) ? "application/octet-stream" : contentType);
                        content.Headers.Add("x-goog-meta-firebasestoragedownloadtokens", downloadToken);

                        using var request = new System.Net.Http.HttpRequestMessage(System.Net.Http.HttpMethod.Post, uploadUrl);
                        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);
                        request.Content = content;

                        var response = await _httpClient.SendAsync(request, cancellationToken);
                        if (response.IsSuccessStatusCode)
                        {
                            var persistentUrl = $"https://firebasestorage.googleapis.com/v0/b/{bucketName}/o/{Uri.EscapeDataString(storagePath)}?alt=media&token={downloadToken}";
                            _logger.LogInformation("File {FileName} successfully uploaded to Firebase Cloud Storage: {Url}", cleanFileName, persistentUrl);
                            return (storagePath, persistentUrl);
                        }
                        else
                        {
                            var respBody = await response.Content.ReadAsStringAsync(cancellationToken);
                            _logger.LogWarning("Firebase Cloud Storage upload returned {StatusCode}: {Body}. Falling back to local storage.", response.StatusCode, respBody);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed uploading to Firebase Cloud Storage. Falling back to local storage.");
            }
        }

        // 3. Resilient local storage fallback
        try
        {
            var uploadsDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", folder.Trim('/'));
            Directory.CreateDirectory(uploadsDir);
            var localFilePath = Path.Combine(uploadsDir, uniqueFileName);

            if (stream.CanSeek)
            {
                stream.Seek(0, SeekOrigin.Begin);
            }

            using (var fileStream = new FileStream(localFilePath, FileMode.Create, FileAccess.Write, FileShare.None, 4096, true))
            {
                await stream.CopyToAsync(fileStream, cancellationToken);
            }

            var serverBaseUrl = ResolveServerBaseUrl();
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

    public async Task<(Stream Stream, string ContentType, string FileName)?> GetFileAsync(string storagePath, CancellationToken cancellationToken = default)
    {
        var localFilePath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", storagePath.Replace('/', Path.DirectorySeparatorChar));
        if (File.Exists(localFilePath))
        {
            var stream = new FileStream(localFilePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            var ext = Path.GetExtension(localFilePath).ToLowerInvariant();
            var contentType = ext switch
            {
                ".jpg" or ".jpeg" => "image/jpeg",
                ".png" => "image/png",
                ".gif" => "image/gif",
                ".webp" => "image/webp",
                ".pdf" => "application/pdf",
                ".txt" => "text/plain",
                ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                ".mp3" => "audio/mpeg",
                ".wav" => "audio/wav",
                ".mp4" => "video/mp4",
                ".mov" => "video/quicktime",
                _ => "application/octet-stream"
            };
            return (stream, contentType, Path.GetFileName(localFilePath));
        }

        return await Task.FromResult<(Stream Stream, string ContentType, string FileName)?>(null);
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

    private static string MaskToken(string token)
    {
        if (string.IsNullOrEmpty(token)) return "***";
        if (token.Length <= 10) return "***";
        return $"{token[..4]}...{token[^4..]}";
    }

    public async Task<bool> SendNotificationAsync(
        string deviceToken,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(deviceToken)) return false;

        try
        {
            if (FirebaseApp.DefaultInstance != null)
            {
                var message = new FirebaseAdmin.Messaging.Message
                {
                    Token = deviceToken,
                    Notification = new Notification { Title = title, Body = body },
                    Data = data ?? new Dictionary<string, string>(),
                    Android = new AndroidConfig
                    {
                        Priority = Priority.High,
                        Notification = new AndroidNotification
                        {
                            ChannelId = "circle_chat_messages",
                            Priority = NotificationPriority.HIGH,
                            DefaultSound = true,
                            DefaultVibrateTimings = true,
                            Tag = data != null && data.TryGetValue("conversationId", out var convId) ? convId : null
                        }
                    }
                };

                var response = await FirebaseMessaging.DefaultInstance.SendAsync(message, cancellationToken);
                _logger.LogInformation("Push notification delivered to device {Device}: {ResponseId}",
                    MaskToken(deviceToken), response);
                return true;
            }
            else
            {
                _logger.LogInformation("[Dev Notification] To: {Device} | Title: {Title} | Body: {Body}",
                    MaskToken(deviceToken), title, body);
                return true;
            }
        }
        catch (FirebaseMessagingException fcmEx)
        {
            _logger.LogWarning("Firebase messaging error delivering push to {Device}: ErrorCode: {ErrorCode}",
                MaskToken(deviceToken), fcmEx.MessagingErrorCode);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Failed to deliver push notification to device {Device}: {ErrorMessage}",
                MaskToken(deviceToken), ex.Message);
            return false;
        }
    }

    public async Task<PushNotificationResult> SendMulticastNotificationAsync(
        IEnumerable<string> deviceTokens,
        string title,
        string body,
        Dictionary<string, string>? data = null,
        CancellationToken cancellationToken = default)
    {
        var tokenList = deviceTokens.Where(t => !string.IsNullOrWhiteSpace(t)).Distinct().ToList();
        var result = new PushNotificationResult();
        if (!tokenList.Any()) return result;

        if (FirebaseApp.DefaultInstance == null)
        {
            result.SuccessCount = tokenList.Count;
            result.FailureCount = 0;
            _logger.LogInformation("[Dev Multicast Notification] To {Count} devices | Title: {Title} | Body: {Body}",
                tokenList.Count, title, body);
            return result;
        }

        const int maxRetries = 2;
        int attempt = 0;
        var tokensToProcess = new List<string>(tokenList);

        while (tokensToProcess.Any() && attempt <= maxRetries && !cancellationToken.IsCancellationRequested)
        {
            attempt++;
            var nextRetryTokens = new List<string>();

            try
            {
                var message = new MulticastMessage
                {
                    Tokens = tokensToProcess,
                    Notification = new Notification { Title = title, Body = body },
                    Data = data ?? new Dictionary<string, string>(),
                    Android = new AndroidConfig
                    {
                        Priority = Priority.High,
                        Notification = new AndroidNotification
                        {
                            ChannelId = "circle_chat_messages",
                            Priority = NotificationPriority.HIGH,
                            DefaultSound = true,
                            DefaultVibrateTimings = true,
                            Tag = data != null && data.TryGetValue("conversationId", out var convId) ? convId : null
                        }
                    }
                };

                var batchResponse = await FirebaseMessaging.DefaultInstance.SendEachForMulticastAsync(message, cancellationToken);
                result.SuccessCount += batchResponse.SuccessCount;

                _logger.LogInformation("Multicast push attempt {Attempt}/{MaxRetries} sent to {Count} devices. Success: {Success}, Failures: {Failures}",
                    attempt, maxRetries + 1, tokensToProcess.Count, batchResponse.SuccessCount, batchResponse.FailureCount);

                for (int i = 0; i < batchResponse.Responses.Count; i++)
                {
                    var resp = batchResponse.Responses[i];
                    var token = tokensToProcess[i];
                    if (!resp.IsSuccess)
                    {
                        if (resp.Exception != null)
                        {
                            var fcmCode = resp.Exception.MessagingErrorCode;
                            _logger.LogWarning("Multicast delivery failed for device {Device}: {ErrorCode}",
                                MaskToken(token), fcmCode);

                            if (fcmCode == MessagingErrorCode.Unregistered ||
                                fcmCode == MessagingErrorCode.InvalidArgument ||
                                fcmCode == MessagingErrorCode.SenderIdMismatch)
                            {
                                if (!result.InvalidTokens.Contains(token))
                                {
                                    result.InvalidTokens.Add(token);
                                }
                            }
                            else if (fcmCode == MessagingErrorCode.Unavailable ||
                                     fcmCode == MessagingErrorCode.Internal ||
                                     fcmCode == MessagingErrorCode.QuotaExceeded)
                            {
                                if (attempt <= maxRetries)
                                {
                                    nextRetryTokens.Add(token);
                                }
                            }
                        }
                        else if (attempt <= maxRetries)
                        {
                            nextRetryTokens.Add(token);
                        }
                    }
                }
            }
            catch (Exception ex) when (attempt <= maxRetries && !cancellationToken.IsCancellationRequested)
            {
                _logger.LogWarning(ex, "Transient exception sending multicast push notifications on attempt {Attempt}. Retrying batch.", attempt);
                nextRetryTokens = new List<string>(tokensToProcess);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send multicast push notifications to {Count} devices on attempt {Attempt}", tokensToProcess.Count, attempt);
                break;
            }

            tokensToProcess = nextRetryTokens;
            if (tokensToProcess.Any() && attempt <= maxRetries)
            {
                var delayMs = attempt * 500; // 500ms, then 1000ms
                await Task.Delay(delayMs, cancellationToken);
            }
        }

        result.FailureCount = tokenList.Count - result.SuccessCount;
        return result;
    }
}

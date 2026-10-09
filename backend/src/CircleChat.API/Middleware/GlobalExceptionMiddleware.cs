using System.Net;
using System.Text.Json;
using CircleChat.Application.DTOs;
using CircleChat.Domain.Exceptions;

namespace CircleChat.API.Middleware;

public class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;

    public GlobalExceptionMiddleware(RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An unhandled exception occurred during request execution");
            await HandleExceptionAsync(context, ex);
        }
    }

    private static Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.ContentType = "application/json";

        var (statusCode, message) = exception switch
        {
            UnauthorizedDomainException ex => (HttpStatusCode.Forbidden, ex.Message),
            EntityNotFoundException ex => (HttpStatusCode.NotFound, ex.Message),
            DomainException ex => (HttpStatusCode.BadRequest, ex.Message),
            UnauthorizedAccessException => (HttpStatusCode.Unauthorized, "Unauthorized access"),
            _ => (HttpStatusCode.InternalServerError, "An unexpected server error occurred.")
        };

        context.Response.StatusCode = (int)statusCode;

        var response = ApiResponse<object>.Fail(message, (int)statusCode, new List<string> { exception.Message });
        var json = JsonSerializer.Serialize(response);

        return context.Response.WriteAsync(json);
    }
}

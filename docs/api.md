# CircleChat API Specification

## 1. Architectural Style
The CircleChat API utilizes FastEndpoints on ASP.NET Core 9, adhering to REST semantics for state persistence and SignalR for bi-directional real-time telemetry.

## 2. Standard Responses & Errors
All error responses adhere to the standard envelope:
```json
{
  "statusCode": 400,
  "message": "Validation failed",
  "errors": [
    "Password must be at least 8 characters long."
  ]
}
```

## 3. Endpoints Matrix

### Authentication (`/api/auth`)
- `POST /api/auth/register` - Register a new account with an invitation code.
- `POST /api/auth/login` - Authenticate with email/password; returns JWT and Refresh Token.
- `POST /api/auth/refresh` - Rotate refresh token and obtain a fresh JWT.
- `POST /api/auth/logout` - Revoke the refresh token.
- `POST /api/auth/change-password` - Update current user's password.

### Invitations (`/api/invitations`)
- `POST /api/invitations` - Create a new invitation code (admin/owner or trusted member).
- `GET /api/invitations/validate/{code}` - Check if an invitation code is valid.

### Users (`/api/users`)
- `GET /api/users/me` - Retrieve current user profile.
- `PUT /api/users/me` - Update profile (DisplayName, Bio, etc.).
- `POST /api/users/me/avatar` - Upload or update profile avatar.
- `GET /api/users/search?q={query}` - Search users by name or email.

### Conversations (`/api/conversations`)
- `POST /api/conversations/direct` - Start or retrieve a direct conversation with another user.
- `POST /api/conversations/group` - Create a new group chat.
- `GET /api/conversations` - List all conversations for the authenticated user.
- `GET /api/conversations/{id}` - Get metadata and members for a conversation.
- `PUT /api/conversations/{id}` - Update group name/description/avatar.
- `POST /api/conversations/{id}/members` - Add member to group.
- `DELETE /api/conversations/{id}/members/{userId}` - Remove member from group.
- `POST /api/conversations/{id}/leave` - Leave a conversation.

### Messages (`/api/conversations/{id}/messages` and `/api/messages/{id}`)
- `GET /api/conversations/{id}/messages?before={cursor}&limit=50` - Keyset paginated messages.
- `POST /api/conversations/{id}/messages` - Send a text, reply, or attachment-backed message.
- `PUT /api/messages/{id}` - Edit message content (author only).
- `DELETE /api/messages/{id}` - Soft-delete message.
- `POST /api/messages/{id}/reactions` - Add reaction emoji.
- `DELETE /api/messages/{id}/reactions/{reaction}` - Remove reaction emoji.
- `POST /api/messages/{id}/read` - Mark message as read.

### Attachments (`/api/attachments`)
- `POST /api/attachments/upload` - Securely upload attachment file (media/document) to Firebase Storage and return metadata.

### Devices (`/api/devices`)
- `POST /api/devices` - Register mobile device FCM token.
- `DELETE /api/devices/{token}` - Unregister device FCM token.

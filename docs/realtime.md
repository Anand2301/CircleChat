# CircleChat Real-Time Communication (SignalR)

## 1. ChatHub Overview
Hub URL: `/hubs/chat` (requires JWT authentication via query string `?access_token=...`).

## 2. Real-Time Events
- **Client to Server**:
  - `JoinConversation(Guid conversationId)`
  - `LeaveConversation(Guid conversationId)`
  - `StartTyping(Guid conversationId)`
  - `StopTyping(Guid conversationId)`
  - `MarkMessageDelivered(Guid messageId)`
  - `MarkMessageRead(Guid messageId)`

- **Server to Client (Broadcast)**:
  - `ReceiveMessage(MessageDto message)`
  - `MessageEdited(Guid messageId, string newContent, DateTime updatedAt)`
  - `MessageDeleted(Guid messageId)`
  - `ReactionUpdated(Guid messageId, string reaction, string userId, bool added)`
  - `UserTyping(Guid conversationId, string userId, string displayName, bool isTyping)`
  - `UserPresenceChanged(string userId, bool isOnline, DateTime? lastSeenAt)`
  - `MessageStatusUpdated(Guid messageId, string status, string userId)`

## 3. Ephemeral State Handling
- Typing events are never persisted to PostgreSQL. They are managed through in-memory debouncing and dispatched directly to active conversation channels.
- Presence tracking handles connection lifecycle (`OnConnectedAsync`, `OnDisconnectedAsync`) with heartbeat debounce to prevent spurious state toggling on mobile network handovers.

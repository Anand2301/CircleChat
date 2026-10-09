# CircleChat Firebase Integration

## 1. Connected Project
- Project ID: `csharp-dsa-masterclass`
- Project Number: `1038169764598`
- Storage Bucket: `csharp-dsa-masterclass.firebasestorage.app`
- Android App ID: `1:1038169764598:android:0e1b915264d2ed8b84f2d7`
- Android Package: `com.circlechat.app`

## 2. Firebase Cloud Storage
- Abstraction: `IFileStorage`
- Implementation: `FirebaseFileStorage`
- Safe filename hashing: `attachments/{conversationId}/{Guid}_{SafeSanitizedFileName}`
- Content verification: MIME validation, size limits (images: max 15MB, documents: max 50MB, audio: max 25MB).
- Binary content is uploaded to Firebase Cloud Storage, returning signed/public download URLs; only metadata is persisted in PostgreSQL.

## 3. Firebase Cloud Messaging (FCM)
- Mobile devices register FCM token via `POST /api/devices`.
- Background notification dispatch: When message is sent to conversation members who are offline or inactive on SignalR, FCM pushes payload with `senderName`, `conversationId`, and sanitised `messagePreview`.
- Foreground priority: If user is actively connected on SignalR in that conversation, push alert notification sound is suppressed to prevent duplication.

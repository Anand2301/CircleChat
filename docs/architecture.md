# CircleChat Architecture

## 1. Overview
CircleChat is a private, invite-only, high-performance mobile messaging system designed for trusted circles (10–100 users). It guarantees end-to-end data ownership by employing a secure ASP.NET Core (.NET 9) backend with PostgreSQL as the single source of truth, real-time bidirectional communication via SignalR, Firebase Cloud Storage for attachments, and Firebase Cloud Messaging (FCM) for background notifications.

## 2. High-Level Architecture Diagram
```
                     ┌────────────────────────┐
                     │ Flutter Android Client │
                     │  (Material 3 / Riverpod│
                     └──────────┬─────────────┘
                                │ HTTPS REST / WSS SignalR
                                ▼
                     ┌────────────────────────┐
                     │   ASP.NET Core API     │
                     │  (FastEndpoints / .NET9│
                     └────┬─────────┬─────────┘
                          │         │
               ┌──────────┴──┐   ┌──┴─────────────────────────┐
               ▼             ▼   ▼                            ▼
       ┌──────────────┐ ┌───────────────┐           ┌────────────────────┐
       │  PostgreSQL  │ │ Firebase FCM  │           │  Firebase Storage  │
       │ (Users, Msgs,│ │  (Push Alerts)│           │ (Images, Files,    │
       │  Groups, etc)│ └───────────────┘           │  Avatars, Media)   │
       └──────────────┘                             └────────────────────┘
```

## 3. Layer Separation (Clean Architecture)

### 3.1 CircleChat.Domain
- Pure domain models without infrastructure or framework dependencies.
- Entities: `ApplicationUser`, `Conversation`, `ConversationMember`, `Message`, `MessageRead`, `MessageReaction`, `Attachment`, `Invitation`, `RefreshToken`, `Device`.
- Enums: `ConversationType` (Direct, Group), `MemberRole` (Owner, Admin, Member), `MessageType` (Text, Image, File, Audio, System), `DevicePlatform` (Android, iOS, Web).
- Domain rules, guards, and domain exceptions.

### 3.2 CircleChat.Application
- Business operations, queries, commands, validation, and contracts.
- Interfaces: `IApplicationDbContext`, `ITokenService`, `ICurrentUserService`, `IFileStorage`, `IPresenceService`, `IPushNotificationService`, `ISignalRNotifier`.
- FluentValidation validators for all input DTOs.
- DTO contracts matching FastEndpoints.

### 3.3 CircleChat.Infrastructure
- Entity Framework Core 9 with Npgsql PostgreSQL provider.
- ASP.NET Core Identity integration with `ApplicationUser`.
- Firebase Storage client implementation (`FirebaseFileStorage`) for file and media storage.
- Firebase Cloud Messaging integration (`FirebasePushNotificationService`) with fail-safe background notifications.
- In-memory presence service (`PresenceService`) designed for seamless Redis cache drop-in.

### 3.4 CircleChat.API
- FastEndpoints for feature-sliced REST API (`/api/auth/*`, `/api/users/*`, `/api/conversations/*`, `/api/messages/*`, `/api/attachments/*`, `/api/devices/*`).
- SignalR `ChatHub` mapped to `/hubs/chat` handling real-time conversation events, typing states, and read receipts.
- Global exception handling middleware, Serilog structured logging, JWT bearer authentication, and Swagger OpenAPI documentation.

## 4. Security Principles
- Never trust client-supplied user identifiers; extract authenticated `UserId` strictly from verified JWT claims.
- Enforce conversation membership checks server-side on every message, read receipt, reaction, or membership operation.
- Use refresh token rotation with SHA-256 token hashing and revocation tracking.
- Validate MIME type, extension, magic bytes, and size before persisting file metadata.

# CircleChat

A secure, private, invite-only mobile messaging system with real-time bi-directional chat, presence, typing indicators, read receipts, media sharing, and push notifications.

---

## 1. Project Overview & Architecture
CircleChat is designed for closed circles (10–100 trusted users) seeking complete privacy and control over their communication infrastructure.

### Architectural Diagram
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

---

## 2. Technology Stack

### Backend
- **Framework**: .NET 9 / ASP.NET Core 9
- **Endpoints**: FastEndpoints (Feature-sliced vertical architecture)
- **Real-Time**: ASP.NET Core SignalR
- **Database**: PostgreSQL with Entity Framework Core 9 (Npgsql)
- **Security & Identity**: ASP.NET Core Identity, JWT Bearer Tokens, Refresh Token Rotation
- **Validation**: FluentValidation
- **Logging**: Serilog (Console + Rolling Day File Logs)
- **API Documentation**: FastEndpoints Swagger / OpenAPI

### Mobile
- **Framework**: Flutter (Dart 3, Android-first)
- **Design System**: Material 3 (Dynamic Light/Dark Themes)
- **State Management**: Riverpod (v2.6)
- **Real-Time Client**: SignalR NetCore Client
- **Local Security**: Flutter Secure Storage

### Firebase
- **Project**: Connected Firebase Project (`csharp-dsa-masterclass`)
- **Android App ID**: `1:1038169764598:android:0e1b915264d2ed8b84f2d7` (`com.circlechat.app`)
- **Services**: Cloud Storage (media & attachments), Cloud Messaging (FCM background push notifications)

---

## 3. Repository Structure
```
CircleChat/
├── backend/
│   ├── CircleChat.slnx
│   ├── src/
│   │   ├── CircleChat.Domain/           # Entities, Enums, Exceptions
│   │   ├── CircleChat.Application/      # DTOs, Interfaces, Validators
│   │   ├── CircleChat.Infrastructure/   # EF Core, PostgreSQL, Firebase, Identity
│   │   └── CircleChat.API/              # FastEndpoints, ChatHub, Middlewares
│   └── tests/
│       ├── CircleChat.UnitTests/        # 9 Unit tests (Domain & Validators)
│       └── CircleChat.IntegrationTests/ # 6 Integration tests (HTTP pipeline)
├── mobile/
│   └── circle_chat/                     # Complete Flutter Android App
├── docs/                                # Technical specifications
│   ├── architecture.md
│   ├── database.md
│   ├── api.md
│   ├── authentication.md
│   ├── realtime.md
│   ├── firebase.md
│   └── deployment.md
├── docker/
│   └── Dockerfile
├── docker-compose.yml
├── .env.example
└── README.md
```

---

## 4. Quick Start & Setup

### Prerequisites
- .NET 9 SDK
- Flutter SDK (v3.24+)
- Android SDK (API 34/36) & JDK 17
- PostgreSQL 16+ or Docker

### Step 1: Environment Setup
Copy the environment template:
```bash
cp .env.example .env
```
Provide your PostgreSQL password in `.env`.

### Step 2: Database Migration
Apply the Entity Framework Core migrations to your PostgreSQL instance:
```bash
cd backend
dotnet ef database update --project src/CircleChat.Infrastructure --startup-project src/CircleChat.API
```

### Step 3: Running the Backend API
```bash
cd backend/src/CircleChat.API
dotnet run
```
The API starts at `http://localhost:5000` with Swagger UI at `http://localhost:5000/swagger`.

### Step 4: Running with Docker Compose
Or run both the API and PostgreSQL in isolated containers:
```bash
docker compose up -d
```

### Step 5: Running Tests
Run all unit and integration test suites:
```bash
cd backend
dotnet test CircleChat.slnx
```
Run Flutter widget tests:
```bash
cd mobile/circle_chat
flutter test
```

---

## 5. Building the Android Release APK
To compile the standalone production Android APK:
```bash
cd mobile/circle_chat
flutter build apk --release
```
The output release APK is generated at:
`mobile/circle_chat/build/app/outputs/flutter-apk/app-release.apk`

---

## 6. Security & Invite-Only Flow
1. **Invite-Only Registration**: Users cannot register freely. Registration requires an active, non-expired invitation code (`CC-XXXXXXXX`).
2. **Token Security**: Short-lived JWT access tokens paired with long-lived refresh tokens. Refresh tokens are rotated upon each renewal.
3. **Server Authorization**: Every conversation access checks group membership server-side; client identifiers are never trusted.

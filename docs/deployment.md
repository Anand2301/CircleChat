# CircleChat Deployment Guide

## 1. Docker Compose
The system is ready for single-command orchestration:
```bash
docker compose up -d
```
Services included:
- `circlechat-postgres`: PostgreSQL 17 on port 5432 with persisted volume `circlechat_pgdata`.
- `circlechat-api`: ASP.NET Core 9 container exposing port 5000/5001.

## 2. Environment Variables (.env)
```env
DATABASE_CONNECTION_STRING=Host=postgres;Port=5432;Database=CircleChat;Username=postgres;Password=YourSecurePassword
JWT_SECRET=super_secret_key_at_least_32_characters_long_for_security_12345
JWT_ISSUER=CircleChatAPI
JWT_AUDIENCE=CircleChatClients
FIREBASE_PROJECT_ID=csharp-dsa-masterclass
FIREBASE_STORAGE_BUCKET=csharp-dsa-masterclass.firebasestorage.app
```

## 3. Database Migration
Migrations apply automatically on startup in containerized environments or manually via:
```bash
dotnet ef database update --project src/CircleChat.Infrastructure --startup-project src/CircleChat.API
```

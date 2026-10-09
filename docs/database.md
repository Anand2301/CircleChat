# CircleChat Database Design

## 1. Primary Database
PostgreSQL is the single source of truth for all structured application data.

## 2. Entity Relational Model & Indexes

### Tables & Relationships
- **AspNetUsers (ApplicationUser)**
  - `Id` (PK, string/uuid)
  - `FullName`, `DisplayName`, `Bio`, `ProfileImageUrl`
  - `IsActive` (bool), `LastSeenAt` (timestamp with tz), `CreatedAt`, `UpdatedAt`
  - standard Identity columns (`Email`, `PasswordHash`, `SecurityStamp`, etc.)

- **Invitations**
  - `Id` (PK, Guid)
  - `Code` (varchar 32, Unique Index)
  - `CreatedById` (FK -> AspNetUsers.Id)
  - `ExpiresAt` (timestamptz)
  - `MaxUses` (int), `UsedCount` (int)
  - `IsActive` (bool), `CreatedAt` (timestamptz)

- **Conversations**
  - `Id` (PK, Guid)
  - `Type` (enum: Direct = 0, Group = 1)
  - `Name` (nullable varchar 128)
  - `Description` (nullable varchar 512)
  - `CreatedById` (FK -> AspNetUsers.Id)
  - `CreatedAt`, `UpdatedAt` (timestamptz)

- **ConversationMembers**
  - `ConversationId` (PK part 1, FK -> Conversations.Id)
  - `UserId` (PK part 2, FK -> AspNetUsers.Id)
  - `Role` (enum: Member = 0, Admin = 1, Owner = 2)
  - `JoinedAt`, `LeftAt` (nullable timestamptz)
  - `IsActive` (bool)
  - Composite Index: `(ConversationId, UserId)`, `(UserId, IsActive)`

- **Messages**
  - `Id` (PK, Guid)
  - `ConversationId` (FK -> Conversations.Id)
  - `SenderId` (FK -> AspNetUsers.Id)
  - `Content` (text)
  - `MessageType` (enum: Text = 0, Image = 1, File = 2, Audio = 3, System = 4)
  - `ReplyToMessageId` (nullable FK -> Messages.Id)
  - `CreatedAt` (timestamptz)
  - `UpdatedAt` (nullable timestamptz)
  - `DeletedAt` (nullable timestamptz, soft-delete)
  - Composite Index: `(ConversationId, CreatedAt DESC, Id)` for fast cursor-based pagination

- **MessageReads**
  - `MessageId` (PK part 1, FK -> Messages.Id)
  - `UserId` (PK part 2, FK -> AspNetUsers.Id)
  - `ReadAt` (timestamptz)
  - Composite Index: `(MessageId, UserId)`

- **MessageReactions**
  - `Id` (PK, Guid)
  - `MessageId` (FK -> Messages.Id)
  - `UserId` (FK -> AspNetUsers.Id)
  - `Reaction` (varchar 16)
  - `CreatedAt` (timestamptz)
  - Unique Composite Index: `(MessageId, UserId, Reaction)`

- **Attachments**
  - `Id` (PK, Guid)
  - `MessageId` (FK -> Messages.Id)
  - `FileName` (varchar 256)
  - `StoragePath` (varchar 512)
  - `ContentType` (varchar 128)
  - `FileSize` (bigint)
  - `CreatedAt` (timestamptz)

- **RefreshTokens**
  - `Id` (PK, Guid)
  - `UserId` (FK -> AspNetUsers.Id)
  - `TokenHash` (varchar 128, Index)
  - `ExpiresAt`, `CreatedAt`, `RevokedAt` (nullable timestamptz)

- **Devices**
  - `Id` (PK, Guid)
  - `UserId` (FK -> AspNetUsers.Id)
  - `DeviceToken` (varchar 512, Index)
  - `Platform` (varchar 32)
  - `CreatedAt`, `LastSeenAt` (timestamptz)
  - `IsActive` (bool)

## 3. Query Optimization & Cursors
Messages are paged using keyset (cursor) pagination:
```sql
SELECT * FROM "Messages"
WHERE "ConversationId" = @convId
  AND ("CreatedAt" < @beforeTime OR ("CreatedAt" = @beforeTime AND "Id" < @beforeId))
  AND "DeletedAt" IS NULL
ORDER BY "CreatedAt" DESC, "Id" DESC
LIMIT 50;
```
This guarantees constant-time query evaluation regardless of conversation history depth without offset scan penalties.

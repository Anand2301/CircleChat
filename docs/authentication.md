# CircleChat Authentication & Authorization

## 1. Identity & Credentials
- Built on ASP.NET Core Identity with PBKDF2 password hashing.
- Invite-only verification: Users cannot register without an active, non-expired, remaining-quota invitation code.

## 2. JWT Access Tokens & Refresh Tokens
- **Access Token**: Short-lived JWT (e.g., 60 minutes) signed with HMAC-SHA256, carrying `sub` (UserId), `email`, and `name`.
- **Refresh Token**: High-entropy cryptographically secure random bytes stored as a SHA-256 hash in PostgreSQL with expiration and revocation metadata.
- **Refresh Token Rotation**: Each call to `/api/auth/refresh` invalidates the old token and generates a new token pair. If a revoked token is reused, the session is invalidated.

## 3. Conversation Authorization Pattern
Every conversation request undergoes strict server-side pipeline validation:
1. Extract `UserId` strictly from `User.FindFirst(ClaimTypes.NameIdentifier)`.
2. Validate that `ConversationMember` exists for `(ConversationId, UserId)` and `IsActive == true`.
3. For administrative mutations (changing group title, adding/removing members), verify `Role == MemberRole.Admin || Role == MemberRole.Owner`.
4. Disallow any access to unauthorized conversation streams.

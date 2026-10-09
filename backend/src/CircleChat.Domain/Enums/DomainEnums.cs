namespace CircleChat.Domain.Enums;

public enum ConversationType
{
    Direct = 0,
    Group = 1
}

public enum MemberRole
{
    Member = 0,
    Admin = 1,
    Owner = 2
}

public enum MessageType
{
    Text = 0,
    Image = 1,
    File = 2,
    Audio = 3,
    System = 4
}

public enum DevicePlatform
{
    Android = 0,
    iOS = 1,
    Web = 2
}

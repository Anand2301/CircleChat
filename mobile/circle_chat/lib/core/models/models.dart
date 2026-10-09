int _parseInt(dynamic val, [int defaultValue = 0]) {
  if (val == null) return defaultValue;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) {
    final lower = val.trim().toLowerCase();
    if (lower == 'text') return 0;
    if (lower == 'image') return 1;
    if (lower == 'file') return 2;
    if (lower == 'audio') return 3;
    if (lower == 'system') return 4;
    return int.tryParse(val.trim()) ?? defaultValue;
  }
  return defaultValue;
}

bool _parseBool(dynamic val, [bool defaultValue = false]) {
  if (val == null) return defaultValue;
  if (val is bool) return val;
  if (val is num) return val != 0;
  if (val is String) {
    final lower = val.trim().toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return defaultValue;
}

DateTime _parseDateTime(dynamic val) {
  if (val == null) return DateTime.now();
  if (val is DateTime) return val;
  return DateTime.tryParse(val.toString()) ?? DateTime.now();
}

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String displayName;
  final String? bio;
  final String? profileImageUrl;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.displayName,
    this.bio,
    this.profileImageUrl,
    this.isOnline = false,
    this.lastSeenAt,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['Id'])?.toString() ?? '';
    final email = (json['email'] ?? json['Email'])?.toString() ?? '';
    final fullName = (json['fullName'] ?? json['FullName'])?.toString() ?? '';
    final displayName = (json['displayName'] ?? json['DisplayName'])?.toString() ?? fullName;
    final bio = (json['bio'] ?? json['Bio'])?.toString();
    final profileImageUrl = (json['profileImageUrl'] ?? json['ProfileImageUrl'])?.toString();
    final isOnline = _parseBool(json['isOnline'] ?? json['IsOnline']);
    final lastSeen = json['lastSeenAt'] ?? json['LastSeenAt'];
    final createdAt = json['createdAt'] ?? json['CreatedAt'];

    return UserModel(
      id: id,
      email: email,
      fullName: fullName,
      displayName: displayName.isNotEmpty ? displayName : 'User',
      bio: bio,
      profileImageUrl: profileImageUrl,
      isOnline: isOnline,
      lastSeenAt: lastSeen != null ? DateTime.tryParse(lastSeen.toString()) : null,
      createdAt: _parseDateTime(createdAt),
    );
  }
}

class UserSearchResult {
  final String id;
  final String displayName;
  final String fullName;
  final String email;
  final String? profileImageUrl;
  final bool isOnline;

  UserSearchResult({
    required this.id,
    required this.displayName,
    required this.fullName,
    required this.email,
    this.profileImageUrl,
    this.isOnline = false,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['Id'])?.toString() ?? '';
    final displayName = (json['displayName'] ?? json['DisplayName'])?.toString() ?? '';
    final fullName = (json['fullName'] ?? json['FullName'])?.toString() ?? '';
    final email = (json['email'] ?? json['Email'])?.toString() ?? '';
    final profileImageUrl = (json['profileImageUrl'] ?? json['ProfileImageUrl'])?.toString();
    final isOnline = _parseBool(json['isOnline'] ?? json['IsOnline']);

    return UserSearchResult(
      id: id,
      displayName: displayName.isNotEmpty ? displayName : fullName,
      fullName: fullName,
      email: email,
      profileImageUrl: profileImageUrl,
      isOnline: isOnline,
    );
  }
}

class ConversationMemberModel {
  final String userId;
  final String displayName;
  final String? profileImageUrl;
  final int role; // 0 = Member, 1 = Admin, 2 = Owner
  final DateTime joinedAt;
  final bool isOnline;

  ConversationMemberModel({
    required this.userId,
    required this.displayName,
    this.profileImageUrl,
    required this.role,
    required this.joinedAt,
    this.isOnline = false,
  });

  factory ConversationMemberModel.fromJson(Map<String, dynamic> json) {
    final userId = (json['userId'] ?? json['UserId'])?.toString() ?? '';
    final displayName = (json['displayName'] ?? json['DisplayName'])?.toString() ?? 'Member';
    final profileImageUrl = (json['profileImageUrl'] ?? json['ProfileImageUrl'])?.toString();
    final role = _parseInt(json['role'] ?? json['Role'], 0);
    final joinedAt = json['joinedAt'] ?? json['JoinedAt'];
    final isOnline = _parseBool(json['isOnline'] ?? json['IsOnline']);

    return ConversationMemberModel(
      userId: userId,
      displayName: displayName,
      profileImageUrl: profileImageUrl,
      role: role,
      joinedAt: _parseDateTime(joinedAt),
      isOnline: isOnline,
    );
  }
}

class ConversationModel {
  final String id;
  final int type; // 0 = Direct, 1 = Group
  final String name;
  final String? description;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MessageModel? lastMessage;
  final int unreadCount;
  final List<ConversationMemberModel> members;

  ConversationModel({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.unreadCount = 0,
    required this.members,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['Id'])?.toString() ?? '';
    final type = _parseInt(json['type'] ?? json['Type'], 0);
    final name = (json['name'] ?? json['Name'])?.toString() ?? 'Conversation';
    final description = (json['description'] ?? json['Description'])?.toString();
    final imageUrl = (json['imageUrl'] ?? json['ImageUrl'])?.toString();
    final createdAt = json['createdAt'] ?? json['CreatedAt'];
    final updatedAt = json['updatedAt'] ?? json['UpdatedAt'];
    final lastMsgRaw = json['lastMessage'] ?? json['LastMessage'];
    final unreadCount = _parseInt(json['unreadCount'] ?? json['UnreadCount'], 0);
    final membersRaw = (json['members'] ?? json['Members']) as List<dynamic>? ?? [];

    return ConversationModel(
      id: id,
      type: type,
      name: name,
      description: description,
      imageUrl: imageUrl,
      createdAt: _parseDateTime(createdAt),
      updatedAt: _parseDateTime(updatedAt),
      lastMessage: lastMsgRaw != null && lastMsgRaw is Map
          ? MessageModel.fromJson(Map<String, dynamic>.from(lastMsgRaw))
          : null,
      unreadCount: unreadCount,
      members: membersRaw
          .whereType<Map>()
          .map((m) => ConversationMemberModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

class AttachmentModel {
  final String id;
  final String fileName;
  final String storagePath;
  final String downloadUrl;
  final String contentType;
  final int fileSize;

  AttachmentModel({
    required this.id,
    required this.fileName,
    required this.storagePath,
    required this.downloadUrl,
    required this.contentType,
    required this.fileSize,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['Id'])?.toString() ?? '';
    final fileName = (json['fileName'] ?? json['FileName'])?.toString() ?? '';
    final storagePath = (json['storagePath'] ?? json['StoragePath'])?.toString() ?? '';
    final downloadUrl = (json['downloadUrl'] ?? json['DownloadUrl'] ?? storagePath)?.toString() ?? '';
    final contentType = (json['contentType'] ?? json['ContentType'])?.toString() ?? '';
    final fileSize = _parseInt(json['fileSize'] ?? json['FileSize'], 0);

    return AttachmentModel(
      id: id,
      fileName: fileName,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      contentType: contentType,
      fileSize: fileSize,
    );
  }
}

class MessageReactionModel {
  final String id;
  final String userId;
  final String displayName;
  final String reaction;
  final DateTime createdAt;

  MessageReactionModel({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.reaction,
    required this.createdAt,
  });

  factory MessageReactionModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['Id'])?.toString() ?? '';
    final userId = (json['userId'] ?? json['UserId'])?.toString() ?? '';
    final displayName = (json['displayName'] ?? json['DisplayName'])?.toString() ?? 'User';
    final reaction = (json['reaction'] ?? json['Reaction'])?.toString() ?? '';
    final createdAt = json['createdAt'] ?? json['CreatedAt'];

    return MessageReactionModel(
      id: id,
      userId: userId,
      displayName: displayName,
      reaction: reaction,
      createdAt: _parseDateTime(createdAt),
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderDisplayName;
  final String? senderProfileImageUrl;
  final String content;
  final int messageType; // 0 = Text, 1 = Image, 2 = File, 3 = Audio, 4 = System
  final String? replyToMessageId;
  final MessageModel? replyToMessage;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final int deliveryStatus; // 0 = Sent, 1 = Delivered, 2 = Read
  final List<MessageReactionModel> reactions;
  final List<AttachmentModel> attachments;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderDisplayName,
    this.senderProfileImageUrl,
    required this.content,
    required this.messageType,
    this.replyToMessageId,
    this.replyToMessage,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deliveryStatus = 0,
    this.reactions = const [],
    this.attachments = const [],
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['Id'])?.toString() ?? '';
    final conversationId = (json['conversationId'] ?? json['ConversationId'])?.toString() ?? '';
    final senderId = (json['senderId'] ?? json['SenderId'])?.toString() ?? '';
    final senderDisplayName = (json['senderDisplayName'] ?? json['SenderDisplayName'])?.toString() ?? 'User';
    final senderProfileImageUrl = (json['senderProfileImageUrl'] ?? json['SenderProfileImageUrl'])?.toString();
    final content = (json['content'] ?? json['Content'])?.toString() ?? '';
    final messageType = _parseInt(json['messageType'] ?? json['MessageType'], 0);
    final replyToId = (json['replyToMessageId'] ?? json['ReplyToMessageId'])?.toString();
    final replyToRaw = json['replyToMessage'] ?? json['ReplyToMessage'];
    final createdAt = json['createdAt'] ?? json['CreatedAt'];
    final updatedAt = json['updatedAt'] ?? json['UpdatedAt'];
    final isDeleted = _parseBool(json['isDeleted'] ?? json['IsDeleted']);
    final deliveryStatus = _parseInt(json['deliveryStatus'] ?? json['DeliveryStatus'], 0);
    final reactionsRaw = (json['reactions'] ?? json['Reactions']) as List<dynamic>? ?? [];
    final attachmentsRaw = (json['attachments'] ?? json['Attachments']) as List<dynamic>? ?? [];

    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      senderDisplayName: senderDisplayName,
      senderProfileImageUrl: senderProfileImageUrl,
      content: content,
      messageType: messageType,
      replyToMessageId: replyToId,
      replyToMessage: replyToRaw != null && replyToRaw is Map
          ? MessageModel.fromJson(Map<String, dynamic>.from(replyToRaw))
          : null,
      createdAt: _parseDateTime(createdAt),
      updatedAt: updatedAt != null ? DateTime.tryParse(updatedAt.toString()) : null,
      isDeleted: isDeleted,
      deliveryStatus: deliveryStatus,
      reactions: reactionsRaw
          .whereType<Map>()
          .map((r) => MessageReactionModel.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      attachments: attachmentsRaw
          .whereType<Map>()
          .map((a) => AttachmentModel.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
    );
  }
}

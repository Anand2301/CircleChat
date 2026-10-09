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
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      bio: json['bio'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeenAt: json['lastSeenAt'] != null ? DateTime.tryParse(json['lastSeenAt'].toString()) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
    return UserSearchResult(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
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
    return ConversationMemberModel(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Member',
      profileImageUrl: json['profileImageUrl'] as String?,
      role: json['role'] as int? ?? 0,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isOnline: json['isOnline'] as bool? ?? false,
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
    return ConversationModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as int? ?? 0,
      name: json['name'] as String? ?? 'Conversation',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastMessage: json['lastMessage'] != null ? MessageModel.fromJson(json['lastMessage']) : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((m) => ConversationMemberModel.fromJson(m))
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
    return AttachmentModel(
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      storagePath: json['storagePath'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
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
    return MessageReactionModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      reaction: json['reaction'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
    return MessageModel(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderDisplayName: json['senderDisplayName'] as String? ?? '',
      senderProfileImageUrl: json['senderProfileImageUrl'] as String?,
      content: json['content'] as String? ?? '',
      messageType: json['messageType'] as int? ?? 0,
      replyToMessageId: json['replyToMessageId'] as String?,
      replyToMessage: json['replyToMessage'] != null
          ? MessageModel.fromJson(json['replyToMessage'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deliveryStatus: json['deliveryStatus'] as int? ?? 0,
      reactions: (json['reactions'] as List<dynamic>? ?? [])
          .map((r) => MessageReactionModel.fromJson(r))
          .toList(),
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((a) => AttachmentModel.fromJson(a))
          .toList(),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/signalr_service.dart';
import '../authentication/auth_controller.dart';

class ChatState {
  final bool isLoading;
  final bool isLoadingOlder;
  final List<MessageModel> messages;
  final MessageModel? replyingTo;
  final String? typingUserName;
  final bool isTyping;
  final String? error;

  ChatState({
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.messages = const [],
    this.replyingTo,
    this.typingUserName,
    this.isTyping = false,
    this.error,
  });

  ChatState copyWith({
    bool? isLoading,
    bool? isLoadingOlder,
    List<MessageModel>? messages,
    MessageModel? replyingTo,
    bool clearReplyingTo = false,
    String? typingUserName,
    bool? isTyping,
    String? error,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      messages: messages ?? this.messages,
      replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
      typingUserName: typingUserName,
      isTyping: isTyping ?? this.isTyping,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final String conversationId;
  final String currentUserId;

  ChatNotifier({required this.conversationId, required this.currentUserId})
      : super(ChatState(isLoading: true)) {
    loadMessages();
    _subscribeSignalR();
  }

  void _subscribeSignalR() {
    SignalRService.instance.joinConversation(conversationId);

    SignalRService.instance.addMessageListener((data) {
      final msg = MessageModel.fromJson(data);
      if (msg.conversationId == conversationId) {
        _onNewMessage(msg);
      }
    });

    SignalRService.instance.addEditListener((msgId, newContent, updatedAt) {
      _onMessageEdited(msgId, newContent, updatedAt);
    });

    SignalRService.instance.addDeleteListener((msgId) {
      _onMessageDeleted(msgId);
    });

    SignalRService.instance.addReactionListener((msgId, reaction, userId, added) {
      _onReactionUpdated(msgId, reaction, userId, added);
    });

    SignalRService.instance.addTypingListener((convId, userId, displayName, isTyping) {
      if (convId == conversationId && userId != currentUserId) {
        state = state.copyWith(typingUserName: isTyping ? displayName : null);
      }
    });

    SignalRService.instance.addReadListener((msgId, userId, readAt) {
      _onMessageRead(msgId, userId);
    });
  }

  @override
  void dispose() {
    SignalRService.instance.leaveConversation(conversationId);
    super.dispose();
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = '${ApiConstants.conversationMessages(conversationId)}?limit=50';
      final data = await ApiClient.get(url);
      if (data is List) {
        final list = data.map((json) => MessageModel.fromJson(json)).toList();
        state = state.copyWith(isLoading: false, messages: list);

        // Mark unread messages as read
        for (final m in list) {
          if (m.senderId != currentUserId && m.deliveryStatus < 2) {
            markAsRead(m.id);
          }
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadOlderMessages() async {
    if (state.isLoadingOlder || state.messages.isEmpty) return;

    final oldestMessageId = state.messages.last.id;
    state = state.copyWith(isLoadingOlder: true);

    try {
      final url = '${ApiConstants.conversationMessages(conversationId)}?before=$oldestMessageId&limit=50';
      final data = await ApiClient.get(url);
      if (data is List && data.isNotEmpty) {
        final older = data.map((json) => MessageModel.fromJson(json)).toList();
        state = state.copyWith(
          isLoadingOlder: false,
          messages: [...state.messages, ...older],
        );
      } else {
        state = state.copyWith(isLoadingOlder: false);
      }
    } catch (_) {
      state = state.copyWith(isLoadingOlder: false);
    }
  }

  void setReplyingTo(MessageModel? msg) {
    state = state.copyWith(replyingTo: msg, clearReplyingTo: msg == null);
  }

  Future<bool> sendMessage(String text, {int messageType = 0, List<String>? attachmentIds}) async {
    if (text.trim().isEmpty && (attachmentIds == null || attachmentIds.isEmpty)) return false;

    try {
      final body = {
        'content': text.trim(),
        'messageType': messageType,
        'replyToMessageId': state.replyingTo?.id,
        'attachmentIds': attachmentIds,
      };

      setReplyingTo(null);

      final data = await ApiClient.post(
        ApiConstants.conversationMessages(conversationId),
        body: body,
      );

      final msg = MessageModel.fromJson(data);
      _onNewMessage(msg);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    try {
      await ApiClient.put(
        ApiConstants.messageDetails(messageId),
        body: {'content': newContent},
      );
      _onMessageEdited(messageId, newContent, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await ApiClient.delete(ApiConstants.messageDetails(messageId));
      _onMessageDeleted(messageId);
    } catch (_) {}
  }

  Future<void> addReaction(String messageId, String reaction) async {
    try {
      await ApiClient.post(
        ApiConstants.messageReactions(messageId),
        body: {'reaction': reaction},
      );
      _onReactionUpdated(messageId, reaction, currentUserId, true);
    } catch (_) {}
  }

  Future<void> removeReaction(String messageId, String reaction) async {
    try {
      await ApiClient.delete('${ApiConstants.messageReactions(messageId)}/$reaction');
      _onReactionUpdated(messageId, reaction, currentUserId, false);
    } catch (_) {}
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await ApiClient.post(ApiConstants.messageRead(messageId));
    } catch (_) {}
  }

  void startTyping() {
    SignalRService.instance.startTyping(conversationId);
  }

  void stopTyping() {
    SignalRService.instance.stopTyping(conversationId);
  }

  void _onNewMessage(MessageModel msg) {
    if (state.messages.any((m) => m.id == msg.id)) return;
    state = state.copyWith(messages: [msg, ...state.messages]);
  }

  void _onMessageEdited(String msgId, String newContent, String updatedAtStr) {
    final updatedList = state.messages.map((m) {
      if (m.id == msgId) {
        return MessageModel(
          id: m.id,
          conversationId: m.conversationId,
          senderId: m.senderId,
          senderDisplayName: m.senderDisplayName,
          senderProfileImageUrl: m.senderProfileImageUrl,
          content: newContent,
          messageType: m.messageType,
          replyToMessageId: m.replyToMessageId,
          replyToMessage: m.replyToMessage,
          createdAt: m.createdAt,
          updatedAt: DateTime.tryParse(updatedAtStr) ?? DateTime.now(),
          isDeleted: m.isDeleted,
          deliveryStatus: m.deliveryStatus,
          reactions: m.reactions,
          attachments: m.attachments,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(messages: updatedList);
  }

  void _onMessageDeleted(String msgId) {
    final updatedList = state.messages.map((m) {
      if (m.id == msgId) {
        return MessageModel(
          id: m.id,
          conversationId: m.conversationId,
          senderId: m.senderId,
          senderDisplayName: m.senderDisplayName,
          senderProfileImageUrl: m.senderProfileImageUrl,
          content: 'This message was deleted.',
          messageType: m.messageType,
          replyToMessageId: m.replyToMessageId,
          replyToMessage: m.replyToMessage,
          createdAt: m.createdAt,
          updatedAt: m.updatedAt,
          isDeleted: true,
          deliveryStatus: m.deliveryStatus,
          reactions: m.reactions,
          attachments: m.attachments,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(messages: updatedList);
  }

  void _onReactionUpdated(String msgId, String reaction, String userId, bool added) {
    final updatedList = state.messages.map((m) {
      if (m.id == msgId) {
        final reactions = List<MessageReactionModel>.from(m.reactions);
        if (added) {
          if (!reactions.any((r) => r.userId == userId && r.reaction == reaction)) {
            reactions.add(MessageReactionModel(
              id: '',
              userId: userId,
              displayName: userId == currentUserId ? 'You' : 'User',
              reaction: reaction,
              createdAt: DateTime.now(),
            ));
          }
        } else {
          reactions.removeWhere((r) => r.userId == userId && r.reaction == reaction);
        }

        return MessageModel(
          id: m.id,
          conversationId: m.conversationId,
          senderId: m.senderId,
          senderDisplayName: m.senderDisplayName,
          senderProfileImageUrl: m.senderProfileImageUrl,
          content: m.content,
          messageType: m.messageType,
          replyToMessageId: m.replyToMessageId,
          replyToMessage: m.replyToMessage,
          createdAt: m.createdAt,
          updatedAt: m.updatedAt,
          isDeleted: m.isDeleted,
          deliveryStatus: m.deliveryStatus,
          reactions: reactions,
          attachments: m.attachments,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(messages: updatedList);
  }

  void _onMessageRead(String msgId, String userId) {
    final updatedList = state.messages.map((m) {
      if (m.id == msgId && m.senderId == currentUserId) {
        return MessageModel(
          id: m.id,
          conversationId: m.conversationId,
          senderId: m.senderId,
          senderDisplayName: m.senderDisplayName,
          senderProfileImageUrl: m.senderProfileImageUrl,
          content: m.content,
          messageType: m.messageType,
          replyToMessageId: m.replyToMessageId,
          replyToMessage: m.replyToMessage,
          createdAt: m.createdAt,
          updatedAt: m.updatedAt,
          isDeleted: m.isDeleted,
          deliveryStatus: 2, // Read
          reactions: m.reactions,
          attachments: m.attachments,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(messages: updatedList);
  }
}

final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>((ref, conversationId) {
  final user = ref.watch(authProvider).user;
  return ChatNotifier(
    conversationId: conversationId,
    currentUserId: user?.id ?? '',
  );
});

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/signalr_service.dart';
import '../authentication/auth_controller.dart';
import '../conversations/conversations_controller.dart';

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
  final Ref? ref;

  final List<VoidCallback> _unsubscribers = [];
  StreamSubscription? _reconnectSubscription;

  ChatNotifier({required this.conversationId, required this.currentUserId, this.ref})
      : super(ChatState(isLoading: true)) {
    loadMessages();
    _subscribeSignalR();
  }

  void _subscribeSignalR() {
    SignalRService.instance.ensureConnected();
    SignalRService.instance.joinConversation(conversationId);

    _unsubscribers.add(SignalRService.instance.addMessageListener((data) {
      if (!mounted) return;
      try {
        final msg = MessageModel.fromJson(data);
        if (msg.conversationId.trim().toLowerCase() == conversationId.trim().toLowerCase()) {
          debugPrint('[ChatNotifier] Received message ${msg.id} for active conversation $conversationId');
          _onNewMessage(msg);
        }
      } catch (e) {
        debugPrint('[ChatNotifier] Error parsing message: $e');
      }
    }));

    _unsubscribers.add(SignalRService.instance.addEditListener((msgId, newContent, updatedAt) {
      if (!mounted) return;
      _onMessageEdited(msgId, newContent, updatedAt);
    }));

    _unsubscribers.add(SignalRService.instance.addDeleteListener((msgId) {
      if (!mounted) return;
      _onMessageDeleted(msgId);
    }));

    _unsubscribers.add(SignalRService.instance.addReactionListener((msgId, reaction, userId, added) {
      if (!mounted) return;
      _onReactionUpdated(msgId, reaction, userId, added);
    }));

    _unsubscribers.add(SignalRService.instance.addTypingListener((convId, userId, displayName, isTyping) {
      if (!mounted) return;
      if (convId.trim().toLowerCase() == conversationId.trim().toLowerCase() && userId != currentUserId) {
        state = state.copyWith(typingUserName: isTyping ? displayName : null);
      }
    }));

    _unsubscribers.add(SignalRService.instance.addReadListener((msgId, userId, readAt) {
      if (!mounted) return;
      _onMessageRead(msgId, userId);
    }));

    _reconnectSubscription = SignalRService.instance.reconnectedStream.listen((_) {
      if (mounted) {
        syncMissedMessages();
      }
    });
  }

  @override
  void dispose() {
    for (final unsub in _unsubscribers) {
      unsub();
    }
    _unsubscribers.clear();
    _reconnectSubscription?.cancel();
    SignalRService.instance.leaveConversation(conversationId);
    super.dispose();
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = '${ApiConstants.conversationMessages(conversationId)}?limit=50';
      final data = await ApiClient.get(url);
      if (!mounted) return;

      if (data is List) {
        final history = data.map((json) => MessageModel.fromJson(json)).toList();

        // Merge history with any messages that arrived via SignalR or optimistic send while request was in-flight
        final Map<String, MessageModel> byId = {};
        for (final m in history) {
          if (m.id.isNotEmpty) {
            byId[m.id] = m;
          }
        }
        for (final m in state.messages) {
          if (m.id.isNotEmpty) {
            final existing = byId[m.id];
            if (existing == null) {
              byId[m.id] = m;
            } else {
              final preferCurrent = m.deliveryStatus > existing.deliveryStatus ||
                  (m.updatedAt != null && (existing.updatedAt == null || m.updatedAt!.isAfter(existing.updatedAt!)));
              byId[m.id] = preferCurrent ? m : existing;
            }
          }
        }

        final merged = byId.values.toList();
        merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = state.copyWith(isLoading: false, messages: merged);

        if (merged.isNotEmpty) {
          try {
            ref?.read(conversationsProvider.notifier).updateLastMessage(merged.first);
          } catch (_) {}
        }

        // Mark unread messages as read
        for (final m in merged) {
          if (m.senderId != currentUserId && m.deliveryStatus < 2) {
            markAsRead(m.id);
          }
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> syncMissedMessages() async {
    if (!mounted) return;
    try {
      String url;
      if (state.messages.isNotEmpty) {
        final newestId = state.messages.first.id;
        url = '${ApiConstants.conversationMessages(conversationId)}?after=$newestId&limit=50';
      } else {
        url = '${ApiConstants.conversationMessages(conversationId)}?limit=50';
      }

      final data = await ApiClient.get(url);
      if (!mounted) return;

      if (data is List && data.isNotEmpty) {
        final incoming = data.map((json) => MessageModel.fromJson(json)).toList();
        final existingIds = state.messages.map((m) => m.id).toSet();
        final newOnly = incoming.where((m) => !existingIds.contains(m.id)).toList();

        if (newOnly.isNotEmpty) {
          final merged = [...newOnly, ...state.messages];
          merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          state = state.copyWith(messages: merged);

          try {
            ref?.read(conversationsProvider.notifier).updateLastMessage(merged.first);
          } catch (_) {}

          for (final m in newOnly) {
            if (m.senderId != currentUserId && m.deliveryStatus < 2) {
              markAsRead(m.id);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> loadOlderMessages() async {
    if (state.isLoadingOlder || state.messages.isEmpty) return;

    final oldestMessageId = state.messages.last.id;
    state = state.copyWith(isLoadingOlder: true);

    try {
      final url = '${ApiConstants.conversationMessages(conversationId)}?before=$oldestMessageId&limit=50';
      final data = await ApiClient.get(url);
      if (!mounted) return;

      if (data is List && data.isNotEmpty) {
        final older = data.map((json) => MessageModel.fromJson(json)).toList();
        final existingIds = state.messages.map((m) => m.id).toSet();
        final newOlderOnly = older.where((m) => !existingIds.contains(m.id)).toList();

        final merged = [...state.messages, ...newOlderOnly];
        merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = state.copyWith(
          isLoadingOlder: false,
          messages: merged,
        );
      } else {
        state = state.copyWith(isLoadingOlder: false);
      }
    } catch (_) {
      if (mounted) state = state.copyWith(isLoadingOlder: false);
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
    if (!mounted) return;
    // Prevent duplicate messages
    if (state.messages.any((m) => m.id == msg.id)) return;

    final updated = [msg, ...state.messages];
    // Keep ordering stable: newest first
    updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(messages: updated);

    // Synchronize with conversation list preview immediately
    try {
      ref?.read(conversationsProvider.notifier).updateLastMessage(msg);
    } catch (_) {}

    // If incoming message from other user and viewing this chat, mark read
    if (msg.senderId != currentUserId) {
      markAsRead(msg.id);
    }
  }

  void _onMessageEdited(String msgId, String newContent, String updatedAtStr) {
    if (!mounted) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
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
  final currentUserId = ref.watch(authProvider.select((s) => s.user?.id)) ?? '';
  return ChatNotifier(
    conversationId: conversationId,
    currentUserId: currentUserId,
    ref: ref,
  );
});

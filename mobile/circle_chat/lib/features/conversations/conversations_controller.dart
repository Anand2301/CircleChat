import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/signalr_service.dart';
import '../../core/storage/token_storage.dart';
import '../authentication/auth_controller.dart';

class ConversationsState {
  final bool isLoading;
  final List<ConversationModel> conversations;
  final String? error;

  ConversationsState({
    this.isLoading = false,
    this.conversations = const [],
    this.error,
  });

  ConversationsState copyWith({
    bool? isLoading,
    List<ConversationModel>? conversations,
    String? error,
  }) {
    return ConversationsState(
      isLoading: isLoading ?? this.isLoading,
      conversations: conversations ?? this.conversations,
      error: error,
    );
  }
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final List<VoidCallback> _unsubscribers = [];
  StreamSubscription? _reconnectSubscription;
  String? _currentUserId;

  ConversationsNotifier({String this._currentUserId = ''}) : super(ConversationsState(isLoading: true)) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      _initUserId();
    }
    loadConversations();
    _subscribeToSignalR();
  }

  Future<void> _initUserId() async {
    _currentUserId = await TokenStorage.getUserId();
  }

  void updateLastMessage(MessageModel msg) {
    _handleIncomingMessage(msg);
  }

  void _subscribeToSignalR() {
    _unsubscribers.add(SignalRService.instance.addMessageListener((data) {
      if (!mounted) return;
      try {
        final newMsg = MessageModel.fromJson(data);
        _handleIncomingMessage(newMsg);
      } catch (_) {}
    }));

    _unsubscribers.add(SignalRService.instance.addPresenceListener((userId, isOnline, lastSeen) {
      if (!mounted) return;
      _handlePresenceChanged(userId, isOnline);
    }));

    _reconnectSubscription = SignalRService.instance.reconnectedStream.listen((_) {
      if (mounted) {
        loadConversations();
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
    super.dispose();
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await ApiClient.get(ApiConstants.conversations);
      if (!mounted) return;

      if (data is List) {
        final list = data.map((json) => ConversationModel.fromJson(json)).toList();
        state = state.copyWith(isLoading: false, conversations: list);
      } else {
        state = state.copyWith(isLoading: false, conversations: const []);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _handleIncomingMessage(MessageModel msg) {
    if (!mounted) return;
    final updatedList = List<ConversationModel>.from(state.conversations);
    final targetId = msg.conversationId.trim().toLowerCase();
    final index = updatedList.indexWhere((c) => c.id.trim().toLowerCase() == targetId);

    if (index != -1) {
      final old = updatedList[index];
      final isFromMe = msg.senderId == _currentUserId;
      final updated = ConversationModel(
        id: old.id,
        type: old.type,
        name: old.name,
        description: old.description,
        imageUrl: old.imageUrl,
        createdAt: old.createdAt,
        updatedAt: msg.createdAt,
        lastMessage: msg,
        unreadCount: isFromMe ? old.unreadCount : (old.unreadCount + 1),
        members: old.members,
      );
      updatedList.removeAt(index);
      updatedList.insert(0, updated);
      state = state.copyWith(conversations: updatedList);
    } else {
      // Reload conversations if a new conversation was created
      loadConversations();
    }
  }

  void markConversationRead(String conversationId) {
    if (!mounted) return;
    final targetId = conversationId.trim().toLowerCase();
    final updatedList = state.conversations.map((c) {
      if (c.id.trim().toLowerCase() == targetId) {
        return ConversationModel(
          id: c.id,
          type: c.type,
          name: c.name,
          description: c.description,
          imageUrl: c.imageUrl,
          createdAt: c.createdAt,
          updatedAt: c.updatedAt,
          lastMessage: c.lastMessage,
          unreadCount: 0,
          members: c.members,
        );
      }
      return c;
    }).toList();

    state = state.copyWith(conversations: updatedList);
  }

  void _handlePresenceChanged(String userId, bool isOnline) {
    if (!mounted) return;
    final updatedList = state.conversations.map((c) {
      final updatedMembers = c.members.map((m) {
        if (m.userId == userId) {
          return ConversationMemberModel(
            userId: m.userId,
            displayName: m.displayName,
            profileImageUrl: m.profileImageUrl,
            role: m.role,
            joinedAt: m.joinedAt,
            isOnline: isOnline,
          );
        }
        return m;
      }).toList();

      return ConversationModel(
        id: c.id,
        type: c.type,
        name: c.name,
        description: c.description,
        imageUrl: c.imageUrl,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        lastMessage: c.lastMessage,
        unreadCount: c.unreadCount,
        members: updatedMembers,
      );
    }).toList();

    state = state.copyWith(conversations: updatedList);
  }

  Future<ConversationModel?> createDirectConversation(String otherUserId) async {
    try {
      final data = await ApiClient.post(
        ApiConstants.conversationsDirect,
        body: {'otherUserId': otherUserId},
      );
      final conv = ConversationModel.fromJson(data);
      await loadConversations();
      return conv;
    } catch (e) {
      return null;
    }
  }

  Future<ConversationModel?> createGroupConversation(String name, String? description, List<String> memberIds) async {
    try {
      final data = await ApiClient.post(
        ApiConstants.conversationsGroup,
        body: {
          'name': name,
          'description': description,
          'memberUserIds': memberIds,
        },
      );
      final conv = ConversationModel.fromJson(data);
      await loadConversations();
      return conv;
    } catch (e) {
      return null;
    }
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  final currentUserId = ref.watch(authProvider.select((s) => s.user?.id)) ?? '';
  return ConversationsNotifier(currentUserId: currentUserId);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/signalr_service.dart';

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
  ConversationsNotifier() : super(ConversationsState(isLoading: true)) {
    loadConversations();
    _subscribeToSignalR();
  }

  void _subscribeToSignalR() {
    SignalRService.instance.addMessageListener((data) {
      final newMsg = MessageModel.fromJson(data);
      _handleIncomingMessage(newMsg);
    });

    SignalRService.instance.addPresenceListener((userId, isOnline, lastSeen) {
      _handlePresenceChanged(userId, isOnline);
    });
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await ApiClient.get(ApiConstants.conversations);
      if (data is List) {
        final list = data.map((json) => ConversationModel.fromJson(json)).toList();
        state = state.copyWith(isLoading: false, conversations: list);
      } else {
        state = state.copyWith(isLoading: false, conversations: []);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _handleIncomingMessage(MessageModel msg) {
    final updatedList = List<ConversationModel>.from(state.conversations);
    final index = updatedList.indexWhere((c) => c.id == msg.conversationId);

    if (index != -1) {
      final old = updatedList[index];
      final updated = ConversationModel(
        id: old.id,
        type: old.type,
        name: old.name,
        description: old.description,
        imageUrl: old.imageUrl,
        createdAt: old.createdAt,
        updatedAt: msg.createdAt,
        lastMessage: msg,
        unreadCount: old.unreadCount + 1,
        members: old.members,
      );
      updatedList.removeAt(index);
      updatedList.insert(0, updated);
      state = state.copyWith(conversations: updatedList);
    } else {
      // Reload conversations if not found
      loadConversations();
    }
  }

  void _handlePresenceChanged(String userId, bool isOnline) {
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
  return ConversationsNotifier();
});

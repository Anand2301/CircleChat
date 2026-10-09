import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

typedef OnMessageReceivedCallback = void Function(Map<String, dynamic> message);
typedef OnMessageEditedCallback = void Function(String messageId, String newContent, String updatedAt);
typedef OnMessageDeletedCallback = void Function(String messageId);
typedef OnReactionUpdatedCallback = void Function(String messageId, String reaction, String userId, bool added);
typedef OnUserTypingCallback = void Function(String conversationId, String userId, String displayName, bool isTyping);
typedef OnPresenceChangedCallback = void Function(String userId, bool isOnline, String? lastSeenAt);
typedef OnMessageReadCallback = void Function(String messageId, String userId, String readAt);

class SignalRService {
  static SignalRService? _instance;
  static SignalRService get instance => _instance ??= SignalRService._();

  SignalRService._();

  HubConnection? _hubConnection;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  final _reconnectedController = StreamController<void>.broadcast();
  Stream<void> get reconnectedStream => _reconnectedController.stream;

  final Set<String> _activeConversationIds = {};
  Set<String> get activeConversationIds => Set.unmodifiable(_activeConversationIds);

  // Event callbacks
  final List<OnMessageReceivedCallback> _messageCallbacks = [];
  final List<OnMessageEditedCallback> _editCallbacks = [];
  final List<OnMessageDeletedCallback> _deleteCallbacks = [];
  final List<OnReactionUpdatedCallback> _reactionCallbacks = [];
  final List<OnUserTypingCallback> _typingCallbacks = [];
  final List<OnPresenceChangedCallback> _presenceCallbacks = [];
  final List<OnMessageReadCallback> _readCallbacks = [];

  VoidCallback addMessageListener(OnMessageReceivedCallback cb) {
    _messageCallbacks.add(cb);
    return () => _messageCallbacks.remove(cb);
  }
  void removeMessageListener(OnMessageReceivedCallback cb) => _messageCallbacks.remove(cb);

  VoidCallback addEditListener(OnMessageEditedCallback cb) {
    _editCallbacks.add(cb);
    return () => _editCallbacks.remove(cb);
  }
  void removeEditListener(OnMessageEditedCallback cb) => _editCallbacks.remove(cb);

  VoidCallback addDeleteListener(OnMessageDeletedCallback cb) {
    _deleteCallbacks.add(cb);
    return () => _deleteCallbacks.remove(cb);
  }
  void removeDeleteListener(OnMessageDeletedCallback cb) => _deleteCallbacks.remove(cb);

  VoidCallback addReactionListener(OnReactionUpdatedCallback cb) {
    _reactionCallbacks.add(cb);
    return () => _reactionCallbacks.remove(cb);
  }
  void removeReactionListener(OnReactionUpdatedCallback cb) => _reactionCallbacks.remove(cb);

  VoidCallback addTypingListener(OnUserTypingCallback cb) {
    _typingCallbacks.add(cb);
    return () => _typingCallbacks.remove(cb);
  }
  void removeTypingListener(OnUserTypingCallback cb) => _typingCallbacks.remove(cb);

  VoidCallback addPresenceListener(OnPresenceChangedCallback cb) {
    _presenceCallbacks.add(cb);
    return () => _presenceCallbacks.remove(cb);
  }
  void removePresenceListener(OnPresenceChangedCallback cb) => _presenceCallbacks.remove(cb);

  VoidCallback addReadListener(OnMessageReadCallback cb) {
    _readCallbacks.add(cb);
    return () => _readCallbacks.remove(cb);
  }
  void removeReadListener(OnMessageReadCallback cb) => _readCallbacks.remove(cb);

  Future<void> connect() async {
    if (_isConnected && _hubConnection?.state == HubConnectionState.Connected) return;

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      if (_hubConnection != null) {
        try {
          await _hubConnection?.stop();
        } catch (_) {}
        _hubConnection = null;
      }

      final url = '${ApiConstants.signalRHubUrl}?access_token=$token';

      _hubConnection = HubConnectionBuilder()
          .withUrl(url, options: HttpConnectionOptions(
            accessTokenFactory: () => Future.value(token),
            transport: HttpTransportType.WebSockets,
            logMessageContent: false,
          ))
          .withAutomaticReconnect()
          .build();

      _registerHubHandlers();

      _hubConnection?.onclose(({error}) {
        _isConnected = false;
        _connectionStateController.add(false);
      });

      _hubConnection?.onreconnecting(({error}) {
        _isConnected = false;
        _connectionStateController.add(false);
      });

      _hubConnection?.onreconnected(({connectionId}) async {
        _isConnected = true;
        _connectionStateController.add(true);
        await _restoreSubscriptions();
        _reconnectedController.add(null);
      });

      await _hubConnection?.start();
      _isConnected = true;
      _connectionStateController.add(true);
      await _restoreSubscriptions();
    } catch (_) {
      _isConnected = false;
      _connectionStateController.add(false);
    }
  }

  Future<void> ensureConnected() async {
    if (!_isConnected ||
        _hubConnection == null ||
        _hubConnection?.state == HubConnectionState.Disconnected) {
      await connect();
    }
  }

  Future<void> _restoreSubscriptions() async {
    if (!_isConnected || _hubConnection?.state != HubConnectionState.Connected) return;
    for (final convId in _activeConversationIds.toList()) {
      try {
        await _hubConnection?.invoke('JoinConversation', args: [convId]);
      } catch (_) {}
    }
  }

  void _registerHubHandlers() {
    _hubConnection?.on('ReceiveMessage', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          final data = arguments[0] as Map<String, dynamic>;
          final cbs = List<OnMessageReceivedCallback>.from(_messageCallbacks);
          for (final cb in cbs) {
            try {
              cb(data);
            } catch (_) {}
          }
        } catch (_) {}
      }
    });

    _hubConnection?.on('MessageEdited', (arguments) {
      if (arguments != null && arguments.length >= 3) {
        try {
          final id = arguments[0].toString();
          final content = arguments[1].toString();
          final updatedAt = arguments[2].toString();
          final cbs = List<OnMessageEditedCallback>.from(_editCallbacks);
          for (final cb in cbs) {
            try {
              cb(id, content, updatedAt);
            } catch (_) {}
          }
        } catch (_) {}
      }
    });

    _hubConnection?.on('MessageDeleted', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          final id = arguments[0].toString();
          final cbs = List<OnMessageDeletedCallback>.from(_deleteCallbacks);
          for (final cb in cbs) {
            try {
              cb(id);
            } catch (_) {}
          }
        } catch (_) {}
      }
    });

    _hubConnection?.on('ReactionUpdated', (arguments) {
      if (arguments != null && arguments.length >= 4) {
        try {
          final id = arguments[0].toString();
          final reaction = arguments[1].toString();
          final userId = arguments[2].toString();
          final added = arguments[3] as bool? ?? false;
          final cbs = List<OnReactionUpdatedCallback>.from(_reactionCallbacks);
          for (final cb in cbs) {
            try {
              cb(id, reaction, userId, added);
            } catch (_) {}
          }
        } catch (_) {}
      }
    });

    _hubConnection?.on('UserTyping', (arguments) {
      if (arguments != null && arguments.length >= 4) {
        try {
          final convId = arguments[0].toString();
          final userId = arguments[1].toString();
          final displayName = arguments[2].toString();
          final isTyping = arguments[3] as bool? ?? false;
          final cbs = List<OnUserTypingCallback>.from(_typingCallbacks);
          for (final cb in cbs) {
            try {
              cb(convId, userId, displayName, isTyping);
            } catch (_) {}
          }
        } catch (_) {}
      }
    });

    _hubConnection?.on('UserPresenceChanged', (arguments) {
      if (arguments != null && arguments.length >= 2) {
        try {
          final userId = arguments[0].toString();
          final isOnline = arguments[1] as bool? ?? false;
          final lastSeen = arguments.length > 2 ? arguments[2]?.toString() : null;
          final cbs = List<OnPresenceChangedCallback>.from(_presenceCallbacks);
          for (final cb in cbs) {
            try {
              cb(userId, isOnline, lastSeen);
            } catch (_) {}
          }
        } catch (_) {}
      }
    });

    _hubConnection?.on('MessageRead', (arguments) {
      if (arguments != null && arguments.length >= 3) {
        try {
          final msgId = arguments[0].toString();
          final userId = arguments[1].toString();
          final readAt = arguments[2].toString();
          final cbs = List<OnMessageReadCallback>.from(_readCallbacks);
          for (final cb in cbs) {
            try {
              cb(msgId, userId, readAt);
            } catch (_) {}
          }
        } catch (_) {}
      }
    });
  }

  Future<void> joinConversation(String conversationId) async {
    _activeConversationIds.add(conversationId);
    if (_isConnected && _hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection?.invoke('JoinConversation', args: [conversationId]);
      } catch (_) {}
    }
  }

  Future<void> leaveConversation(String conversationId) async {
    _activeConversationIds.remove(conversationId);
    if (_isConnected && _hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection?.invoke('LeaveConversation', args: [conversationId]);
      } catch (_) {}
    }
  }

  Future<void> startTyping(String conversationId) async {
    if (_isConnected && _hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection?.invoke('StartTyping', args: [conversationId]);
      } catch (_) {}
    }
  }

  Future<void> stopTyping(String conversationId) async {
    if (_isConnected && _hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection?.invoke('StopTyping', args: [conversationId]);
      } catch (_) {}
    }
  }

  Future<void> disconnect() async {
    try {
      await _hubConnection?.stop();
    } catch (_) {}
    _activeConversationIds.clear();
    _isConnected = false;
    _connectionStateController.add(false);
  }
}

import 'dart:async';
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

  // Event callbacks
  final List<OnMessageReceivedCallback> _messageCallbacks = [];
  final List<OnMessageEditedCallback> _editCallbacks = [];
  final List<OnMessageDeletedCallback> _deleteCallbacks = [];
  final List<OnReactionUpdatedCallback> _reactionCallbacks = [];
  final List<OnUserTypingCallback> _typingCallbacks = [];
  final List<OnPresenceChangedCallback> _presenceCallbacks = [];
  final List<OnMessageReadCallback> _readCallbacks = [];

  void addMessageListener(OnMessageReceivedCallback cb) => _messageCallbacks.add(cb);
  void removeMessageListener(OnMessageReceivedCallback cb) => _messageCallbacks.remove(cb);

  void addEditListener(OnMessageEditedCallback cb) => _editCallbacks.add(cb);
  void removeEditListener(OnMessageEditedCallback cb) => _editCallbacks.remove(cb);

  void addDeleteListener(OnMessageDeletedCallback cb) => _deleteCallbacks.add(cb);
  void removeDeleteListener(OnMessageDeletedCallback cb) => _deleteCallbacks.remove(cb);

  void addReactionListener(OnReactionUpdatedCallback cb) => _reactionCallbacks.add(cb);
  void removeReactionListener(OnReactionUpdatedCallback cb) => _reactionCallbacks.remove(cb);

  void addTypingListener(OnUserTypingCallback cb) => _typingCallbacks.add(cb);
  void removeTypingListener(OnUserTypingCallback cb) => _typingCallbacks.remove(cb);

  void addPresenceListener(OnPresenceChangedCallback cb) => _presenceCallbacks.add(cb);
  void removePresenceListener(OnPresenceChangedCallback cb) => _presenceCallbacks.remove(cb);

  void addReadListener(OnMessageReadCallback cb) => _readCallbacks.add(cb);
  void removeReadListener(OnMessageReadCallback cb) => _readCallbacks.remove(cb);

  Future<void> connect() async {
    if (_isConnected && _hubConnection?.state == HubConnectionState.Connected) return;

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    try {
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

      _hubConnection?.onreconnected(({connectionId}) {
        _isConnected = true;
        _connectionStateController.add(true);
      });

      await _hubConnection?.start();
      _isConnected = true;
      _connectionStateController.add(true);
    } catch (_) {
      _isConnected = false;
      _connectionStateController.add(false);
    }
  }

  void _registerHubHandlers() {
    _hubConnection?.on('ReceiveMessage', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<String, dynamic>;
        for (final cb in _messageCallbacks) {
          cb(data);
        }
      }
    });

    _hubConnection?.on('MessageEdited', (arguments) {
      if (arguments != null && arguments.length >= 3) {
        final id = arguments[0].toString();
        final content = arguments[1].toString();
        final updatedAt = arguments[2].toString();
        for (final cb in _editCallbacks) {
          cb(id, content, updatedAt);
        }
      }
    });

    _hubConnection?.on('MessageDeleted', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final id = arguments[0].toString();
        for (final cb in _deleteCallbacks) {
          cb(id);
        }
      }
    });

    _hubConnection?.on('ReactionUpdated', (arguments) {
      if (arguments != null && arguments.length >= 4) {
        final id = arguments[0].toString();
        final reaction = arguments[1].toString();
        final userId = arguments[2].toString();
        final added = arguments[3] as bool? ?? false;
        for (final cb in _reactionCallbacks) {
          cb(id, reaction, userId, added);
        }
      }
    });

    _hubConnection?.on('UserTyping', (arguments) {
      if (arguments != null && arguments.length >= 4) {
        final convId = arguments[0].toString();
        final userId = arguments[1].toString();
        final displayName = arguments[2].toString();
        final isTyping = arguments[3] as bool? ?? false;
        for (final cb in _typingCallbacks) {
          cb(convId, userId, displayName, isTyping);
        }
      }
    });

    _hubConnection?.on('UserPresenceChanged', (arguments) {
      if (arguments != null && arguments.length >= 2) {
        final userId = arguments[0].toString();
        final isOnline = arguments[1] as bool? ?? false;
        final lastSeen = arguments.length > 2 ? arguments[2]?.toString() : null;
        for (final cb in _presenceCallbacks) {
          cb(userId, isOnline, lastSeen);
        }
      }
    });

    _hubConnection?.on('MessageRead', (arguments) {
      if (arguments != null && arguments.length >= 3) {
        final msgId = arguments[0].toString();
        final userId = arguments[1].toString();
        final readAt = arguments[2].toString();
        for (final cb in _readCallbacks) {
          cb(msgId, userId, readAt);
        }
      }
    });
  }

  Future<void> joinConversation(String conversationId) async {
    if (_isConnected && _hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection?.invoke('JoinConversation', args: [conversationId]);
      } catch (_) {}
    }
  }

  Future<void> leaveConversation(String conversationId) async {
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
    _isConnected = false;
    _connectionStateController.add(false);
  }
}

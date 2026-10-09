import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/push_notification_service.dart';
import '../../core/network/signalr_service.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/avatar_widget.dart';
import '../../core/widgets/typing_indicator.dart';
import '../conversations/conversations_controller.dart';
import 'chat_controller.dart';
import 'image_viewer_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final ConversationModel conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  String _currentUserId = '';
  bool _isUploading = false;
  bool _isSending = false;
  bool _hasText = false;
  File? _pendingImage;

  final List<String> _reactions = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushNotificationService.instance.activeConversationId = widget.conversation.id;
    PushNotificationService.instance.onSyncActiveConversation = () {
      if (mounted) {
        ref.read(chatProvider(widget.conversation.id).notifier).syncMissedMessages();
      }
    };
    SignalRService.instance.ensureConnected();
    _loadCurrentUserId();
    _scrollController.addListener(_onScroll);
    _textController.addListener(_handleTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(conversationsProvider.notifier).markConversationRead(widget.conversation.id);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PushNotificationService.instance.activeConversationId = widget.conversation.id;
      SignalRService.instance.ensureConnected();
      ref.read(chatProvider(widget.conversation.id).notifier).syncMissedMessages();
      ref.read(conversationsProvider.notifier).markConversationRead(widget.conversation.id);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (PushNotificationService.instance.activeConversationId == widget.conversation.id) {
        PushNotificationService.instance.activeConversationId = null;
      }
    }
  }

  void _handleTextChanged() {
    final hasNow = _textController.text.trim().isNotEmpty;
    if (hasNow != _hasText) {
      setState(() => _hasText = hasNow);
    }
  }

  Future<void> _loadCurrentUserId() async {
    final id = await TokenStorage.getUserId() ?? '';
    if (mounted) setState(() => _currentUserId = id);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatProvider(widget.conversation.id).notifier).loadOlderMessages();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (PushNotificationService.instance.activeConversationId == widget.conversation.id) {
      PushNotificationService.instance.activeConversationId = null;
    }
    PushNotificationService.instance.onSyncActiveConversation = null;
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_isSending) return;
    final text = _textController.text.trim();
    if (text.isEmpty && _pendingImage == null) return;

    setState(() => _isSending = true);

    try {
      ref.read(chatProvider(widget.conversation.id).notifier).stopTyping();

      // If an image is pending, upload it first
      if (_pendingImage != null) {
        setState(() => _isUploading = true);
        final uploadData = await ApiClient.uploadFile(
          ApiConstants.attachmentsUpload,
          _pendingImage!,
        );
        final attachmentId = (uploadData['id'] ?? uploadData['Id'])?.toString() ?? '';

        final ok = await ref.read(chatProvider(widget.conversation.id).notifier).sendMessage(
              text,
              messageType: 1, // Image
              attachmentIds: attachmentId.isNotEmpty ? [attachmentId] : null,
            );

        if (ok) {
          _textController.clear();
          setState(() {
            _pendingImage = null;
            _isUploading = false;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to send image message. Please tap send to retry.'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      } else {
        // Plain text message
        final ok = await ref.read(chatProvider(widget.conversation.id).notifier).sendMessage(text);
        if (ok) {
          _textController.clear();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to send message. Please tap send to retry.'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _handlePickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _pendingImage = File(picked.path);
    });
  }

  void _showAttachmentOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.mintAccent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0D9488), size: 22),
                  ),
                  title: Text(
                    'Photo Library',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Share photos and pictures',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handlePickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.paleBlue.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0284C7), size: 22),
                  ),
                  title: Text(
                    'Camera',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Capture and send a photo instantly',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handlePickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReactionSheet(MessageModel message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAuthor = message.senderId == _currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating Reaction Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _reactions.map((emoji) {
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          ref.read(chatProvider(widget.conversation.id).notifier).addReaction(message.id, emoji);
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                // Action Card
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.reply_rounded),
                        title: const Text('Reply', style: TextStyle(fontWeight: FontWeight.w500)),
                        onTap: () {
                          Navigator.pop(ctx);
                          ref.read(chatProvider(widget.conversation.id).notifier).setReplyingTo(message);
                        },
                      ),
                      if (isAuthor && !message.isDeleted) ...[
                        Divider(height: 1, indent: 56, color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                        ListTile(
                          leading: const Icon(Icons.edit_rounded),
                          title: const Text('Edit message', style: TextStyle(fontWeight: FontWeight.w500)),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showEditDialog(message);
                          },
                        ),
                        Divider(height: 1, indent: 56, color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                        ListTile(
                          leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
                          title: const Text('Delete message', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w500)),
                          onTap: () {
                            Navigator.pop(ctx);
                            ref.read(chatProvider(widget.conversation.id).notifier).deleteMessage(message.id);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(MessageModel message) {
    final editController = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Message', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Enter new message text'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatProvider(widget.conversation.id).notifier).editMessage(message.id, editController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(chatProvider(widget.conversation.id), (previous, next) {
      if (previous != null && next.messages.length > previous.messages.length) {
        if (_scrollController.hasClients && _scrollController.offset < 100) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    });

    final chatState = ref.watch(chatProvider(widget.conversation.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDirect = widget.conversation.type == 0;
    final otherMember = isDirect
        ? widget.conversation.members.firstWhere(
            (m) => m.userId != _currentUserId,
            orElse: () => widget.conversation.members.first,
          )
        : null;
    final isOnline = otherMember?.isOnline ?? false;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: AppBar(
        scrolledUnderElevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatarWithStatus(
              name: widget.conversation.name,
              imageUrl: widget.conversation.imageUrl,
              isOnline: isOnline,
              showStatus: isDirect,
              radius: 19,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  if (chatState.typingUserName != null)
                    Text(
                      '${chatState.typingUserName} is typing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.mintAccent : AppTheme.lightAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (isDirect && isOnline)
                    const Text(
                      'Active now',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0D9488),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      isDirect ? 'Offline' : '${widget.conversation.members.length} members',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: chatState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : chatState.messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppTheme.mintAccent : AppTheme.lightAccent)
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 32,
                                    color: isDark ? AppTheme.mintAccent : AppTheme.lightAccent,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No messages yet',
                                  style: TextStyle(
                                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Say hello and start the conversation!',
                                  style: TextStyle(
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          itemCount: chatState.messages.length +
                              (chatState.isLoadingOlder ? 1 : 0) +
                              (chatState.typingUserName != null ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (chatState.typingUserName != null && index == 0) {
                              return TypingIndicatorBubble(userName: chatState.typingUserName);
                            }

                            final adjustedIndex = chatState.typingUserName != null ? index - 1 : index;

                            if (adjustedIndex == chatState.messages.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }

                            final message = chatState.messages[adjustedIndex];
                            final isMe = message.senderId == _currentUserId;
                            return _buildMessageBubble(message, isMe);
                          },
                        ),
            ),
            if (chatState.replyingTo != null) _buildReplyBar(chatState.replyingTo!),
            if (_pendingImage != null) _buildPendingImageBar(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingImageBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _pendingImage!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Photo ready to send',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                Text(
                  _isUploading ? 'Uploading...' : 'Tap send to share',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!_isUploading)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => setState(() => _pendingImage = null),
            )
          else
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat('h:mm a').format(message.createdAt.toLocal());

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );

    final bubbleColor = isMe
        ? (isDark ? AppTheme.darkBubbleMe : AppTheme.lightBubbleMe)
        : (isDark ? AppTheme.darkBubbleOther : AppTheme.lightBubbleOther);

    final textColor = isMe
        ? (isDark ? AppTheme.darkBubbleMeText : AppTheme.lightBubbleMeText)
        : (isDark ? AppTheme.darkBubbleOtherText : AppTheme.lightBubbleOtherText);

    final metaColor = isMe
        ? (isDark
            ? AppTheme.darkBubbleMeText.withValues(alpha: 0.65)
            : AppTheme.lightBubbleMeText.withValues(alpha: 0.7))
        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showReactionSheet(message),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: bubbleRadius,
                border: !isMe
                    ? Border.all(
                        color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                        width: 0.8,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group sender name if group conversation
                  if (!isMe && widget.conversation.type == 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        message.senderDisplayName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.mintAccent : AppTheme.lightAccent,
                        ),
                      ),
                    ),
                  // Reply quote
                  if (message.replyToMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.black.withValues(alpha: 0.1)
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: isMe
                                ? (isDark ? AppTheme.midnightBackground : AppTheme.lightBubbleMeText)
                                : (isDark ? AppTheme.mintAccent : AppTheme.lightAccent),
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyToMessage!.senderDisplayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isMe
                                  ? (isDark ? AppTheme.darkBubbleMeText : AppTheme.lightBubbleMeText)
                                  : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            message.replyToMessage!.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isMe
                                  ? (isDark ? AppTheme.darkBubbleMeText.withValues(alpha: 0.7) : AppTheme.lightBubbleMeText.withValues(alpha: 0.8))
                                  : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Image attachment if present
                  if (message.messageType == 1 && message.attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Builder(
                        builder: (context) {
                          final rawUrl = message.attachments.first.downloadUrl;
                          final resolved = resolveMediaUrl(rawUrl) ?? rawUrl;
                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ImageViewerScreen(
                                    imageUrl: resolved,
                                    fileName: message.attachments.first.fileName.isNotEmpty
                                        ? message.attachments.first.fileName
                                        : 'Photo',
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Hero(
                                tag: 'img_${message.id}_${message.attachments.first.id}',
                                child: Image.network(
                                  resolved,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      height: 180,
                                      color: Colors.black.withValues(alpha: 0.1),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: progress.expectedTotalBytes != null
                                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                          color: isMe ? Colors.black54 : AppTheme.mintAccent,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, _, _) => Container(
                                    height: 120,
                                    color: Colors.black.withValues(alpha: 0.1),
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_rounded,
                                        size: 36,
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  // Text content
                  if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.3,
                        color: textColor,
                        fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  const SizedBox(height: 3),
                  // Metadata row (timestamp + delivery ticks)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: metaColor,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.deliveryStatus == 2
                              ? Icons.done_all_rounded
                              : (message.deliveryStatus == 1 ? Icons.done_all_rounded : Icons.done_rounded),
                          size: 14,
                          color: message.deliveryStatus == 2
                              ? const Color(0xFF0D9488)
                              : metaColor,
                        ),
                      ],
                    ],
                  ),
                  // Reaction chips
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: message.reactions.map((r) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.3)
                                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            r.reaction,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBar(MessageModel replyMessage) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.mintAccent : AppTheme.lightAccent,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${replyMessage.senderDisplayName}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isDark ? AppTheme.mintAccent : AppTheme.lightAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyMessage.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => ref.read(chatProvider(widget.conversation.id).notifier).setReplyingTo(null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSend = (_hasText || _pendingImage != null) && !_isSending;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.mintAccent : AppTheme.lightAccent).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                size: 20,
                color: isDark ? AppTheme.mintAccent : AppTheme.lightAccent,
              ),
            ),
            tooltip: 'Add Image',
            onPressed: _showAttachmentOptions,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                  width: 0.6,
                ),
              ),
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 5,
                style: TextStyle(
                  fontSize: 15.5,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
                onChanged: (val) {
                  if (val.trim().isNotEmpty) {
                    ref.read(chatProvider(widget.conversation.id).notifier).startTyping();
                  } else {
                    ref.read(chatProvider(widget.conversation.id).notifier).stopTyping();
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    fontSize: 15,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: canSend
                  ? (isDark ? AppTheme.mintAccent : AppTheme.lightAccent)
                  : (isDark ? const Color(0xFF22323D) : const Color(0xFFE2E8F0)),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: canSend ? _handleSend : null,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _isSending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? AppTheme.midnightBackground : Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: canSend
                              ? (isDark ? AppTheme.midnightBackground : Colors.white)
                              : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

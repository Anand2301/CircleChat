import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import 'chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final ConversationModel conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  String _currentUserId = '';
  bool _isUploading = false;

  final List<String> _reactions = ['👍', '❤️', '😂', '😮', '😢', '👏', '🔥'];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadCurrentUserId() async {
    final id = await TokenStorage.getUserId() ?? '';
    if (mounted) setState(() => _currentUserId = id);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatProvider(widget.conversation.id).notifier).loadOlderMessages();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    ref.read(chatProvider(widget.conversation.id).notifier).stopTyping();
    await ref.read(chatProvider(widget.conversation.id).notifier).sendMessage(text);
  }

  Future<void> _handlePickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final uploadData = await ApiClient.uploadFile(
        ApiConstants.attachmentsUpload,
        File(picked.path),
      );
      final attachmentId = uploadData['id'] as String;

      await ref.read(chatProvider(widget.conversation.id).notifier).sendMessage(
            '',
            messageType: 1, // Image
            attachmentIds: [attachmentId],
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showReactionSheet(MessageModel message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final isAuthor = message.senderId == _currentUserId;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick emoji bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _reactions.map((emoji) {
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          ref.read(chatProvider(widget.conversation.id).notifier).addReaction(message.id, emoji);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(chatProvider(widget.conversation.id).notifier).setReplyingTo(message);
                  },
                ),
                if (isAuthor && !message.isDeleted) ...[
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit message'),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditDialog(message);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('Delete message', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(chatProvider(widget.conversation.id).notifier).deleteMessage(message.id);
                    },
                  ),
                ],
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
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new message text'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
    final chatState = ref.watch(chatProvider(widget.conversation.id));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                widget.conversation.name.isNotEmpty ? widget.conversation.name[0].toUpperCase() : 'C',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chatState.typingUserName != null)
                    Text(
                      '${chatState.typingUserName} is typing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Text(
                      widget.conversation.type == 0 ? 'Private Chat' : '${widget.conversation.members.length} members',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
            if (_isUploading)
              const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: chatState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : chatState.messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text('No messages yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Send a message to start the conversation!', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: chatState.messages.length + (chatState.isLoadingOlder ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == chatState.messages.length) {
                              return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
                            }
                            final message = chatState.messages[index];
                            final isMe = message.senderId == _currentUserId;
                            return _buildMessageBubble(message, isMe);
                          },
                        ),
            ),
            if (chatState.replyingTo != null) _buildReplyBar(chatState.replyingTo!),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('hh:mm a').format(message.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showReactionSheet(message),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? theme.colorScheme.primary
                    : (theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && widget.conversation.type == 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderDisplayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white70 : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  if (message.replyToMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: isMe ? Colors.white : theme.colorScheme.primary, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyToMessage!.senderDisplayName,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.black87),
                          ),
                          Text(
                            message.replyToMessage!.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  if (message.messageType == 1 && message.attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          message.attachments.first.downloadUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                        ),
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? Colors.white : (theme.brightness == Brightness.dark ? Colors.white : Colors.black87),
                      fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey[500]),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.deliveryStatus == 2 ? Icons.done_all_rounded : (message.deliveryStatus == 1 ? Icons.done_all_rounded : Icons.done_rounded),
                          size: 14,
                          color: message.deliveryStatus == 2 ? Colors.cyanAccent : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: message.reactions.map((r) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${r.reaction} ${r.displayName == 'You' ? 'You' : ''}', style: const TextStyle(fontSize: 12)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Row(
        children: [
          Icon(Icons.reply, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replying to ${replyMessage.senderDisplayName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(replyMessage.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => ref.read(chatProvider(widget.conversation.id).notifier).setReplyingTo(null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image_outlined),
            onPressed: () => _handlePickImage(ImageSource.gallery),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () => _handlePickImage(ImageSource.camera),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              onChanged: (val) {
                if (val.isNotEmpty) {
                  ref.read(chatProvider(widget.conversation.id).notifier).startTyping();
                } else {
                  ref.read(chatProvider(widget.conversation.id).notifier).stopTyping();
                }
              },
              decoration: InputDecoration(
                hintText: 'Message...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _handleSend,
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

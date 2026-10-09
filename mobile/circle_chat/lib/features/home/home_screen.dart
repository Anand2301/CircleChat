import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../authentication/auth_controller.dart';
import '../chat/chat_screen.dart';
import '../conversations/conversations_controller.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _ConversationsTab(),
          _UsersSearchTab(),
          ProfileScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _ConversationsTab extends ConsumerWidget {
  const _ConversationsTab();

  void _showNewChatDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _NewChatModal(),
    );
  }

  void _showNewGroupDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _NewGroupModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CircleChat', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'New Group',
            onPressed: () => _showNewGroupDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(conversationsProvider.notifier).loadConversations(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.conversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No conversations yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showNewChatDialog(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Start New Chat'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final conv = state.conversations[index];
                      final isDirect = conv.type == 0;
                      final otherMember = isDirect ? conv.members.firstWhere((m) => m.userId != ref.read(authProvider).user?.id, orElse: () => conv.members.first) : null;
                      final isOnline = otherMember?.isOnline ?? false;
                      final lastMsg = conv.lastMessage;
                      final timeStr = lastMsg != null
                          ? DateFormat('hh:mm a').format(lastMsg.createdAt.toLocal())
                          : '';

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              backgroundImage: conv.imageUrl != null ? NetworkImage(conv.imageUrl!) : null,
                              child: conv.imageUrl == null
                                  ? Text(
                                      conv.name.isNotEmpty ? conv.name[0].toUpperCase() : 'C',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null,
                            ),
                            if (isDirect && isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                conv.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (timeStr.isNotEmpty)
                              Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMsg != null ? lastMsg.content : 'No messages yet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: conv.unreadCount > 0 ? theme.colorScheme.onSurface : Colors.grey[600],
                                  fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (conv.unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${conv.unreadCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
                          );
                        },
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChatDialog(context, ref),
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}

class _UsersSearchTab extends ConsumerStatefulWidget {
  const _UsersSearchTab();

  @override
  ConsumerState<_UsersSearchTab> createState() => _UsersSearchTabState();
}

class _UsersSearchTabState extends ConsumerState<_UsersSearchTab> {
  final _searchController = TextEditingController();
  List<UserSearchResult> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    try {
      final url = '${ApiConstants.usersSearch}?q=${Uri.encodeComponent(query)}';
      final data = await ApiClient.get(url);
      if (data is List) {
        setState(() {
          _results = data.map((json) => UserSearchResult.fromJson(json)).toList();
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover People'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search people by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text('No users found', style: TextStyle(color: Colors.grey[500])),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null,
                                  child: user.profileImageUrl == null
                                      ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U')
                                      : null,
                                ),
                                if (user.isOnline)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(user.email),
                            trailing: IconButton(
                              icon: const Icon(Icons.chat_bubble_outline),
                              onPressed: () async {
                                final conv = await ref
                                    .read(conversationsProvider.notifier)
                                    .createDirectConversation(user.id);
                                if (conv != null && mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _NewChatModal extends ConsumerStatefulWidget {
  const _NewChatModal();

  @override
  ConsumerState<_NewChatModal> createState() => _NewChatModalState();
}

class _NewChatModalState extends ConsumerState<_NewChatModal> {
  List<UserSearchResult> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final data = await ApiClient.get(ApiConstants.usersSearch);
      if (data is List) {
        setState(() {
          _users = data.map((json) => UserSearchResult.fromJson(json)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('New Direct Conversation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: controller,
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U'),
                          ),
                          title: Text(user.displayName),
                          subtitle: Text(user.email),
                          onTap: () async {
                            Navigator.pop(context);
                            final conv = await ref
                                .read(conversationsProvider.notifier)
                                .createDirectConversation(user.id);
                            if (conv != null && mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NewGroupModal extends ConsumerStatefulWidget {
  const _NewGroupModal();

  @override
  ConsumerState<_NewGroupModal> createState() => _NewGroupModalState();
}

class _NewGroupModalState extends ConsumerState<_NewGroupModal> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  List<UserSearchResult> _availableUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final data = await ApiClient.get(ApiConstants.usersSearch);
      if (data is List) {
        setState(() {
          _availableUsers = data.map((json) => UserSearchResult.fromJson(json)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Create New Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Group Name', prefixIcon: Icon(Icons.group)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Description (optional)', prefixIcon: Icon(Icons.description)),
          ),
          const SizedBox(height: 16),
          const Text('Select Members:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _availableUsers.length,
                    itemBuilder: (context, index) {
                      final u = _availableUsers[index];
                      final isSelected = _selectedUserIds.contains(u.id);
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(u.displayName),
                        subtitle: Text(u.email),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedUserIds.add(u.id);
                            } else {
                              _selectedUserIds.remove(u.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.trim().isEmpty) return;
              Navigator.pop(context);
              final conv = await ref.read(conversationsProvider.notifier).createGroupConversation(
                    _nameController.text.trim(),
                    _descController.text.trim(),
                    _selectedUserIds.toList(),
                  );
              if (conv != null && mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
                );
              }
            },
            child: const Text('Create Group'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

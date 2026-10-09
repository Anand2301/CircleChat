import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/signalr_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/avatar_widget.dart';
import '../../core/widgets/ios_search_bar.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SignalRService.instance.ensureConnected();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SignalRService.instance.ensureConnected();
      ref.read(conversationsProvider.notifier).loadConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'People',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
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
      ),
    );
  }
}

class _ConversationsTab extends ConsumerStatefulWidget {
  const _ConversationsTab();

  @override
  ConsumerState<_ConversationsTab> createState() => _ConversationsTabState();
}

class _ConversationsTabState extends ConsumerState<_ConversationsTab> {
  final _searchController = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNewChatDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewChatModal(),
    );
  }

  void _showNewGroupDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewGroupModal(),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inDays == 0 && now.day == local.day) {
      return DateFormat('h:mm a').format(local);
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(local);
    } else {
      return DateFormat('M/d/yy').format(local);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(authProvider).user?.id ?? '';

    final filteredConversations = state.conversations.where((c) {
      if (_filterQuery.isEmpty) return true;
      final q = _filterQuery.toLowerCase();
      final nameMatches = c.name.toLowerCase().contains(q);
      final lastMsgMatches = c.lastMessage?.content.toLowerCase().contains(q) ?? false;
      return nameMatches || lastMsgMatches;
    }).toList();

    final authUser = ref.watch(authProvider).user;
    final firstName = (authUser?.displayName ?? authUser?.fullName ?? '').trim().split(' ').first;
    final greeting = firstName.isNotEmpty ? 'Hey, $firstName 👋' : 'Hey there 👋';

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: AppBar(
        scrolledUnderElevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              greeting,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.mintAccent,
              ),
            ),
            const Text(
              'CircleChat',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryText,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_add_rounded, size: 20),
            ),
            tooltip: 'New Group',
            onPressed: () => _showNewGroupDialog(context, ref),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_square, size: 19),
            ),
            tooltip: 'New Chat',
            onPressed: () => _showNewChatDialog(context, ref),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: IosSearchBar(
              controller: _searchController,
              hintText: 'Search chats and messages...',
              onChanged: (val) => setState(() => _filterQuery = val.trim()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () => ref.read(conversationsProvider.notifier).loadConversations(),
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredConversations.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.forum_rounded,
                                      size: 38,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _filterQuery.isNotEmpty ? 'No Results Found' : 'No Conversations Yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _filterQuery.isNotEmpty
                                        ? 'No chats match "$_filterQuery"'
                                        : 'Connect securely with friends and family in your private circle.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                    ),
                                  ),
                                  if (_filterQuery.isEmpty) ...[
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () => _showNewChatDialog(context, ref),
                                      icon: const Icon(Icons.add_rounded, size: 20),
                                      label: const Text('Start New Chat'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 4, bottom: 20),
                          itemCount: filteredConversations.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 82,
                            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                          ),
                          itemBuilder: (context, index) {
                            final conv = filteredConversations[index];
                            final isDirect = conv.type == 0;
                            final otherMember = isDirect
                                ? conv.members.firstWhere(
                                    (m) => m.userId != currentUserId,
                                    orElse: () => conv.members.first,
                                  )
                                : null;
                            final isOnline = otherMember?.isOnline ?? false;
                            final lastMsg = conv.lastMessage;
                            final timeStr = lastMsg != null ? _formatTimestamp(lastMsg.createdAt) : '';
                            final isLastMsgFromMe = lastMsg != null && lastMsg.senderId == currentUserId;

                            return Material(
                              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatarWithStatus(
                                        name: conv.name,
                                        imageUrl: conv.imageUrl,
                                        isOnline: isOnline,
                                        showStatus: isDirect,
                                        radius: 26,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    conv.name,
                                                    style: TextStyle(
                                                      fontWeight: conv.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                                                      fontSize: 16,
                                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                                      letterSpacing: -0.3,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (timeStr.isNotEmpty)
                                                  Text(
                                                    timeStr,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                                                      color: conv.unreadCount > 0
                                                          ? AppTheme.primaryColor
                                                          : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (isLastMsgFromMe) ...[
                                                  Icon(
                                                    lastMsg.deliveryStatus == 2
                                                        ? Icons.done_all_rounded
                                                        : (lastMsg.deliveryStatus == 1 ? Icons.done_all_rounded : Icons.done_rounded),
                                                    size: 15,
                                                    color: lastMsg.deliveryStatus == 2
                                                        ? AppTheme.primaryColor
                                                        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    lastMsg != null
                                                        ? (lastMsg.isDeleted
                                                            ? 'This message was deleted'
                                                            : (lastMsg.messageType == 1
                                                                ? '📷 Photo'
                                                                : (lastMsg.messageType == 2
                                                                    ? '📎 Attachment'
                                                                    : (lastMsg.content.isNotEmpty ? lastMsg.content : '📷 Photo'))))
                                                        : 'No messages yet',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: conv.unreadCount > 0
                                                          ? AppTheme.primaryText
                                                          : AppTheme.secondaryText,
                                                      fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                                if (conv.unreadCount > 0)
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.mintAccent,
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      '${conv.unreadCount}',
                                                      style: const TextStyle(
                                                        color: AppTheme.midnightBackground,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
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
      if (data is List && mounted) {
        setState(() {
          _results = data.map((json) => UserSearchResult.fromJson(json)).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: AppBar(
        scrolledUnderElevation: 0.5,
        title: const Text(
          'People',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: IosSearchBar(
              controller: _searchController,
              hintText: 'Search people by name or email...',
              onChanged: _search,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 78,
                          color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                        ),
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          return Material(
                            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatarWithStatus(
                                name: user.displayName,
                                imageUrl: user.profileImageUrl,
                                isOnline: user.isOnline,
                                showStatus: true,
                                radius: 24,
                              ),
                              title: Text(
                                user.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                ),
                              ),
                              subtitle: Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                onPressed: () async {
                                  final conv = await ref
                                      .read(conversationsProvider.notifier)
                                      .createDirectConversation(user.id);
                                  if (conv != null && context.mounted) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
                                    );
                                  }
                                },
                                child: const Text(
                                  'Message',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
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
  final _searchController = TextEditingController();
  List<UserSearchResult> _users = [];
  bool _loading = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final data = await ApiClient.get(ApiConstants.usersSearch);
      if (data is List && mounted) {
        setState(() {
          _users = data.map((json) => UserSearchResult.fromJson(json)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _users.where((u) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return u.displayName.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Text(
                    'New Chat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: IosSearchBar(
                controller: _searchController,
                hintText: 'Search people...',
                onChanged: (val) => setState(() => _filter = val.trim()),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: _loading
                  ? const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'No contacts found',
                              style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 76,
                            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                          ),
                          itemBuilder: (context, index) {
                            final user = filtered[index];
                            return ListTile(
                              leading: CircleAvatarWithStatus(
                                name: user.displayName,
                                imageUrl: user.profileImageUrl,
                                isOnline: user.isOnline,
                                showStatus: true,
                                radius: 22,
                              ),
                              title: Text(
                                user.displayName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                              subtitle: Text(user.email, style: const TextStyle(fontSize: 13)),
                              onTap: () async {
                                Navigator.pop(context);
                                final conv = await ref
                                    .read(conversationsProvider.notifier)
                                    .createDirectConversation(user.id);
                                if (conv != null && context.mounted) {
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
        ),
      ),
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
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final data = await ApiClient.get(ApiConstants.usersSearch);
      if (data is List && mounted) {
        setState(() {
          _availableUsers = data.map((json) => UserSearchResult.fromJson(json)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Create New Group',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    prefixIcon: Icon(Icons.group_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add Members (${_selectedUserIds.length} selected):',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _availableUsers.isEmpty
                          ? Center(
                              child: Text(
                                'No contacts available',
                                style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _availableUsers.length,
                              itemBuilder: (context, index) {
                                final u = _availableUsers[index];
                                final isSelected = _selectedUserIds.contains(u.id);
                                return CheckboxListTile(
                                  value: isSelected,
                                  activeColor: AppTheme.primaryColor,
                                  secondary: CircleAvatarWithStatus(
                                    name: u.displayName,
                                    imageUrl: u.profileImageUrl,
                                    radius: 18,
                                  ),
                                  title: Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text(u.email, style: const TextStyle(fontSize: 12)),
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
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _isCreating
                      ? null
                      : () async {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) return;

                          setState(() => _isCreating = true);
                          final conv = await ref.read(conversationsProvider.notifier).createGroupConversation(
                                name,
                                _descController.text.trim(),
                                _selectedUserIds.toList(),
                              );

                          if (mounted) setState(() => _isCreating = false);

                          if (conv != null && context.mounted) {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
                            );
                          }
                        },
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Group'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

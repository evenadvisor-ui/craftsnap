import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firebase = FirebaseService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Map<String, String> _relationshipCache =
      {}; // uid -> 'friend'|'pending'|'none'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.trim().length >= 2) {
      _runSearch(_searchController.text.trim());
    } else {
      setState(() => _searchResults = []);
    }
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    try {
      final results = await _firebase.searchUsers(query);
      // Check relationships
      final Map<String, String> cache = {};
      for (final r in results) {
        final uid = r['uid'] as String;
        final isFriend = await _firebase.isFriend(uid);
        if (isFriend) {
          cache[uid] = 'friend';
        } else {
          final sent = await _firebase.hasSentRequest(uid);
          cache[uid] = sent ? 'pending' : 'none';
        }
      }
      if (mounted) {
        setState(() {
          _searchResults = results;
          _relationshipCache = cache;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(String uid) async {
    await _firebase.sendFriendRequest(uid);
    setState(() => _relationshipCache[uid] = 'pending');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request sent!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D111C),
        elevation: 0,
        title: const Text(
          'Friends',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4ADE80),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF4ADE80),
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'My Friends'),
            Tab(text: 'Requests'),
            Tab(text: 'Find'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyFriendsTab(firebase: _firebase),
          _RequestsTab(firebase: _firebase),
          _FindTab(
            controller: _searchController,
            results: _searchResults,
            searching: _searching,
            relationshipCache: _relationshipCache,
            onSendRequest: _sendRequest,
            firebase: _firebase,
          ),
        ],
      ),
    );
  }
}

// ── My Friends Tab ────────────────────────────────────────────────────────────

class _MyFriendsTab extends StatelessWidget {
  final FirebaseService firebase;
  const _MyFriendsTab({required this.firebase});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firebase.getFriendsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.people_outline,
            title: 'No friends yet',
            subtitle: 'Go to "Find" to connect\nwith other EcoCrafters',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = data['uid'] as String;
            final name = data['displayName'] ?? 'Anonymous';
            return _FriendTile(
              name: name,
              uid: uid,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chat button
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFF4ADE80),
                      size: 20,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(friendUid: uid, friendName: name),
                      ),
                    ),
                  ),
                  // Remove button
                  IconButton(
                    icon: Icon(
                      Icons.person_remove_outlined,
                      color: Colors.white.withOpacity(0.3),
                      size: 20,
                    ),
                    onPressed: () =>
                        _confirmRemove(context, uid, name, firebase),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmRemove(
    BuildContext context,
    String uid,
    String name,
    FirebaseService firebase,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove $name?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'They will be removed from your friends list.',
          style: TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await firebase.removeFriend(uid);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Requests Tab ──────────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  final FirebaseService firebase;
  const _RequestsTab({required this.firebase});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firebase.getFriendRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            subtitle: 'Friend requests will\nappear here',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final fromUid = data['fromUid'] as String;
            final fromName = data['fromName'] ?? 'Anonymous';
            return _FriendTile(
              name: fromName,
              uid: fromUid,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Accept
                  IconButton(
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF4ADE80),
                      size: 24,
                    ),
                    onPressed: () => firebase.acceptFriendRequest(fromUid),
                  ),
                  // Decline
                  IconButton(
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.redAccent,
                      size: 24,
                    ),
                    onPressed: () => firebase.declineFriendRequest(fromUid),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Find Tab ──────────────────────────────────────────────────────────────────

class _FindTab extends StatelessWidget {
  final TextEditingController controller;
  final List<Map<String, dynamic>> results;
  final bool searching;
  final Map<String, String> relationshipCache;
  final Future<void> Function(String) onSendRequest;
  final FirebaseService firebase;

  const _FindTab({
    required this.controller,
    required this.results,
    required this.searching,
    required this.relationshipCache,
    required this.onSendRequest,
    required this.firebase,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search by name...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.4),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: searching
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
                )
              : results.isEmpty
              ? _EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'Find EcoCrafters',
                  subtitle: 'Search by display name to\nconnect with others',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final user = results[i];
                    final uid = user['uid'] as String;
                    final name = user['displayName'] ?? 'Anonymous';
                    final rel = relationshipCache[uid] ?? 'none';

                    Widget trailingWidget;
                    if (rel == 'friend') {
                      trailingWidget = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ADE80).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Friends',
                          style: TextStyle(
                            color: Color(0xFF4ADE80),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    } else if (rel == 'pending') {
                      trailingWidget = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Pending',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    } else {
                      trailingWidget = GestureDetector(
                        onTap: () => onSendRequest(uid),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ADE80),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              color: Color(0xFF0D111C),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }

                    return _FriendTile(
                      name: name,
                      uid: uid,
                      trailing: trailingWidget,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _FriendTile extends StatelessWidget {
  final String name;
  final String uid;
  final Widget trailing;

  const _FriendTile({
    required this.name,
    required this.uid,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4ADE80), Color(0xFF22D3EE)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: const Color(0xFF4ADE80), size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

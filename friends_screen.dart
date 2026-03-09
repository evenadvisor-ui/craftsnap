import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'phone_auth_screen.dart';
import 'user_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FRIENDS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchController = TextEditingController();
  List<EcoUser> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => FirebaseService.instance.isLoggedIn;

  Future<void> _goToLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
    );
    if (result == true) setState(() {});
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await FirebaseService.instance.searchUsers(query.trim());
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Friends 👥'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        body: _LoginPrompt(onLogin: _goToLogin),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F2),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text(
          'Friends 👥',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'My Friends'),
            Tab(text: 'Requests'),
            Tab(text: 'Find'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _MyFriendsTab(),
          _RequestsTab(),
          _FindFriendsTab(
            searchController: _searchController,
            searchResults: _searchResults,
            isSearching: _searching,
            onSearch: _search,
          ),
        ],
      ),
    );
  }
}

// ── My Friends tab ────────────────────────────────────────────────────────────

class _MyFriendsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EcoUser>>(
      stream: FirebaseService.instance.getFriendsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        final friends = snap.data ?? [];
        if (friends.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🤝', style: TextStyle(fontSize: 64)),
                SizedBox(height: 16),
                Text(
                  'No friends yet!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Go to the "Find" tab to\nsearch for eco crafters.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          itemBuilder: (_, i) => _FriendTile(
            user: friends[i],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    UserProfileScreen(uid: friends[i].uid, isMe: false),
              ),
            ),
            trailing: _RemoveButton(uid: friends[i].uid),
          ),
        );
      },
    );
  }
}

// ── Requests tab ──────────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.instance.getIncomingRequestsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('📬', style: TextStyle(fontSize: 64)),
                SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'When someone sends you a friend\nrequest, it will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (_, i) {
            final req = requests[i];
            return _RequestTile(
              uid: req['uid'] as String,
              name: req['name'] as String,
              photoUrl: req['photoUrl'] as String?,
            );
          },
        );
      },
    );
  }
}

// ── Find Friends tab ──────────────────────────────────────────────────────────

class _FindFriendsTab extends StatelessWidget {
  final TextEditingController searchController;
  final List<EcoUser> searchResults;
  final bool isSearching;
  final void Function(String) onSearch;

  const _FindFriendsTab({
    required this.searchController,
    required this.searchResults,
    required this.isSearching,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: searchController,
            onChanged: onSearch,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Search by name...',
              prefixIcon: const Icon(Icons.search, color: Colors.green),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.green, width: 1.5),
              ),
            ),
          ),
        ),

        Expanded(
          child: isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.green),
                )
              : searchController.text.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🔍', style: TextStyle(fontSize: 64)),
                      SizedBox(height: 16),
                      Text(
                        'Search for eco crafters',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : searchResults.isEmpty
              ? const Center(
                  child: Text(
                    'No users found.\nTry a different name.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: searchResults.length,
                  itemBuilder: (_, i) =>
                      _SearchResultTile(user: searchResults[i]),
                ),
        ),
      ],
    );
  }
}

// ── Tile widgets ──────────────────────────────────────────────────────────────

class _FriendTile extends StatelessWidget {
  final EcoUser user;
  final VoidCallback onTap;
  final Widget? trailing;

  const _FriendTile({required this.user, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: _AvatarWidget(photoUrl: user.photoUrl, name: user.displayName),
        title: Text(
          user.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Row(
          children: [
            Text(
              '🌿 ${user.totalCrafts} crafts',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Text(
              '❤️ ${user.totalLikes}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}

class _RequestTile extends StatefulWidget {
  final String uid;
  final String name;
  final String? photoUrl;

  const _RequestTile({required this.uid, required this.name, this.photoUrl});

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _loading = false;
  bool _handled = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    await FirebaseService.instance.acceptFriendRequest(widget.uid);
    if (mounted) setState(() => _handled = true);
  }

  Future<void> _decline() async {
    setState(() => _loading = true);
    await FirebaseService.instance.declineFriendRequest(widget.uid);
    if (mounted) setState(() => _handled = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_handled) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _AvatarWidget(photoUrl: widget.photoUrl, name: widget.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const Text(
                    'wants to be friends',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.green,
                ),
              )
            else ...[
              // Accept
              GestureDetector(
                onTap: _accept,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Decline
              GestureDetector(
                onTap: _decline,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  final EcoUser user;
  const _SearchResultTile({required this.user});

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  FriendStatus? _status;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await FirebaseService.instance.getFriendStatus(
      widget.user.uid,
    );
    if (mounted)
      setState(() {
        _status = status;
        _loading = false;
      });
  }

  Future<void> _sendRequest() async {
    setState(() => _sending = true);
    await FirebaseService.instance.sendFriendRequest(widget.user.uid);
    if (mounted)
      setState(() {
        _status = FriendStatus.requestSent;
        _sending = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                UserProfileScreen(uid: widget.user.uid, isMe: false),
          ),
        ),
        leading: _AvatarWidget(
          photoUrl: widget.user.photoUrl,
          name: widget.user.displayName,
        ),
        title: Text(
          widget.user.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          '🌿 ${widget.user.totalCrafts} crafts',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.green,
                ),
              )
            : _buildStatusButton(),
      ),
    );
  }

  Widget _buildStatusButton() {
    switch (_status) {
      case FriendStatus.friends:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '✓ Friends',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case FriendStatus.requestSent:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Sent ✓',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        );
      case FriendStatus.requestReceived:
        return GestureDetector(
          onTap: () async {
            await FirebaseService.instance.acceptFriendRequest(widget.user.uid);
            setState(() => _status = FriendStatus.friends);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Accept',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      default:
        return GestureDetector(
          onTap: _sending ? null : _sendRequest,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '+ Add',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
    }
  }
}

class _RemoveButton extends StatefulWidget {
  final String uid;
  const _RemoveButton({required this.uid});

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _removed = false;

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Friend'),
        content: const Text('Remove this person from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseService.instance.removeFriend(widget.uid);
      if (mounted) setState(() => _removed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_removed) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
      onPressed: _confirmRemove,
      tooltip: 'Remove friend',
    );
  }
}

// ── Shared avatar widget ──────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  final String? photoUrl;
  final String name;

  const _AvatarWidget({required this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(radius: 24, backgroundImage: NetworkImage(photoUrl!));
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.green.shade100,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.green.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  final VoidCallback onLogin;
  const _LoginPrompt({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🤝', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            const Text(
              'Connect with Eco Crafters',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Sign in to add friends and follow their crafting journey!',
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.phone),
              label: const Text('Sign in with Phone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

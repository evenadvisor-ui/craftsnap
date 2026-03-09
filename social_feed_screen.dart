import 'dart:io';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'phone_auth_screen.dart';
import 'comments_screen.dart';
import 'user_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SOCIAL FEED SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F2),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Text('🌿', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'EcoCraft Feed',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () {
                final uid = FirebaseService.instance.currentUid;
                if (uid != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(uid: uid, isMe: true),
                    ),
                  );
                }
              },
            )
          else
            TextButton(
              onPressed: _goToLogin,
              child: const Text(
                'Sign In',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: '🌍  Community'),
            Tab(text: '👥  Friends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _isLoggedIn
              ? _PostFeed(stream: FirebaseService.instance.getFeedStream())
              : _LoginPrompt(onLogin: _goToLogin),
          _isLoggedIn
              ? _PostFeed(
                  stream: FirebaseService.instance.getFriendsFeedStream(),
                  emptyMessage:
                      'No posts yet from friends.\nAdd friends and follow their eco journey! 🌿',
                )
              : _LoginPrompt(onLogin: _goToLogin),
        ],
      ),
    );
  }
}

// ── Feed list ─────────────────────────────────────────────────────────────────

class _PostFeed extends StatelessWidget {
  final Stream<List<CraftPost>> stream;
  final String emptyMessage;

  const _PostFeed({
    required this.stream,
    this.emptyMessage = 'No posts yet.\nBe the first to share a craft! 🎨',
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CraftPost>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Could not load feed',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final posts = snap.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🌱', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: Colors.green,
          onRefresh: () async {},
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
            itemCount: posts.length,
            itemBuilder: (_, i) => _PostCard(post: posts[i]),
          ),
        );
      },
    );
  }
}

// ── Single post card ──────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final CraftPost post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late bool _liked;
  late int _likeCount;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.likedByMe;
    _likeCount = widget.post.likeCount;
  }

  Future<void> _toggleLike() async {
    if (_toggling) return;
    if (!FirebaseService.instance.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to like posts!')));
      return;
    }
    setState(() {
      _toggling = true;
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    await FirebaseService.instance.toggleLike(
      widget.post.id,
      !_liked, // pass the PREVIOUS state
    );
    setState(() => _toggling = false);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        uid: post.authorUid,
                        isMe:
                            post.authorUid ==
                            FirebaseService.instance.currentUid,
                      ),
                    ),
                  ),
                  child: _Avatar(
                    photoUrl: post.authorPhotoUrl,
                    name: post.authorName,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _timeAgo(post.createdAt),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Objects used chips
                if (post.objectsUsed.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post.objectsUsed.take(2).join(' + '),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Craft photo (if shared) ──
          if (post.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.network(
                post.imageUrl!,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          // ── Craft info ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Craft title
                Text(
                  post.craft.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                // Description
                Text(
                  post.craft.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),

                // Steps count & materials count
                Row(
                  children: [
                    _Pill(
                      icon: Icons.format_list_numbered,
                      label: '${post.craft.steps.length} steps',
                      color: Colors.blue.shade50,
                      textColor: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.inventory_2_outlined,
                      label: '${post.craft.materials.length} materials',
                      color: Colors.orange.shade50,
                      textColor: Colors.orange.shade700,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Action row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Row(
              children: [
                // Like button
                _ActionBtn(
                  icon: _liked ? Icons.favorite : Icons.favorite_border,
                  label: '$_likeCount',
                  color: _liked ? Colors.red : Colors.grey,
                  onTap: _toggleLike,
                ),
                // Comment button
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  label: '${post.commentCount}',
                  color: Colors.grey,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommentsScreen(post: post),
                    ),
                  ),
                ),
                const Spacer(),
                // View full craft button
                TextButton(
                  onPressed: () {
                    // Show craft detail bottom sheet
                    _showCraftDetail(context, post);
                  },
                  child: Text(
                    'View craft →',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCraftDetail(BuildContext context, CraftPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      post.craft.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.craft.description,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '🛒 Materials',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...post.craft.materials.map(
                      (m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(m, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '🔨 Steps',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                      post.craft.steps.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                post.craft.steps[i],
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color == Colors.grey ? Colors.black54 : color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            const Text('🌿', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            const Text(
              'Join the Eco Community',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Sign in to see crafts from the community,\nlike posts, and share your own creations!',
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

// ── Avatar widget (reused across screens) ─────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const _Avatar({required this.photoUrl, required this.name, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.green.shade100,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.green.shade800,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

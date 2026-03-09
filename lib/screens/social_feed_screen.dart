import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'comments_screen.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  final _firebase = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D111C),
        elevation: 0,
        title: const Text(
          'EcoCraft Feed',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.recycling,
                color: Color(0xFF4ADE80),
                size: 22,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firebase.getFeedStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading feed',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyFeed();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return _FeedCard(
                postId: docs[i].id,
                data: data,
                currentUid: _firebase.currentUser?.uid ?? '',
                onLike: () => _firebase.toggleLike(docs[i].id),
                onComment: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentsScreen(
                      postId: docs[i].id,
                      postAuthor: data['authorName'] ?? '',
                      craftName: data['craftName'] ?? '',
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF4ADE80),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No crafts shared yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your EcoCraft!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;
  final String currentUid;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _FeedCard({
    required this.postId,
    required this.data,
    required this.currentUid,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    final likes = List<String>.from(data['likes'] ?? []);
    final isLiked = likes.contains(currentUid);
    final likeCount = data['likeCount'] ?? 0;
    final commentCount = data['commentCount'] ?? 0;
    final authorName = data['authorName'] ?? 'Anonymous';
    final craftName = data['craftName'] ?? '';
    final objectDetected = data['objectDetected'] ?? '';
    final description = data['description'] ?? '';
    final imageBase64 = data['imageBase64'];
    final createdAt = data['createdAt'] as Timestamp?;
    final timeAgo = _formatTime(createdAt);
    final initials = authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Object tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF4ADE80).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    objectDetected.replaceAll('-', ' '),
                    style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Image (if available)
          if (imageBase64 != null && imageBase64.toString().isNotEmpty)
            ClipRRect(
              child: Container(
                height: 200,
                width: double.infinity,
                color: Colors.white.withOpacity(0.03),
                child: const Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.white24,
                    size: 48,
                  ),
                ),
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  craftName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      height: 1.45,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _ActionBtn(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '$likeCount',
                  color: isLiked ? Colors.redAccent : Colors.white38,
                  onTap: onLike,
                ),
                const SizedBox(width: 4),
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  label: '$commentCount',
                  color: Colors.white38,
                  onTap: onComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }
}

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
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 20, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

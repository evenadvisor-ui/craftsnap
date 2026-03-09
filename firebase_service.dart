import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS FOR SOCIAL FEATURES
// ─────────────────────────────────────────────────────────────────────────────

class EcoUser {
  final String uid;
  final String displayName;
  final String phoneNumber;
  final String? photoUrl;
  final int totalCrafts;
  final int totalLikes;
  final List<String> badges; // e.g. ['eco-pioneer', 'craft-master']

  EcoUser({
    required this.uid,
    required this.displayName,
    required this.phoneNumber,
    this.photoUrl,
    this.totalCrafts = 0,
    this.totalLikes = 0,
    this.badges = const [],
  });

  factory EcoUser.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EcoUser(
      uid: doc.id,
      displayName: d['displayName'] ?? 'Eco Crafter',
      phoneNumber: d['phoneNumber'] ?? '',
      photoUrl: d['photoUrl'],
      totalCrafts: d['totalCrafts'] ?? 0,
      totalLikes: d['totalLikes'] ?? 0,
      badges: List<String>.from(d['badges'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'phoneNumber': phoneNumber,
    'photoUrl': photoUrl,
    'totalCrafts': totalCrafts,
    'totalLikes': totalLikes,
    'badges': badges,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class CraftPost {
  final String id;
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;
  final CraftIdea craft;
  final String? imageUrl; // optional photo of their finished craft
  final List<String> objectsUsed; // e.g. ['plastic-water-bottle', 'cardboard']
  final int likeCount;
  final bool likedByMe;
  final int commentCount;
  final DateTime createdAt;

  CraftPost({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorPhotoUrl,
    required this.craft,
    this.imageUrl,
    this.objectsUsed = const [],
    this.likeCount = 0,
    this.likedByMe = false,
    this.commentCount = 0,
    required this.createdAt,
  });

  factory CraftPost.fromDoc(DocumentSnapshot doc, {bool likedByMe = false}) {
    final d = doc.data() as Map<String, dynamic>;
    return CraftPost(
      id: doc.id,
      authorUid: d['authorUid'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      authorPhotoUrl: d['authorPhotoUrl'],
      craft: CraftIdea.fromJson(d['craft']),
      imageUrl: d['imageUrl'],
      objectsUsed: List<String>.from(d['objectsUsed'] ?? []),
      likeCount: d['likeCount'] ?? 0,
      likedByMe: likedByMe,
      commentCount: d['commentCount'] ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class CraftComment {
  final String id;
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final DateTime createdAt;

  CraftComment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
  });

  factory CraftComment.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CraftComment(
      id: doc.id,
      authorUid: d['authorUid'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      authorPhotoUrl: d['authorPhotoUrl'],
      text: d['text'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

enum FriendStatus { none, requestSent, requestReceived, friends }

// ─────────────────────────────────────────────────────────────────────────────
// FIREBASE SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  FirebaseService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ── Convenience getters ──────────────────────

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;
  bool get isLoggedIn => _auth.currentUser != null;

  Stream<User?> get authStateStream => _auth.authStateChanges();

  // ─────────────────────────────────────────────────────────────────────────
  // AUTH — Phone Number
  // ─────────────────────────────────────────────────────────────────────────

  /// Step 1: Send OTP to phone number (format: +91XXXXXXXXXX)
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android auto-verification
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Step 2: Verify the OTP the user typed
  Future<UserCredential?> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() => _auth.signOut();

  // ─────────────────────────────────────────────────────────────────────────
  // USER PROFILE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> createOrUpdateProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    if (currentUid == null) return;
    final ref = _db.collection('users').doc(currentUid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'displayName': displayName,
        'phoneNumber': currentUser?.phoneNumber ?? '',
        'photoUrl': photoUrl,
        'totalCrafts': 0,
        'totalLikes': 0,
        'badges': ['eco-pioneer'], // first badge for joining
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({
        'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<EcoUser?> getUser(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return EcoUser.fromDoc(snap);
  }

  Future<EcoUser?> getCurrentUser() async {
    if (currentUid == null) return null;
    return getUser(currentUid!);
  }

  /// Upload profile photo and return download URL
  Future<String?> uploadProfilePhoto(File imageFile) async {
    if (currentUid == null) return null;
    final ref = _storage.ref('profile_photos/$currentUid.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCIAL FEED — Posts
  // ─────────────────────────────────────────────────────────────────────────

  /// Get global feed (all users, most recent first)
  Stream<List<CraftPost>> getFeedStream() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snap) async {
          final uid = currentUid;
          final List<CraftPost> posts = [];
          for (final doc in snap.docs) {
            bool liked = false;
            if (uid != null) {
              final likeDoc = await _db
                  .collection('posts')
                  .doc(doc.id)
                  .collection('likes')
                  .doc(uid)
                  .get();
              liked = likeDoc.exists;
            }
            posts.add(CraftPost.fromDoc(doc, likedByMe: liked));
          }
          return posts;
        });
  }

  /// Get feed showing only friends' posts
  Stream<List<CraftPost>> getFriendsFeedStream() {
    if (currentUid == null) return Stream.value([]);
    return _db
        .collection('friends')
        .doc(currentUid)
        .collection('accepted')
        .snapshots()
        .asyncMap((friendsSnap) async {
          final friendUids = friendsSnap.docs.map((d) => d.id).toList();
          if (friendUids.isEmpty) return <CraftPost>[];

          final postsSnap = await _db
              .collection('posts')
              .where('authorUid', whereIn: friendUids.take(10).toList())
              .orderBy('createdAt', descending: true)
              .limit(30)
              .get();

          final List<CraftPost> posts = [];
          for (final doc in postsSnap.docs) {
            final likeDoc = await _db
                .collection('posts')
                .doc(doc.id)
                .collection('likes')
                .doc(currentUid)
                .get();
            posts.add(CraftPost.fromDoc(doc, likedByMe: likeDoc.exists));
          }
          return posts;
        });
  }

  /// Post a craft to the social feed
  Future<String> sharePost({
    required CraftIdea craft,
    required List<String> objectsUsed,
    File? craftPhoto,
  }) async {
    if (currentUid == null) throw Exception('Not logged in');

    final user = await getCurrentUser();
    String? imageUrl;

    if (craftPhoto != null) {
      final ref = _storage.ref(
        'craft_photos/${currentUid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(craftPhoto);
      imageUrl = await ref.getDownloadURL();
    }

    final docRef = await _db.collection('posts').add({
      'authorUid': currentUid,
      'authorName': user?.displayName ?? 'Eco Crafter',
      'authorPhotoUrl': user?.photoUrl,
      'craft': craft.toJson(),
      'imageUrl': imageUrl,
      'objectsUsed': objectsUsed,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update user's craft count
    await _db.collection('users').doc(currentUid).update({
      'totalCrafts': FieldValue.increment(1),
    });

    return docRef.id;
  }

  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIKES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    if (currentUid == null) return;

    final likeRef = _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(currentUid);

    final postRef = _db.collection('posts').doc(postId);

    if (currentlyLiked) {
      await likeRef.delete();
      await postRef.update({'likeCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
      await postRef.update({'likeCount': FieldValue.increment(1)});
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMMENTS
  // ─────────────────────────────────────────────────────────────────────────

  Stream<List<CraftComment>> getCommentsStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(CraftComment.fromDoc).toList());
  }

  Future<void> addComment(String postId, String text) async {
    if (currentUid == null) return;
    final user = await getCurrentUser();

    await _db.collection('posts').doc(postId).collection('comments').add({
      'authorUid': currentUid,
      'authorName': user?.displayName ?? 'Eco Crafter',
      'authorPhotoUrl': user?.photoUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FRIENDS
  // ─────────────────────────────────────────────────────────────────────────

  /// Search users by display name (prefix search)
  Future<List<EcoUser>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final snap = await _db
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();
    return snap.docs
        .map(EcoUser.fromDoc)
        .where((u) => u.uid != currentUid)
        .toList();
  }

  /// Get the friendship status between current user and another user
  Future<FriendStatus> getFriendStatus(String otherUid) async {
    if (currentUid == null) return FriendStatus.none;

    // Check if already friends
    final friendDoc = await _db
        .collection('friends')
        .doc(currentUid)
        .collection('accepted')
        .doc(otherUid)
        .get();
    if (friendDoc.exists) return FriendStatus.friends;

    // Check if we sent them a request
    final sentDoc = await _db
        .collection('friend_requests')
        .doc(otherUid)
        .collection('received')
        .doc(currentUid)
        .get();
    if (sentDoc.exists) return FriendStatus.requestSent;

    // Check if they sent us a request
    final receivedDoc = await _db
        .collection('friend_requests')
        .doc(currentUid)
        .collection('received')
        .doc(otherUid)
        .get();
    if (receivedDoc.exists) return FriendStatus.requestReceived;

    return FriendStatus.none;
  }

  /// Send a friend request
  Future<void> sendFriendRequest(String toUid) async {
    if (currentUid == null) return;
    final user = await getCurrentUser();
    await _db
        .collection('friend_requests')
        .doc(toUid)
        .collection('received')
        .doc(currentUid)
        .set({
          'fromUid': currentUid,
          'fromName': user?.displayName ?? 'Eco Crafter',
          'fromPhotoUrl': user?.photoUrl,
          'sentAt': FieldValue.serverTimestamp(),
        });
  }

  /// Accept a friend request
  Future<void> acceptFriendRequest(String fromUid) async {
    if (currentUid == null) return;

    // Add to both users' accepted friends
    final batch = _db.batch();

    batch.set(
      _db
          .collection('friends')
          .doc(currentUid)
          .collection('accepted')
          .doc(fromUid),
      {'since': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db
          .collection('friends')
          .doc(fromUid)
          .collection('accepted')
          .doc(currentUid),
      {'since': FieldValue.serverTimestamp()},
    );

    // Remove the request
    batch.delete(
      _db
          .collection('friend_requests')
          .doc(currentUid)
          .collection('received')
          .doc(fromUid),
    );

    await batch.commit();
  }

  /// Decline or cancel a friend request
  Future<void> declineFriendRequest(String fromUid) async {
    if (currentUid == null) return;
    await _db
        .collection('friend_requests')
        .doc(currentUid)
        .collection('received')
        .doc(fromUid)
        .delete();
  }

  /// Remove a friend
  Future<void> removeFriend(String otherUid) async {
    if (currentUid == null) return;
    final batch = _db.batch();
    batch.delete(
      _db
          .collection('friends')
          .doc(currentUid)
          .collection('accepted')
          .doc(otherUid),
    );
    batch.delete(
      _db
          .collection('friends')
          .doc(otherUid)
          .collection('accepted')
          .doc(currentUid),
    );
    await batch.commit();
  }

  /// Get my friends list
  Stream<List<EcoUser>> getFriendsStream() {
    if (currentUid == null) return Stream.value([]);
    return _db
        .collection('friends')
        .doc(currentUid)
        .collection('accepted')
        .snapshots()
        .asyncMap((snap) async {
          final users = <EcoUser>[];
          for (final doc in snap.docs) {
            final user = await getUser(doc.id);
            if (user != null) users.add(user);
          }
          return users;
        });
  }

  /// Get incoming friend requests
  Stream<List<Map<String, dynamic>>> getIncomingRequestsStream() {
    if (currentUid == null) return Stream.value([]);
    return _db
        .collection('friend_requests')
        .doc(currentUid)
        .collection('received')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            return {
              'uid': data['fromUid'] ?? '',
              'name': data['fromName'] ?? 'Eco Crafter',
              'photoUrl': data['fromPhotoUrl'],
            };
          }).toList(),
        );
  }

  /// Get posts by a specific user
  Future<List<CraftPost>> getUserPosts(String uid) async {
    final snap = await _db
        .collection('posts')
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final List<CraftPost> posts = [];
    for (final doc in snap.docs) {
      bool liked = false;
      if (currentUid != null) {
        final likeDoc = await _db
            .collection('posts')
            .doc(doc.id)
            .collection('likes')
            .doc(currentUid)
            .get();
        liked = likeDoc.exists;
      }
      posts.add(CraftPost.fromDoc(doc, likedByMe: liked));
    }
    return posts;
  }
}

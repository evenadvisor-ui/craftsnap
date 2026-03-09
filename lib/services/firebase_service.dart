import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Auth ────────────────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ─── User Profile ─────────────────────────────────────────────────────────────

  Future<bool> userProfileExists(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists && (doc.data()?['displayName'] != null);
  }

  Future<void> createUserProfile({
    required String uid,
    required String displayName,
    required String email,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'friendCount': 0,
      'postCount': 0,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Stream<DocumentSnapshot> userProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // ─── Social Feed ──────────────────────────────────────────────────────────────

  Future<String> createFeedPost({
    required String craftName,
    required String objectDetected,
    required String description,
    String? imageBase64,
  }) async {
    final user = currentUser!;
    final profile = await getUserProfile(user.uid);
    final displayName = profile?['displayName'] ?? 'Anonymous';

    final docRef = await _firestore.collection('feed').add({
      'authorUid': user.uid,
      'authorName': displayName,
      'craftName': craftName,
      'objectDetected': objectDetected,
      'description': description,
      'imageBase64': imageBase64,
      'likes': [],
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(user.uid).update({
      'postCount': FieldValue.increment(1),
    });

    return docRef.id;
  }

  Stream<QuerySnapshot> getFeedStream() {
    return _firestore
        .collection('feed')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> toggleLike(String postId) async {
    final uid = currentUser!.uid;
    final ref = _firestore.collection('feed').doc(postId);
    final doc = await ref.get();
    final likes = List<String>.from(doc.data()?['likes'] ?? []);
    if (likes.contains(uid)) {
      await ref.update({
        'likes': FieldValue.arrayRemove([uid]),
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      await ref.update({
        'likes': FieldValue.arrayUnion([uid]),
        'likeCount': FieldValue.increment(1),
      });
    }
  }

  // ─── Comments ─────────────────────────────────────────────────────────────────

  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final user = currentUser!;
    final profile = await getUserProfile(user.uid);
    final displayName = profile?['displayName'] ?? 'Anonymous';

    await _firestore.collection('feed').doc(postId).collection('comments').add({
      'authorUid': user.uid,
      'authorName': displayName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('feed').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  Stream<QuerySnapshot> getCommentsStream(String postId) {
    return _firestore
        .collection('feed')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // ─── Friends ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final lower = query.toLowerCase();
    final snapshot = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: lower)
        .where('displayName', isLessThanOrEqualTo: '$lower\uf8ff')
        .limit(20)
        .get();
    return snapshot.docs
        .where((d) => d.id != currentUser!.uid)
        .map((d) => {'uid': d.id, ...d.data()})
        .toList();
  }

  Future<void> sendFriendRequest(String toUid) async {
    final fromUid = currentUser!.uid;
    final profile = await getUserProfile(fromUid);
    final displayName = profile?['displayName'] ?? 'Anonymous';
    await _firestore
        .collection('users')
        .doc(toUid)
        .collection('friendRequests')
        .doc(fromUid)
        .set({
          'fromUid': fromUid,
          'fromName': displayName,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> acceptFriendRequest(String fromUid) async {
    final myUid = currentUser!.uid;
    final myProfile = await getUserProfile(myUid);
    final myName = myProfile?['displayName'] ?? 'Anonymous';
    final theirProfile = await getUserProfile(fromUid);
    final theirName = theirProfile?['displayName'] ?? 'Anonymous';
    final batch = _firestore.batch();
    batch.set(
      _firestore
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(fromUid),
      {
        'uid': fromUid,
        'displayName': theirName,
        'addedAt': FieldValue.serverTimestamp(),
      },
    );
    batch.set(
      _firestore
          .collection('users')
          .doc(fromUid)
          .collection('friends')
          .doc(myUid),
      {
        'uid': myUid,
        'displayName': myName,
        'addedAt': FieldValue.serverTimestamp(),
      },
    );
    batch.delete(
      _firestore
          .collection('users')
          .doc(myUid)
          .collection('friendRequests')
          .doc(fromUid),
    );
    batch.update(_firestore.collection('users').doc(myUid), {
      'friendCount': FieldValue.increment(1),
    });
    batch.update(_firestore.collection('users').doc(fromUid), {
      'friendCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> declineFriendRequest(String fromUid) async {
    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('friendRequests')
        .doc(fromUid)
        .delete();
  }

  Future<void> removeFriend(String friendUid) async {
    final myUid = currentUser!.uid;
    final batch = _firestore.batch();
    batch.delete(
      _firestore
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(friendUid),
    );
    batch.delete(
      _firestore
          .collection('users')
          .doc(friendUid)
          .collection('friends')
          .doc(myUid),
    );
    batch.update(_firestore.collection('users').doc(myUid), {
      'friendCount': FieldValue.increment(-1),
    });
    batch.update(_firestore.collection('users').doc(friendUid), {
      'friendCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Stream<QuerySnapshot> getFriendsStream() {
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getFriendRequestsStream() {
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('friendRequests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<bool> isFriend(String otherUid) async {
    final doc = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('friends')
        .doc(otherUid)
        .get();
    return doc.exists;
  }

  Future<bool> hasSentRequest(String toUid) async {
    final doc = await _firestore
        .collection('users')
        .doc(toUid)
        .collection('friendRequests')
        .doc(currentUser!.uid)
        .get();
    return doc.exists;
  }

  // ─── Chat ─────────────────────────────────────────────────────────────────────

  String _chatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> sendMessage({
    required String toUid,
    required String text,
  }) async {
    final fromUid = currentUser!.uid;
    final chatId = _chatId(fromUid, toUid);
    final profile = await getUserProfile(fromUid);
    final displayName = profile?['displayName'] ?? 'Anonymous';
    final batch = _firestore.batch();
    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    batch.set(msgRef, {
      'senderUid': fromUid,
      'senderName': displayName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
    batch.set(_firestore.collection('chats').doc(chatId), {
      'participants': [fromUid, toUid],
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderUid': fromUid,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Stream<QuerySnapshot> getChatStream(String otherUid) {
    final chatId = _chatId(currentUser!.uid, otherUid);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> markMessagesRead(String otherUid) async {
    final myUid = currentUser!.uid;
    final chatId = _chatId(myUid, otherUid);
    final unread = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderUid', isNotEqualTo: myUid)
        .where('read', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}

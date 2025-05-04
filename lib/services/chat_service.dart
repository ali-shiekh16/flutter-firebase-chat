import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Send a message
  Future<void> sendMessage(String receiverId, String content) async {
    final String senderId = currentUserId;
    final Timestamp timestamp = Timestamp.now();

    // Create new message
    MessageModel message = MessageModel(
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      timestamp: timestamp.toDate(),
      isRead: false,
    );

    // Create chat room ID (sorted to ensure consistency)
    List<String> ids = [senderId, receiverId];
    ids.sort(); // Sort IDs to ensure the chatroom ID is always the same for both users
    String chatRoomId = ids.join('_');

    // Add message to database
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(message.toMap());

    // Update chat room summary
    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'participants': [senderId, receiverId],
      'lastMessage': content,
      'lastMessageTime': timestamp,
      'lastMessageSenderId': senderId,
      'unreadCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  // Get messages stream for a specific chat room
  Stream<QuerySnapshot> getMessages(String otherUserId) {
    // Create chat room ID (sorted to ensure consistency)
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get chat rooms for current user
  Stream<QuerySnapshot> getChatRooms() {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String otherUserId) async {
    // Create chat room ID (sorted to ensure consistency)
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    // Get unread messages
    QuerySnapshot unreadMessages =
        await _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .where('receiverId', isEqualTo: currentUserId)
            .get();

    // Update each message
    WriteBatch batch = _firestore.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Update chat room summary
    if (unreadMessages.docs.isNotEmpty) {
      batch.update(_firestore.collection('chat_rooms').doc(chatRoomId), {
        'unreadCount': 0,
      });
    }

    await batch.commit();
  }
}

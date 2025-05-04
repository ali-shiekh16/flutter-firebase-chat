import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime? timestamp;
  final bool isRead;

  MessageModel({
    this.id = '',
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.timestamp,
    this.isRead = false,
  });

  // Create model from Firestore document
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      isRead: data['isRead'] ?? false,
    );
  }

  // Convert model to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp':
          timestamp != null
              ? Timestamp.fromDate(timestamp!)
              : FieldValue.serverTimestamp(),
      'isRead': isRead,
    };
  }
}

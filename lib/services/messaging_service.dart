import 'package:cloud_firestore/cloud_firestore.dart';

class MessagingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> sendMessage(String chatId, Map<String, dynamic> messageData) async {
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<String> getChatId(String userId, String peerId) async {
    final chatsRef = _db.collection('chats');
    final chatQuery = await chatsRef.where('participants', arrayContains: userId).get();
    for (var doc in chatQuery.docs) {
      final participants = List<String>.from(doc['participants']);
      if (participants.contains(peerId)) {
        return doc.id;
      }
    }
    final chatDoc = await chatsRef.add({
      'participants': [userId, peerId],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return chatDoc.id;
  }

  Stream<QuerySnapshot> getUserChats(String userId) {
    return _db.collection('chats').where('participants', arrayContains: userId).snapshots();
  }

  Future<void> deleteMessageForBoth(String chatId, String messageId) async {
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'deleted': true, 'text': ''});
    } catch (e) {
      throw Exception('Error deleting message for both: $e');
    }
  }

  Future<void> deleteMessageForSenderOnly(String chatId, String messageId, String senderId) async {
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'deletedFor': FieldValue.arrayUnion([senderId])});
    } catch (e) {
      throw Exception('Error deleting message for sender: $e');
    }
  }
}

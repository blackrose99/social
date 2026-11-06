// lib/features/chat/models/message_model.dart
class MessageModel {
  final String id;
  final String conversationId;
  final String senderUsername;
  final String content;
  final String type; // 'text', 'image', 'video', 'audio'
  final String? mediaUrl;
  final DateTime timestamp;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderUsername,
    required this.content,
    this.type = 'text',
    this.mediaUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'conversation_id': conversationId,
      'sender_username': senderUsername.toLowerCase(),
      'content': content,
      'type': type,
      'media_url': mediaUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['_id']?.toString() ?? '',
      conversationId: map['conversation_id'] ?? '',
      senderUsername: map['sender_username'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? 'text',
      mediaUrl: map['media_url'],
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

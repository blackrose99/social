// lib/features/chat/models/message_model.dart
class MessageModel {
  final String id;
  final String conversationId;
  final String senderUsername;
  final String content;
  final String type; // 'text', 'image', 'video', 'audio'
  final String? mediaUrl;
  final DateTime timestamp;
  final DateTime? expiresAt;
  final bool isSeen;
  final DateTime? seenAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderUsername,
    required this.content,
    this.type = 'text',
    this.mediaUrl,
    required this.timestamp,
    this.expiresAt,
    this.isSeen = false,
    this.seenAt,
  });

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderUsername,
    String? content,
    String? type,
    String? mediaUrl,
    DateTime? timestamp,
    DateTime? expiresAt,
    bool? isSeen,
    DateTime? seenAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderUsername: senderUsername ?? this.senderUsername,
      content: content ?? this.content,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      isSeen: isSeen ?? this.isSeen,
      seenAt: seenAt ?? this.seenAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'conversation_id': conversationId,
      'sender_username': senderUsername.toLowerCase(),
      'content': content,
      'type': type,
      'media_url': mediaUrl,
      'timestamp': timestamp.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_seen': isSeen,
      'seen_at': seenAt?.toIso8601String(),
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
      expiresAt: DateTime.tryParse(map['expires_at'] ?? ''),
      isSeen: map['is_seen'] == true,
      seenAt: DateTime.tryParse(map['seen_at'] ?? ''),
    );
  }
}

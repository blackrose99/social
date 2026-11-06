// lib/features/chat/models/conversation_model.dart
class ConversationModel {
  final String id;
  final String type; // 'direct' or 'group'
  final String? name;
  final List<String> participants;
  final DateTime updatedAt;
  final Map<String, dynamic>? lastMessage;

  ConversationModel({
    required this.id,
    required this.type,
    this.name,
    required this.participants,
    required this.updatedAt,
    this.lastMessage,
  });

  bool get isGroup => type == 'group';

  /// Obtiene el nombre a mostrar en la lista según el usuario actual
  String getDisplayName(String currentUsername) {
    if (isGroup) {
      return name?.isNotEmpty == true ? name! : "Grupo (${participants.length})";
    }
    // Si es 1-a-1, obtener el otro participante
    final other = participants.firstWhere(
      (p) => p.toLowerCase() != currentUsername.toLowerCase(),
      orElse: () => participants.isNotEmpty ? participants.first : 'Contacto',
    );
    return "@$other";
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'type': type,
      'name': name,
      'participants': participants.map((p) => p.toLowerCase()).toList(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message': lastMessage,
    };
  }

  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    final rawParticipants = map['participants'];
    List<String> participantsList = [];
    if (rawParticipants is List) {
      participantsList = rawParticipants.map((e) => e.toString()).toList();
    }

    return ConversationModel(
      id: map['_id']?.toString() ?? '',
      type: map['type'] ?? 'direct',
      name: map['name'],
      participants: participantsList,
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
      lastMessage: map['last_message'] != null
          ? Map<String, dynamic>.from(map['last_message'])
          : null,
    );
  }
}

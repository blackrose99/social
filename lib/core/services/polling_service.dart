// lib/core/services/polling_service.dart
import 'dart:async';
import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import '../config/app_config.dart';
import 'mongo_service.dart';
import 'notification_service.dart';

class PollingService {
  static final PollingService _instance = PollingService._internal();
  factory PollingService() => _instance;
  PollingService._internal();

  Timer? _timer;
  DateTime _lastCheckedTimestamp = DateTime.now().subtract(const Duration(minutes: 5));
  bool _isPolling = false;
  final Set<String> _notifiedMessageIds = {};

  void startPolling({Duration interval = const Duration(milliseconds: 2500)}) {
    _timer?.cancel();
    _isPolling = true;

    _timer = Timer.periodic(interval, (_) => _checkNewMessages());
    log("PollingService iniciado con intervalo de ${interval.inMilliseconds}ms");
  }

  void restartPolling() {
    _timer?.cancel();
    _isPolling = false;
    _lastCheckedTimestamp = DateTime.now().subtract(const Duration(minutes: 2));
    startPolling(interval: const Duration(milliseconds: 2500));
  }

  void stopPolling() {
    _timer?.cancel();
    _isPolling = false;
    log("PollingService detenido.");
  }

  Future<void> _checkNewMessages() async {
    final currentUsername = AppConfig.getCurrentUsername();
    if (currentUsername == null || currentUsername.isEmpty) return;

    final mongo = MongoService();
    if (!mongo.isConnected) {
      final success = await mongo.connect();
      if (!success) return;
    }

    try {
      final cleanCurrent = currentUsername.replaceAll('@', '').trim().toLowerCase();

      // 1. Obtener las conversaciones a las que pertenece el usuario
      final convCursor = mongo.conversationsCollection.find(
        where.oneFrom('participants', [cleanCurrent, '@$cleanCurrent']),
      );
      final myConvs = await convCursor.toList();
      if (myConvs.isEmpty) return;

      final myConvIds = myConvs.map((c) => c['_id']?.toString()).whereType<String>().toList();

      // 2. Buscar mensajes nuevos en esas conversaciones enviados por otros usuarios
      final cursor = mongo.messagesCollection.find(
        where
            .oneFrom('conversation_id', myConvIds)
            .gt('timestamp', _lastCheckedTimestamp.toIso8601String())
            .ne('sender_username', cleanCurrent),
      );

      final newMessages = await cursor.toList();

      if (newMessages.isNotEmpty) {
        for (final msg in newMessages) {
          final msgId = msg['_id']?.toString() ?? '';
          if (_notifiedMessageIds.contains(msgId)) continue;
          _notifiedMessageIds.add(msgId);

          final sender = msg['sender_username'] ?? 'Contacto';
          String content = msg['content'] ?? '';
          final type = msg['type'] ?? 'text';
          if (content.isEmpty) {
            if (type == 'image') content = '📷 Foto';
            if (type == 'audio') content = '🎤 Nota de voz';
            if (type == 'video') content = '🎬 Video';
          }

          final convId = msg['conversation_id'];

          await NotificationService().showNewMessageNotification(
            sender: sender,
            messageContent: content,
            conversationId: convId,
          );

          final msgTime = DateTime.tryParse(msg['timestamp'] ?? '');
          if (msgTime != null && msgTime.isAfter(_lastCheckedTimestamp)) {
            _lastCheckedTimestamp = msgTime;
          }
        }
      }
    } catch (e) {
      log("Error durante polling de mensajes: $e");
    }
  }
}

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
  DateTime _lastCheckedTimestamp = DateTime.now();
  bool _isPolling = false;

  void startPolling({Duration interval = const Duration(seconds: 8)}) {
    if (_isPolling) return;
    _isPolling = true;
    _lastCheckedTimestamp = DateTime.now();

    _timer = Timer.periodic(interval, (_) => _checkNewMessages());
    log("PollingService iniciado con intervalo de ${interval.inSeconds}s");
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
      // Buscar mensajes recibidos más recientes que la última marca de tiempo
      final cursor = mongo.messagesCollection.find(
        where
            .gt('timestamp', _lastCheckedTimestamp.toIso8601String())
            .ne('sender_username', currentUsername.toLowerCase()),
      );

      final newMessages = await cursor.toList();

      if (newMessages.isNotEmpty) {
        log("Nuevos mensajes detectados en polling: ${newMessages.length}");
        for (final msg in newMessages) {
          final sender = msg['sender_username'] ?? 'Desconocido';
          final content = msg['content'] ?? (msg['type'] == 'image' ? '[Foto]' : '[Archivo]');
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

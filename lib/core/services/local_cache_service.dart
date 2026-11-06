// lib/core/services/local_cache_service.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../features/chat/models/conversation_model.dart';
import '../../features/chat/models/message_model.dart';

class LocalCacheService {
  static final LocalCacheService _instance = LocalCacheService._internal();
  factory LocalCacheService() => _instance;
  LocalCacheService._internal();

  Directory? _cacheDir;

  Future<Directory> _getDir() async {
    _cacheDir ??= await getApplicationDocumentsDirectory();
    return _cacheDir!;
  }

  File _getMessagesFile(Directory dir, String conversationId) {
    // Sanitize conversationId for safe filename
    final safeId = conversationId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${dir.path}/messages_cache_$safeId.json');
  }

  File _getConversationsFile(Directory dir) {
    return File('${dir.path}/conversations_cache.json');
  }

  /// Carga los mensajes guardados en el almacenamiento local del dispositivo
  Future<List<MessageModel>> getCachedMessages(String conversationId) async {
    try {
      final dir = await _getDir();
      final file = _getMessagesFile(dir, conversationId);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((item) => MessageModel.fromMap(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      log("Error leyendo caché local de mensajes: $e");
      return [];
    }
  }

  /// Guarda y fusiona mensajes en el caché local del teléfono sin borrar los existentes
  Future<List<MessageModel>> mergeAndSaveMessages(
    String conversationId,
    List<MessageModel> newMessages,
  ) async {
    try {
      final dir = await _getDir();
      final file = _getMessagesFile(dir, conversationId);

      List<MessageModel> existing = [];
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          if (content.isNotEmpty) {
            final List<dynamic> jsonList = jsonDecode(content);
            existing = jsonList.map((item) => MessageModel.fromMap(Map<String, dynamic>.from(item))).toList();
          }
        } catch (_) {}
      }

      // Fusionar por ID preservando mensajes locales
      final Map<String, MessageModel> map = {
        for (final m in existing) m.id: m,
      };

      for (final m in newMessages) {
        map[m.id] = m;
      }

      final mergedList = map.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Guardar en disco persistente
      final jsonString = jsonEncode(mergedList.map((m) => m.toMap()).toList());
      await file.writeAsString(jsonString, flush: true);

      return mergedList;
    } catch (e) {
      log("Error guardando mensajes en caché local: $e");
      return newMessages;
    }
  }

  /// Guarda un mensaje individual directamente en el caché local
  Future<void> saveSingleMessage(String conversationId, MessageModel message) async {
    await mergeAndSaveMessages(conversationId, [message]);
  }

  /// Carga las conversaciones guardadas en el teléfono
  Future<List<ConversationModel>> getCachedConversations() async {
    try {
      final dir = await _getDir();
      final file = _getConversationsFile(dir);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((item) => ConversationModel.fromMap(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      log("Error leyendo caché local de conversaciones: $e");
      return [];
    }
  }

  /// Guarda y fusiona conversaciones en el almacenamiento local
  Future<void> saveConversations(List<ConversationModel> conversations) async {
    try {
      final dir = await _getDir();
      final file = _getConversationsFile(dir);
      final jsonString = jsonEncode(conversations.map((c) => c.toMap()).toList());
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      log("Error guardando conversaciones en caché local: $e");
    }
  }
}

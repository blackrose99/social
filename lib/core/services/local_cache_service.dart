// lib/core/services/local_cache_service.dart
import 'dart:async';
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
  final Map<String, List<MessageModel>> _memoryMessages = {};
  List<ConversationModel>? _memoryConversations;

  Future<Directory> _getDir() async {
    _cacheDir ??= await getApplicationDocumentsDirectory();
    return _cacheDir!;
  }

  File _getMessagesFile(Directory dir, String conversationId) {
    final safeId = conversationId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${dir.path}/messages_cache_$safeId.json');
  }

  File _getConversationsFile(Directory dir) {
    return File('${dir.path}/conversations_cache.json');
  }

  /// Carga los mensajes guardados (de memoria ultrarrápida o disco)
  Future<List<MessageModel>> getCachedMessages(String conversationId) async {
    if (_memoryMessages.containsKey(conversationId)) {
      return List<MessageModel>.from(_memoryMessages[conversationId]!);
    }

    try {
      final dir = await _getDir();
      final file = _getMessagesFile(dir, conversationId);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);
      final list = jsonList
          .map((item) => MessageModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      _memoryMessages[conversationId] = list;
      return list;
    } catch (e) {
      log("Error leyendo caché local de mensajes: $e");
      return [];
    }
  }

  /// Guarda y fusiona mensajes en memoria al instante y en disco en segundo plano
  Future<List<MessageModel>> mergeAndSaveMessages(
    String conversationId,
    List<MessageModel> newMessages,
  ) async {
    final existing = _memoryMessages[conversationId] ?? await getCachedMessages(conversationId);

    // Fusionar por ID preservando y actualizando estado (ej. visto/isSeen)
    final Map<String, MessageModel> map = {
      for (final m in existing) m.id: m,
    };

    for (final m in newMessages) {
      map[m.id] = m;
    }

    final mergedList = map.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _memoryMessages[conversationId] = mergedList;

    // Persistir en disco en segundo plano sin congelar la UI
    unawaited(_persistMessagesToDisk(conversationId, mergedList));

    return mergedList;
  }

  Future<void> _persistMessagesToDisk(String conversationId, List<MessageModel> list) async {
    try {
      final dir = await _getDir();
      final file = _getMessagesFile(dir, conversationId);
      final jsonString = jsonEncode(list.map((m) => m.toMap()).toList());
      await file.writeAsString(jsonString, flush: false);
    } catch (e) {
      log("Error persistiendo mensajes: $e");
    }
  }

  /// Guarda un mensaje individual directamente en el caché local
  Future<void> saveSingleMessage(String conversationId, MessageModel message) async {
    await mergeAndSaveMessages(conversationId, [message]);
  }

  /// Elimina los mensajes cacheados de una conversación específica
  Future<void> clearCachedMessages(String conversationId) async {
    _memoryMessages.remove(conversationId);
    try {
      final dir = await _getDir();
      final file = _getMessagesFile(dir, conversationId);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      log("Error borrando caché local de mensajes: $e");
    }
  }

  /// Carga las conversaciones guardadas en el teléfono
  Future<List<ConversationModel>> getCachedConversations() async {
    if (_memoryConversations != null) {
      return List<ConversationModel>.from(_memoryConversations!);
    }

    try {
      final dir = await _getDir();
      final file = _getConversationsFile(dir);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);
      final list = jsonList
          .map((item) => ConversationModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      _memoryConversations = list;
      return list;
    } catch (e) {
      log("Error leyendo caché local de conversaciones: $e");
      return [];
    }
  }

  /// Guarda y fusiona conversaciones en el almacenamiento local
  Future<void> saveConversations(List<ConversationModel> conversations) async {
    _memoryConversations = conversations;
    try {
      final dir = await _getDir();
      final file = _getConversationsFile(dir);
      final jsonString = jsonEncode(conversations.map((c) => c.toMap()).toList());
      unawaited(file.writeAsString(jsonString, flush: false));
    } catch (e) {
      log("Error guardando conversaciones en caché local: $e");
    }
  }
}

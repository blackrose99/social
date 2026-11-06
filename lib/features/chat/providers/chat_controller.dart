// lib/features/chat/providers/chat_controller.dart
import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/mongo_service.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ChatController extends ChangeNotifier {
  final MongoService _mongo = MongoService();
  final LocalCacheService _cache = LocalCacheService();

  List<ConversationModel> _conversations = [];
  List<ConversationModel> get conversations => _conversations;

  List<MessageModel> _currentMessages = [];
  List<MessageModel> get currentMessages => _currentMessages;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _activeConversationId;
  String? get activeConversationId => _activeConversationId;

  StreamSubscription? _changeStreamSub;
  Timer? _activeRoomPollingTimer;

  /// Limpia automáticamente de la base de datos mensajes y multimedia vencidos
  Future<void> _cleanExpiredMessages() async {
    try {
      if (!_mongo.isConnected) return;
      final nowStr = DateTime.now().toIso8601String();
      await _mongo.messagesCollection.deleteMany(
        where.lt('expires_at', nowStr),
      );
    } catch (_) {}
  }

  /// Carga las conversaciones del usuario actual (primero de caché local, luego de Atlas)
  Future<void> loadConversations() async {
    final currentUsername = AppConfig.getCurrentUsername();
    if (currentUsername == null || currentUsername.isEmpty) return;

    // 1. Mostrar de inmediato desde caché persistente local
    final cached = await _cache.getCachedConversations();
    if (cached.isNotEmpty && _conversations.isEmpty) {
      _conversations = cached;
      notifyListeners();
    }

    try {
      if (!_mongo.isConnected) {
        await _mongo.connect();
      }

      // Limpiar vencidos en Atlas (Atlas actúa como puente temporal)
      _cleanExpiredMessages();

      final current = currentUsername.trim().toLowerCase();

      final cursor = _mongo.conversationsCollection.find(
        where
            .eq('participants', current)
            .sortBy('updated_at', descending: true),
      );

      final list = await cursor.toList();
      _conversations = list.map((doc) => ConversationModel.fromMap(doc)).toList();
      await _cache.saveConversations(_conversations);
      notifyListeners();
    } catch (e) {
      log("Error cargando conversaciones: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Busca si existe un usuario registrado (soporta prefijos y quita arrobas)
  Future<Map<String, dynamic>?> findUser(String username) async {
    final clean = username.replaceAll('@', '').trim().toLowerCase();
    if (clean.isEmpty) return null;

    try {
      if (!_mongo.isConnected) await _mongo.connect();

      // Búsqueda exacta
      var user = await _mongo.usersCollection.findOne(
        where.eq('username', clean),
      );

      // Si no coincide exacto, busca si empieza por ese texto (ej: "lm" encuentra "lmc")
      if (user == null) {
        user = await _mongo.usersCollection.findOne(
          where.match('username', '^$clean'),
        );
      }

      return user;
    } catch (e) {
      log("Error verificando usuario: $e");
      return null;
    }
  }

  /// Crea o abre una conversación 1-a-1
  Future<ConversationModel?> getOrCreateDirectChat(String targetUsername) async {
    final currentUsername = AppConfig.getCurrentUsername();
    if (currentUsername == null) return null;

    final current = currentUsername.trim().toLowerCase();
    final cleanInput = targetUsername.replaceAll('@', '').trim().toLowerCase();

    if (cleanInput.isEmpty) {
      throw Exception("Por favor ingresa un nombre de usuario.");
    }

    // Buscar en Atlas
    final userDoc = await findUser(cleanInput);
    if (userDoc == null) {
      throw Exception("El usuario '@$cleanInput' no fue encontrado. Verifica el nombre.");
    }

    final target = (userDoc['username'] as String).toLowerCase();

    if (target == current) {
      throw Exception("No puedes abrir un chat contigo mismo.");
    }

    try {
      // Buscar conversación existente entre ambos
      final existingDoc = await _mongo.conversationsCollection.findOne(
        where
            .eq('type', 'direct')
            .all('participants', [current, target]),
      );

      if (existingDoc != null) {
        final conv = ConversationModel.fromMap(existingDoc);
        await loadConversations();
        return conv;
      }

      // Si no existe, crearla
      final newConv = ConversationModel(
        id: const Uuid().v4(),
        type: 'direct',
        participants: [current, target],
        updatedAt: DateTime.now(),
      );

      await _mongo.conversationsCollection.insert(newConv.toMap());
      await loadConversations();
      return newConv;
    } catch (e) {
      log("Error creando chat 1-a-1: $e");
      rethrow;
    }
  }

  /// Crea una conversación grupal
  Future<ConversationModel?> createGroupChat({
    required String groupName,
    required List<String> memberUsernames,
  }) async {
    final currentUsername = AppConfig.getCurrentUsername();
    if (currentUsername == null) return null;

    final current = currentUsername.trim().toLowerCase();
    final participants = {
      current,
      ...memberUsernames.map((u) => u.replaceAll('@', '').trim().toLowerCase())
    }.toList();

    if (participants.length < 2) {
      throw Exception("Un grupo debe tener al menos 2 integrantes.");
    }

    try {
      final newConv = ConversationModel(
        id: const Uuid().v4(),
        type: 'group',
        name: groupName.trim(),
        participants: participants,
        updatedAt: DateTime.now(),
      );

      await _mongo.conversationsCollection.insert(newConv.toMap());
      await loadConversations();
      return newConv;
    } catch (e) {
      log("Error creando grupo: $e");
      rethrow;
    }
  }

  /// Abre la sala de chat y comienza a escuchar mensajes
  Future<void> enterChatRoom(String conversationId) async {
    _activeConversationId = conversationId;

    // 1. Cargar inmediatamente desde el almacenamiento local del dispositivo
    final cached = await _cache.getCachedMessages(conversationId);
    _currentMessages = cached;
    _isLoading = cached.isEmpty;
    notifyListeners();

    // 2. Traer mensajes nuevos desde Atlas (puente) y sincronizar
    await _fetchRoomMessages(conversationId);
    _isLoading = false;
    notifyListeners();

    _startListeningRoomMessages(conversationId);
  }

  /// Carga y sincroniza mensajes desde el puente Atlas preservando el historial local
  Future<void> _fetchRoomMessages(String conversationId) async {
    try {
      if (!_mongo.isConnected) await _mongo.connect();

      final cursor = _mongo.messagesCollection.find(
        where
            .eq('conversation_id', conversationId)
            .sortBy('timestamp', descending: false),
      );

      final docs = await cursor.toList();
      final atlasMsgs = docs.map((d) => MessageModel.fromMap(d)).toList();

      // Fusionar y persistir localmente en el teléfono
      _currentMessages = await _cache.mergeAndSaveMessages(conversationId, atlasMsgs);
      notifyListeners();
    } catch (e) {
      log("Error obteniendo mensajes de la sala: $e");
    }
  }

  /// Inicia escucha reactiva continua (Change Streams + Polling de alta frecuencia)
  void _startListeningRoomMessages(String conversationId) {
    _stopListeningRoomMessages();

    // 1. Change Stream reactivo en Atlas
    try {
      final pipeline = [
        {
          r'$match': {
            'operationType': 'insert',
            'fullDocument.conversation_id': conversationId,
          }
        }
      ];

      final stream = _mongo.messagesCollection.watch(pipeline);
      _changeStreamSub = stream.listen((event) async {
        final fullDoc = event.fullDocument;
        if (fullDoc != null) {
          final newMsg = MessageModel.fromMap(fullDoc);
          if (!_currentMessages.any((m) => m.id == newMsg.id)) {
            _currentMessages = await _cache.mergeAndSaveMessages(conversationId, [newMsg]);
            notifyListeners();
          }
        }
      }, onError: (_) {});
    } catch (e) {
      log("Change Stream aviso: $e");
    }

    // 2. Polling ultra-fiable en primer plano (cada 1.5 segundos)
    _activeRoomPollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_activeConversationId != conversationId) return;

      try {
        final cursor = _mongo.messagesCollection.find(
          where
              .eq('conversation_id', conversationId)
              .sortBy('timestamp', descending: false),
        );

        final newDocs = await cursor.toList();
        final atlasMsgs = newDocs.map((doc) => MessageModel.fromMap(doc)).toList();

        // Si hay mensajes nuevos en Atlas, agregarlos y guardarlos en caché del teléfono
        final hasNew = atlasMsgs.any((m) => !_currentMessages.any((cm) => cm.id == m.id));
        if (hasNew) {
          _currentMessages = await _cache.mergeAndSaveMessages(conversationId, atlasMsgs);
          notifyListeners();
        }
      } catch (e) {
        log("Error en sala polling: $e");
      }
    });
  }

  void _stopListeningRoomMessages() {
    _changeStreamSub?.cancel();
    _changeStreamSub = null;
    _activeRoomPollingTimer?.cancel();
    _activeRoomPollingTimer = null;
  }

  /// Sale de la sala activa
  void leaveChatRoom() {
    _stopListeningRoomMessages();
    _activeConversationId = null;
    _currentMessages = [];
  }

  /// Envía un nuevo mensaje a la conversación
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String type = 'text',
    String? mediaUrl,
  }) async {
    final currentUsername = AppConfig.getCurrentUsername();
    if (currentUsername == null) return;

    final now = DateTime.now();
    final retentionDays = AppConfig.getRetentionDays();
    final expiresAt = now.add(Duration(days: retentionDays));

    final message = MessageModel(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderUsername: currentUsername.toLowerCase(),
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      timestamp: now,
      expiresAt: expiresAt,
    );

    // Añadir localmente de inmediato para sensación instantánea y guardar en caché local
    _currentMessages.add(message);
    await _cache.saveSingleMessage(conversationId, message);
    notifyListeners();

    try {
      if (!_mongo.isConnected) await _mongo.connect();

      // Insertar en colección de mensajes
      await _mongo.messagesCollection.insert(message.toMap());

      // Actualizar última actividad de la conversación
      await _mongo.conversationsCollection.update(
        where.eq('_id', conversationId),
        modify
            .set('updated_at', now.toIso8601String())
            .set('last_message', {
          'sender': currentUsername.toLowerCase(),
          'content': content.isNotEmpty ? content : (type == 'image' ? '[Foto]' : '[Archivo]'),
          'type': type,
          'timestamp': now.toIso8601String(),
        }),
      );

      // Refrescar lista de chats
      loadConversations();
    } catch (e) {
      log("Error enviando mensaje: $e");
    }
  }

  /// Cierra la sesión
  Future<void> logout() async {
    leaveChatRoom();
    await AppConfig.setCurrentUsername(null);
    _conversations = [];
    notifyListeners();
  }
}

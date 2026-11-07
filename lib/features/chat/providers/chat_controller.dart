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
  DateTime? _lastCleanupTime;

  /// Limpia automáticamente de la base de datos mensajes y multimedia vencidos (máximo una vez cada 15 min)
  Future<void> _cleanExpiredMessages() async {
    final now = DateTime.now();
    if (_lastCleanupTime != null && now.difference(_lastCleanupTime!).inMinutes < 15) {
      return;
    }
    _lastCleanupTime = now;
    try {
      if (!_mongo.isConnected) return;
      final nowStr = now.toIso8601String();
      await _mongo.messagesCollection.deleteMany(
        where.lt('expires_at', nowStr),
      );
    } catch (_) {}
  }

  /// Carga las conversaciones del usuario actual (primero de caché local, luego de Atlas)
  Future<void> loadConversations() async {
    final currentUsername = AppConfig.getCurrentUsername();
    if (currentUsername == null || currentUsername.isEmpty) return;

    // 1. Mostrar de inmediato desde memoria/caché local
    final cached = await _cache.getCachedConversations();
    if (cached.isNotEmpty && _conversations.isEmpty) {
      _conversations = cached;
      notifyListeners();
    }

    try {
      if (!_mongo.isConnected) {
        await _mongo.connect();
      }

      // Limpieza periódica no bloqueante
      _cleanExpiredMessages();

      final current = currentUsername.replaceAll('@', '').trim().toLowerCase();

      // Buscar conversaciones donde el usuario participe optimizado
      final cursor = _mongo.conversationsCollection.find(
        where
            .oneFrom('participants', [current, '@$current'])
            .sortBy('updated_at', descending: true)
            .limit(40),
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

  /// Busca si existe un usuario registrado (soporta prefijos, mayúsculas y quita arrobas)
  Future<Map<String, dynamic>?> findUser(String username) async {
    final clean = username.replaceAll('@', '').trim().toLowerCase();
    if (clean.isEmpty) return null;

    try {
      if (!_mongo.isConnected) await _mongo.connect();

      // 1. Búsqueda exacta limpia
      var user = await _mongo.usersCollection.findOne(
        where.eq('username', clean),
      );

      // 2. Búsqueda con @ por si se registró antiguamente con arroba
      user ??= await _mongo.usersCollection.findOne(
        where.eq('username', '@$clean'),
      );

      // 3. Búsqueda con expresión regular por si tiene @
      user ??= await _mongo.usersCollection.findOne(
        where.match('username', '^@?$clean\$'),
      );

      // 4. Si no coincide exacto, busca si empieza por ese texto
      user ??= await _mongo.usersCollection.findOne(
        where.match('username', '^@?$clean'),
      );

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

    final current = currentUsername.replaceAll('@', '').trim().toLowerCase();
    final cleanInput = targetUsername.replaceAll('@', '').trim().toLowerCase();

    if (cleanInput.isEmpty) {
      throw Exception("Por favor ingresa un nombre de usuario.");
    }

    // Buscar en Atlas
    final userDoc = await findUser(cleanInput);
    if (userDoc == null) {
      throw Exception("El usuario '@$cleanInput' no fue encontrado. Verifica el nombre.");
    }

    final target = (userDoc['username'] as String).replaceAll('@', '').trim().toLowerCase();

    if (target == current) {
      throw Exception("No puedes abrir un chat contigo mismo.");
    }

    try {
      if (!_mongo.isConnected) await _mongo.connect();

      // Buscar conversación existente entre ambos (buscando combinaciones limpias y con @)
      final existingDoc = await _mongo.conversationsCollection.findOne(
        where
            .eq('type', 'direct')
            .oneFrom('participants', [current, '@$current'])
            .oneFrom('participants', [target, '@$target']),
      );

      if (existingDoc != null) {
        final conv = ConversationModel.fromMap(existingDoc);
        await loadConversations();
        return conv;
      }

      // Si no existe, crearla SIEMPRE limpia sin @
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

      // Cargar los últimos 50 mensajes de forma ultrarrápida
      final cursor = _mongo.messagesCollection.find(
        where
            .eq('conversation_id', conversationId)
            .sortBy('timestamp', descending: true)
            .limit(50),
      );

      final docs = await cursor.toList();
      final atlasMsgs = docs.reversed.map((d) => MessageModel.fromMap(d)).toList();

      // Fusionar y persistir localmente en memoria y disco
      _currentMessages = await _cache.mergeAndSaveMessages(conversationId, atlasMsgs);
      notifyListeners();

      // Marcar mensajes del remitente como leídos
      markMessagesAsSeen(conversationId);
    } catch (e) {
      log("Error obteniendo mensajes de la sala: $e");
    }
  }

  /// Marca todos los mensajes recibidos en esta conversación como vistos / leídos (Doble Check)
  Future<void> markMessagesAsSeen(String conversationId) async {
    final currentUsername = AppConfig.getCurrentUsername();
    if (currentUsername == null) return;
    final cleanCurrent = currentUsername.replaceAll('@', '').trim().toLowerCase();

    try {
      if (!_mongo.isConnected) await _mongo.connect();

      await _mongo.messagesCollection.updateMany(
        where
            .eq('conversation_id', conversationId)
            .ne('sender_username', cleanCurrent)
            .eq('is_seen', false),
        modify
            .set('is_seen', true)
            .set('seen_at', DateTime.now().toIso8601String()),
      );
    } catch (_) {}
  }

  /// Inicia escucha reactiva continua (Polling de alta frecuencia sub-segundo: 650ms)
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
            markMessagesAsSeen(conversationId);
          }
        }
      }, onError: (_) {});
    } catch (e) {
      log("Change Stream aviso: $e");
    }

    // 2. Polling ultra-rápido en primer plano (cada 650ms para sensación en tiempo real)
    _activeRoomPollingTimer = Timer.periodic(const Duration(milliseconds: 650), (_) async {
      if (_activeConversationId != conversationId) return;

      try {
        if (!_mongo.isConnected) {
          await _mongo.connect();
        }
        if (!_mongo.isConnected) return;

        // Traer los 30 mensajes más recientes con limit para consulta instantánea (<30ms)
        final cursor = _mongo.messagesCollection.find(
          where
              .eq('conversation_id', conversationId)
              .sortBy('timestamp', descending: true)
              .limit(30),
        );

        final newDocs = await cursor.toList();
        final atlasMsgs = newDocs.reversed.map((doc) => MessageModel.fromMap(doc)).toList();

        // Detectar si hay mensajes nuevos O si cambió el estado de visto (doble check)
        bool hasChanges = false;
        if (atlasMsgs.length != _currentMessages.length) {
          hasChanges = true;
        } else {
          for (final am in atlasMsgs) {
            final match = _currentMessages.cast<MessageModel?>().firstWhere(
                  (cm) => cm?.id == am.id,
                  orElse: () => null,
                );
            if (match == null || match.isSeen != am.isSeen) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          _currentMessages = await _cache.mergeAndSaveMessages(conversationId, atlasMsgs);
          notifyListeners();

          // Si recibimos mensajes no vistos, marcarlos como vistos
          final currentUsername = AppConfig.getCurrentUsername()?.replaceAll('@', '').trim().toLowerCase();
          final hasUnseen = atlasMsgs.any((m) => m.senderUsername.toLowerCase() != currentUsername && !m.isSeen);
          if (hasUnseen) {
            markMessagesAsSeen(conversationId);
          }
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

  /// Refresca manualmente los mensajes de la sala activa desde Atlas
  Future<void> refreshActiveRoom() async {
    if (_activeConversationId == null) return;
    await _fetchRoomMessages(_activeConversationId!);
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

    final cleanCurrent = currentUsername.replaceAll('@', '').trim().toLowerCase();
    final now = DateTime.now();
    final retentionDays = AppConfig.getRetentionDays();
    final expiresAt = now.add(Duration(days: retentionDays));

    final message = MessageModel(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderUsername: cleanCurrent,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      timestamp: now,
      expiresAt: expiresAt,
      isSeen: false,
    );

    // Añadir a memoria localmente al instante para respuesta visual a 0ms
    _currentMessages.add(message);
    notifyListeners();

    // Guardar en caché local en segundo plano
    _cache.saveSingleMessage(conversationId, message);

    try {
      if (!_mongo.isConnected) await _mongo.connect();

      // Enviar a MongoDB Atlas en paralelo para máxima velocidad
      await Future.wait([
        _mongo.messagesCollection.insert(message.toMap()),
        _mongo.conversationsCollection.update(
          where.eq('_id', conversationId),
          modify
              .set('updated_at', now.toIso8601String())
              .set('last_message', {
            'sender': cleanCurrent,
            'content': content.isNotEmpty ? content : (type == 'image' ? '[Foto]' : (type == 'audio' ? '[Audio]' : '[Video]')),
            'type': type,
            'timestamp': now.toIso8601String(),
          }),
        ),
      ]);

      // Refrescar lista de chats en segundo plano
      loadConversations();
    } catch (e) {
      log("Error enviando mensaje: $e");
    }
  }

  /// Vacía / borra todos los mensajes de una conversación completa sin eliminar el contacto
  Future<void> clearConversationMessages(String conversationId) async {
    try {
      if (!_mongo.isConnected) await _mongo.connect();

      // 1. Borrar todos los mensajes de esta conversación en MongoDB Atlas
      await _mongo.messagesCollection.deleteMany(
        where.eq('conversation_id', conversationId),
      );

      // 2. Limpiar el last_message de la conversación en Atlas (dejando participantes intactos)
      await _mongo.conversationsCollection.update(
        where.eq('_id', conversationId),
        modify
            .set('updated_at', DateTime.now().toIso8601String())
            .unset('last_message'),
      );

      // 3. Borrar los mensajes del almacenamiento en caché local del teléfono
      await _cache.clearCachedMessages(conversationId);

      // 4. Si la sala está abierta actualmente, limpiar los mensajes en pantalla
      if (_activeConversationId == conversationId) {
        _currentMessages = [];
        notifyListeners();
      }

      // 5. Recargar la lista de conversaciones
      await loadConversations();
    } catch (e) {
      log("Error vaciando mensajes de la conversación: $e");
      rethrow;
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

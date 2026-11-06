// lib/core/services/mongo_service.dart
import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import '../config/app_config.dart';

class MongoService {
  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;
  MongoService._internal();

  Db? _db;
  bool _isConnected = false;

  bool get isConnected => _isConnected && _db != null && _db!.state == State.open;

  Db get db {
    if (_db == null || !_isConnected) {
      throw StateError("MongoDB no está conectado. Llama a connect() primero.");
    }
    return _db!;
  }

  DbCollection get usersCollection => db.collection('users');
  DbCollection get conversationsCollection => db.collection('conversations');
  DbCollection get messagesCollection => db.collection('messages');

  /// Inicializa la conexión con MongoDB Atlas
  Future<bool> connect([String? customPassword]) async {
    final password = customPassword ?? AppConfig.getDbPassword();
    if (password.trim().isEmpty) {
      log("MongoDB: No hay contraseña configurada.");
      return false;
    }

    try {
      if (_db != null && _isConnected) {
        await _db!.close();
      }

      final uri = AppConfig.buildMongoUri(password);
      log("MongoDB: Conectando a Atlas...");
      _db = await Db.create(uri);
      await _db!.open();
      _isConnected = true;
      log("✅ Conexión establecida con éxito con MongoDB Atlas.");
      return true;
    } catch (e) {
      _isConnected = false;
      log("❌ Error conectando a MongoDB Atlas: $e");
      return false;
    }
  }

  /// Cierra la conexión
  Future<void> disconnect() async {
    if (_db != null) {
      try {
        await _db!.close();
      } catch (_) {}
      _isConnected = false;
      log("MongoDB: Conexión cerrada.");
    }
  }

  /// Crea índices para optimizar búsquedas y tiempos de respuesta
  Future<void> setupIndexes() async {
    if (!isConnected) return;
    try {
      await usersCollection.createIndex(keys: {'username': 1}, unique: true);
      await messagesCollection.createIndex(keys: {'conversation_id': 1, 'timestamp': -1});
      await conversationsCollection.createIndex(keys: {'participants': 1});
    } catch (e) {
      log("Nota al crear índices: $e");
    }
  }
}

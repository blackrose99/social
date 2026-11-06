// lib/core/services/notification_service.dart
import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/app_config.dart';
import '../navigation/app_navigator.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          log("Notificación tocada: Abriendo SIEMPRE la pantalla de Notas (camuflaje)");
          AppNavigator.openNotesDisguise();
        },
      );

      // Solicitar permisos en Android 13+
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();

      _initialized = true;
    } catch (e) {
      log("Error inicializando NotificationService: $e");
    }
  }

  /// Muestra una notificación adaptada al modo sigilo o modo explícito
  Future<void> showNewMessageNotification({
    required String sender,
    required String messageContent,
    String? conversationId,
  }) async {
    final bool isStealth = AppConfig.isStealthNotificationsEnabled();

    // En modo sigilo parece una tarea rutinaria de sincronización del sistema
    final String title = isStealth
        ? "Sincronización del sistema"
        : "Mensaje de @$sender";

    final String body = isStealth
        ? "Notas sincronizadas correctamente con el almacenamiento."
        : messageContent;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'stealth_messages_channel',
      'Alertas de Sincronización',
      channelDescription: 'Canal de notificaciones del sistema',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        id: DateTime.now().millisecond,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: conversationId,
      );
    } catch (e) {
      log("Error mostrando notificación: $e");
    }
  }
}

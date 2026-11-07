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
          log("Notificación tocada: Abriendo pantalla");
          AppNavigator.openNotesDisguise();
        },
      );

      // Solicitar permisos en Android 13+
      await requestPermission();

      _initialized = true;
    } catch (e) {
      log("Error inicializando NotificationService: $e");
    }
  }

  Future<bool> requestPermission() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Muestra una notificación con vibración y sonido
  Future<void> showNewMessageNotification({
    required String sender,
    required String messageContent,
    String? conversationId,
  }) async {
    final bool isStealth = AppConfig.isStealthNotificationsEnabled();

    final String title = isStealth
        ? "Sincronización del sistema"
        : "💬 @$sender";

    final String body = isStealth
        ? "Notas sincronizadas correctamente con el almacenamiento."
        : messageContent;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'chat_messages_channel_v3',
      'Mensajes Seguros',
      channelDescription: 'Alertas en tiempo real de nuevos mensajes',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
      styleInformation: BigTextStyleInformation(body),
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    try {
      final notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _notificationsPlugin.show(
        id: notifId,
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

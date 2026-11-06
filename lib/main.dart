// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'core/navigation/app_navigator.dart';
import 'core/services/notification_service.dart';
import 'core/services/polling_service.dart';
import 'features/chat/providers/chat_controller.dart';
import 'features/disguise/presentation/disguise_notes_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar configuraciones persistentes
  await AppConfig.init();

  // Inicializar servicio de notificaciones locales discretas
  await NotificationService().init();

  // Iniciar servicio de polling en segundo plano para escuchar nuevos mensajes
  PollingService().startPolling();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatController()),
      ],
      child: const StealthMessengerApp(),
    ),
  );
}

class StealthMessengerApp extends StatelessWidget {
  const StealthMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppNavigator.navigatorKey,
      title: 'Notas Rápidas', // Nombre fachada para el sistema operativo
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
        ),
      ),
      home: const DisguiseNotesScreen(),
    );
  }
}

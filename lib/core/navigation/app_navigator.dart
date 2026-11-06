// lib/core/navigation/app_navigator.dart
import 'package:flutter/material.dart';
import '../../features/disguise/presentation/disguise_notes_screen.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Fuerza el reseteo inmediato a la pantalla de notas (camuflaje)
  static void openNotesDisguise() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DisguiseNotesScreen()),
      (route) => false,
    );
  }
}

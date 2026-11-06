// lib/core/utils/hash_helper.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class HashHelper {
  /// Hashea la contraseña usando SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Genera un color pastel único para el avatar a partir del nombre de usuario
  static Color getAvatarColor(String username) {
    if (username.isEmpty) return Colors.blueGrey;
    final int hash = username.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> colors = [
      Colors.indigo.shade400,
      Colors.teal.shade500,
      Colors.blue.shade600,
      Colors.deepPurple.shade400,
      Colors.blueGrey.shade600,
      Colors.cyan.shade700,
      Colors.brown.shade400,
      Colors.deepOrange.shade400,
      Colors.amber.shade800,
    ];
    return colors[hash % colors.length];
  }
}

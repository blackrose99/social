// lib/core/config/app_config.dart
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String defaultClusterHost = "cluster0.zckl11f.mongodb.net";
  static const String defaultUser = "lmcastano";
  static const String defaultDbPassword = r"1q2w3e4r5T*/*";
  static const String defaultDbName = "stealth_social";

  // Clave secreta por defecto en la fachada de notas para abrir el chat
  static const String defaultSecretTrigger = "#open7788";

  // Claves de SharedPreferences
  static const String _prefDbUser = 'db_user';
  static const String _prefDbPassword = 'db_password';
  static const String _prefSecretTrigger = 'secret_trigger';
  static const String _prefCurrentUsername = 'current_username';
  static const String _prefStealthNotifications = 'stealth_notifications';
  static const String _prefCloudinaryCloud = 'cloudinary_cloud';
  static const String _prefCloudinaryPreset = 'cloudinary_preset';
  static const String _prefRetentionDays = 'retention_days';
  static const int defaultRetentionDays = 7;
  static const List<String> adminUsernames = ['mannu', 'lmc', 'luis'];

  static bool isCurrentUserAdmin() {
    final current = getCurrentUsername()?.toLowerCase().trim();
    if (current == null || current.isEmpty) return false;
    return adminUsernames.contains(current);
  }

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String getDbUser() {
    final saved = _prefs?.getString(_prefDbUser);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return defaultUser;
  }

  static Future<void> setDbUser(String user) async {
    await _prefs?.setString(_prefDbUser, user.trim());
  }

  static String getDbPassword() {
    final saved = _prefs?.getString(_prefDbPassword);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved;
    }
    return defaultDbPassword;
  }

  static Future<void> setDbPassword(String password) async {
    await _prefs?.setString(_prefDbPassword, password);
  }

  static String getSecretTrigger() {
    return _prefs?.getString(_prefSecretTrigger) ?? defaultSecretTrigger;
  }

  static Future<void> setSecretTrigger(String trigger) async {
    await _prefs?.setString(_prefSecretTrigger, trigger);
  }

  static String? getCurrentUsername() {
    final raw = _prefs?.getString(_prefCurrentUsername);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.replaceAll('@', '').trim().toLowerCase();
  }

  static Future<void> setCurrentUsername(String? username) async {
    if (username == null) {
      await _prefs?.remove(_prefCurrentUsername);
    } else {
      final clean = username.replaceAll('@', '').trim().toLowerCase();
      await _prefs?.setString(_prefCurrentUsername, clean);
    }
  }

  static bool isStealthNotificationsEnabled() {
    return _prefs?.getBool(_prefStealthNotifications) ?? true;
  }

  static Future<void> setStealthNotifications(bool enabled) async {
    await _prefs?.setBool(_prefStealthNotifications, enabled);
  }

  static String getCloudinaryCloud() {
    return _prefs?.getString(_prefCloudinaryCloud) ?? "demo";
  }

  static Future<void> setCloudinaryConfig(String cloud, String preset) async {
    await _prefs?.setString(_prefCloudinaryCloud, cloud);
    await _prefs?.setString(_prefCloudinaryPreset, preset);
  }

  static String getCloudinaryPreset() {
    return _prefs?.getString(_prefCloudinaryPreset) ?? "unsigned_preset";
  }

  static int getRetentionDays() {
    return _prefs?.getInt(_prefRetentionDays) ?? defaultRetentionDays;
  }

  static Future<void> setRetentionDays(int days) async {
    final clamped = days.clamp(1, 7);
    await _prefs?.setInt(_prefRetentionDays, clamped);
  }

  static String buildMongoUri([String? password, String? username]) {
    final user = username ?? getDbUser();
    final pwd = password ?? getDbPassword();
    final encodedPwd = Uri.encodeComponent(pwd);
    return "mongodb+srv://$user:$encodedPwd@$defaultClusterHost/$defaultDbName?retryWrites=true&w=majority";
  }
}

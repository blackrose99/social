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
  static const String _prefDbPassword = 'db_password';
  static const String _prefSecretTrigger = 'secret_trigger';
  static const String _prefCurrentUsername = 'current_username';
  static const String _prefStealthNotifications = 'stealth_notifications';
  static const String _prefCloudinaryCloud = 'cloudinary_cloud';
  static const String _prefCloudinaryPreset = 'cloudinary_preset';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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
    return _prefs?.getString(_prefCurrentUsername);
  }

  static Future<void> setCurrentUsername(String? username) async {
    if (username == null) {
      await _prefs?.remove(_prefCurrentUsername);
    } else {
      await _prefs?.setString(_prefCurrentUsername, username);
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

  static String buildMongoUri([String? password]) {
    final pwd = password ?? getDbPassword();
    final encodedPwd = Uri.encodeComponent(pwd);
    return "mongodb+srv://$defaultUser:$encodedPwd@$defaultClusterHost/$defaultDbName?retryWrites=true&w=majority";
  }
}

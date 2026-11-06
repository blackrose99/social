// lib/features/chat/presentation/stealth_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/mongo_service.dart';
import '../../disguise/presentation/disguise_notes_screen.dart';
import '../providers/chat_controller.dart';

class StealthSettingsScreen extends StatefulWidget {
  const StealthSettingsScreen({super.key});

  @override
  State<StealthSettingsScreen> createState() => _StealthSettingsScreenState();
}

class _StealthSettingsScreenState extends State<StealthSettingsScreen> {
  late TextEditingController _triggerController;
  late TextEditingController _dbPasswordController;
  late TextEditingController _cloudinaryCloudController;
  late TextEditingController _cloudinaryPresetController;
  bool _stealthNotifications = true;

  @override
  void initState() {
    super.initState();
    _triggerController = TextEditingController(text: AppConfig.getSecretTrigger());
    _dbPasswordController = TextEditingController(text: AppConfig.getDbPassword());
    _cloudinaryCloudController = TextEditingController(text: AppConfig.getCloudinaryCloud());
    _cloudinaryPresetController = TextEditingController(text: AppConfig.getCloudinaryPreset());
    _stealthNotifications = AppConfig.isStealthNotificationsEnabled();
  }

  @override
  void dispose() {
    _triggerController.dispose();
    _dbPasswordController.dispose();
    _cloudinaryCloudController.dispose();
    _cloudinaryPresetController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    await AppConfig.setSecretTrigger(_triggerController.text.trim());
    await AppConfig.setDbPassword(_dbPasswordController.text.trim());
    await AppConfig.setStealthNotifications(_stealthNotifications);
    await AppConfig.setCloudinaryConfig(
      _cloudinaryCloudController.text.trim(),
      _cloudinaryPresetController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada exitosamente')),
      );
      Navigator.pop(context);
    }
  }

  void _emergencyLock() {
    // Bloqueo de emergencia: regresa de inmediato a la fachada de notas
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DisguiseNotesScreen()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    final controller = context.read<ChatController>();
    await controller.logout();
    await MongoService().disconnect();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const DisguiseNotesScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = AppConfig.getCurrentUsername() ?? 'Desconocido';

    return Scaffold(
      backgroundColor: const Color(0xFF14171E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E27),
        elevation: 0,
        title: const Text(
          'Ajustes de Privacidad & Sigilo',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          IconButton(
            tooltip: 'Bloqueo Rápido',
            icon: const Icon(Icons.lock, color: Colors.amber),
            onPressed: _emergencyLock,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Usuario actual
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.amber.shade700,
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sesión activa como:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sección de Modo Sigilo
          const Text(
            'CAMUFLAJE Y SEGURIDAD',
            style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _triggerController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Código Secreto de Desbloqueo',
                    helperText: 'Escríbelo en el buscador de notas para abrir el chat',
                    helperStyle: TextStyle(color: Colors.white38),
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.key, color: Colors.amber),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notificaciones en Modo Sigilo', style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                    'Muestra "Sincronización del sistema" en vez de datos de chat',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  value: _stealthNotifications,
                  activeThumbColor: Colors.amber,
                  onChanged: (val) => setState(() => _stealthNotifications = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sección MongoDB Atlas
          const Text(
            'CONEXIÓN DIRECTA A MONGODB ATLAS',
            style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clúster: cluster0.zckl11f.mongodb.net\nUsuario: lmcastano',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dbPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Contraseña del Clúster Atlas',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.lock, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sección Multimedia Serverless (Cloudinary)
          const Text(
            'ALMACENAMIENTO MULTIMEDIA (SERVERLESS)',
            style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _cloudinaryCloudController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Cloudinary Cloud Name',
                    hintText: 'ej. mi-cloud-id',
                    hintStyle: TextStyle(color: Colors.white24),
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cloudinaryPresetController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Cloudinary Upload Preset (Unsigned)',
                    hintText: 'ej. chat_preset',
                    hintStyle: TextStyle(color: Colors.white24),
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Botón Guardar
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.save),
              label: const Text('GUARDAR AJUSTES', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _saveSettings,
            ),
          ),
          const SizedBox(height: 12),

          // Botón Cerrar Sesión
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Cerrar Sesión'),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }
}

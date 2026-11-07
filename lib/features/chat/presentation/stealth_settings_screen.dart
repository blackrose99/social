// lib/features/chat/presentation/stealth_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' hide State, Center;
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/mongo_service.dart';
import '../../../core/utils/hash_helper.dart';
import '../../disguise/presentation/disguise_notes_screen.dart';
import '../providers/chat_controller.dart';
import 'chat_room_screen.dart';

class StealthSettingsScreen extends StatefulWidget {
  const StealthSettingsScreen({super.key});

  @override
  State<StealthSettingsScreen> createState() => _StealthSettingsScreenState();
}

class _StealthSettingsScreenState extends State<StealthSettingsScreen> {
  late TextEditingController _triggerController;
  late TextEditingController _dbUserController;
  late TextEditingController _dbPasswordController;
  late TextEditingController _cloudinaryCloudController;
  late TextEditingController _cloudinaryPresetController;

  bool _stealthNotifications = true;
  int _retentionDays = 7;
  bool _obscureDbPassword = true;
  bool _isTestingConnection = false;

  // Panel de administración de usuarios
  bool _loadingUsers = false;
  List<Map<String, dynamic>> _registeredUsers = [];

  @override
  void initState() {
    super.initState();
    _triggerController = TextEditingController(text: AppConfig.getSecretTrigger());
    _dbUserController = TextEditingController(text: AppConfig.getDbUser());
    _dbPasswordController = TextEditingController(text: AppConfig.getDbPassword());
    _cloudinaryCloudController = TextEditingController(text: AppConfig.getCloudinaryCloud());
    _cloudinaryPresetController = TextEditingController(text: AppConfig.getCloudinaryPreset());
    _stealthNotifications = AppConfig.isStealthNotificationsEnabled();
    _retentionDays = AppConfig.getRetentionDays();

    if (AppConfig.isCurrentUserAdmin()) {
      _loadUsers();
    }
  }

  @override
  void dispose() {
    _triggerController.dispose();
    _dbUserController.dispose();
    _dbPasswordController.dispose();
    _cloudinaryCloudController.dispose();
    _cloudinaryPresetController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!AppConfig.isCurrentUserAdmin()) return;
    setState(() => _loadingUsers = true);
    try {
      final mongo = MongoService();
      if (!mongo.isConnected) await mongo.connect();
      final list = await mongo.usersCollection.find().toList();
      if (mounted) {
        setState(() {
          _registeredUsers = list;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _testClusterConnection() async {
    setState(() => _isTestingConnection = true);
    try {
      final user = _dbUserController.text.trim();
      final pwd = _dbPasswordController.text.trim();
      final uri = AppConfig.buildMongoUri(pwd, user);
      final testDb = await Db.create(uri);
      await testDb.open();
      await testDb.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ¡Conexión exitosa con el clúster de MongoDB Atlas!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error conectando al clúster: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _changeUserPasswordDialog(String targetUsername) async {
    final pwdController = TextEditingController();
    bool obscure = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E222B),
          title: Text(
            'Cambiar Clave: @$targetUsername',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: TextField(
            controller: pwdController,
            obscureText: obscure,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nueva Contraseña',
              labelStyle: const TextStyle(color: Colors.white70),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                onPressed: () => setDlgState(() => obscure = !obscure),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.black),
              onPressed: () async {
                final newPass = pwdController.text.trim();
                if (newPass.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La contraseña debe tener al menos 4 caracteres')),
                  );
                  return;
                }
                Navigator.pop(ctx);

                try {
                  final newHash = HashHelper.hashPassword(newPass);
                  final mongo = MongoService();
                  if (!mongo.isConnected) await mongo.connect();
                  await mongo.usersCollection.update(
                    where.eq('username', targetUsername),
                    modify.set('password_hash', newHash),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Contraseña de @$targetUsername actualizada exitosamente')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error actualizando contraseña: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUserDialog(String targetUsername) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: const Text('Eliminar Usuario', style: TextStyle(color: Colors.redAccent)),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente a @$targetUsername del sistema?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final mongo = MongoService();
        if (!mongo.isConnected) await mongo.connect();
        await mongo.usersCollection.remove(where.eq('username', targetUsername));
        await mongo.conversationsCollection.remove(where.eq('participants', targetUsername));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Usuario @$targetUsername eliminado')),
          );
        }
        await _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _sendMessageToUser(String targetUsername) async {
    final currentUsername = AppConfig.getCurrentUsername() ?? '';
    final cleanTarget = targetUsername.replaceAll('@', '').trim().toLowerCase();
    final cleanCurrent = currentUsername.replaceAll('@', '').trim().toLowerCase();

    if (cleanTarget == cleanCurrent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes abrir un chat contigo mismo.')),
      );
      return;
    }

    try {
      final controller = context.read<ChatController>();
      final conv = await controller.getOrCreateDirectChat(cleanTarget);
      if (conv != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(conversation: conv),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir chat con @$cleanTarget: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    await AppConfig.setSecretTrigger(_triggerController.text.trim());
    await AppConfig.setStealthNotifications(_stealthNotifications);
    await AppConfig.setRetentionDays(_retentionDays);

    // Solo los administradores pueden guardar cambios en credenciales del clúster
    if (AppConfig.isCurrentUserAdmin()) {
      await AppConfig.setDbUser(_dbUserController.text.trim());
      await AppConfig.setDbPassword(_dbPasswordController.text.trim());
      await AppConfig.setCloudinaryConfig(
        _cloudinaryCloudController.text.trim(),
        _cloudinaryPresetController.text.trim(),
      );
      // Reconectar si las credenciales cambiaron
      await MongoService().connect();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada exitosamente')),
      );
      Navigator.pop(context);
    }
  }

  void _emergencyLock() {
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
    final isAdmin = AppConfig.isCurrentUserAdmin();

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
                  backgroundColor: isAdmin ? Colors.amber.shade700 : Colors.blueGrey,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Sesión activa como:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          if (isAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade800,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
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
                const Divider(color: Colors.white10, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Puente Temporal Atlas (TTL)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          'Borrar de Atlas tras: $_retentionDays día${_retentionDays > 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.amber, fontSize: 12),
                        ),
                      ],
                    ),
                    DropdownButton<int>(
                      dropdownColor: const Color(0xFF1E222B),
                      value: _retentionDays,
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      items: [1, 2, 3, 4, 5, 6, 7].map((days) {
                        return DropdownMenuItem<int>(
                          value: days,
                          child: Text('$days día${days > 1 ? 's' : ''}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _retentionDays = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'La base de datos Atlas funciona como un puente temporal para transferir mensajes y audios. Tras este plazo se borran de Atlas para no dejar rastro en la nube, pero tus mensajes y audios permanecen protegidos en el almacenamiento local de tu dispositivo.',
                  style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECCIÓN EXCLUSIVA DE ADMINISTRADOR: CLÚSTER MONGODB
          if (isAdmin) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CLÚSTER ATLAS (SOLO ADMIN)',
                  style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber.shade900, borderRadius: BorderRadius.circular(4)),
                  child: const Text('PROTEGIDO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Host: cluster0.zckl11f.mongodb.net\nBase de datos: stealth_social',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dbUserController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Usuario del Clúster',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.person, color: Colors.amber),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _dbPasswordController,
                    obscureText: _obscureDbPassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Contraseña del Clúster Atlas',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock, color: Colors.amber),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureDbPassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white54,
                        ),
                        onPressed: () => setState(() => _obscureDbPassword = !_obscureDbPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber,
                        side: const BorderSide(color: Colors.amber),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isTestingConnection
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                          : const Icon(Icons.wifi_tethering),
                      label: Text(_isTestingConnection ? 'Probando...' : 'Probar Conexión con Clúster'),
                      onPressed: _isTestingConnection ? null : _testClusterConnection,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECCIÓN EXCLUSIVA DE ADMINISTRADOR: GESTIÓN DE USUARIOS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GESTIÓN DE USUARIOS (SOLO ADMIN)',
                  style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.amber, size: 20),
                  onPressed: _loadUsers,
                  tooltip: 'Recargar usuarios',
                ),
              ],
            ),
            const SizedBox(height: 4),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: _loadingUsers
                  ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.amber)))
                  : _registeredUsers.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No hay usuarios encontrados en el sistema.', style: TextStyle(color: Colors.white54)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _registeredUsers.length,
                          separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                          itemBuilder: (ctx, index) {
                            final user = _registeredUsers[index];
                            final uName = (user['username'] ?? '').toString();
                            final isUserAdmin = AppConfig.adminUsernames.contains(uName.toLowerCase());

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: isUserAdmin ? Colors.amber.shade700 : Colors.blueGrey.shade700,
                                child: Text(
                                  uName.isNotEmpty ? uName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: isUserAdmin ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    '@$uName',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                  if (isUserAdmin) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade800,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ADMIN',
                                        style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                'Registrado: ${user['created_at'] != null ? user['created_at'].toString().split('T').first : 'N/A'}',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.greenAccent, size: 20),
                                    tooltip: 'Mandar mensaje',
                                    onPressed: () => _sendMessageToUser(uName),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.key, color: Colors.amber, size: 20),
                                    tooltip: 'Cambiar contraseña',
                                    onPressed: () => _changeUserPasswordDialog(uName),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    tooltip: 'Eliminar usuario',
                                    onPressed: () => _deleteUserDialog(uName),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 20),
          ],

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

// lib/features/auth/presentation/hidden_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' hide State, Center;
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/mongo_service.dart';
import '../../../core/utils/hash_helper.dart';
import '../../chat/presentation/chat_list_screen.dart';
import '../models/user_model.dart';

class HiddenAuthScreen extends StatefulWidget {
  const HiddenAuthScreen({super.key});

  @override
  State<HiddenAuthScreen> createState() => _HiddenAuthScreenState();
}

class _HiddenAuthScreenState extends State<HiddenAuthScreen> {
  bool _isLogin = true; // Por defecto Iniciar Sesión para acceder inmediatamente
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final rawUsername = _usernameController.text.trim();
    final cleanUsername = rawUsername.replaceAll('@', '').trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (cleanUsername.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Por favor ingresa tu alias y contraseña.');
      return;
    }

    if (cleanUsername.length < 3) {
      setState(() => _errorMessage = 'El alias debe tener al menos 3 letras.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final mongo = MongoService();
      if (!mongo.isConnected) {
        final connected = await mongo.connect();
        if (!connected) {
          throw Exception("No se pudo conectar al clúster de Atlas. Revisa tu conexión a internet.");
        }
        await mongo.setupIndexes();
      }

      final usersCol = mongo.usersCollection;
      final passwordHash = HashHelper.hashPassword(password);

      if (_isLogin) {
        // INICIO DE SESIÓN
        // Buscar de forma tolerante (limpio, con @ o insensible a mayúsculas)
        var userDoc = await usersCol.findOne({'username': cleanUsername});
        userDoc ??= await usersCol.findOne({'username': '@$cleanUsername'});
        userDoc ??= await usersCol.findOne(
          where.match('username', '^@?$cleanUsername\$'),
        );

        if (userDoc == null) {
          throw Exception("El alias '@$cleanUsername' no está registrado. Si no tienes cuenta, toca arriba en 'Crear Perfil'.");
        }

        if (userDoc['password_hash'] != passwordHash) {
          throw Exception("Contraseña incorrecta para @$cleanUsername.");
        }

        // Guardar SIEMPRE el username normalizado sin @
        await AppConfig.setCurrentUsername(cleanUsername);
        if (!mounted) return;
        _goToChatList();
      } else {
        // REGISTRO DE NUEVO PERFIL (Evitar duplicados estrictamente)
        final existing = await usersCol.findOne(
          where.match('username', '^@?$cleanUsername\$'),
        );
        if (existing != null) {
          throw Exception("El alias '@$cleanUsername' ya existe y pertenece a otro usuario. Elige un nombre de usuario diferente.");
        }

        final newUser = UserModel(
          id: const Uuid().v4(),
          username: cleanUsername,
          passwordHash: passwordHash,
          createdAt: DateTime.now(),
        );

        await usersCol.insert(newUser.toMap());
        // Guardar SIEMPRE el username normalizado sin @
        await AppConfig.setCurrentUsername(cleanUsername);

        if (!mounted) return;
        _goToChatList();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToChatList() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ChatListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101216),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Perfil Privado',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: const Icon(Icons.favorite, color: Colors.amber, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                _isLogin ? 'Bienvenido de nuevo' : 'Crea tu Perfil Secreto',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isLogin
                    ? 'Ingresa tu alias y PIN para abrir tus conversaciones'
                    : 'Crea tu nombre aquí. Pídele a tu contacto que instale la app y te busque con este nombre.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 24),

              // Selector Tabs: Iniciar Sesión vs Crear Perfil (Iniciar Sesión primero)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isLogin = true;
                          _errorMessage = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isLogin ? Colors.amber.shade700 : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                color: _isLogin ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isLogin = false;
                          _errorMessage = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isLogin ? Colors.amber.shade700 : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Crear Perfil',
                              style: TextStyle(
                                color: !_isLogin ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Campo de Usuario / Alias
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Tu Alias o Nombre Secreto',
                  hintText: 'ej. mannu, mi_amor, cielo',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.alternate_email, color: Colors.amber),
                  filled: true,
                  fillColor: const Color(0xFF1C2029),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Campo de PIN o Contraseña
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'PIN o Contraseña Secreta',
                  hintText: 'ej. 1234 o una palabra',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.key, color: Colors.amber),
                  filled: true,
                  fillColor: const Color(0xFF1C2029),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade700),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Botón Principal
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          _isLogin ? 'ENTRAR A MIS CHATS' : 'CREAR Y ENTRAR',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

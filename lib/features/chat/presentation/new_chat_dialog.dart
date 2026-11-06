// lib/features/chat/presentation/new_chat_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/hash_helper.dart';
import '../models/conversation_model.dart';
import '../providers/chat_controller.dart';

class NewChatDialog extends StatefulWidget {
  const NewChatDialog({super.key});

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  bool _isGroup = false;
  bool _isLoading = false;
  String? _error;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final Set<String> _selectedMembers = {};

  @override
  void dispose() {
    _usernameController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final controller = context.read<ChatController>();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      ConversationModel? conv;
      if (!_isGroup) {
        final targetUser = _usernameController.text.trim();
        if (targetUser.isEmpty) {
          throw Exception("Ingresa el alias del usuario a buscar.");
        }
        conv = await controller.getOrCreateDirectChat(targetUser);
      } else {
        final groupName = _groupNameController.text.trim();
        if (groupName.isEmpty) {
          throw Exception("Por favor ingresa un nombre para el grupo.");
        }
        if (_selectedMembers.isEmpty) {
          throw Exception("Debes marcar al menos un contacto con el check para crear el grupo.");
        }

        conv = await controller.createGroupChat(
          groupName: groupName,
          memberUsernames: _selectedMembers.toList(),
        );
      }

      if (mounted && conv != null) {
        Navigator.pop(context, conv);
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final currentUsername = AppConfig.getCurrentUsername() ?? '';

    // Obtener los contactos/amigos con los que ya se tiene conversación directa
    final Set<String> availableContacts = {};
    for (final c in controller.conversations) {
      for (final p in c.participants) {
        final lower = p.toLowerCase();
        if (lower != currentUsername.toLowerCase()) {
          availableContacts.add(lower);
        }
      }
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1E222B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _isGroup ? Icons.group_add : Icons.person_add,
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          Text(
            _isGroup ? 'Nuevo Grupo' : 'Buscar Usuario',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector: 1 a 1 vs Grupal
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('1 a 1')),
                    selected: !_isGroup,
                    onSelected: (val) => setState(() {
                      _isGroup = false;
                      _error = null;
                    }),
                    selectedColor: Colors.amber.shade700,
                    labelStyle: TextStyle(
                      color: !_isGroup ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Grupal')),
                    selected: _isGroup,
                    onSelected: (val) => setState(() {
                      _isGroup = true;
                      _error = null;
                    }),
                    selectedColor: Colors.amber.shade700,
                    labelStyle: TextStyle(
                      color: _isGroup ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_isGroup) ...[
              TextField(
                controller: _usernameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Alias del usuario',
                  hintText: 'ej. lmc, mannu, cielo',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixText: '@',
                  prefixStyle: const TextStyle(color: Colors.amber),
                  filled: true,
                  fillColor: const Color(0xFF14171E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Escribe el nombre de usuario de la persona para abrir el chat privado directamente.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ] else ...[
              TextField(
                controller: _groupNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre del grupo',
                  hintText: 'ej. Amigos Secretos',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF14171E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Selecciona con check los amigos para el grupo:',
                style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (availableContacts.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Aún no tienes contactos agregados.\nInicia primero un chat 1-a-1 con un usuario para que aparezca en tu lista de amigos seleccionables.',
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
                  ),
                ),
              ] else ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: availableContacts.map((contact) {
                      final isChecked = _selectedMembers.contains(contact);
                      return CheckboxListTile(
                        value: isChecked,
                        activeColor: Colors.amber.shade700,
                        checkColor: Colors.black,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        secondary: CircleAvatar(
                          radius: 16,
                          backgroundColor: HashHelper.getAvatarColor(contact),
                          child: Text(
                            contact[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          '@$contact',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        onChanged: (bool? val) {
                          setState(() {
                            if (val == true) {
                              _selectedMembers.add(contact);
                            } else {
                              _selectedMembers.remove(contact);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
            foregroundColor: Colors.black,
          ),
          onPressed: _isLoading ? null : _handleCreate,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  _isGroup ? 'Crear Grupo' : 'Comenzar',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}

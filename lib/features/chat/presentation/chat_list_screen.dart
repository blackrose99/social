// lib/features/chat/presentation/chat_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/hash_helper.dart';
import '../../disguise/presentation/disguise_notes_screen.dart';
import '../models/conversation_model.dart';
import '../providers/chat_controller.dart';
import 'chat_room_screen.dart';
import 'new_chat_dialog.dart';
import 'stealth_settings_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatController>().loadConversations();
    });
    // Auto-refrescar lista de chats continuamente para sincronización en tiempo real
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) {
        context.read<ChatController>().loadConversations();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _lockAndReturnToNotes() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DisguiseNotesScreen()),
      (route) => false,
    );
  }

  Future<void> _openNewChatDialog() async {
    final result = await showDialog<ConversationModel>(
      context: context,
      builder: (ctx) => const NewChatDialog(),
    );

    if (result != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(conversation: result),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUsername = AppConfig.getCurrentUsername() ?? 'Usuario';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _lockAndReturnToNotes();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121418),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1E27),
          elevation: 1,
          leading: Padding(
            padding: const EdgeInsets.all(10.0),
            child: CircleAvatar(
              backgroundColor: HashHelper.getAvatarColor(currentUsername),
              child: Text(
                currentUsername.isNotEmpty ? currentUsername[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Red Segura',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '@$currentUsername',
                style: const TextStyle(color: Colors.amber, fontSize: 12),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Ajustes de sigilo',
              icon: const Icon(Icons.settings_outlined, color: Colors.white70),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StealthSettingsScreen()),
                );
              },
            ),
            IconButton(
              tooltip: 'Bloqueo instantáneo',
              icon: const Icon(Icons.lock, color: Colors.amber),
              onPressed: _lockAndReturnToNotes,
            ),
          ],
        ),
        body: Consumer<ChatController>(
          builder: (context, controller, child) {
            if (controller.isLoading && controller.conversations.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              );
            }

            final conversations = controller.conversations;

            if (conversations.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1E28),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.lock_person_outlined, size: 54, color: Colors.amber),
                            const SizedBox(height: 12),
                            const Text(
                              'Canal Privado Activo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tu alias registrado es: @$currentUsername',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Comparte tu alias con ella para que te busque, o busca el alias de ella aquí abajo para empezar a hablar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.person_search_rounded),
                          label: const Text(
                            'BUSCAR USUARIO / HABLAR',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: _openNewChatDialog,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              color: Colors.amber,
              backgroundColor: const Color(0xFF1E222B),
              onRefresh: () => controller.loadConversations(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: conversations.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.white.withValues(alpha: 0.05),
                  height: 1,
                  indent: 72,
                ),
                itemBuilder: (context, index) {
                  final conv = conversations[index];
                  final displayName = conv.getDisplayName(currentUsername);
                  final lastMsg = conv.lastMessage;
                  final String preview = lastMsg != null
                      ? '${lastMsg['sender'] == currentUsername ? 'Tú: ' : ''}${lastMsg['content'] ?? ''}'
                      : 'Conversación creada';

                  final DateTime date = lastMsg != null && lastMsg['timestamp'] != null
                      ? (DateTime.tryParse(lastMsg['timestamp']) ?? conv.updatedAt)
                      : conv.updatedAt;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: HashHelper.getAvatarColor(displayName),
                      child: Text(
                        displayName.replaceAll('@', '')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormat('hh:mm a').format(date),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatRoomScreen(conversation: conv),
                        ),
                      );
                      controller.loadConversations();
                    },
                  );
                },
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.amber.shade700,
          elevation: 3,
          onPressed: _openNewChatDialog,
          child: const Icon(Icons.add_comment_rounded, color: Colors.black),
        ),
      ),
    );
  }
}

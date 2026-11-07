// lib/features/chat/presentation/chat_room_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/hash_helper.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../providers/chat_controller.dart';

class ChatRoomScreen extends StatefulWidget {
  final ConversationModel conversation;

  const ChatRoomScreen({super.key, required this.conversation});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isSending = false;
  bool _isRecording = false;
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatController>().enterChatRoom(widget.conversation.id);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _currentlyPlayingId = null);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _confirmClearThisConversation() async {
    final currentUsername = AppConfig.getCurrentUsername() ?? '';
    final displayName = widget.conversation.getDisplayName(currentUsername);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: Text('¿Vaciar chat con $displayName?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Se eliminarán todos los mensajes y archivos de esta sala, pero conservarás el contacto en tu lista.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.black,
            ),
            child: const Text('Vaciar Chat', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await context.read<ChatController>().clearConversationMessages(widget.conversation.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Chat vaciado. El contacto se conserva.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al vaciar chat: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    final controller = context.read<ChatController>();

    await controller.sendMessage(
      conversationId: widget.conversation.id,
      content: text,
      type: 'text',
    );

    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final file = await StorageService.pickImage(source: source);
    if (file == null) return;

    setState(() => _isSending = true);

    try {
      final uploadedUrl = await StorageService.uploadFile(file, resourceType: 'image');
      if (uploadedUrl != null && mounted) {
        final controller = context.read<ChatController>();
        await controller.sendMessage(
          conversationId: widget.conversation.id,
          content: '',
          type: 'image',
          mediaUrl: uploadedUrl,
        );
        _scrollToBottom();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar la imagen.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendVideo() async {
    final file = await StorageService.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _isSending = true);

    try {
      final uploadedUrl = await StorageService.uploadFile(file, resourceType: 'video');
      if (uploadedUrl != null && mounted) {
        final controller = context.read<ChatController>();
        await controller.sendMessage(
          conversationId: widget.conversation.id,
          content: '[Video privado]',
          type: 'video',
          mediaUrl: uploadedUrl,
        );
        _scrollToBottom();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el video.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleRecordAudio() async {
    if (_isRecording) {
      // Detener y enviar grabación
      try {
        final path = await _audioRecorder.stop();
        setState(() => _isRecording = false);

        if (path != null && File(path).existsSync()) {
          setState(() => _isSending = true);
          final file = File(path);
          final uploadedUrl = await StorageService.uploadFile(file, resourceType: 'auto');

          if (uploadedUrl != null && mounted) {
            final controller = context.read<ChatController>();
            await controller.sendMessage(
              conversationId: widget.conversation.id,
              content: '[Nota de voz]',
              type: 'audio',
              mediaUrl: uploadedUrl,
            );
            _scrollToBottom();
          }
        }
      } catch (e) {
        setState(() => _isRecording = false);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    } else {
      // Iniciar grabación
      try {
        final hasPermission = await _audioRecorder.hasPermission();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Se necesita permiso de micrófono.')),
            );
          }
          return;
        }

        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
          path: filePath,
        );

        setState(() => _isRecording = true);
      } catch (e) {
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _playAudio(MessageModel message) async {
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) return;

    if (_currentlyPlayingId == message.id) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = null);
      return;
    }

    try {
      final url = message.mediaUrl!;
      if (url.startsWith('data:audio')) {
        final commaIdx = url.indexOf(',');
        final base64Data = url.substring(commaIdx + 1);
        final bytes = base64Decode(base64Data);
        await _audioPlayer.stop();
        await _audioPlayer.play(BytesSource(bytes));
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
      }

      setState(() => _currentlyPlayingId = message.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al reproducir nota de voz')),
        );
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      backgroundColor: const Color(0xFF1E222B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Cámara',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Fotos',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.video_library_rounded,
                  label: 'Video',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendVideo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.amber.shade700,
              child: Icon(icon, color: Colors.black, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadMedia(MessageModel message) async {
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) return;

    final isAdmin = AppConfig.isCurrentUserAdmin();
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Solo los administradores pueden descargar archivos.')),
      );
      return;
    }

    final ext = message.type == 'video' ? 'mp4' : 'jpg';
    final fileName = 'privado_${message.id.substring(0, 8)}.$ext';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descargando archivo en tu dispositivo...')),
    );

    final savedPath = await StorageService.saveMediaToDevice(
      mediaUrl: message.mediaUrl!,
      fileName: fileName,
    );

    if (mounted) {
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text('✅ Guardado en Descargas:\n$fileName'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Error al guardar el archivo.')),
        );
      }
    }
  }

  void _showMediaViewer(MessageModel message) {
    final isAdmin = AppConfig.isCurrentUserAdmin();

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: message.type == 'video'
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam, color: Colors.amber, size: 70),
                            const SizedBox(height: 12),
                            const Text(
                              'Video Privado',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isAdmin
                                  ? 'Toca el botón superior para descargar el video a tu teléfono'
                                  : 'Reproducción protegida (Solo visualización)',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        )
                      : (message.mediaUrl != null && message.mediaUrl!.startsWith('data:image')
                          ? Image.memory(
                              base64Decode(message.mediaUrl!.substring(message.mediaUrl!.indexOf(',') + 1)),
                              fit: BoxFit.contain,
                            )
                          : Image.network(
                              message.mediaUrl ?? '',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Text(
                                '[Error cargando imagen]',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )),
                ),
              ),
              Positioned(
                top: 40,
                left: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: isAdmin
                    ? CircleAvatar(
                        backgroundColor: Colors.amber.shade700,
                        child: IconButton(
                          tooltip: 'Descargar archivo (Admin)',
                          icon: const Icon(Icons.download, color: Colors.black),
                          onPressed: () {
                            _downloadMedia(message);
                          },
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, color: Colors.amber, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Solo visualización',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(MessageModel message, bool isMe) {
    if (message.type == 'audio') {
      final isPlaying = _currentlyPlayingId == message.id;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: isMe ? Colors.black : Colors.amber,
              size: 36,
            ),
            onPressed: () => _playAudio(message),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nota de voz',
                style: TextStyle(
                  color: isMe ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                isPlaying ? 'Reproduciendo...' : 'Toca para escuchar',
                style: TextStyle(
                  color: isMe ? Colors.black54 : Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      );
    }

    if (message.type == 'video') {
      return GestureDetector(
        onTap: () => _showMediaViewer(message),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_fill, color: isMe ? Colors.black : Colors.amber, size: 48),
                const SizedBox(height: 6),
                Text(
                  'Video adjunto (Toca para ver)',
                  style: TextStyle(color: isMe ? Colors.black87 : Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (message.type == 'image' && message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
      final url = message.mediaUrl!;
      Widget imageWidget;
      if (url.startsWith('data:image')) {
        try {
          final commaIdx = url.indexOf(',');
          final base64Data = url.substring(commaIdx + 1);
          final bytes = base64Decode(base64Data);
          imageWidget = ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              height: 200,
              width: double.infinity,
            ),
          );
        } catch (_) {
          imageWidget = const Text('[Error imagen]');
        }
      } else {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            height: 200,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('[Imagen no disponible]', style: TextStyle(color: Colors.white60)),
            ),
          ),
        );
      }

      return GestureDetector(
        onTap: () => _showMediaViewer(message),
        child: imageWidget,
      );
    }

    return Text(
      message.content,
      style: TextStyle(
        color: isMe ? Colors.black : Colors.white,
        fontSize: 15,
        height: 1.3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUsername = AppConfig.getCurrentUsername() ?? '';
    final displayName = widget.conversation.getDisplayName(currentUsername);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _audioPlayer.stop();
          context.read<ChatController>().leaveChatRoom();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF101216),
        appBar: AppBar(
          backgroundColor: const Color(0xFF181B22),
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.white70),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: HashHelper.getAvatarColor(displayName),
                child: Text(
                  displayName.replaceAll('@', '')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.conversation.isGroup
                          ? '${widget.conversation.participants.length} personas'
                          : 'Chat cifrado directo',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              tooltip: 'Actualizar mensajes',
              onPressed: () async {
                await context.read<ChatController>().refreshActiveRoom();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mensajes sincronizados'),
                      duration: Duration(milliseconds: 900),
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.amber),
              tooltip: 'Vaciar conversación',
              onPressed: _confirmClearThisConversation,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Consumer<ChatController>(
                builder: (context, controller, child) {
                  final messages = controller.currentMessages;

                  if (controller.isLoading && messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator(color: Colors.amber));
                  }

                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'Comienza a hablar en privado.\nNadie más tiene acceso a este canal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderUsername.toLowerCase() == currentUsername.toLowerCase();

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.amber.shade800 : const Color(0xFF222733),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(isMe ? 14 : 2),
                              bottomRight: Radius.circular(isMe ? 2 : 14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMe && widget.conversation.isGroup) ...[
                                Text(
                                  '@${msg.senderUsername}',
                                  style: TextStyle(
                                    color: HashHelper.getAvatarColor(msg.senderUsername),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],

                              _buildMessageContent(msg, isMe),

                              const SizedBox(height: 3),
                              Text(
                                DateFormat('hh:mm a').format(msg.timestamp),
                                style: TextStyle(
                                  color: isMe ? Colors.black54 : Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            if (_isSending)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: Colors.amber.shade900.withValues(alpha: 0.2),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                    SizedBox(width: 8),
                    Text('Enviando...', style: TextStyle(color: Colors.amber, fontSize: 12)),
                  ],
                ),
              ),

            if (_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: Colors.red.shade900.withValues(alpha: 0.3),
                child: const Row(
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Grabando nota de voz...', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            // Barra inferior de entrada
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: const Color(0xFF181B22),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.white70),
                      onPressed: _isSending ? null : _showAttachmentMenu,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Mensaje...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF232733),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _handleSendText(),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Si hay texto, muestra botón de enviar. Si no, botón de nota de voz (micrófono)
                    if (_textController.text.trim().isNotEmpty) ...[
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: Colors.amber.shade700,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.black, size: 19),
                          onPressed: _isSending ? null : _handleSendText,
                        ),
                      ),
                    ] else ...[
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: _isRecording ? Colors.redAccent : Colors.amber.shade700,
                        child: IconButton(
                          icon: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            color: Colors.black,
                            size: 21,
                          ),
                          onPressed: _isSending ? null : _toggleRecordAudio,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

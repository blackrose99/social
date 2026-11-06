// lib/features/disguise/presentation/disguise_notes_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../auth/presentation/hidden_auth_screen.dart';
import '../../chat/presentation/chat_list_screen.dart';
import '../models/note_model.dart';
import 'note_detail_screen.dart';

class DisguiseNotesScreen extends StatefulWidget {
  const DisguiseNotesScreen({super.key});

  @override
  State<DisguiseNotesScreen> createState() => _DisguiseNotesScreenState();
}

class _DisguiseNotesScreenState extends State<DisguiseNotesScreen> {
  static const String _prefNotesKey = 'disguise_notes_list';
  final TextEditingController _searchController = TextEditingController();
  List<NoteModel> _notes = [];
  List<NoteModel> _filteredNotes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_prefNotesKey);

    if (jsonList != null && jsonList.isNotEmpty) {
      setState(() {
        _notes = jsonList.map((str) => NoteModel.fromJson(str)).toList();
        _filteredNotes = List.from(_notes);
      });
    } else {
      // Notas por defecto sumamente realistas
      final defaultNotes = [
        NoteModel(
          id: '1',
          title: 'Lista de compras semana',
          content: 'Leche deslactosada, café en grano, pechuga de pollo, huevos, plátanos y pan de avena.',
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        NoteModel(
          id: '2',
          title: 'Pendientes del auto',
          content: 'Revisión periódica de frenos y cambio de aceite antes del viaje del fin de semana.',
          updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        NoteModel(
          id: '3',
          title: 'Ideas para remodelar sala',
          content: 'Pintura gris perla, lámpara de pie cálida, estante para plantas suculentas.',
          updatedAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ];

      setState(() {
        _notes = defaultNotes;
        _filteredNotes = List.from(defaultNotes);
      });
      _saveNotes();
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _notes.map((n) => n.toJson()).toList();
    await prefs.setStringList(_prefNotesKey, jsonList);
  }

  void _onSearchChanged(String query) {
    // Verificación del disparador secreto
    final trigger = AppConfig.getSecretTrigger();
    if (query.trim() == trigger) {
      _searchController.clear();
      FocusScope.of(context).unfocus();
      _navigateToHiddenZone();
      return;
    }

    setState(() {
      if (query.trim().isEmpty) {
        _filteredNotes = List.from(_notes);
      } else {
        _filteredNotes = _notes.where((note) {
          final q = query.toLowerCase();
          return note.title.toLowerCase().contains(q) ||
              note.content.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  void _navigateToHiddenZone() {
    final currentUser = AppConfig.getCurrentUsername();

    Widget target;
    if (currentUser != null && currentUser.isNotEmpty) {
      target = const ChatListScreen();
    } else {
      target = const HiddenAuthScreen();
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => target,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _openNoteEditor([NoteModel? note]) async {
    final result = await Navigator.push<NoteModel>(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    );

    if (result != null) {
      setState(() {
        if (note != null) {
          final index = _notes.indexWhere((n) => n.id == note.id);
          if (index != -1) {
            _notes[index] = result;
          }
        } else {
          _notes.insert(0, result);
        }
        _onSearchChanged(_searchController.text);
      });
      _saveNotes();
    }
  }

  void _deleteNote(String id) {
    setState(() {
      _notes.removeWhere((n) => n.id == id);
      _onSearchChanged(_searchController.text);
    });
    _saveNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: GestureDetector(
          onTap: _navigateToHiddenZone,
          onLongPress: _navigateToHiddenZone,
          child: const Row(
            children: [
              Icon(Icons.description_outlined, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Notas Rápidas',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar cuenta',
            icon: const Icon(Icons.sync_rounded, color: Colors.black54),
            onPressed: _navigateToHiddenZone,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda con camuflaje
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar en todas las notas...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),

          // Listado de notas
          Expanded(
            child: _filteredNotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notes, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No hay notas que coincidan',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
                      return Dismissible(
                        key: Key(note.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteNote(note.id),
                        child: Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          color: Colors.white,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            title: Text(
                              note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  note.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat('dd MMM yyyy').format(note.updatedAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _openNoteEditor(note),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber.shade700,
        elevation: 2,
        onPressed: () => _openNoteEditor(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/notes/domain/nota_model.dart';
import 'package:notes_app/features/notes/presentation/providers/notes_provider.dart';
import 'package:notes_app/features/notes/presentation/screens/add_edit_note_screen.dart';
import 'package:notes_app/core/enums/estado_note_type.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  EstadoNoteType _currentFilter = EstadoNoteType.ACTIVA;
  bool _isSearching = false;

  // Multi-selección
  final Set<int> _selectedNoteIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Nota> _filtrar(List<Nota> notas, EstadoNoteType estado) {
    var filtradas = notas.where((n) => n.estado == estado).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtradas = filtradas.where((n) =>
        n.titulo.toLowerCase().contains(q) ||
        n.contenido.toLowerCase().contains(q)
      ).toList();
    }
    filtradas.sort((a, b) {
      if (a.esAnclada && !b.esAnclada) return -1;
      if (!a.esAnclada && b.esAnclada) return 1;
      
      final fa = a.fechaCreacion ?? DateTime(2000);
      final fb = b.fechaCreacion ?? DateTime(2000);
      return fb.compareTo(fa);
    });
    return filtradas;
  }

  String _formatFecha(DateTime date) {
    final meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return "${date.day} ${meses[date.month - 1]}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  void _cambiarEstado(Nota nota, String nuevoEstado, String mensaje) async {
    if (nota.id == null) return;
    try {
      await ref.read(notesProvider.notifier).cambiarEstado(nota.id!, nuevoEstado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: const Color(0xFF2A9D8F),
            behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    }
  }

  void _eliminarPermanente(Nota nota) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar permanentemente', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
        content: Text('¿Eliminar "${nota.titulo}" para siempre?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(notesProvider.notifier).deleteNota(nota.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Nota eliminada permanentemente 🗑️'), backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
                      backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ══════════════════════════════════════════
          //  HEADER LIMPIO
          // ══════════════════════════════════════════
          // ══════════════════════════════════════════
          if (ref.watch(selectionModeProvider))
            _buildSelectionHeader()
          else
            Padding(
              padding: const EdgeInsets.only(top: 60, left: 24, right: 16, bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_isSearching)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mis Notas', style: TextStyle(color: Color(0xFF2D3142), fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        notesAsync.when(
                          loading: () => const Text('Cargando...', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          error: (_, __) => const Text('Error', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          data: (notas) {
                            final count = notas.where((n) => n.estado == _currentFilter).length;
                            return Text(
                              '$count nota${count == 1 ? '' : 's'} ${_currentFilter.name.toLowerCase()}',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                if (_isSearching) ...[
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: const InputDecoration(
                        hintText: 'Buscar...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                ] else ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _isSearching = true;
                          });
                        },
                      ),
                      PopupMenuButton<EstadoNoteType>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onSelected: (val) => setState(() => _currentFilter = val),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: EstadoNoteType.ACTIVA, child: Text('Activas')),
                          const PopupMenuItem(value: EstadoNoteType.ARCHIVADA, child: Text('Archivadas')),
                          const PopupMenuItem(value: EstadoNoteType.ELIMINADA, child: Text('Papelera')),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Espaciado dinámico
          const SizedBox(height: 10),

          // ══════════════════════════════════════════
          //  LISTA DE NOTAS
          // ══════════════════════════════════════════
          notesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: Color(0xFF2A9D8F)),
              ),
            ),
            error: (error, _) => Center(child: Text('Error: $error', style: const TextStyle(color: Colors.red))),
            data: (todasLasNotas) {
              final filtradas = _filtrar(todasLasNotas, _currentFilter);
              return _buildNotasList(filtradas, _currentFilter);
            },
          ),
        ],
      ),
    ),
    bottomNavigationBar: ref.watch(selectionModeProvider) ? _buildBottomSelectionBar() : null,
    );
  }

  // ══════════════════════════════════════════════════
  //  SELECTION HEADER & BOTTOM BAR (ESTILO MIUI)
  // ══════════════════════════════════════════════════
  Widget _buildSelectionHeader() {
    return Container(
      color: Colors.transparent, // Fix background UI
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 10), // Padding ajustado al borde superior seguro
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
             icon: const Icon(Icons.close, color: Color(0xFF2D3142)),
             onPressed: () {
               ref.read(selectionModeProvider.notifier).toggle(false);
               setState(() {
                 _selectedNoteIds.clear();
               });
             },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_selectedNoteIds.length} seleccionado${_selectedNoteIds.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
            ),
          ),
          IconButton(
             icon: const Icon(Icons.checklist, color: Color(0xFF2A9D8F), size: 28), // Icono más afín a la captura de pantalla
             tooltip: 'Seleccionar todo',
             onPressed: () {
                final notesAsync = ref.read(notesProvider);
                notesAsync.whenData((notas) {
                   final filtradas = _filtrar(notas, _currentFilter);
                   setState(() {
                      if (_selectedNoteIds.length == filtradas.length) {
                         _selectedNoteIds.clear(); // Deseleccionar
                      } else {
                         _selectedNoteIds.addAll(filtradas.map((n) => n.id!));
                      }
                   });
                });
             },
          )
        ],
      ),
    );
  }

  Widget _buildBottomSelectionBar() {
    final notasAsync = ref.read(notesProvider);
    bool todasAncladas = true;

    if (notasAsync.hasValue) {
      final notas = notasAsync.value!;
      for (int id in _selectedNoteIds) {
        final notaOpt = notas.where((n) => n.id == id);
        if (notaOpt.isNotEmpty && !notaOpt.first.esAnclada) {
          todasAncladas = false;
          break;
        }
      }
    } else {
      todasAncladas = false;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomActionItem(Icons.lock_outline, 'Ocultar', () {}),
          _bottomActionItem(todasAncladas ? Icons.push_pin : Icons.push_pin_outlined, todasAncladas ? 'Desanclar' : 'Anclar', () async {
            if (_selectedNoteIds.isEmpty) return;
            final nuevoEstadoAnclado = !todasAncladas;
            try {
              // Se hace request al backend para anclarlas
              await ref.read(notesProvider.notifier).anclarNotasMasivo(_selectedNoteIds.toList(), nuevoEstadoAnclado);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(nuevoEstadoAnclado ? 'Notas ancladas' : 'Notas desancladas')));
                ref.read(selectionModeProvider.notifier).toggle(false);
                setState(() => _selectedNoteIds.clear());
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }),
          _bottomActionItem(Icons.folder_open_outlined, 'Mover a', () {}),
          _bottomActionItem(Icons.delete_outline, 'Eliminar', () {}),
        ],
      ),
    );
  }

  Widget _bottomActionItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF2D3142), size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF2D3142))),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  LISTA
  // ══════════════════════════════════════════════════
  Widget _buildNotasList(List<Nota> notas, EstadoNoteType estado) {
    if (notas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: _buildEmptyState(estado),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      itemCount: notas.length,
      itemBuilder: (context, index) {
        final nota = notas[index];
        final isSelectionMode = ref.watch(selectionModeProvider);
        return Padding(
          padding: EdgeInsets.only(bottom: (index == notas.length - 1 && isSelectionMode) ? 80 : 12),
          child: _buildSwipeableCard(nota, estado),
        );
      },
    );
  }

  Widget _buildEmptyState(EstadoNoteType estado) {
    IconData icono;
    String mensaje;
    switch (estado) {
      case EstadoNoteType.ACTIVA: icono = Icons.note_alt_outlined; mensaje = 'No tienes notas activas'; break;
      case EstadoNoteType.ARCHIVADA: icono = Icons.archive_outlined; mensaje = 'No hay notas archivadas'; break;
      case EstadoNoteType.ELIMINADA: icono = Icons.delete_outline; mensaje = 'La papelera está vacía'; break;
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 56, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 14),
          Text(mensaje, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  SWIPE
  // ══════════════════════════════════════════════════
  Widget _buildSwipeableCard(Nota nota, EstadoNoteType estado) {
    if (estado == EstadoNoteType.ACTIVA) {
      return Dismissible(
        key: Key('nota_${nota.id}'),
        background: _swipeBg(Colors.orange, Icons.archive, 'Archivar', true),
        secondaryBackground: _swipeBg(Colors.redAccent, Icons.delete, 'Papelera', false),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            _cambiarEstado(nota, 'ARCHIVADA', '"${nota.titulo}" archivada 📦');
          } else {
            _cambiarEstado(nota, 'ELIMINADA', '"${nota.titulo}" movida a papelera 🗑️');
          }
          return false;
        },
        child: _buildNoteCard(nota, estado),
      );
    } else if (estado == EstadoNoteType.ARCHIVADA) {
      return Dismissible(
        key: Key('nota_${nota.id}'),
        background: _swipeBg(Colors.green, Icons.restore, 'Restaurar', true),
        secondaryBackground: _swipeBg(Colors.redAccent, Icons.delete, 'Papelera', false),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            _cambiarEstado(nota, 'ACTIVA', '"${nota.titulo}" restaurada ✅');
          } else {
            _cambiarEstado(nota, 'ELIMINADA', '"${nota.titulo}" movida a papelera 🗑️');
          }
          return false;
        },
        child: _buildNoteCard(nota, estado),
      );
    } else {
      return Dismissible(
        key: Key('nota_${nota.id}'),
        background: _swipeBg(Colors.green, Icons.restore, 'Restaurar', true),
        secondaryBackground: _swipeBg(Colors.red, Icons.delete_forever, 'Eliminar', false),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            _cambiarEstado(nota, 'ACTIVA', '"${nota.titulo}" restaurada ✅');
          } else {
            _eliminarPermanente(nota);
          }
          return false;
        },
        child: _buildNoteCard(nota, estado),
      );
    }
  }

  Widget _swipeBg(Color color, IconData icon, String label, bool isLeft) {
    return Container(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeft
            ? [Icon(icon, color: color, size: 22), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold))]
            : [Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)), const SizedBox(width: 6), Icon(icon, color: color, size: 22)],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  NOTE CARD (MISMO ESTILO DEL DASHBOARD)
  Widget _buildNoteCard(Nota nota, EstadoNoteType estado) {
    final esPapelera = estado == EstadoNoteType.ELIMINADA;
    final isSelected = _selectedNoteIds.contains(nota.id);

    return GestureDetector(
      onLongPress: () {
        if (!esPapelera) {
          ref.read(selectionModeProvider.notifier).toggle(true);
          setState(() {
            if (isSelected) {
               _selectedNoteIds.remove(nota.id);
               if (_selectedNoteIds.isEmpty) ref.read(selectionModeProvider.notifier).toggle(false);
            } else {
               _selectedNoteIds.add(nota.id!);
            }
          });
        }
      },
      onTap: () {
        if (ref.read(selectionModeProvider)) {
          setState(() {
            if (isSelected) {
              _selectedNoteIds.remove(nota.id);
              if (_selectedNoteIds.isEmpty) ref.read(selectionModeProvider.notifier).toggle(false);
            } else {
              _selectedNoteIds.add(nota.id!);
            }
          });
        } else if (!esPapelera) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditNoteScreen(notaToEdit: nota)));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF2A9D8F) : Colors.grey.withOpacity(0.1), width: isSelected ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título + menú alineado al top con un container transparente para quitar el padding por defecto del IconButton interno del PopupMenu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      nota.titulo,
                      maxLines: 1, // Limitar a una línea
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: esPapelera ? Colors.grey : const Color(0xFF2D3142),
                        decoration: esPapelera ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 24,
                  width: 24,
                  child: ref.watch(selectionModeProvider)
                      ? Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? const Color(0xFFE8B237) : Colors.transparent, border: Border.all(color: isSelected ? const Color(0xFFE8B237) : Colors.grey.withOpacity(0.5), width: 2)),
                          child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        )
                      : _buildPopupMenu(nota, estado),
                ),
              ],
            ),
            // Contenido
            if (nota.contenido.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                nota.contenido,
                style: TextStyle(color: esPapelera ? Colors.grey.withOpacity(0.5) : Colors.grey, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            // Badge + Fecha
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (nota.fechaCreacion != null)
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 13, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                        _formatFecha(nota.fechaCreacion!),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      if (nota.esAnclada) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.push_pin, size: 14, color: Color(0xFFE8B237)), // Chincheta dorada estilo MIUI
                      ],
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  POPUP MENU
  // ══════════════════════════════════════════════════
  Widget _buildPopupMenu(Nota nota, EstadoNoteType estado) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, color: Colors.grey.withOpacity(0.4), size: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        switch (value) {
          case 'editar': Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditNoteScreen(notaToEdit: nota))); break;
          case 'archivar': _cambiarEstado(nota, 'ARCHIVADA', '"${nota.titulo}" archivada 📦'); break;
          case 'desarchivar': _cambiarEstado(nota, 'ACTIVA', '"${nota.titulo}" restaurada ✅'); break;
          case 'papelera': _cambiarEstado(nota, 'ELIMINADA', '"${nota.titulo}" → papelera 🗑️'); break;
          case 'restaurar': _cambiarEstado(nota, 'ACTIVA', '"${nota.titulo}" restaurada ✅'); break;
          case 'eliminar': _eliminarPermanente(nota); break;
        }
      },
      itemBuilder: (context) {
        switch (estado) {
          case EstadoNoteType.ACTIVA: return [
            _menuItem('editar', Icons.edit_outlined, 'Editar', const Color(0xFF2A9D8F)),
            _menuItem('archivar', Icons.archive_outlined, 'Archivar', Colors.orange),
            _menuItem('papelera', Icons.delete_outline, 'Mover a papelera', Colors.redAccent),
          ];
          case EstadoNoteType.ARCHIVADA: return [
            _menuItem('editar', Icons.edit_outlined, 'Editar', const Color(0xFF2A9D8F)),
            _menuItem('desarchivar', Icons.unarchive_outlined, 'Restaurar', Colors.green),
            _menuItem('papelera', Icons.delete_outline, 'Mover a papelera', Colors.redAccent),
          ];
          case EstadoNoteType.ELIMINADA: return [
            _menuItem('restaurar', Icons.restore, 'Restaurar', Colors.green),
            _menuItem('eliminar', Icons.delete_forever, 'Eliminar permanente', Colors.red),
          ];
        }
      },
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String text, Color color) {
    return PopupMenuItem(value: value, child: Row(children: [
      Icon(icon, size: 18, color: color), const SizedBox(width: 10),
      Text(text, style: TextStyle(color: (color.value == Colors.redAccent.value || color.value == Colors.red.value) ? color : const Color(0xFF2D3142), fontSize: 14)),
    ]));
  }
}

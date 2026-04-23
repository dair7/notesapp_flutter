import 'dart:async';
import 'package:flutter/material.dart';
import 'package:notes_app/core/utils/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/notes/domain/nota_model.dart';
import 'package:notes_app/features/notes/presentation/providers/notes_provider.dart';
import 'package:notes_app/features/notes/presentation/screens/add_edit_note_screen_v2.dart';
import 'package:notes_app/core/enums/estado_note_type.dart';
import 'package:notes_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:notes_app/core/utils/note_preview.dart';

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
  bool _isGridView = false;

  // Multi-selección
  final Set<int> _selectedNoteIds = {};

  // Cambios pendientes de confirmar al backend: notaId → {nuevoEstado, timer}
  final Map<int, ({String nuevoEstado, String estadoAnterior, Timer timer})> _pendientes = {};

  @override
  void dispose() {
    // Confirmar al backend cualquier cambio pendiente antes de salir
    for (final entry in _pendientes.entries) {
      entry.value.timer.cancel();
      ref.read(notesProvider.notifier).cambiarEstado(entry.key, entry.value.nuevoEstado).ignore();
    }
    _pendientes.clear();
    _searchController.dispose();
    super.dispose();
  }

  List<Nota> _filtrar(List<Nota> notas, EstadoNoteType estado) {
    var filtradas = notas.where((n) => n.estado == estado).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtradas = filtradas.where((n) =>
        n.titulo.toLowerCase().contains(q) ||
        previewContenidoNota(n.contenido).toLowerCase().contains(q)
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
      if (mounted) AppSnackBar.exito(context, mensaje);
    } catch (e) {
      if (mounted) AppSnackBar.errorDesdeExcepcion(context, e);
    }
  }

  // UI optimista: cambio local inmediato → timer 4s → commit al backend
  // Si el usuario deshace antes del timer: 0 llamadas al backend
  void _moverConDeshacer(Nota nota, String nuevoEstado, String estadoAnterior, String mensaje) {
    if (nota.id == null) return;

    // Cancelar timer previo de esta nota si existe
    _pendientes[nota.id!]?.timer.cancel();
    _pendientes.remove(nota.id!);

    // 1. Cambio visual inmediato sin tocar el backend
    ref.read(notesProvider.notifier).cambiarEstadoLocal(nota.id!, nuevoEstado);

    // 2. Toast con "Deshacer"
    AppSnackBar.conDeshacer(context, mensaje, () {
      // Usuario deshizo → cancelar timer y revertir localmente (0 llamadas API)
      _pendientes[nota.id!]?.timer.cancel();
      _pendientes.remove(nota.id!);
      ref.read(notesProvider.notifier).cambiarEstadoLocal(nota.id!, estadoAnterior);
    });

    // 3. Timer de 4s — al expirar se confirma en el backend
    final timer = Timer(const Duration(seconds: 4), () async {
      _pendientes.remove(nota.id!);
      try {
        await ref.read(notesProvider.notifier).cambiarEstado(nota.id!, nuevoEstado);
      } catch (e) {
        // Si falla el backend, revertir la UI
        if (mounted) {
          ref.read(notesProvider.notifier).cambiarEstadoLocal(nota.id!, estadoAnterior);
          AppSnackBar.error(context, 'No se pudo guardar el cambio');
        }
      }
    });

    _pendientes[nota.id!] = (nuevoEstado: nuevoEstado, estadoAnterior: estadoAnterior, timer: timer);
  }

  void _eliminarPermanente(Nota nota) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar permanentemente', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Eliminar "${nota.titulo}" para siempre?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(notesProvider.notifier).deleteNota(nota.id);
                if (mounted) AppSnackBar.exito(context, 'Nota eliminada permanentemente');
              } catch (e) {
                if (mounted) AppSnackBar.errorDesdeExcepcion(context, e);
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
    final accentColor = ref.watch(settingsProvider).accentColor;
    final cs = Theme.of(context).colorScheme;
    final isSelectionMode = ref.watch(selectionModeProvider);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER ──────────────────────────────────
              isSelectionMode
                  ? _buildSelectionHeader(cs, accentColor)
                  : _buildHeader(cs, accentColor, notesAsync),

              // ── CHIPS DE FILTRO ──────────────────────────
              if (!isSelectionMode) _buildFilterChips(cs, accentColor),

              const SizedBox(height: 8),

              // ── LISTA O CUADRÍCULA ───────────────────────
              Expanded(
                child: notesAsync.when(
                  loading: () => Center(child: CircularProgressIndicator(color: accentColor)),
                  error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
                  data: (todasLasNotas) {
                    final filtradas = _filtrar(todasLasNotas, _currentFilter);
                    if (filtradas.isEmpty) return _buildEmptyState(cs, _currentFilter);
                    return _isGridView
                        ? _buildGrid(filtradas, cs, accentColor)
                        : _buildLista(filtradas, cs, accentColor);
                  },
                ),
              ),
            ],
          ),

          // ── BARRA SELECCIÓN ANIMADA ──────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AnimatedSlide(
              offset: isSelectionMode ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: isSelectionMode ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _buildBottomSelectionBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HEADER NORMAL
  // ══════════════════════════════════════════════════════════
  Widget _buildHeader(ColorScheme cs, Color accentColor, AsyncValue<List<Nota>> notesAsync) {
    return Padding(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 8, bottom: 4),
      child: Row(
        children: [
          // Título y contador
          if (!_isSearching)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mis Notas',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 3),
                  notesAsync.when(
                    loading: () => Text('Cargando...', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13)),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (notas) {
                      final count = notas.where((n) => n.estado == _currentFilter).length;
                      return Text(
                        '$count nota${count == 1 ? '' : 's'}',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45), fontSize: 13),
                      );
                    },
                  ),
                ],
              ),
            ),

          // Barra de búsqueda activa
          if (_isSearching)
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Buscar notas...',
                          hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(width: 4),

          // Botón cerrar búsqueda o abrir búsqueda
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: cs.onSurface.withValues(alpha: 0.5),
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),

          // Toggle lista / cuadrícula (solo visible cuando no busca)
          if (!_isSearching)
            IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                color: cs.onSurface.withValues(alpha: 0.5),
                size: 22,
              ),
              tooltip: _isGridView ? 'Vista lista' : 'Vista cuadrícula',
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HEADER MODO SELECCIÓN
  // ══════════════════════════════════════════════════════════
  Widget _buildSelectionHeader(ColorScheme cs, Color accentColor) {
    return Container(
      padding: const EdgeInsets.only(top: 48, left: 8, right: 8, bottom: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: cs.onSurface),
            onPressed: () {
              ref.read(selectionModeProvider.notifier).toggle(false);
              setState(() => _selectedNoteIds.clear());
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${_selectedNoteIds.length} seleccionado${_selectedNoteIds.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
          ),
          IconButton(
            icon: Icon(Icons.checklist_rounded, color: accentColor, size: 26),
            tooltip: 'Seleccionar todo',
            onPressed: () {
              final notesAsync = ref.read(notesProvider);
              notesAsync.whenData((notas) {
                final filtradas = _filtrar(notas, _currentFilter);
                setState(() {
                  if (_selectedNoteIds.length == filtradas.length) {
                    _selectedNoteIds.clear();
                  } else {
                    _selectedNoteIds.addAll(filtradas.map((n) => n.id!));
                  }
                });
              });
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CHIPS DE FILTRO
  // ══════════════════════════════════════════════════════════
  Widget _buildFilterChips(ColorScheme cs, Color accentColor) {
    final filtros = [
      (EstadoNoteType.ACTIVA,    'Activas'),
      (EstadoNoteType.ARCHIVADA, 'Archivadas'),
      (EstadoNoteType.ELIMINADA, 'Papelera'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        children: filtros.asMap().entries.map((entry) {
          final i = entry.key;
          final f = entry.value;
          final isActive = _currentFilter == f.$1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < filtros.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _currentFilter = f.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? accentColor : cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? accentColor : cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                    boxShadow: isActive
                        ? [BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      f.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  ESTADO VACÍO
  // ══════════════════════════════════════════════════════════
  Widget _buildEmptyState(ColorScheme cs, EstadoNoteType estado) {
    IconData icono;
    String titulo;
    String subtitulo;
    switch (estado) {
      case EstadoNoteType.ACTIVA:
        icono = Icons.note_alt_outlined;
        titulo = 'Sin notas activas';
        subtitulo = 'Toca + para crear tu primera nota';
        break;
      case EstadoNoteType.ARCHIVADA:
        icono = Icons.archive_outlined;
        titulo = 'Nada archivado';
        subtitulo = 'Las notas archivadas aparecerán aquí';
        break;
      case EstadoNoteType.ELIMINADA:
        icono = Icons.delete_outline;
        titulo = 'Papelera vacía';
        subtitulo = 'Las notas eliminadas se muestran aquí';
        break;
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(icono, size: 34, color: cs.onSurface.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 16),
          Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 4),
          Text(subtitulo, style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  VISTA LISTA
  // ══════════════════════════════════════════════════════════
  Widget _buildLista(List<Nota> notas, ColorScheme cs, Color accentColor) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 100),
      itemCount: notas.length,
      itemBuilder: (context, index) {
        final nota = notas[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildSwipeableCard(nota, _currentFilter, cs, accentColor),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  //  VISTA CUADRÍCULA
  // ══════════════════════════════════════════════════════════
  Widget _buildGrid(List<Nota> notas, ColorScheme cs, Color accentColor) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: notas.length,
      itemBuilder: (context, index) {
        final nota = notas[index];
        return _buildGridCard(nota, _currentFilter, cs, accentColor);
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SWIPE WRAPPER (solo para lista)
  // ══════════════════════════════════════════════════════════
  Widget _buildSwipeableCard(Nota nota, EstadoNoteType estado, ColorScheme cs, Color accentColor) {
    if (estado == EstadoNoteType.ACTIVA) {
      return Dismissible(
        key: Key('nota_${nota.id}'),
        background: _swipeBg(Colors.orange, Icons.archive, 'Archivar', true),
        secondaryBackground: _swipeBg(Colors.redAccent, Icons.delete, 'Papelera', false),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            _moverConDeshacer(nota, 'ARCHIVADA', 'ACTIVA', '"${nota.titulo}" archivada');
          } else {
            _moverConDeshacer(nota, 'ELIMINADA', 'ACTIVA', '"${nota.titulo}" movida a papelera');
          }
          return false;
        },
        child: _buildNoteCard(nota, estado, cs, accentColor),
      );
    } else if (estado == EstadoNoteType.ARCHIVADA) {
      return Dismissible(
        key: Key('nota_${nota.id}'),
        background: _swipeBg(Colors.green, Icons.restore, 'Restaurar', true),
        secondaryBackground: _swipeBg(Colors.redAccent, Icons.delete, 'Papelera', false),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            _moverConDeshacer(nota, 'ACTIVA', 'ARCHIVADA', '"${nota.titulo}" restaurada');
          } else {
            _moverConDeshacer(nota, 'ELIMINADA', 'ARCHIVADA', '"${nota.titulo}" movida a papelera');
          }
          return false;
        },
        child: _buildNoteCard(nota, estado, cs, accentColor),
      );
    } else {
      return Dismissible(
        key: Key('nota_${nota.id}'),
        background: _swipeBg(Colors.green, Icons.restore, 'Restaurar', true),
        secondaryBackground: _swipeBg(Colors.red, Icons.delete_forever, 'Eliminar', false),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            _moverConDeshacer(nota, 'ACTIVA', 'ELIMINADA', '"${nota.titulo}" restaurada');
          } else {
            _eliminarPermanente(nota);
          }
          return false;
        },
        child: _buildNoteCard(nota, estado, cs, accentColor),
      );
    }
  }

  Widget _swipeBg(Color color, IconData icon, String label, bool isLeft) {
    return Container(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeft
            ? [Icon(icon, color: color, size: 20), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))]
            : [Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(width: 6), Icon(icon, color: color, size: 20)],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TARJETA — LISTA
  // ══════════════════════════════════════════════════════════
  Widget _buildNoteCard(Nota nota, EstadoNoteType estado, ColorScheme cs, Color accentColor) {
    final esPapelera = estado == EstadoNoteType.ELIMINADA;
    final isSelected = _selectedNoteIds.contains(nota.id);
    final isSelectionMode = ref.watch(selectionModeProvider);

    return GestureDetector(
      onLongPress: () {
        if (!esPapelera) {
          ref.read(selectionModeProvider.notifier).toggle(true);
          setState(() => _selectedNoteIds.add(nota.id!));
        }
      },
      onTap: () {
        if (isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedNoteIds.remove(nota.id);
              if (_selectedNoteIds.isEmpty) ref.read(selectionModeProvider.notifier).toggle(false);
            } else {
              _selectedNoteIds.add(nota.id!);
            }
          });
        } else if (!esPapelera) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditNoteScreenV2(notaToEdit: nota)));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.1)
              : esPapelera
                  ? cs.surfaceContainerLowest.withValues(alpha: 0.6)
                  : nota.color != null
                      ? Color(int.parse(nota.color!.replaceFirst('#', 'FF'), radix: 16))
                      : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : cs.outlineVariant.withValues(alpha: 0.25),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    nota.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: esPapelera ? cs.onSurface.withValues(alpha: 0.35) : cs.onSurface,
                      decoration: esPapelera ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  // Contenido
                  if (nota.contenido.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      previewContenidoNota(nota.contenido),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: esPapelera ? 0.25 : 0.5),
                      ),
                    ),
                  ],
                  // Etiquetas
                  if (nota.etiquetas.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: nota.etiquetas.take(3).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Fecha + anclar
                  Row(
                    children: [
                      if (nota.fechaCreacion != null) ...[
                        Icon(Icons.access_time_rounded, size: 12, color: cs.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(width: 4),
                        Text(
                          _formatFecha(nota.fechaCreacion!),
                          style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.38)),
                        ),
                      ],
                      if (nota.esAnclada) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.push_pin_rounded, size: 13, color: accentColor.withValues(alpha: 0.7)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Checkbox selección o popup menú
            const SizedBox(width: 8),
            SizedBox(
              width: 24,
              height: 24,
              child: isSelectionMode
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedNoteIds.remove(nota.id);
                            if (_selectedNoteIds.isEmpty) ref.read(selectionModeProvider.notifier).toggle(false);
                          } else {
                            _selectedNoteIds.add(nota.id!);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? accentColor : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? accentColor : cs.onSurface.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                            : null,
                      ),
                    )
                  : _buildPopupMenu(nota, estado, cs),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TARJETA — CUADRÍCULA
  // ══════════════════════════════════════════════════════════
  Widget _buildGridCard(Nota nota, EstadoNoteType estado, ColorScheme cs, Color accentColor) {
    final esPapelera = estado == EstadoNoteType.ELIMINADA;
    final isSelected = _selectedNoteIds.contains(nota.id);
    final isSelectionMode = ref.watch(selectionModeProvider);

    return GestureDetector(
      onLongPress: () {
        if (!esPapelera) {
          ref.read(selectionModeProvider.notifier).toggle(true);
          setState(() => _selectedNoteIds.add(nota.id!));
        }
      },
      onTap: () {
        if (isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedNoteIds.remove(nota.id);
              if (_selectedNoteIds.isEmpty) ref.read(selectionModeProvider.notifier).toggle(false);
            } else {
              _selectedNoteIds.add(nota.id!);
            }
          });
        } else if (!esPapelera) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditNoteScreenV2(notaToEdit: nota)));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.1)
              : esPapelera
                  ? cs.surfaceContainerLowest.withValues(alpha: 0.6)
                  : nota.color != null
                      ? Color(int.parse(nota.color!.replaceFirst('#', 'FF'), radix: 16))
                      : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : cs.outlineVariant.withValues(alpha: 0.25),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila: título + checkbox/pin
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    nota.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: esPapelera ? cs.onSurface.withValues(alpha: 0.35) : cs.onSurface,
                      decoration: esPapelera ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isSelectionMode)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? accentColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? accentColor : cs.onSurface.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                        : null,
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (nota.esAnclada)
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(Icons.push_pin_rounded, size: 13, color: accentColor.withValues(alpha: 0.7)),
                        ),
                      _buildPopupMenu(nota, estado, cs),
                    ],
                  ),
              ],
            ),
            // Contenido
            if (nota.contenido.isNotEmpty) ...[
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  previewContenidoNota(nota.contenido),
                  maxLines: 4,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: esPapelera ? 0.25 : 0.5),
                  ),
                ),
              ),
            ] else
              const Spacer(),
            // Etiquetas en cuadrícula
            if (nota.etiquetas.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: nota.etiquetas.take(2).map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                )).toList(),
              ),
            ],
            // Fecha
            if (nota.fechaCreacion != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 11, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(width: 3),
                  Text(
                    _formatFecha(nota.fechaCreacion!),
                    style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.38)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  POPUP MENÚ
  // ══════════════════════════════════════════════════════════
  Widget _buildPopupMenu(Nota nota, EstadoNoteType estado, ColorScheme cs) {
    return GestureDetector(
      onTap: () => _mostrarAccionesSheet(nota, estado, cs),
      child: Icon(Icons.more_vert_rounded, color: cs.onSurface.withValues(alpha: 0.35), size: 20),
    );
  }

  void _mostrarAccionesSheet(Nota nota, EstadoNoteType estado, ColorScheme cs) {
    final accentColor = ref.read(settingsProvider).accentColor;

    // Acciones según el estado de la nota
    final acciones = <_SheetAccion>[];
    if (estado == EstadoNoteType.ACTIVA) {
      acciones.addAll([
        _SheetAccion(Icons.edit_rounded,          'Editar',             accentColor,       () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditNoteScreenV2(notaToEdit: nota)))),
        _SheetAccion(Icons.push_pin_outlined,     nota.esAnclada ? 'Desanclar' : 'Anclar', accentColor, () => _cambiarEstado(nota, nota.esAnclada ? 'ACTIVA' : 'ACTIVA', nota.esAnclada ? '"${nota.titulo}" desanclada' : '"${nota.titulo}" anclada')),
        _SheetAccion(Icons.archive_outlined,      'Archivar',           Colors.orange,     () => _cambiarEstado(nota, 'ARCHIVADA', '"${nota.titulo}" archivada')),
        _SheetAccion(Icons.delete_outline_rounded,'Mover a papelera',   Colors.redAccent,  () => _cambiarEstado(nota, 'ELIMINADA', '"${nota.titulo}" movida a papelera'), isDestructive: true),
      ]);
    } else if (estado == EstadoNoteType.ARCHIVADA) {
      acciones.addAll([
        _SheetAccion(Icons.edit_rounded,          'Editar',             accentColor,       () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditNoteScreenV2(notaToEdit: nota)))),
        _SheetAccion(Icons.unarchive_outlined,    'Restaurar',          Colors.green,      () => _cambiarEstado(nota, 'ACTIVA', '"${nota.titulo}" restaurada')),
        _SheetAccion(Icons.delete_outline_rounded,'Mover a papelera',   Colors.redAccent,  () => _cambiarEstado(nota, 'ELIMINADA', '"${nota.titulo}" movida a papelera'), isDestructive: true),
      ]);
    } else {
      acciones.addAll([
        _SheetAccion(Icons.restore_rounded,       'Restaurar',          Colors.green,      () => _cambiarEstado(nota, 'ACTIVA', '"${nota.titulo}" restaurada')),
        _SheetAccion(Icons.delete_forever_rounded,'Eliminar permanentemente', Colors.red,  () => _eliminarPermanente(nota), isDestructive: true),
      ]);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Info de la nota
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.note_rounded, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nota.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
                          ),
                          if (nota.contenido.isNotEmpty)
                            Text(
                              nota.contenido,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.45)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Divider(color: cs.outlineVariant.withValues(alpha: 0.25), height: 1, indent: 24, endIndent: 24),
              const SizedBox(height: 8),

              // Acciones
              ...acciones.map((a) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () { Navigator.pop(sheetCtx); a.onTap(); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                    child: Row(
                      children: [
                        Icon(a.icon, size: 20, color: a.isDestructive ? Colors.redAccent : cs.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 16),
                        Text(
                          a.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: a.isDestructive ? Colors.redAccent : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BARRA INFERIOR SELECCIÓN
  // ══════════════════════════════════════════════════════════
  Widget _buildBottomSelectionBar() {
    final accentColor = ref.watch(settingsProvider).accentColor;
    final cs = Theme.of(context).colorScheme;
    final notasAsync = ref.read(notesProvider);
    bool todasAncladas = true;

    if (notasAsync.hasValue) {
      for (int id in _selectedNoteIds) {
        final notaOpt = notasAsync.value!.where((n) => n.id == id);
        if (notaOpt.isNotEmpty && !notaOpt.first.esAnclada) {
          todasAncladas = false;
          break;
        }
      }
    } else {
      todasAncladas = false;
    }

    return Container(
      padding: EdgeInsets.only(
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _selectionIcon(
            icon: todasAncladas ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            tooltip: todasAncladas ? 'Desanclar' : 'Anclar',
            color: accentColor,
            cs: cs,
            onTap: () async {
              if (_selectedNoteIds.isEmpty) return;
              final nuevoEstadoAnclado = !todasAncladas;
              try {
                await ref.read(notesProvider.notifier).anclarNotasMasivo(_selectedNoteIds.toList(), nuevoEstadoAnclado);
                if (mounted) {
                  AppSnackBar.exito(context, nuevoEstadoAnclado ? 'Notas ancladas' : 'Notas desancladas');
                  ref.read(selectionModeProvider.notifier).toggle(false);
                  setState(() => _selectedNoteIds.clear());
                }
              } catch (e) {
                if (mounted) AppSnackBar.errorDesdeExcepcion(context, e);
              }
            },
          ),
          _selectionIcon(
            icon: Icons.archive_outlined,
            tooltip: 'Archivar',
            color: Colors.orange,
            cs: cs,
            onTap: _archivarSeleccionadasConDeshacer,
          ),
          _selectionIcon(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Eliminar',
            color: Colors.redAccent,
            cs: cs,
            onTap: _eliminarSeleccionadas,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _selectionIcon({
    required IconData icon,
    required String tooltip,
    required Color color,
    required ColorScheme cs,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(tooltip, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  void _archivarSeleccionadasConDeshacer() {
    if (_selectedNoteIds.isEmpty) return;

    final ids = _selectedNoteIds.toList();
    final cantidad = ids.length;
    final estadoAnterior = _currentFilter.name;

    // Cancelar timers pendientes de estas notas
    for (final id in ids) {
      _pendientes[id]?.timer.cancel();
      _pendientes.remove(id);
    }

    // 1. Cambio local inmediato
    for (final id in ids) {
      ref.read(notesProvider.notifier).cambiarEstadoLocal(id, 'ARCHIVADA');
    }

    // Salir del modo selección
    ref.read(selectionModeProvider.notifier).toggle(false);
    setState(() => _selectedNoteIds.clear());

    // 2. Toast con Deshacer
    AppSnackBar.conDeshacer(
      context,
      '$cantidad nota${cantidad == 1 ? '' : 's'} archivada${cantidad == 1 ? '' : 's'}',
      () {
        for (final id in ids) {
          _pendientes[id]?.timer.cancel();
          _pendientes.remove(id);
          ref.read(notesProvider.notifier).cambiarEstadoLocal(id, estadoAnterior);
        }
      },
    );

    // 3. Timer único — al expirar confirma todo en el backend
    final timer = Timer(const Duration(seconds: 4), () async {
      for (final id in ids) {
        _pendientes.remove(id);
      }
      try {
        for (final id in ids) {
          await ref.read(notesProvider.notifier).cambiarEstado(id, 'ARCHIVADA');
        }
      } catch (e) {
        if (mounted) {
          for (final id in ids) {
            ref.read(notesProvider.notifier).cambiarEstadoLocal(id, estadoAnterior);
          }
          AppSnackBar.error(context, 'Error al archivar');
        }
      }
    });

    // Registrar en _pendientes para que dispose() los confirme si el usuario sale
    for (final id in ids) {
      _pendientes[id] = (nuevoEstado: 'ARCHIVADA', estadoAnterior: estadoAnterior, timer: timer);
    }
  }

  Future<void> _eliminarSeleccionadas() async {
    if (_selectedNoteIds.isEmpty) return;

    final esPapelera = _currentFilter == EstadoNoteType.ELIMINADA;
    final ids = _selectedNoteIds.toList();
    final cantidad = ids.length;

    // Desde papelera → eliminación permanente, sí requiere confirmación
    if (esPapelera) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Eliminar permanentemente', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('¿Eliminar $cantidad nota${cantidad == 1 ? '' : 's'} para siempre?\nEsta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
      try {
        for (final id in ids) {
          await ref.read(notesProvider.notifier).deleteNota(id);
        }
        if (mounted) {
          ref.read(selectionModeProvider.notifier).toggle(false);
          setState(() => _selectedNoteIds.clear());
          AppSnackBar.exito(context, '$cantidad nota${cantidad == 1 ? '' : 's'} eliminada${cantidad == 1 ? '' : 's'} permanentemente');
        }
      } catch (e) {
        if (mounted) AppSnackBar.errorDesdeExcepcion(context, e);
      }
      return;
    }

    // Desde activas/archivadas → optimista con Deshacer, sin diálogo
    final estadoAnterior = _currentFilter.name;

    for (final id in ids) {
      _pendientes[id]?.timer.cancel();
      _pendientes.remove(id);
      ref.read(notesProvider.notifier).cambiarEstadoLocal(id, 'ELIMINADA');
    }

    ref.read(selectionModeProvider.notifier).toggle(false);
    setState(() => _selectedNoteIds.clear());

    AppSnackBar.conDeshacer(
      context,
      '$cantidad nota${cantidad == 1 ? '' : 's'} movida${cantidad == 1 ? '' : 's'} a papelera',
      () {
        for (final id in ids) {
          _pendientes[id]?.timer.cancel();
          _pendientes.remove(id);
          ref.read(notesProvider.notifier).cambiarEstadoLocal(id, estadoAnterior);
        }
      },
    );

    final timer = Timer(const Duration(seconds: 4), () async {
      for (final id in ids) {
        _pendientes.remove(id);
      }
      try {
        for (final id in ids) {
          await ref.read(notesProvider.notifier).cambiarEstado(id, 'ELIMINADA');
        }
      } catch (e) {
        if (mounted) {
          for (final id in ids) {
            ref.read(notesProvider.notifier).cambiarEstadoLocal(id, estadoAnterior);
          }
          AppSnackBar.error(context, 'Error al mover a papelera');
        }
      }
    });

    for (final id in ids) {
      _pendientes[id] = (nuevoEstado: 'ELIMINADA', estadoAnterior: estadoAnterior, timer: timer);
    }
  }
}

class _SheetAccion {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SheetAccion(this.icon, this.label, this.color, this.onTap, {this.isDestructive = false});
}

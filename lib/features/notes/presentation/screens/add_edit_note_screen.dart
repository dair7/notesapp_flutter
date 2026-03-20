import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/notes/domain/nota_model.dart';
import 'package:notes_app/core/enums/estado_note_type.dart';
import 'package:notes_app/features/notes/presentation/providers/notes_provider.dart';

class AddEditNoteScreen extends ConsumerStatefulWidget {
  final Nota? notaToEdit;

  const AddEditNoteScreen({super.key, this.notaToEdit});

  @override
  ConsumerState<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends ConsumerState<AddEditNoteScreen> {
  late TextEditingController _tituloController;
  late TextEditingController _contenidoController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.notaToEdit?.titulo ?? '');
    _contenidoController = TextEditingController(text: widget.notaToEdit?.contenido ?? '');
  }

  Future<void> _guardarNota() async {
    final titulo = _tituloController.text.trim();
    final contenido = _contenidoController.text.trim();

    if (titulo.isEmpty && contenido.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('La nota está vacía'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final esEdicion = widget.notaToEdit != null;

      final nota = Nota(
        id: esEdicion ? widget.notaToEdit!.id : null,
        titulo: titulo.isEmpty ? 'Sin título' : titulo,
        contenido: contenido,
        fechaCreacion: esEdicion ? widget.notaToEdit!.fechaCreacion : DateTime.now(),
        estado: esEdicion ? widget.notaToEdit!.estado : EstadoNoteType.ACTIVA,
      );

      if (esEdicion) {
        await ref.read(notesProvider.notifier).updateNota(nota);
      } else {
        await ref.read(notesProvider.notifier).addNota(nota);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(esEdicion ? 'Nota actualizada ✏️' : 'Nota guardada ✅'),
            backgroundColor: const Color(0xFF2A9D8F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3142)),
        title: Text(
          widget.notaToEdit != null ? 'Editar Nota' : 'Nueva Nota',
          style: const TextStyle(color: Color(0xFF2D3142), fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _guardarNota,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2A9D8F)),
                    )
                  : const Icon(Icons.check, color: Color(0xFF2A9D8F)),
              label: const Text(
                'Guardar',
                style: TextStyle(color: Color(0xFF2A9D8F), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Column(
          children: [
            TextField(
              controller: _tituloController,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
              decoration: const InputDecoration(
                hintText: 'Título',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 28, fontWeight: FontWeight.bold),
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: _contenidoController,
                style: const TextStyle(fontSize: 16, color: Color(0xFF2D3142), height: 1.5),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Empieza a escribir...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
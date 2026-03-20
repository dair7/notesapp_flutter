import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. Importamos Riverpod

// ¡Atención! Ajusta estos imports según tus carpetas
import '../../../notes/domain/nota_model.dart';
import '../../../notes/presentation/providers/notes_provider.dart'; // 2. Importamos nuestro Provider
import '../../../reminders/domain/recordatorio_model.dart';
import '../../../reminders/presentation/providers/reminders_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// 3. Cambiamos StatefulWidget por ConsumerWidget
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _formatTime(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  // 4. El método build ahora recibe 'ref', nuestra antena para escuchar a Riverpod
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    
    // 5. Escuchamos el estado de las notas en tiempo real.
    // 'notesAsync' contendrá la lista, el estado de carga o el error.
    final notesAsync = ref.watch(notesProvider);
    final authState = ref.watch(authProvider);
    final nombre = authState.usuario?.nombre ?? 'Usuario';

    return SingleChildScrollView(
      child: Column(
        children: [
          // --- ENCABEZADO ---
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2A9D8F), Color(0xFF21867a)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¡Hola, $nombre!', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    const Text('Resumen de tu día', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
              Positioned(
                bottom: -25,
                left: 24,
                right: 24,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar notas y recordatorios...',
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40),

          // --- CONTENIDO DINÁMICO (Manejado por Riverpod) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Notas Recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                const SizedBox(height: 12),
                
                // 6. Usamos el método .when() de Riverpod. 
                // Es la forma elegante de manejar Cargando/Error/Datos.
                notesAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: Color(0xFF2A9D8F)),
                    )
                  ),
                  error: (error, stack) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
                  data: (notas) {
                    if (notas.isEmpty) {
                      return const Text('No tienes notas aún. ¡Crea una!');
                    }
                    return Column(
                      children: notas.map((nota) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildNoteCard(nota),
                      )).toList(),
                    );
                  },
                ),

                const SizedBox(height: 25),

                const Text('Próximos Recordatorios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                const SizedBox(height: 12),

                ref.watch(remindersProvider).when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: Color(0xFF2A9D8F)),
                    ),
                  ),
                  error: (error, stack) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
                  data: (recordatorios) {
                    final pendientes = recordatorios.where((r) => !r.completado).toList();
                    if (pendientes.isEmpty) {
                      return const Text('No tienes recordatorios pendientes', style: TextStyle(color: Colors.grey));
                    }
                    return Column(
                      children: pendientes.map((rec) => Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: _buildReminderCard(rec),
                      )).toList(),
                    );
                  },
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // Widget de la tarjeta de nota
  Widget _buildNoteCard(Nota nota) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nota.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3142))),
          const SizedBox(height: 6),
          Text(nota.contenido, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (nota.fechaCreacion != null)
                Text(_formatTime(nota.fechaCreacion!), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  String _tiempoRestante(DateTime fecha) {
    final diferencia = fecha.difference(DateTime.now());
    if (diferencia.isNegative) return 'Vencido';
    if (diferencia.inMinutes < 60) return 'En ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'En ${diferencia.inHours} h';
    return 'En ${diferencia.inDays} d';
  }

  Widget _buildReminderCard(Recordatorio rec) {
    final titulo = rec.notaTitulo ?? 'Sin nota';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2A9D8F).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_outlined, color: Color(0xFF2A9D8F), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142))),
                const SizedBox(height: 3),
                Text(_formatTime(rec.fecha), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2A9D8F).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _tiempoRestante(rec.fecha),
              style: const TextStyle(color: Color(0xFF2A9D8F), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
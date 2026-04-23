import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notes/domain/nota_model.dart';
import '../../../notes/presentation/providers/notes_provider.dart';
import '../../../reminders/domain/recordatorio_model.dart';
import '../../../reminders/presentation/providers/reminders_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:notes_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:notes_app/core/utils/note_preview.dart';
import 'package:notes_app/features/dashboard/presentation/screens/main_layout.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  // ── Helpers de formato ───────────────────────────────
  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fecha(DateTime d) {
    const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${d.day} ${meses[d.month - 1]}';
  }

  String _tiempoRestante(DateTime fecha) {
    final dif = fecha.difference(DateTime.now());
    if (dif.isNegative) return 'Vencido';
    if (dif.inMinutes < 60) return '${dif.inMinutes} min';
    if (dif.inHours < 24)   return '${dif.inHours} h';
    return '${dif.inDays} d';
  }

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync     = ref.watch(notesProvider);
    final remindersAsync = ref.watch(remindersProvider);
    final nombre         = ref.watch(authProvider).usuario?.nombre ?? 'Usuario';
    final inicial        = nombre.substring(0, 1).toUpperCase();
    final accentColor    = ref.watch(settingsProvider).accentColor;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── HEADER + STATS SOLAPADA ─────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Fondo verde
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 62),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft:  Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                      ),
                      child: Center(
                        child: Text(inicial,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_saludo(),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                          Text(nombre,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(_fecha(DateTime.now()),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

              // Stats card solapando el borde inferior del header
              Positioned(
                bottom: -52,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xFFE8B237).withValues(alpha: 0.8),
                      width: 1.7,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildStat(
                        label: 'Notas',
                        value: notesAsync.when(data: (n) => '${n.length}',
                            loading: () => '…', error: (_, _) => '0'),
                        color: Colors.blueAccent,
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.15)),
                      _buildStat(
                        label: 'Pendientes',
                        value: remindersAsync.when(
                            data: (r) => '${r.where((x) => !x.completado).length}',
                            loading: () => '…', error: (_, _) => '0'),
                        color: Colors.orange,
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.15)),
                      _buildStat(
                        label: 'Completados',
                        value: remindersAsync.when(
                            data: (r) => '${r.where((x) => x.completado).length}',
                            loading: () => '…', error: (_, _) => '0'),
                        color: const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 72),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 10),

                // ── NOTAS RECIENTES ─────────────────────────
                _sectionHeader(
                  label: 'Notas recientes',
                  onVerTodas: () =>
                      ref.read(selectedTabProvider.notifier).set(1),
                ),
                const SizedBox(height: 12),

                notesAsync.when(
                  loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: Color(0xFF2A9D8F)),
                      )),
                  error: (e, _) => Text('Error: $e',
                      style: const TextStyle(color: Colors.red)),
                  data: (notas) {
                    if (notas.isEmpty) {
                      return _emptyState(context,
                          icon: Icons.note_alt_outlined,
                          texto: 'Aún no tienes notas');
                    }
                    final recientes = notas.take(3).toList();
                    return Column(
                      children: recientes.map((n) =>
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildNoteCard(context, n),
                          )).toList(),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ── PRÓXIMOS RECORDATORIOS ──────────────────
                _sectionHeader(
                  label: 'Próximos recordatorios',
                  onVerTodas: () =>
                      ref.read(selectedTabProvider.notifier).set(2),
                ),
                const SizedBox(height: 12),

                remindersAsync.when(
                  loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: Color(0xFF2A9D8F)),
                      )),
                  error: (e, _) => Text('Error: $e',
                      style: const TextStyle(color: Colors.red)),
                  data: (recs) {
                    final pendientes = recs
                        .where((r) => !r.completado)
                        .toList()
                      ..sort((a, b) => a.fecha.compareTo(b.fecha));
                    if (pendientes.isEmpty) {
                      return _emptyState(context,
                          icon: Icons.alarm_outlined,
                          texto: 'Sin recordatorios pendientes');
                    }
                    final proximos = pendientes.take(3).toList();
                    return Column(
                      children: proximos.map((r) =>
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildReminderCard(context, r),
                          )).toList(),
                    );
                  },
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  WIDGETS AUXILIARES
  // ═══════════════════════════════════════════════════════

  Widget _buildStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _sectionHeader({required String label, required VoidCallback onVerTodas}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: Colors.grey, letterSpacing: 0.8)),
        GestureDetector(
          onTap: onVerTodas,
          child: const Text('Ver todas',
            style: TextStyle(fontSize: 12, color: Color(0xFF2A9D8F),
                fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, {required IconData icon, required String texto}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: cs.onSurface.withValues(alpha: 0.2), size: 36),
          const SizedBox(height: 8),
          Text(texto, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Nota nota) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Acento lateral
          Container(
            width: 4, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF4A6FA5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nota.titulo,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
                const SizedBox(height: 4),
                Text(previewContenidoNota(nota.contenido),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (nota.fechaCreacion != null)
            Text(_hora(nota.fechaCreacion!),
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, Recordatorio rec) {
    final cs         = Theme.of(context).colorScheme;
    final titulo     = rec.notaTitulo ?? 'Sin nota';
    final vencido    = rec.fecha.isBefore(DateTime.now());
    final badgeColor = vencido ? Colors.redAccent : const Color(0xFF2A9D8F);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.alarm_rounded, color: badgeColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
                const SizedBox(height: 3),
                Text('${_fecha(rec.fecha)} · ${_hora(rec.fecha)}',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_tiempoRestante(rec.fecha),
              style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:notes_app/core/utils/app_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/auth/domain/usuario_model.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:notes_app/features/auth/presentation/screens/login_screen.dart';
import 'package:notes_app/features/notes/presentation/providers/notes_provider.dart';
import 'package:notes_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:notes_app/core/enums/estado_note_type.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authState  = ref.watch(authProvider);
    final usuario    = authState.usuario;
    final settings   = ref.watch(settingsProvider);
    final cs         = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ─── CONTENIDO ────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título simple sin fondo
                Text('Ajustes',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 24),

                // ── Tarjeta de perfil ──────────────────
                _buildProfileCard(usuario, context, settings.accentColor),

                const SizedBox(height: 28),

                // ── Sección: Apariencia ────────────────
                _sectionLabel('Apariencia', context),
                const SizedBox(height: 12),
                _buildThemeTile(context, ref, settings),
                const SizedBox(height: 10),
                _buildAccentColorTile(context, ref, settings),

                const SizedBox(height: 28),

                // ── Sección: Notificaciones ────────────
                _sectionLabel('Notificaciones', context),
                const SizedBox(height: 12),
                _buildNotificacionesTile(context, ref, settings),
                const SizedBox(height: 10),
                _buildAnticipacionTile(context, ref, settings),

                const SizedBox(height: 28),

                // ── Sección: Datos ─────────────────────
                _sectionLabel('Datos', context),
                const SizedBox(height: 12),
                _buildExportarTile(context, ref),
                const SizedBox(height: 10),
                _buildVaciarPapeleraTile(context, ref),

                const SizedBox(height: 28),

                // ── Sección: Información ──────────────
                _sectionLabel('Información', context),
                const SizedBox(height: 12),
                _buildOptionTile(
                  context: context,
                  icon: Icons.info_outline,
                  iconColor: Colors.blueAccent,
                  title: 'Acerca de',
                  subtitle: 'Notas Pro v1.0.0',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Notas Pro',
                    applicationVersion: '1.0.0',
                    applicationIcon: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A9D8F),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.note_alt_rounded, color: Colors.white, size: 24),
                    ),
                    children: [
                      const Text('App de notas y recordatorios con Spring Boot + Flutter.'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Cerrar sesión ──────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _confirmarLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Cerrar sesión',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Versión al fondo ───────────────────
                Center(
                  child: Text('Notas Pro · v1.0.0',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 12)),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  TARJETA DE PERFIL
  // ═══════════════════════════════════════════════════════
  Widget _buildProfileCard(Usuario? usuario, BuildContext context, Color accentColor) {
    final inicial = (usuario?.nombre ?? 'U').substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            ),
            child: Center(
              child: Text(inicial,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 14),

          // Nombre + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usuario?.nombre ?? 'Usuario',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(usuario?.email ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  APARIENCIA — TEMA
  // ═══════════════════════════════════════════════════════
  Widget _buildThemeTile(BuildContext context, WidgetRef ref, SettingsState settings) {
    final cs = Theme.of(context).colorScheme;
    final opciones = {
      ThemeMode.system: ('Sistema',  Icons.brightness_auto),
      ThemeMode.light:  ('Claro',    Icons.light_mode_outlined),
      ThemeMode.dark:   ('Oscuro',   Icons.dark_mode_outlined),
    };
    final actual = opciones[settings.themeMode]!;

    return _buildOptionTile(
      context: context,
      icon: actual.$2,
      iconColor: const Color(0xFF7B5EA7),
      title: 'Tema',
      subtitle: actual.$1,
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: cs.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetCtx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tema de la aplicación',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 20),
              // ignore: deprecated_member_use
              ...opciones.entries.map((e) => RadioListTile<ThemeMode>(
                value: e.key,
                // ignore: deprecated_member_use
                groupValue: settings.themeMode,
                activeColor: const Color(0xFF2A9D8F),
                title: Row(children: [
                  Icon(e.value.$2, size: 20, color: cs.onSurface),
                  const SizedBox(width: 12),
                  Text(e.value.$1, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
                ]),
                // ignore: deprecated_member_use
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setThemeMode(v!);
                  Navigator.pop(sheetCtx);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  APARIENCIA — COLOR DE ACENTO
  // ═══════════════════════════════════════════════════════
  Widget _buildAccentColorTile(BuildContext context, WidgetRef ref, SettingsState settings) {
    final cs = Theme.of(context).colorScheme;
    return _buildOptionTile(
      context: context,
      icon: Icons.palette_outlined,
      iconColor: settings.accentColor,
      title: 'Color de acento',
      subtitle: 'Personaliza el color principal',
      trailing: Container(
        width: 22, height: 22,
        decoration: BoxDecoration(color: settings.accentColor, shape: BoxShape.circle),
      ),
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: cs.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetCtx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Color de acento',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 8),
              Text('Afecta botones, iconos y elementos activos',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: coloresAcento.map((color) {
                  final seleccionado = settings.accentColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      final notifier = ref.read(settingsProvider.notifier);
                      Navigator.pop(sheetCtx);
                      notifier.setAccentColor(color);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: seleccionado
                          ? Border.all(color: color, width: 3)
                          : Border.all(color: Colors.transparent, width: 3),
                        boxShadow: seleccionado
                          ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4))]
                          : [],
                      ),
                      child: seleccionado
                        ? const Icon(Icons.check, color: Colors.white, size: 22)
                        : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  NOTIFICACIONES — TOGGLE
  // ═══════════════════════════════════════════════════════
  Widget _buildNotificacionesTile(BuildContext context, WidgetRef ref, SettingsState settings) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_outlined, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text('Avisos de recordatorios', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: settings.notificacionesEnabled,
            activeThumbColor: const Color(0xFF2A9D8F),
            onChanged: (v) => ref.read(settingsProvider.notifier).setNotificaciones(v),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  NOTIFICACIONES — ANTICIPACIÓN
  // ═══════════════════════════════════════════════════════
  Widget _buildAnticipacionTile(BuildContext context, WidgetRef ref, SettingsState settings) {
    final cs = Theme.of(context).colorScheme;
    String etiqueta(int min) {
      if (min < 60) return '$min min antes';
      return '${min ~/ 60} h antes';
    }

    return _buildOptionTile(
      context: context,
      icon: Icons.schedule,
      iconColor: Colors.orange,
      title: 'Anticipación',
      subtitle: settings.notificacionesEnabled
        ? 'Avisar ${etiqueta(settings.anticipacionMinutos)}'
        : 'Notificaciones desactivadas',
      onTap: settings.notificacionesEnabled
        ? () => showModalBottomSheet(
          context: context,
          backgroundColor: cs.surfaceContainerLowest,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (sheetCtx) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Anticipación del aviso',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 20),
                // ignore: deprecated_member_use
                ...[15, 30, 60].map((min) => RadioListTile<int>(
                  value: min,
                  // ignore: deprecated_member_use
                  groupValue: settings.anticipacionMinutos,
                  activeColor: const Color(0xFF2A9D8F),
                  title: Text(etiqueta(min), style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
                  // ignore: deprecated_member_use
                  onChanged: (v) {
                    ref.read(settingsProvider.notifier).setAnticipacion(v!);
                    Navigator.pop(sheetCtx);
                  },
                )),
              ],
            ),
          ),
        )
        : null,
    );
  }

  // ═══════════════════════════════════════════════════════
  //  DATOS — EXPORTAR NOTAS
  // ═══════════════════════════════════════════════════════
  Widget _buildExportarTile(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return _buildOptionTile(
      context: context,
      icon: Icons.download_outlined,
      iconColor: const Color(0xFF4A6FA5),
      title: 'Exportar notas',
      subtitle: 'Copia tus notas como texto',
      onTap: () {
        final notesAsync = ref.read(notesProvider);
        notesAsync.whenData((notas) {
          if (notas.isEmpty) {
            AppSnackBar.error(context, 'No tienes notas para exportar');
            return;
          }

          // Generar texto exportado
          final buffer = StringBuffer();
          buffer.writeln('═══════════════════════════════');
          buffer.writeln('   NOTAS PRO — Exportación');
          buffer.writeln('═══════════════════════════════\n');

          final activas    = notas.where((n) => n.estado == EstadoNoteType.ACTIVA).toList();
          final archivadas = notas.where((n) => n.estado == EstadoNoteType.ARCHIVADA).toList();

          if (activas.isNotEmpty) {
            buffer.writeln('📝 NOTAS ACTIVAS (${activas.length})');
            buffer.writeln('───────────────────────────────');
            for (final nota in activas) {
              buffer.writeln('• ${nota.titulo}');
              if (nota.contenido.isNotEmpty) buffer.writeln('  ${nota.contenido}');
              buffer.writeln();
            }
          }
          if (archivadas.isNotEmpty) {
            buffer.writeln('📦 ARCHIVADAS (${archivadas.length})');
            buffer.writeln('───────────────────────────────');
            for (final nota in archivadas) {
              buffer.writeln('• ${nota.titulo}');
              if (nota.contenido.isNotEmpty) buffer.writeln('  ${nota.contenido}');
              buffer.writeln();
            }
          }

          final texto = buffer.toString();

          showModalBottomSheet(
            context: context,
            backgroundColor: cs.surfaceContainerLowest,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (_, scrollController) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${activas.length + archivadas.length} notas exportadas',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: texto));
                            Navigator.pop(context);
                            AppSnackBar.exito(context, 'Copiado al portapapeles');
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copiar'),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF2A9D8F)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Text(texto, style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  //  DATOS — VACIAR PAPELERA
  // ═══════════════════════════════════════════════════════
  Widget _buildVaciarPapeleraTile(BuildContext context, WidgetRef ref) {
    return _buildOptionTile(
      context: context,
      icon: Icons.delete_sweep_outlined,
      iconColor: Colors.redAccent,
      title: 'Vaciar papelera',
      subtitle: 'Elimina permanentemente las notas borradas',
      onTap: () {
        final notesAsync = ref.read(notesProvider);
        notesAsync.whenData((notas) {
          final enPapelera = notas.where((n) => n.estado == EstadoNoteType.ELIMINADA).toList();
          if (enPapelera.isEmpty) {
            AppSnackBar.exito(context, 'La papelera ya está vacía');
            return;
          }

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Vaciar papelera',
                style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text(
                '¿Eliminar ${enPapelera.length} nota${enPapelera.length == 1 ? '' : 's'} permanentemente?\nEsta acción no se puede deshacer.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    int eliminadas = 0;
                    for (final nota in enPapelera) {
                      try {
                        await ref.read(notesProvider.notifier).deleteNota(nota.id);
                        eliminadas++;
                      } catch (_) {}
                    }
                    if (context.mounted) {
                      AppSnackBar.exito(context, '$eliminadas nota${eliminadas == 1 ? '' : 's'} eliminada${eliminadas == 1 ? '' : 's'} permanentemente');
                    }
                  },
                  child: const Text('Vaciar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  //  WIDGETS AUXILIARES
  // ═══════════════════════════════════════════════════════
  Widget _sectionLabel(String label, BuildContext context) {
    return Text(label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        letterSpacing: 0.8,
      ));
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  LOGOUT
  // ═══════════════════════════════════════════════════════
  void _confirmarLogout() {
    // Guardamos el notifier aquí, en el State, donde ref siempre es válido.
    final authNotifier = ref.read(authProvider.notifier);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await authNotifier.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Salir', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

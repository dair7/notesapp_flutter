import 'package:flutter/material.dart';

class AppSnackBar {
  static void exito(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, esError: false);

  static void error(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, esError: true);

  static void conDeshacer(BuildContext context, String mensaje, VoidCallback onDeshacer) {
    final overlay = Overlay.of(context);
    final accent = Theme.of(context).colorScheme.primary;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        mensaje: mensaje,
        esError: false,
        accent: accent,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
        onDeshacer: () {
          if (entry.mounted) entry.remove();
          onDeshacer();
        },
      ),
    );

    overlay.insert(entry);
  }

  static void _mostrar(BuildContext context, String mensaje, {required bool esError}) {
    final overlay = Overlay.of(context);
    final accent = Theme.of(context).colorScheme.primary;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        mensaje: mensaje,
        esError: esError,
        accent: accent,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastOverlay extends StatefulWidget {
  final String mensaje;
  final bool esError;
  final Color accent;
  final VoidCallback onDone;
  final VoidCallback? onDeshacer;

  const _ToastOverlay({
    required this.mensaje,
    required this.esError,
    required this.accent,
    required this.onDone,
    this.onDeshacer,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();

    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        await _ctrl.reverse();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.esError ? Colors.redAccent : widget.accent;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.esError
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          color: color,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.mensaje,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (widget.onDeshacer != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: widget.onDeshacer,
                          child: Text(
                            'Deshacer',
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:notes_app/core/utils/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/auth/domain/usuario_model.dart';
import 'package:notes_app/core/network/services/admin_service.dart';
import 'package:notes_app/core/enums/role_type.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';

// Provider para lista de administradores (ADMIN y SUPER_ADMIN)
final adminUsersProvider = FutureProvider<List<Usuario>>((ref) async {
  final todos = await AdminService.listarUsuarios();
  return todos.where((u) => u.role == RoleType.ADMIN || u.role == RoleType.SUPER_ADMIN).toList();
});

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {

  Color _rolColor(RoleType role) {
    switch (role) {
      case RoleType.SUPER_ADMIN: return Colors.deepPurple;
      case RoleType.ADMIN: return Colors.blueAccent;
      case RoleType.USER: return Colors.green;
    }
  }

  void _mostrarCrearAdmin() {
    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Crear Administrador', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(nombreCtrl, 'Nombre', Icons.person_outline),
            const SizedBox(height: 10),
            _buildDialogField(emailCtrl, 'Email', Icons.email_outlined),
            const SizedBox(height: 10),
            _buildDialogField(passCtrl, 'Contraseña', Icons.lock_outline, obscure: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AdminService.crearAdmin(nombreCtrl.text.trim(), emailCtrl.text.trim(), passCtrl.text.trim());
                ref.invalidate(adminUsersProvider);
                if (mounted) {
                  AppSnackBar.exito(context, 'Admin creado exitosamente');
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.error(context, e.toString().replaceAll('Exception: ', ''));
                }
              }
            },
            child: const Text('Crear', style: TextStyle(color: Color(0xFF2A9D8F), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(Usuario usuario) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar admin', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
        content: Text('¿Eliminar a "${usuario.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AdminService.eliminarUsuario(usuario.id!);
                ref.invalidate(adminUsersProvider);
                if (mounted) {
                  AppSnackBar.exito(context, '${usuario.nombre} eliminado');
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.error(context, e.toString().replaceAll('Exception: ', ''));
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
    final adminsAsync = ref.watch(adminUsersProvider);
    final authState = ref.watch(authProvider);
    final isSuperAdmin = authState.usuario?.role == RoleType.SUPER_ADMIN;

    return Column(
      children: [
        // ─── HEADER ───────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
          decoration: const BoxDecoration(
            color: Color(0xFF2A9D8F),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Administradores', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                  if (isSuperAdmin)
                    GestureDetector(
                      onTap: _mostrarCrearAdmin,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('+ Admin', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              adminsAsync.when(
                loading: () => const Text('Cargando...', style: TextStyle(color: Colors.white70, fontSize: 14)),
                error: (_, __) => const Text('Error al cargar', style: TextStyle(color: Colors.white70, fontSize: 14)),
                data: (admins) => Text(
                  '${admins.length} administrador${admins.length == 1 ? '' : 'es'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── LISTA ──────────────────────────────
        Expanded(
          child: adminsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2A9D8F))),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text('Error: $error', style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(adminUsersProvider),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A9D8F)),
                    child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            data: (admins) {
              if (admins.isEmpty) {
                return const Center(child: Text('No hay administradores'));
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminUsersProvider),
                color: const Color(0xFF2A9D8F),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  itemCount: admins.length,
                  itemBuilder: (context, index) {
                    final admin = admins[index];
                    final color = _rolColor(admin.role);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                              child: Center(
                                child: Text(admin.nombre.substring(0, 1).toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(admin.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D3142))),
                                  const SizedBox(height: 2),
                                  Text(admin.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                              child: Text(admin.role.name, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            if (isSuperAdmin && admin.role != RoleType.SUPER_ADMIN) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.6), size: 20),
                                onPressed: () => _confirmarEliminar(admin),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDialogField(TextEditingController controller, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF2A9D8F)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: const Color(0xFFF5F5F7),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

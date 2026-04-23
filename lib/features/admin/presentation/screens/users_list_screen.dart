import 'package:flutter/material.dart';
import 'package:notes_app/core/utils/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/auth/domain/usuario_model.dart';
import 'package:notes_app/core/network/services/admin_service.dart';
import 'package:notes_app/core/enums/role_type.dart';

// Provider para lista de usuarios normales (USER)
final normalUsersProvider = FutureProvider<List<Usuario>>((ref) async {
  final todos = await AdminService.listarUsuarios();
  return todos.where((u) => u.role == RoleType.USER).toList();
});

class UsersListScreen extends ConsumerStatefulWidget {
  const UsersListScreen({super.key});

  @override
  ConsumerState<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends ConsumerState<UsersListScreen> {

  void _confirmarEliminar(Usuario usuario) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar usuario', style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
        content: Text('¿Eliminar a "${usuario.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AdminService.eliminarUsuario(usuario.id!);
                ref.invalidate(normalUsersProvider);
                if (mounted) {
                  AppSnackBar.exito(context, '${usuario.nombre} eliminado');
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.errorDesdeExcepcion(context, e);
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
    final usersAsync = ref.watch(normalUsersProvider);

    return Column(
      children: [
        // ─── HEADER ───────────────────────────────────
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
              const Text('Usuarios', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              usersAsync.when(
                loading: () => const Text('Cargando...', style: TextStyle(color: Colors.white70, fontSize: 14)),
                error: (_, _) => const Text('Error al cargar', style: TextStyle(color: Colors.white70, fontSize: 14)),
                data: (users) => Text(
                  '${users.length} usuario${users.length == 1 ? '' : 's'} normal${users.length == 1 ? '' : 'es'}',
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
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2A9D8F))),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text('Error: $error', style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(normalUsersProvider),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A9D8F)),
                    child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            data: (users) {
              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      const Text('No hay usuarios normales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(normalUsersProvider),
                color: const Color(0xFF2A9D8F),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final usuario = users[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildUserCard(usuario),
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

  Widget _buildUserCard(Usuario usuario) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                usuario.nombre.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usuario.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D3142))),
                const SizedBox(height: 2),
                Text(usuario.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: const Text('USER', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.redAccent.withValues(alpha: 0.6), size: 20),
            onPressed: () => _confirmarEliminar(usuario),
          ),
        ],
      ),
    );
  }
}

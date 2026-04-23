import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:notes_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:notes_app/features/notes/presentation/screens/add_edit_note_screen_v2.dart';
import 'package:notes_app/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:notes_app/features/reminders/presentation/screens/reminders_list_screen.dart';
import 'package:notes_app/features/reminders/presentation/screens/add_reminder_screen.dart';
import 'package:notes_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:notes_app/features/admin/presentation/screens/admin_screen.dart';
import 'package:notes_app/features/admin/presentation/screens/users_list_screen.dart';
import 'package:notes_app/core/enums/role_type.dart';
import 'package:notes_app/features/notes/presentation/providers/notes_provider.dart';
import 'package:notes_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:notes_app/core/services/notification_service.dart';

// Tab actualmente seleccionado en el bottom nav del [MainLayout].
// Se expone como provider para que pantallas internas (p.ej. Dashboard
// con sus botones "Ver todas") puedan cambiar de sección sin depender
// de InheritedWidget ni callbacks.
class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, int>(() {
  return SelectedTabNotifier();
});

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  bool _navVisible = true;

  @override
  void initState() {
    super.initState();
    // Caso cold start: la app fue abierta al tocar una notificación
    // El navigator no estaba listo en ese momento, se guardó el tab aquí
    final tabPendiente = NotificationService.consumirTabPendiente();
    if (tabPendiente != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedTabProvider.notifier).set(tabPendiente);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Caso background: la app estaba en segundo plano y se tocó la notificación
    // pushNamedAndRemoveUntil pasa los argumentos en la ruta
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['tab'] is int) {
      final tab = args['tab'] as int;
      if (tab != ref.read(selectedTabProvider)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(selectedTabProvider.notifier).set(tab);
        });
      }
    }
  }

  bool _isAdmin(RoleType? role) =>
      role == RoleType.ADMIN || role == RoleType.SUPER_ADMIN;

  // ─── Pantallas para ADMIN ─────────────────────
  final List<Widget> _adminScreens = [
    const DashboardScreen(),
    const UsersListScreen(),
    const AdminScreen(),
    const SettingsScreen(),
  ];

  final List<NavigationDestination> _adminDestinations = const [
    NavigationDestination(
      icon:         Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view_rounded),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon:         Icon(Icons.group_outlined),
      selectedIcon: Icon(Icons.group_rounded),
      label: 'Usuarios',
    ),
    NavigationDestination(
      icon:         Icon(Icons.shield_outlined),
      selectedIcon: Icon(Icons.shield_rounded),
      label: 'Admins',
    ),
    NavigationDestination(
      icon:         Icon(Icons.tune_outlined),
      selectedIcon: Icon(Icons.tune_rounded),
      label: 'Ajustes',
    ),
  ];

  // ─── Pantallas para USUARIO normal ────────────
  final List<Widget> _userScreens = [
    const DashboardScreen(),
    const NotesListScreen(),
    const RemindersListScreen(),
    const SettingsScreen(),
  ];

  final List<NavigationDestination> _userDestinations = const [
    NavigationDestination(
      icon:         Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view_rounded),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon:         Icon(Icons.edit_note_outlined),
      selectedIcon: Icon(Icons.edit_note_rounded),
      label: 'Notas',
    ),
    NavigationDestination(
      icon:         Icon(Icons.task_alt),
      selectedIcon: Icon(Icons.task_alt),
      label: 'Tareas',
    ),
    NavigationDestination(
      icon:         Icon(Icons.tune_outlined),
      selectedIcon: Icon(Icons.tune_rounded),
      label: 'Ajustes',
    ),
  ];

  // ─── Detectar dirección del scroll ────────────
  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    // UserScrollNotification da la dirección del gesto del usuario de forma inmediata
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse && _navVisible) {
        // Scrolling hacia abajo → ocultar
        setState(() => _navVisible = false);
      } else if (notification.direction == ScrollDirection.forward && !_navVisible) {
        // Cualquier scroll hacia arriba → mostrar inmediatamente
        setState(() => _navVisible = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final authState    = ref.watch(authProvider);
    final isAdmin      = _isAdmin(authState.usuario?.role);
    final screens      = isAdmin ? _adminScreens    : _userScreens;
    final destinations = isAdmin ? _adminDestinations : _userDestinations;
    final inSelection  = ref.watch(selectionModeProvider);
    final accentColor  = ref.watch(settingsProvider).accentColor;

    // Index del tab actual leído desde el provider global
    int selectedIndex = ref.watch(selectedTabProvider);
    if (selectedIndex >= screens.length) selectedIndex = 0;

    // En modo selección siempre mostramos la barra de selección (la nav desaparece)
    final showNav = !inSelection;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      // extendBody permite que el contenido pase detrás de la nav bar
      extendBody: true,

      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: screens[selectedIndex],
      ),

      // FAB — solo en Notas (tab 1) y Tareas (tab 2), se oculta al hacer scroll
      floatingActionButton: (isAdmin || selectedIndex == 0 || selectedIndex == screens.length - 1 || inSelection)
          ? null
          : AnimatedSlide(
              offset: _navVisible ? Offset.zero : const Offset(0, 2.5),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: _navVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    if (selectedIndex == 2) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddReminderScreen()));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditNoteScreenV2()));
                    }
                  },
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: Text(selectedIndex == 2 ? 'Tarea' : 'Nota'),
                  elevation: 4,
                ),
              ),
            ),

      bottomNavigationBar: showNav
          ? AnimatedSlide(
              offset: _navVisible ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: Container(
                // Fondo transparente para que el margen no se vea sólido
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.80),
                      width: 1.7,
                    ),
                  ),
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      height: 72,
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        final selected = states.contains(WidgetState.selected);
                        return TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? accentColor : Colors.grey,
                        );
                      }),
                    ),
                    child: NavigationBar(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) {
                        ref.read(selectedTabProvider.notifier).set(index);
                        setState(() => _navVisible = true);
                      },
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      indicatorColor: accentColor.withValues(alpha: 0.12),
                      surfaceTintColor: Colors.transparent,
                      destinations: destinations,
                    ),
                  ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

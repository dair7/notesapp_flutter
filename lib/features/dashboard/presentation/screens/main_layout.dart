import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:notes_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:notes_app/features/notes/presentation/screens/add_edit_note_screen.dart';
import 'package:notes_app/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:notes_app/features/reminders/presentation/screens/reminders_list_screen.dart';
import 'package:notes_app/features/reminders/presentation/screens/add_reminder_screen.dart';
import 'package:notes_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:notes_app/features/admin/presentation/screens/admin_screen.dart';
import 'package:notes_app/features/admin/presentation/screens/users_list_screen.dart';
import 'package:notes_app/core/enums/role_type.dart';
import 'package:notes_app/features/notes/presentation/providers/notes_provider.dart';
import 'package:notes_app/features/settings/presentation/providers/settings_provider.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int  _selectedIndex = 0;
  bool _navVisible    = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Abre el tab indicado al navegar desde una notificación
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['tab'] is int) {
      _selectedIndex = args['tab'] as int;
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

    if (_selectedIndex >= screens.length) _selectedIndex = 0;

    // En modo selección siempre mostramos la barra de selección (la nav desaparece)
    final showNav = !inSelection;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      // extendBody permite que el contenido pase detrás de la nav bar
      extendBody: true,

      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: screens[_selectedIndex],
      ),

      // FAB
      floatingActionButton: (isAdmin || _selectedIndex == screens.length - 1 || inSelection)
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                if (_selectedIndex == 2) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddReminderScreen()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditNoteScreen()));
                }
              },
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(_selectedIndex == 2 ? 'Recordatorio' : 'Nota'),
              elevation: 4,
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
                      color: accentColor.withOpacity(0.80),
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
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          _selectedIndex = index;
                          _navVisible    = true;
                        });
                      },
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      indicatorColor: accentColor.withOpacity(0.12),
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

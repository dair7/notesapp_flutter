import 'package:flutter/material.dart';
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

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _selectedIndex = 0;

  bool _isAdmin(RoleType? role) {
    return role == RoleType.ADMIN || role == RoleType.SUPER_ADMIN;
  }

  // ─── Pantallas para ADMIN ─────────────────────
  final List<Widget> _adminScreens = [
    const DashboardScreen(),
    const UsersListScreen(),
    const AdminScreen(),
    const SettingsScreen(),
  ];

  final List<NavigationDestination> _adminDestinations = const [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Color(0xFF2A9D8F)), label: 'Dashboard'),
    NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people, color: Color(0xFF2A9D8F)), label: 'Usuarios'),
    NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings, color: Color(0xFF2A9D8F)), label: 'Admins'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: Color(0xFF2A9D8F)), label: 'Ajustes'),
  ];

  // ─── Pantallas para USUARIO normal ────────────
  final List<Widget> _userScreens = [
    const DashboardScreen(),
    const NotesListScreen(),
    const RemindersListScreen(),
    const SettingsScreen(),
  ];

  final List<NavigationDestination> _userDestinations = const [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Color(0xFF2A9D8F)), label: 'Dashboard'),
    NavigationDestination(icon: Icon(Icons.note_alt_outlined), selectedIcon: Icon(Icons.note_alt, color: Color(0xFF2A9D8F)), label: 'Notas'),
    NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications, color: Color(0xFF2A9D8F)), label: 'Avisos'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: Color(0xFF2A9D8F)), label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = _isAdmin(authState.usuario?.role);
    final screens = isAdmin ? _adminScreens : _userScreens;
    final destinations = isAdmin ? _adminDestinations : _userDestinations;

    if (_selectedIndex >= screens.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: screens[_selectedIndex],

      // FAB: solo para usuarios normales (no admin) y no en selection mode
      floatingActionButton: (isAdmin || _selectedIndex == screens.length - 1 || ref.watch(selectionModeProvider))
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                if (_selectedIndex == 2) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddReminderScreen()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditNoteScreen()));
                }
              },
              backgroundColor: const Color(0xFF2A9D8F),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(_selectedIndex == 2 ? 'Recordatorio' : 'Nota'),
              elevation: 4,
            ),

      bottomNavigationBar: ref.watch(selectionModeProvider)
          ? const SizedBox.shrink()
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              backgroundColor: Colors.white,
              elevation: 10,
              indicatorColor: const Color(0xFF2A9D8F).withOpacity(0.2),
              destinations: destinations,
            ),
    );
  }
}
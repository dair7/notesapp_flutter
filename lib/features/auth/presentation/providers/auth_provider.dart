import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/auth/domain/usuario_model.dart';
import 'package:notes_app/core/network/services/auth_service.dart';
import 'package:notes_app/core/network/api_client.dart';
import 'package:notes_app/features/notes/presentation/providers/notes_provider.dart';
import 'package:notes_app/features/reminders/presentation/providers/reminders_provider.dart';

// Estado de autenticación
class AuthState {
  final Usuario? usuario;
  final bool isLoading;
  final String? error;

  const AuthState({this.usuario, this.isLoading = false, this.error});

  bool get isAuthenticated => usuario != null;

  AuthState copyWith({Usuario? usuario, bool? isLoading, String? error}) {
    return AuthState(
      usuario: usuario ?? this.usuario,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  // Verificar si hay una sesión activa guardada
  Future<void> checkAuthStatus() async {
    final token = await ApiClient.getToken();
    final userId = await ApiClient.getUserId();

    if (token == null || userId == null) {
      await logout();
      return;
    }

    try {
      // Intentamos obtener el perfil del usuario usando su ID guardado
      final response = await ApiClient.get('/api/usuarios/$userId');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final usuario = Usuario.fromJson(data);
        state = AuthState(usuario: usuario);
      } else {
        // Token inválido o expirado
        await logout();
      }
    } catch (e) {
      await logout();
    }
  }

  // Login real contra el backend
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    if (email.isEmpty || password.isEmpty) {
      state = const AuthState(error: 'Email y contraseña son obligatorios');
      return false;
    }

    try {
      final data = await AuthService.login(email, password);
      final usuario = Usuario.fromJson(data['usuario']);
      state = AuthState(usuario: usuario);

      // Invalidar providers de notas y recordatorios para cargar datos del nuevo usuario
      ref.invalidate(notesProvider);
      ref.invalidate(remindersProvider);

      return true;
    } catch (e) {
      state = AuthState(error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  // Registro real contra el backend
  Future<bool> register(String nombre, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
      state = const AuthState(error: 'Todos los campos son obligatorios');
      return false;
    }

    if (password.length < 6) {
      state = const AuthState(
        error: 'La contraseña debe tener al menos 6 caracteres',
      );
      return false;
    }

    try {
      await AuthService.register(nombre, email, password);
      state = const AuthState(
        error:
            'Te hemos enviado un correo. Por favor confírmalo para iniciar sesión',
      );
      return true;
    } catch (e) {
      state = AuthState(error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    // Invalidar refresh token en backend + limpiar sesión local
    await AuthService.logout();

    // Invalidar los providers de datos para que no queden datos del usuario anterior
    ref.invalidate(notesProvider);
    ref.invalidate(remindersProvider);

    // Limpiar el estado de autenticación
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

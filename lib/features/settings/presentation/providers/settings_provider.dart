import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Claves de SharedPreferences ──────────────────────────
const _kThemeMode        = 'theme_mode';
const _kAccentColor      = 'accent_color';
const _kNotificaciones   = 'notificaciones_enabled';
const _kAnticipacion     = 'anticipacion_minutos';

// ── Colores de acento disponibles ────────────────────────
const List<Color> coloresAcento = [
  Color(0xFF2A9D8F), // Teal (por defecto)
  Color(0xFF4A6FA5), // Azul
  Color(0xFF7B5EA7), // Violeta
  Color(0xFFB8860B), // Mostaza
  Color(0xFFE05C5C), // Rojo
  Color(0xFF4CAF50), // Verde
];

class SettingsState {
  final ThemeMode themeMode;
  final Color accentColor;
  final bool notificacionesEnabled;
  final int anticipacionMinutos; // 15, 30 ó 60

  const SettingsState({
    this.themeMode           = ThemeMode.system,
    this.accentColor         = const Color(0xFF2A9D8F),
    this.notificacionesEnabled = true,
    this.anticipacionMinutos = 30,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Color?     accentColor,
    bool?      notificacionesEnabled,
    int?       anticipacionMinutos,
  }) {
    return SettingsState(
      themeMode:              themeMode            ?? this.themeMode,
      accentColor:            accentColor          ?? this.accentColor,
      notificacionesEnabled:  notificacionesEnabled ?? this.notificacionesEnabled,
      anticipacionMinutos:    anticipacionMinutos  ?? this.anticipacionMinutos,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // Carga asíncrona al inicializar
    _cargar();
    return const SettingsState();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      themeMode:              ThemeMode.values[prefs.getInt(_kThemeMode) ?? 0],
      accentColor:            Color(prefs.getInt(_kAccentColor) ?? 0xFF2A9D8F),
      notificacionesEnabled:  prefs.getBool(_kNotificaciones) ?? true,
      anticipacionMinutos:    prefs.getInt(_kAnticipacion) ?? 30,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, mode.index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setAccentColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentColor, color.toARGB32());
    state = state.copyWith(accentColor: color);
  }

  Future<void> setNotificaciones(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificaciones, enabled);
    state = state.copyWith(notificacionesEnabled: enabled);
  }

  Future<void> setAnticipacion(int minutos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAnticipacion, minutos);
    state = state.copyWith(anticipacionMinutos: minutos);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;

  // Clave global de navegación para abrir la app al tocar la notificación
  static GlobalKey<NavigatorState>? navigatorKey;

  // Offsets para evitar colisión de IDs entre tipos de notificación
  static const int _offsetAnticipada = 1000000;
  static const int _offsetVencida    = 2000000;

  /// Inicializa el plugin — llamar una vez en main()
  static Future<void> inicializar({
    required GlobalKey<NavigatorState> navKey,
  }) async {
    if (_inicializado) return;

    navigatorKey = navKey;
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _alTocarNotificacion,
    );

    // Solicitar permiso en Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Solicitar permiso para alarmas exactas
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _inicializado = true;
  }

  /// Al tocar la notificación navega a la pantalla de recordatorios
  static void _alTocarNotificacion(NotificationResponse response) {
    navigatorKey?.currentState?.pushNamedAndRemoveUntil(
      '/dashboard',
      (route) => false,
      arguments: {'tab': 2}, // tab 2 = Recordatorios
    );
  }

  /// Programa dos notificaciones: una hora antes y en el momento exacto
  static Future<void> programar({
    required int id,
    required String titutoNota,
    required DateTime fecha,
  }) async {
    final ahora = DateTime.now();

    // Notificación exacta
    if (fecha.isAfter(ahora)) {
      await _programarUna(
        id: id,
        titulo: 'Tienes un recordatorio pendiente',
        cuerpo: titutoNota,
        fecha: fecha,
      );
    }

    // Notificación anticipada — 1 hora antes (solo si queda más de 1h)
    final unaHoraAntes = fecha.subtract(const Duration(hours: 1));
    if (unaHoraAntes.isAfter(ahora)) {
      await _programarUna(
        id: id + _offsetAnticipada,
        titulo: 'Recordatorio en 1 hora',
        cuerpo: titutoNota,
        fecha: unaHoraAntes,
      );
    }

    // Notificación de vencimiento — 2 horas después si no completó
    final dosHorasDespues = fecha.add(const Duration(hours: 2));
    if (dosHorasDespues.isAfter(ahora)) {
      await _programarUna(
        id: id + _offsetVencida,
        titulo: 'Tarea sin completar',
        cuerpo: titutoNota,
        fecha: dosHorasDespues,
      );
    }
  }

  static Future<void> _programarUna({
    required int id,
    required String titulo,
    required String cuerpo,
    required DateTime fecha,
  }) async {
    await _plugin.zonedSchedule(
      id,
      titulo,
      cuerpo,
      tz.TZDateTime.from(fecha, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'recordatorios_channel',
          'Recordatorios',
          channelDescription: 'Notificaciones de recordatorios de notas',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancela las tres notificaciones (anticipada, exacta, vencimiento)
  static Future<void> cancelar(int id) async {
    await _plugin.cancel(id);
    await _plugin.cancel(id + _offsetAnticipada);
    await _plugin.cancel(id + _offsetVencida);
  }
}

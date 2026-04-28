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

  // Tab pendiente cuando el navigator aún no está listo (cold start)
  static int? _tabPendiente;

  // Offsets para evitar colisión de IDs entre tipos de notificación
  static const int _offsetAnticipada = 1000000;
  static const int _offsetVencida = 2000000;

  /// Inicializa el plugin — llamar una vez en main()
  static Future<void> inicializar({
    required GlobalKey<NavigatorState> navKey,
  }) async {
    if (_inicializado) return;

    navigatorKey = navKey;
    tz_data.initializeTimeZones();
    // Configurar zona horaria local
    final String timeZoneName = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Fallback a UTC si falla la detección
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    final initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _alTocarNotificacion,
    );

    // Detectar si la app fue abierta desde una notificación (cold start / app terminada)
    final detalles = await _plugin.getNotificationAppLaunchDetails();
    if (detalles?.didNotificationLaunchApp == true) {
      _tabPendiente = 2; // Ir a la pantalla de Tareas al iniciar
    }

    // Solicitar permiso en Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // Solicitar permiso para alarmas exactas
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();

    // Cancelar notificaciones antiguas para que se reprogramen con el ícono nuevo
    await _plugin.cancelAll();

    _inicializado = true;
  }

  /// Al tocar la notificación navega a la pantalla de recordatorios.
  /// Si el navigator no está listo (cold start), guarda el tab para que
  /// MainLayout lo consuma después del splash.
  static void _alTocarNotificacion(NotificationResponse response) {
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamedAndRemoveUntil(
        '/dashboard',
        (route) => false,
        arguments: {'tab': 2}, // tab 2 = Recordatorios
      );
    } else {
      // Navigator todavía no está listo — se aplica en MainLayout tras el splash
      _tabPendiente = 2;
    }
  }

  /// Devuelve el tab pendiente de una notificación y lo limpia.
  /// MainLayout debe llamar esto en initState para el caso cold start.
  static int? consumirTabPendiente() {
    final tab = _tabPendiente;
    _tabPendiente = null;
    return tab;
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
    // Convertimos la fecha local a UTC. Así no dependemos de si la zona horaria
    // local está bien configurada o no en la librería.
    final utcDate = fecha.toUtc();
    final tzDate = tz.TZDateTime.from(utcDate, tz.UTC);

    await _plugin.zonedSchedule(
      id,
      titulo,
      cuerpo,
      tzDate,
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

  /// Envía una notificación instantánea (para pruebas)
  static Future<void> notificarAhora({
    required String titulo,
    required String cuerpo,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel',
        'Pruebas',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(999999, titulo, cuerpo, details);
  }

  /// Cancela las tres notificaciones (anticipada, exacta, vencimiento)
  static Future<void> cancelar(int id) async {
    await _plugin.cancel(id);
    await _plugin.cancel(id + _offsetAnticipada);
    await _plugin.cancel(id + _offsetVencida);
  }
}

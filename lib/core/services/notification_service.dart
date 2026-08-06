import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Tipos de notificaciones
enum NotificationType {
  joinRequest,      // Solicitud para unirse a tu actividad
  acceptedToGroup,  // Te aceptaron en un grupo
  activityReminder, // Recordatorio de actividad
  newActivity,      // Nueva actividad de interés

  ;

  static NotificationType fromString(String v) => switch (v) {
        'joinRequest'      => NotificationType.joinRequest,
        'acceptedToGroup'  => NotificationType.acceptedToGroup,
        'activityReminder' => NotificationType.activityReminder,
        _                  => NotificationType.newActivity,
      };
}

/// Modelo de notificación
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final String? activityId;
  final String? activityTitle;
  final String? senderName;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.activityId,
    this.activityTitle,
    this.senderName,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    // Intentar extraer el título de la actividad de las comillas en el body/message
    String? extractedTitle;
    final bodyStr = json['body'] as String? ?? json['message'] as String? ?? '';
    if (bodyStr.isNotEmpty) {
      final match = RegExp(r'\"([^\"]+)\"').firstMatch(bodyStr);
      if (match != null) {
        extractedTitle = match.group(1);
      } else {
        final match2 = RegExp(r'"([^"]+)"').firstMatch(bodyStr);
        if (match2 != null) {
          extractedTitle = match2.group(1);
        }
      }
    }

    return AppNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Notificación',
      message: bodyStr,
      type: NotificationType.fromString(json['type'] as String? ?? ''),
      timestamp: DateTime.tryParse(json['created_at'] as String? ?? json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      activityId: json['entity_id'] as String? ?? json['activityId'] as String?,
      activityTitle: extractedTitle ?? json['activityTitle'] as String?,
      senderName: json['senderName'] as String?,
      isRead: json['is_read'] as bool? ?? json['isRead'] as bool? ?? false,
    );
  }
}

/// Servicio de notificaciones — conectado al backend real
class NotificationService {
  static final List<AppNotification> _cache = [];
  static DateTime? _lastFetch;
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Ids ya avisados, para no repetir la alerta si la misma notificación llega
  /// por Realtime y por una recarga manual.
  static final Set<String> _notifiedIds = {};

  /// Tope del set anterior: sin él crecería sin límite mientras la app siga
  /// abierta. Se conservan los más recientes, que son los que pueden repetirse.
  static const int _maxRememberedIds = 200;

  /// Canal de Realtime activo, si hay sesión.
  static RealtimeChannel? _channel;

  /// Escucha en vivo las notificaciones del usuario.
  ///
  /// Antes sólo se consultaban al abrir el inicio o la pantalla de
  /// notificaciones: quien se quedaba en una pantalla no veía nada nuevo hasta
  /// navegar a otra y volver. Ahora el badge y la alerta del sistema aparecen
  /// en cuanto la fila se inserta en la base de datos.
  static Future<void> subscribeToRealtime() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    await unsubscribeFromRealtime();

    _channel = Supabase.instance.client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _onNotificationInserted(payload.newRecord),
        )
        .onPostgresChanges(
          // Mantiene el estado de leído en sincronía si se marca desde otro
          // dispositivo o desde un trigger del backend.
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _onNotificationUpdated(payload.newRecord),
        )
        .subscribe();

    debugPrint('🔔 Notificaciones en vivo activas.');
  }

  static Future<void> unsubscribeFromRealtime() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await Supabase.instance.client.removeChannel(channel);
    }
  }

  static void _onNotificationInserted(Map<String, dynamic> row) {
    final notif = AppNotification.fromJson(row);
    if (_cache.any((n) => n.id == notif.id)) return;

    _cache.insert(0, notif);
    unreadCount.value = getUnreadCount();
    debugPrint('🔔 Notificación en vivo: "${notif.title}" (sin leer: ${unreadCount.value})');

    if (!notif.isRead) _fireLocalNotification(notif);
  }

  static void _onNotificationUpdated(Map<String, dynamic> row) {
    final notif = AppNotification.fromJson(row);
    final index = _cache.indexWhere((n) => n.id == notif.id);
    if (index == -1) return;

    _cache[index].isRead = notif.isRead;
    unreadCount.value = getUnreadCount();
  }

  /// Muestra la alerta del sistema una sola vez por notificación.
  static void _fireLocalNotification(AppNotification notif) {
    if (!_rememberNotified(notif.id)) return;

    showLocalNotification(
      id: notif.id,
      title: notif.title,
      body: notif.message,
      payload: notif.activityId,
    ).catchError((e) => debugPrint('Error al mostrar notificación local: $e'));
  }

  /// Registra el id y devuelve si era nuevo.
  static bool _rememberNotified(String id) {
    if (!_notifiedIds.add(id)) return false;
    if (_notifiedIds.length > _maxRememberedIds) {
      _notifiedIds.remove(_notifiedIds.first);
    }
    return true;
  }

  /// Inicializa las notificaciones locales nativas y solicita permisos
  static Future<void> initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('launcher_icon');
    
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notificación local presionada. Payload: ${details.payload}');
      },
    );

    // Solicitar permiso en Android 13+ si está disponible
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Dispara una notificación flotante (Heads-up WhatsApp-style) en la bandeja del sistema
  static Future<void> showLocalNotification({
    required String id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'join_high_importance_channel', // ID del canal
      'Alertas Importantes',          // Nombre del canal
      channelDescription: 'Canal de notificaciones flotantes en Join',
      importance: Importance.max,     // Cabecera flotante WhatsApp-style
      priority: Priority.high,        // Alta prioridad del sistema
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''), // Evitar recortar textos largos
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Convertir ID UUID a int usando hashCode absoluto para evitar IDs negativos
    final int intId = id.hashCode.abs();

    await _localNotifications.show(
      intId,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  /// Obtiene notificaciones del backend (con caché de 30s)
  static Future<List<AppNotification>> fetchNotifications(
      {bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastFetch != null &&
        now.difference(_lastFetch!).inSeconds < 30 &&
        _cache.isNotEmpty) {
      return _cache;
    }

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) return [];

      final data = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      final list = data.cast<Map<String, dynamic>>();
      final parsedList = list.map(AppNotification.fromJson).toList();

      final esPrimeraCarga = _lastFetch == null;
      for (final notif in parsedList) {
        if (esPrimeraCarga) {
          // Las que ya existían al abrir la app no deben sonar como nuevas.
          _rememberNotified(notif.id);
        } else if (!notif.isRead) {
          _fireLocalNotification(notif);
        }
      }

      _cache
        ..clear()
        ..addAll(parsedList);
      _lastFetch = now;
      unreadCount.value = getUnreadCount();
      return _cache;
    } catch (e) {
      debugPrint('Error en Supabase fetchNotifications: $e');
      return _cache;
    }
  }

  /// Marca una notificación como leída
  static Future<void> markAsRead(String id) async {
    final idx = _cache.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _cache[idx].isRead = true;
      unreadCount.value = getUnreadCount();
    }

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      debugPrint('Error en Supabase markAsRead: $e');
    }
  }

  /// Marca todas como leídas
  static Future<void> markAllAsRead() async {
    for (final n in _cache) {
      n.isRead = true;
    }
    unreadCount.value = 0;

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) return;

      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', currentUserId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error en Supabase markAllAsRead: $e');
    }
  }

  /// Devuelve las notificaciones del caché actual
  static List<AppNotification> getNotifications() => _cache;

  /// Cuenta no leídas del caché
  static int getUnreadCount() => _cache.where((n) => !n.isRead).length;

  /// Invalida el caché para forzar re-fetch
  static void invalidate() {
    _lastFetch = null;
  }
}

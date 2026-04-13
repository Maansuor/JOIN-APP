import 'package:flutter/foundation.dart';
import 'package:join_app/core/services/api_client.dart';

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
    return AppNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Notificación',
      message: json['message'] as String? ?? '',
      type: NotificationType.fromString(json['type'] as String? ?? ''),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      activityId: json['activityId'] as String?,
      activityTitle: json['activityTitle'] as String?,
      senderName: json['senderName'] as String?,
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

/// Servicio de notificaciones — conectado al backend real
class NotificationService {
  static final List<AppNotification> _cache = [];
  static DateTime? _lastFetch;
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

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
      final response = await ApiClient.instance
          .get('/notifications.php', queryParams: {'action': 'list'});
      final list =
          (response['notifications'] as List? ?? []).cast<Map<String, dynamic>>();
      _cache
        ..clear()
        ..addAll(list.map(AppNotification.fromJson));
      _lastFetch = now;
      unreadCount.value = getUnreadCount();
      return _cache;
    } catch (e) {
      // Si falla, retornar caché o lista vacía
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
      await ApiClient.instance.post(
        '/notifications.php',
        {'id': id},
        queryParams: {'action': 'mark_read'},
      );
    } catch (_) {}
  }

  /// Marca todas como leídas
  static Future<void> markAllAsRead() async {
    for (final n in _cache) {
      n.isRead = true;
    }
    unreadCount.value = 0;

    try {
      await ApiClient.instance.post(
        '/notifications.php',
        {},
        queryParams: {'action': 'mark_all'},
      );
    } catch (_) {}
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

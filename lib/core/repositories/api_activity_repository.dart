import 'dart:io';
import 'dart:convert';
import '../models/activity_model.dart';
import '../models/join_request_model.dart';
import '../services/api_client.dart';
import 'activity_repository.dart';

// ══════════════════════════════════════════════════════════════
//  ApiActivityRepository  — Implementación real con el backend PHP
//  Reemplaza al MockActivityRepository.
// ══════════════════════════════════════════════════════════════
class ApiActivityRepository implements ActivityRepository {
  final ApiClient _api;
  ApiActivityRepository({ApiClient? client})
      : _api = client ?? ApiClient.instance;

  // ── Listar actividades ────────────────────────────────────
  @override
  Future<List<Activity>> getActivities({String? category}) async {
    final params = <String, String>{};
    if (category != null && category != 'Todos') {
      params['category'] = category;
    }
    final data = await _api.get('/activities.php', queryParams: params);
    // Cast defensivo — evita TypeError si el campo es null o tiene formato inesperado
    final rawList = data is Map ? data['activities'] : null;
    if (rawList == null || rawList is! List) return [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => Activity.fromJson(e))
        .toList();
  }

  // ── Detalle de actividad ──────────────────────────────────
  @override
  Future<Activity?> getActivityById(String id) async {
    try {
      final data = await _api.get('/activities.php', queryParams: {'id': id});
      return Activity.fromJson(data['activity'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── Actividades por organizador ───────────────────────────
  @override
  Future<List<Activity>> getActivitiesByOrganizer(String organizerId) async {
    final all = await getActivities();
    return all.where((a) => a.organizerId == organizerId).toList();
  }

  // ── Crear actividad ───────────────────────────────────────
  @override
  Future<Activity> createActivity(Activity activity) async {
    final body = {
      'title': activity.title,
      'description': activity.description,
      'category': activity.category,
      'dateTime': activity.eventDateTime.toIso8601String(),
      'locationName': activity.locationName,
      'latitude': activity.latitude?.toString() ?? '',
      'longitude': activity.longitude?.toString() ?? '',
      'maxParticipants': activity.maxParticipants.toString(),
      'ageRange': activity.ageRange,
      if (activity.imageUrl.startsWith('http') || activity.imageUrl.startsWith('assets')) 'imageUrl': activity.imageUrl,
      'durationMinutes': activity.durationMinutes?.toString() ?? '',
      'cost': activity.cost.toString(),
      'tags': activity.tags.join(','),
      'contributions': jsonEncode(activity.contributions),
    };

    File? localImage;
    if (activity.imageUrl.isNotEmpty && !activity.imageUrl.startsWith('http') && !activity.imageUrl.startsWith('assets')) {
      localImage = File(activity.imageUrl);
    }

    final data = await _api.postMultipart('/activities.php', body, file: localImage);
    return Activity.fromJson(data['activity'] as Map<String, dynamic>);
  }

  // ── Actualizar actividad ──────────────────────────────────
  @override
  Future<Activity> updateActivity(Activity activity) async {
    final body = {
      '_method': 'PUT',
      'title': activity.title,
      'description': activity.description,
      'category': activity.category,
      'dateTime': activity.eventDateTime.toIso8601String(),
      'locationName': activity.locationName,
      'latitude': activity.latitude?.toString() ?? '',
      'longitude': activity.longitude?.toString() ?? '',
      'maxParticipants': activity.maxParticipants.toString(),
      'ageRange': activity.ageRange,
      if (activity.imageUrl.startsWith('http') || activity.imageUrl.startsWith('assets')) 'imageUrl': activity.imageUrl,
      'durationMinutes': activity.durationMinutes?.toString() ?? '',
      'cost': activity.cost.toString(),
      'tags': activity.tags.join(','),
      'contributions': jsonEncode(activity.contributions),
    };

    File? localImage;
    if (activity.imageUrl.isNotEmpty && !activity.imageUrl.startsWith('http') && !activity.imageUrl.startsWith('assets')) {
      localImage = File(activity.imageUrl);
    }

    final data = await _api.postMultipart(
      '/activities.php',
      body,
      file: localImage,
      queryParams: {'id': activity.id},
    );
    return Activity.fromJson(data['activity'] as Map<String, dynamic>);
  }

  // ── Cancelar actividad ────────────────────────────────────
  @override
  Future<void> cancelActivity(String activityId) async {
    await _api.delete('/activities.php', queryParams: {'id': activityId});
  }

  // ── Solicitudes de una actividad ──────────────────────────
  @override
  Future<List<JoinRequest>> getRequestsForActivity(String activityId) async {
    final data = await _api
        .get('/join_requests.php', queryParams: {'activity_id': activityId});
    final list = data['requests'] as List<dynamic>;
    return list
        .map((e) => JoinRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Mis solicitudes ──────────────────────────
  @override
  Future<List<JoinRequest>> getMyAllRequests() async {
    final data = await _api.get('/join_requests.php', queryParams: {'action': 'my'});
    final list = data['requests'] as List<dynamic>;
    return list.map((e) => JoinRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Enviar solicitud ──────────────────────────────────────
  @override
  Future<JoinRequest> submitJoinRequest({
    required String activityId,
    required String userId,
    required String userName,
    required String userImageUrl,
    required String message,
  }) async {
    final data = await _api.post('/join_requests.php', {
      'activityId': activityId,
      'message': message,
    });
    return JoinRequest.fromJson(data['request'] as Map<String, dynamic>);
  }

  // ── Responder solicitud ───────────────────────────────────
  @override
  Future<JoinRequest> respondToRequest({
    required String requestId,
    required bool accepted,
    String? responseMessage,
    required String respondedBy,
  }) async {
    final data = await _api.put('/join_requests.php', {
      'accepted': accepted,
      'responseMessage': responseMessage ?? '',
    }, queryParams: {
      'id': requestId
    });
    return JoinRequest.fromJson(data['request'] as Map<String, dynamic>);
  }

  // ── Mi solicitud para una actividad ──────────────────────
  @override
  Future<JoinRequest?> getMyRequest({
    required String activityId,
    required String userId,
  }) async {
    final data = await _api.get('/join_requests.php', queryParams: {
      'activity_id': activityId,
      'user_id': userId,
    });
    final raw = data['request'];
    if (raw == null) return null;
    return JoinRequest.fromJson(raw as Map<String, dynamic>);
  }
}

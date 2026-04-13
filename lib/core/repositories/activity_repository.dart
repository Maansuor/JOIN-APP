import '../models/activity_model.dart';
import '../models/join_request_model.dart';
import '../data/mock_data.dart';
import '../data/mock_join_requests.dart';

/// Abstracción del repositorio de actividades.
///
/// Define el contrato (interfaz) que cualquier implementación debe cumplir.
/// Actualmente existe [MockActivityRepository] para desarrollo.
/// En Fase 2 se creará [ApiActivityRepository] que llame al backend.
///
/// Para cambiar de mock a producción solo hay que cambiar qué implementación
/// se inyecta en el Provider — el resto del código no cambia.
abstract class ActivityRepository {
  /// Obtiene todas las actividades disponibles
  Future<List<Activity>> getActivities({String? category});

  /// Obtiene una actividad por ID
  Future<Activity?> getActivityById(String id);

  /// Obtiene actividades creadas por un usuario
  Future<List<Activity>> getActivitiesByOrganizer(String organizerId);

  /// Crea una nueva actividad
  Future<Activity> createActivity(Activity activity);

  /// Actualiza una actividad existente
  Future<Activity> updateActivity(Activity activity);

  /// Cancela una actividad
  Future<void> cancelActivity(String activityId);

  /// Obtiene solicitudes de una actividad
  Future<List<JoinRequest>> getRequestsForActivity(String activityId);

  // ── Mis solicitudes ──────────────────────────
  Future<List<JoinRequest>> getMyAllRequests();

  /// Envía una solicitud para unirse a una actividad
  Future<JoinRequest> submitJoinRequest({
    required String activityId,
    required String userId,
    required String userName,
    required String userImageUrl,
    required String message,
  });

  /// Responde a una solicitud (aceptar/rechazar)
  Future<JoinRequest> respondToRequest({
    required String requestId,
    required bool accepted,
    String? responseMessage,
    required String respondedBy,
  });

  /// Obtiene la solicitud de un usuario para una actividad específica
  Future<JoinRequest?> getMyRequest({
    required String activityId,
    required String userId,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Implementación Mock (para desarrollo y pruebas)
// ─────────────────────────────────────────────────────────────────────────────

/// Implementación del repositorio que usa datos mock locales.
/// Se usa durante el desarrollo. En producción se reemplaza por [ApiActivityRepository].
class MockActivityRepository implements ActivityRepository {
  // Copia mutable de los mocks para poder modificarlos durante la sesión
  final List<Activity> _activities = List.from(mockActivities);
  final List<JoinRequest> _requests = List.from(mockJoinRequests);

  @override
  Future<List<Activity>> getActivities({String? category}) async {
    await _simulateDelay();
    if (category == null || category == 'Todos') {
      return List.from(_activities.where((a) => a.isActive));
    }
    return _activities
        .where((a) => a.isActive && a.category == category)
        .toList();
  }

  @override
  Future<Activity?> getActivityById(String id) async {
    await _simulateDelay();
    try {
      return _activities.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Activity>> getActivitiesByOrganizer(String organizerId) async {
    await _simulateDelay();
    return _activities.where((a) => a.organizerId == organizerId).toList();
  }

  @override
  Future<Activity> createActivity(Activity activity) async {
    await _simulateDelay();
    _activities.insert(0, activity);
    return activity;
  }

  @override
  Future<Activity> updateActivity(Activity activity) async {
    await _simulateDelay();
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index == -1) throw Exception('Actividad no encontrada: ${activity.id}');
    _activities[index] = activity;
    return activity;
  }

  @override
  Future<void> cancelActivity(String activityId) async {
    await _simulateDelay();
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index != -1) {
      _activities[index] = _activities[index].copyWith(isActive: false);
    }
  }

  @override
  Future<List<JoinRequest>> getRequestsForActivity(String activityId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return []; // Para mock
  }

  @override
  Future<List<JoinRequest>> getMyAllRequests() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return []; // Para mock
  }

  @override
  Future<JoinRequest> submitJoinRequest({
    required String activityId,
    required String userId,
    required String userName,
    required String userImageUrl,
    required String message,
  }) async {
    await _simulateDelay();

    final request = JoinRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityId: activityId,
      userId: userId,
      userName: userName,
      userImageUrl: userImageUrl,
      message: message,
      requestedAt: DateTime.now(),
      status: JoinRequestStatus.pending,
    );

    _requests.insert(0, request);
    return request;
  }

  @override
  Future<JoinRequest> respondToRequest({
    required String requestId,
    required bool accepted,
    String? responseMessage,
    required String respondedBy,
  }) async {
    await _simulateDelay();

    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) throw Exception('Solicitud no encontrada: $requestId');

    final updated = _requests[index].copyWith(
      status:
          accepted ? JoinRequestStatus.accepted : JoinRequestStatus.rejected,
      respondedAt: DateTime.now(),
      respondedBy: respondedBy,
      responseMessage: responseMessage,
    );

    _requests[index] = updated;
    return updated;
  }

  @override
  Future<JoinRequest?> getMyRequest({
    required String activityId,
    required String userId,
  }) async {
    await _simulateDelay();
    try {
      return _requests.firstWhere(
        (r) => r.activityId == activityId && r.userId == userId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Simula la latencia de red para detectar problemas de UX antes de conectar al backend
  Future<void> _simulateDelay([int ms = 300]) =>
      Future.delayed(Duration(milliseconds: ms));
}

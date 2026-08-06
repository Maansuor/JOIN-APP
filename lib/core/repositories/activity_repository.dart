import '../models/activity_model.dart';
import '../models/event_photo_model.dart';
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
  Future<List<Activity>> getActivities({String? category, String? city});

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

  /// Elimina una actividad permanentemente
  Future<void> deleteActivity(String activityId);

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

  // ── Recuerdos / Mural de Actividades ──────────────────────────
  
  /// Obtiene actividades finalizadas asociadas al usuario (creadas o asistidas)
  Future<List<Activity>> getCompletedActivitiesForUser(String userId);

  /// Obtiene las fotos subidas a un evento
  Future<List<EventPhoto>> getEventPhotos(String activityId);

  /// Sube una foto al mural de un evento
  Future<void> uploadEventPhoto({
    required String activityId,
    required String userId,
    required String photoPath,
    String? caption,
  });

  /// Da o quita like a una foto del mural
  Future<void> toggleLikePhoto({
    required String photoId,
    required String userId,
    required bool like,
  });

  /// Verifica si el usuario ya subió una foto para limitar a 1 por persona
  Future<bool> hasUserUploadedPhoto({
    required String activityId,
    required String userId,
  });

  /// Verifica si el usuario es participante de la actividad
  Future<bool> isUserParticipant({
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
  Future<List<Activity>> getActivities({String? category, String? city}) async {
    await _simulateDelay();
    Iterable<Activity> list = _activities.where((a) => a.isActive);
    if (city != null && city.isNotEmpty) {
      list = list.where((a) => a.city == null || a.city!.isEmpty || a.city!.toLowerCase() == city.toLowerCase());
    }
    if (category == null || category == 'Todos') {
      return list.toList();
    }
    return list.where((a) => a.category == category).toList();
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
  Future<void> deleteActivity(String activityId) async {
    await _simulateDelay();
    _activities.removeWhere((a) => a.id == activityId);
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

  // ── Recuerdos Mock ──────────────────────────

  final List<EventPhoto> _mockPhotos = [];

  @override
  Future<List<Activity>> getCompletedActivitiesForUser(String userId) async {
    await _simulateDelay();
    // Retornamos todas las actividades del organizador y simulamos que están completadas
    final myCreated = _activities.where((a) => a.organizerId == userId).toList();
    // Añadimos un par de mock como si ya hubieran pasado (fecha en el pasado)
    final pastList = myCreated.map((a) => a.copyWith(
      eventDateTime: DateTime.now().subtract(const Duration(days: 2)),
      isActive: false,
    )).toList();
    
    // Y añadimos una actividad mock asistida
    if (_activities.isNotEmpty) {
      final first = _activities.first;
      if (first.organizerId != userId) {
        pastList.add(first.copyWith(
          id: 'past_attended_1',
          title: 'Caminata de Prueba Asistida 🌲',
          eventDateTime: DateTime.now().subtract(const Duration(days: 5)),
          isActive: false,
        ));
      }
    }
    return pastList;
  }

  @override
  Future<List<EventPhoto>> getEventPhotos(String activityId) async {
    await _simulateDelay();
    // Retornar fotos locales mock y las añadidas dinámicamente
    final current = _mockPhotos.where((p) => p.activityId == activityId).toList();
    if (current.isEmpty && activityId != 'past_attended_1') {
      // Devolver algunas fotos mock de prueba por defecto
      return [
        EventPhoto(
          id: 'mock_ph_1',
          activityId: activityId,
          userId: 'other_user',
          userName: 'Ana Torres',
          userImageUrl: 'assets/images/avatars/avatar_2.png',
          photoUrl: 'assets/images/activities/activity_1_hiking.jpg',
          caption: '¡El mejor paisaje! 🌄',
          uploadedAt: DateTime.now().subtract(const Duration(hours: 4)),
          likes: 2,
          likedByUserIds: ['some_user'],
        ),
      ];
    }
    return current;
  }

  @override
  Future<void> uploadEventPhoto({
    required String activityId,
    required String userId,
    required String photoPath,
    String? caption,
  }) async {
    await _simulateDelay();
    _mockPhotos.add(EventPhoto(
      id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
      activityId: activityId,
      userId: userId,
      userName: 'Tú',
      userImageUrl: 'assets/images/avatars/avatar_1.png',
      photoUrl: photoPath, // En mock usamos el path local
      caption: caption,
      uploadedAt: DateTime.now(),
      likes: 0,
      likedByUserIds: [],
    ));
  }

  @override
  Future<void> toggleLikePhoto({
    required String photoId,
    required String userId,
    required bool like,
  }) async {
    await _simulateDelay();
    final index = _mockPhotos.indexWhere((p) => p.id == photoId);
    if (index != -1) {
      final photo = _mockPhotos[index];
      final newLikes = like ? (photo.likes + 1) : (photo.likes - 1).clamp(0, 999);
      final newLikedList = List<String>.from(photo.likedByUserIds);
      if (like) {
        newLikedList.add(userId);
      } else {
        newLikedList.remove(userId);
      }
      _mockPhotos[index] = EventPhoto(
        id: photo.id,
        activityId: photo.activityId,
        userId: photo.userId,
        userName: photo.userName,
        userImageUrl: photo.userImageUrl,
        photoUrl: photo.photoUrl,
        caption: photo.caption,
        uploadedAt: photo.uploadedAt,
        likes: newLikes.toInt(),
        likedByUserIds: newLikedList,
      );
    }
  }

  @override
  Future<bool> hasUserUploadedPhoto({
    required String activityId,
    required String userId,
  }) async {
    await _simulateDelay();
    return _mockPhotos.any((p) => p.activityId == activityId && p.userId == userId);
  }

  @override
  Future<bool> isUserParticipant({
    required String activityId,
    required String userId,
  }) async {
    await _simulateDelay();
    return true; // En mock permitimos todo por simplicidad
  }

  /// Simula la latencia de red para detectar problemas de UX antes de conectar al backend
  Future<void> _simulateDelay([int ms = 300]) =>
      Future.delayed(Duration(milliseconds: ms));
}


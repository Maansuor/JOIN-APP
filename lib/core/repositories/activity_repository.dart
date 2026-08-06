import '../models/activity_model.dart';
import '../models/event_photo_model.dart';
import '../models/join_request_model.dart';

/// Abstracción del repositorio de actividades.
///
/// Define el contrato que cualquier implementación debe cumplir. La única
/// implementación es [SupabaseActivityRepository]; se inyecta en AppState, así
/// que sustituirla por otra no obliga a tocar el resto del código.
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

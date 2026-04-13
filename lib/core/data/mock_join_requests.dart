import 'package:join_app/core/models/join_request_model.dart';

/// Mock data de solicitudes de unión
/// Simulan solicitudes de usuarios a diferentes actividades
final List<JoinRequest> mockJoinRequests = [
  // Solicitudes para la actividad 1 (Caminata al Atardecer)
  JoinRequest(
    id: 'req_1',
    activityId: '1',
    userId: 'user_1',
    message: '¡Hola Camila! Me encanta el trekking y tengo equipo propio. ¡Vamos!',
    requestedAt: DateTime.now().subtract(const Duration(hours: 2)),
    status: JoinRequestStatus.pending,
  ),
  JoinRequest(
    id: 'req_2',
    activityId: '1',
    userId: 'user_2',
    message: 'Oye, ¿puedo llevar a mi novia también? Ella también quiere venir.',
    requestedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
    status: JoinRequestStatus.pending,
  ),
  JoinRequest(
    id: 'req_3',
    activityId: '1',
    userId: 'user_4',
    message: 'Perfecto para relajarme. ¡Cuenten conmigo!',
    requestedAt: DateTime.now().subtract(const Duration(hours: 1)),
    status: JoinRequestStatus.accepted,
    respondedAt: DateTime.now().subtract(const Duration(minutes: 45)),
    respondedBy: 'org_1',
  ),
  JoinRequest(
    id: 'req_4',
    activityId: '1',
    userId: 'user_5',
    message: 'Soy ciclista, ¿puedo llevar mi bicicleta?',
    requestedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    status: JoinRequestStatus.rejected,
    respondedAt: DateTime.now().subtract(const Duration(minutes: 15)),
    respondedBy: 'org_1',
    responseMessage: 'Es caminata, no es apto para bicicletas. Otro día!',
  ),

  // Solicitudes para la actividad 2 (Futbol)
  JoinRequest(
    id: 'req_5',
    activityId: '2',
    userId: 'user_1',
    message: '¿Cuál es el nivel de juego? Juego casual.',
    requestedAt: DateTime.now().subtract(const Duration(hours: 3)),
    status: JoinRequestStatus.pending,
  ),
  JoinRequest(
    id: 'req_6',
    activityId: '2',
    userId: 'user_3',
    message: 'Vengo a animar y llevaré cervezas 😄',
    requestedAt: DateTime.now().subtract(const Duration(hours: 2)),
    status: JoinRequestStatus.accepted,
    respondedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
    respondedBy: 'org_2',
  ),

  // Solicitudes para la actividad 3 (Parrillada)
  JoinRequest(
    id: 'req_7',
    activityId: '3',
    userId: 'user_1',
    message: 'Perfecto, llevaré vino tinto. ¿A qué hora es?',
    requestedAt: DateTime.now().subtract(const Duration(hours: 4)),
    status: JoinRequestStatus.pending,
  ),
  JoinRequest(
    id: 'req_8',
    activityId: '3',
    userId: 'user_2',
    message: 'Somos 3 amigos, ¿hay cupo para todos?',
    requestedAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 30)),
    status: JoinRequestStatus.accepted,
    respondedAt: DateTime.now().subtract(const Duration(hours: 2)),
    respondedBy: 'org_3',
  ),

  // Solicitudes para la actividad 4 (Yoga)
  JoinRequest(
    id: 'req_9',
    activityId: '4',
    userId: 'user_1',
    message: '¿Es principiante friendly? Soy novato.',
    requestedAt: DateTime.now().subtract(const Duration(hours: 5)),
    status: JoinRequestStatus.accepted,
    respondedAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 45)),
    respondedBy: 'org_4',
  ),
  JoinRequest(
    id: 'req_10',
    activityId: '4',
    userId: 'user_5',
    message: '¡Voy! Necesito relajarme después de tanto entrenar.',
    requestedAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 30)),
    status: JoinRequestStatus.pending,
  ),
];

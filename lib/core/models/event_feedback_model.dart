/// Modelo para Feedback Post-Evento
class EventFeedback {
  final String id;
  final String activityId;
  final String userId; // Quien envía el feedback
  final double groupRating; // 1-5 estrellas para el grupo en general
  final String groupComment; // Comentario sobre el evento
  final int attendanceScore; // 1-5 ¿Qué tal fue?
  final bool wouldAttendAgain; // ¿Volverías a asistir?
  final List<String> bestThings; // Lo mejor del evento (tags)
  final List<String> improvementSuggestions; // Sugerencias de mejora
  final DateTime submittedAt;

  EventFeedback({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.groupRating,
    required this.groupComment,
    required this.attendanceScore,
    required this.wouldAttendAgain,
    required this.bestThings,
    required this.improvementSuggestions,
    required this.submittedAt,
  });
}

/// Estados posibles de una solicitud de unirse
enum JoinRequestStatus {
  pending, // Esperando respuesta del organizador
  accepted, // Aceptada, usuario tiene acceso
  rejected, // Rechazada
  cancelled, // Cancelada por el usuario
}

/// Extensión para serializar/deserializar el enum
extension JoinRequestStatusX on JoinRequestStatus {
  String get value => name; // 'pending', 'accepted', etc.

  static JoinRequestStatus fromString(String value) {
    return JoinRequestStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => JoinRequestStatus.pending,
    );
  }
}

/// Modelo de Solicitud para Unirse a una Actividad
class JoinRequest {
  final String id;
  final String activityId;
  final String userId;
  final String userName; // Desnormalizado para mostrar en UI sin joins
  final String userImageUrl;
  final double userRating;
  final String message;
  final DateTime requestedAt;
  final JoinRequestStatus status;
  final DateTime? respondedAt;
  final String? respondedBy;
  final String? responseMessage;
  final DateTime? userBirthDate; // Agregado para ver edad en preview
  final String? userGender;      // Agregado para ver género en preview

  const JoinRequest({
    required this.id,
    required this.activityId,
    required this.userId,
    this.userName = '',
    this.userImageUrl = '',
    this.userRating = 0.0,
    required this.message,
    required this.requestedAt,
    required this.status,
    this.respondedAt,
    this.respondedBy,
    this.responseMessage,
    this.userBirthDate,
    this.userGender,
  });

  /// Crea un JoinRequest desde un mapa JSON
  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    final activityId = (json['activityId'] ?? json['activity_id'] ?? '') as String;
    final userId = (json['userId'] ?? json['user_id'] ?? '') as String;
    final userName = (json['userName'] ?? json['user_name'] ?? json['display_name'] ?? '') as String;
    final userImageUrl = (json['userImageUrl'] ?? json['user_image_url'] ?? json['profile_image_url'] ?? '') as String;
    final userRating = (json['userRating'] ?? json['user_rating'] ?? json['rating'] ?? 0.0) as num;
    final message = json['message'] as String? ?? '';
    
    final requestedAtStr = (json['requestedAt'] ?? json['requested_at']) as String?;
    final requestedAt = requestedAtStr != null ? DateTime.parse(requestedAtStr) : DateTime.now();

    final statusVal = (json['status'] as String? ?? 'pending');
    final status = JoinRequestStatusX.fromString(statusVal);

    final respondedAtStr = (json['respondedAt'] ?? json['responded_at']) as String?;
    final respondedAt = respondedAtStr != null ? DateTime.parse(respondedAtStr) : null;

    final respondedBy = (json['respondedBy'] ?? json['responded_by']) as String?;
    final responseMessage = (json['responseMessage'] ?? json['response_message']) as String?;

    final userBirthDateStr = (json['userBirthDate'] ?? json['user_birth_date'] ?? json['birth_date']) as String?;
    final userBirthDate = userBirthDateStr != null ? DateTime.parse(userBirthDateStr) : null;

    final userGender = (json['userGender'] ?? json['user_gender'] ?? json['gender']) as String?;

    return JoinRequest(
      id: json['id'] as String,
      activityId: activityId,
      userId: userId,
      userName: userName,
      userImageUrl: userImageUrl,
      userRating: userRating.toDouble(),
      message: message,
      requestedAt: requestedAt,
      status: status,
      respondedAt: respondedAt,
      respondedBy: respondedBy,
      responseMessage: responseMessage,
      userBirthDate: userBirthDate,
      userGender: userGender,
    );
  }

  /// Convierte el modelo a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityId': activityId,
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'message': message,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status.value,
      if (respondedAt != null) 'respondedAt': respondedAt!.toIso8601String(),
      if (respondedBy != null) 'respondedBy': respondedBy,
      if (responseMessage != null) 'responseMessage': responseMessage,
      if (userBirthDate != null) 'userBirthDate': userBirthDate!.toIso8601String(),
      if (userGender != null) 'userGender': userGender,
    };
  }

  /// Crea una copia con campos modificados
  JoinRequest copyWith({
    JoinRequestStatus? status,
    DateTime? respondedAt,
    String? respondedBy,
    String? responseMessage,
  }) {
    return JoinRequest(
      id: id,
      activityId: activityId,
      userId: userId,
      userName: userName,
      userImageUrl: userImageUrl,
      userRating: userRating,
      message: message,
      requestedAt: requestedAt,
      status: status ?? this.status,
      respondedAt: respondedAt ?? this.respondedAt,
      respondedBy: respondedBy ?? this.respondedBy,
      responseMessage: responseMessage ?? this.responseMessage,
      userBirthDate: userBirthDate,
      userGender: userGender,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JoinRequest && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

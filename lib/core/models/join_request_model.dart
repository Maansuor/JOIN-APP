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
    return JoinRequest(
      id: json['id'] as String,
      activityId: json['activityId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String? ?? '',
      userImageUrl: json['userImageUrl'] as String? ?? '',
      userRating: (json['userRating'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String? ?? '',
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      status:
          JoinRequestStatusX.fromString(json['status'] as String? ?? 'pending'),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
      respondedBy: json['respondedBy'] as String?,
      responseMessage: json['responseMessage'] as String?,
      userBirthDate: json['userBirthDate'] != null
          ? DateTime.parse(json['userBirthDate'] as String)
          : null,
      userGender: json['userGender'] as String?,
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

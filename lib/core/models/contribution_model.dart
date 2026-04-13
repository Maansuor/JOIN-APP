/// Modelo de Aporte / Contribución
class Contribution {
  final String id;
  final String activityId;
  final String title; // Ej: "Carbón", "Carne", "Bebidas"
  final String description; // Descripción del aporte
  final String category; // "food", "drinks", "supplies", "entertainment"
  final bool isRequired; // ¿Es obligatorio o sugerencia?
  final String? assignedToUserId; // ID del usuario que se ha comprometido a llevar
  final String? assignedToUserName; // Nombre del usuario
  final String? assignedToUserImage; // Foto del usuario
  final DateTime createdAt;
  final String createdByUserId; // ID del organizador que creó el aporte

  Contribution({
    required this.id,
    required this.activityId,
    required this.title,
    required this.description,
    required this.category,
    required this.isRequired,
    this.assignedToUserId,
    this.assignedToUserName,
    this.assignedToUserImage,
    required this.createdAt,
    required this.createdByUserId,
  });

  /// ¿El aporte está cubierto?
  bool get isCovered => assignedToUserId != null;

  /// Crea una copia con campos modificados
  Contribution copyWith({
    String? assignedToUserId,
    String? assignedToUserName,
    String? assignedToUserImage,
  }) {
    return Contribution(
      id: id,
      activityId: activityId,
      title: title,
      description: description,
      category: category,
      isRequired: isRequired,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedToUserName: assignedToUserName ?? this.assignedToUserName,
      assignedToUserImage: assignedToUserImage ?? this.assignedToUserImage,
      createdAt: createdAt,
      createdByUserId: createdByUserId,
    );
  }

  /// Quita la asignación
  Contribution unassign() {
    return copyWith(
      assignedToUserId: null,
      assignedToUserName: null,
      assignedToUserImage: null,
    );
  }
}

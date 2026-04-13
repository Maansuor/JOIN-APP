/// Tipos de medallas que se pueden otorgar
enum BadgeType {
  bestOrganizer,      // El mejor organizador
  mostFun,            // El más divertido
  superReliable,      // Super cumplido
  bestPhotographer,   // Mejor fotógrafo
  mostSpirited,       // El más animado
  helpfulContributor, // Mejor contribuidor
}

/// Modelo para Medalla / Reconocimiento
class Badge {
  final String id;
  final String activityId;
  final String awardedToUserId; // Usuario que recibe la medalla
  final String awardedToUserName;
  final String awardedToUserImage;
  final BadgeType type;
  final String title; // Nombre de la medalla
  final String description; // Descripción
  final String emoji; // Emoji representativo
  final String awardedByUserId; // Quién otorga (puede ser el organizador)
  final String awardedByUserName;
  final String? personalMessage; // Mensaje personal (opcional)
  final DateTime awardedAt;

  Badge({
    required this.id,
    required this.activityId,
    required this.awardedToUserId,
    required this.awardedToUserName,
    required this.awardedToUserImage,
    required this.type,
    required this.title,
    required this.description,
    required this.emoji,
    required this.awardedByUserId,
    required this.awardedByUserName,
    this.personalMessage,
    required this.awardedAt,
  });

  /// Obtiene el emoji basado en el tipo
  static String getEmojiForType(BadgeType type) {
    switch (type) {
      case BadgeType.bestOrganizer:
        return '👑';
      case BadgeType.mostFun:
        return '🎉';
      case BadgeType.superReliable:
        return '✅';
      case BadgeType.bestPhotographer:
        return '📸';
      case BadgeType.mostSpirited:
        return '🔥';
      case BadgeType.helpfulContributor:
        return '🤝';
    }
  }

  /// Obtiene el título basado en el tipo
  static String getTitleForType(BadgeType type) {
    switch (type) {
      case BadgeType.bestOrganizer:
        return 'Mejor Organizador';
      case BadgeType.mostFun:
        return 'El Más Divertido';
      case BadgeType.superReliable:
        return 'Super Cumplido';
      case BadgeType.bestPhotographer:
        return 'Mejor Fotógrafo';
      case BadgeType.mostSpirited:
        return 'El Más Animado';
      case BadgeType.helpfulContributor:
        return 'Excelente Contribuidor';
    }
  }
}

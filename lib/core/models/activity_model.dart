/// Modelo de Actividad para Join
class Activity {
  final String id;
  final String title;
  final String description;
  final String
      category; // 'Deportes', 'Comida', 'Naturaleza', 'Chill', 'Juntas'
  final String imageUrl;
  final double distance; // en km (calculado localmente)
  final String ageRange; // ej: "20-30 años", "Libre"
  final int maxParticipants;
  final int currentParticipants;
  final String organizerId;
  final String organizerName;
  final String organizerImageUrl;
  final double organizerRating; // 0-5
  final int organizerActivities; // Cuántos planes ha hecho
  final DateTime eventDateTime;
  final String location; // alias de locationName
  final String locationName; // nombre legible del lugar
  final double? latitude;
  final double? longitude;
  final List<String> tags;
  final bool isActive;
  // Campos v1.1.0
  final int? durationMinutes;
  final double cost;
  final List<String> contributions;

  const Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.imageUrl = '',
    this.distance = 0.0,
    this.ageRange = 'Libre',
    required this.maxParticipants,
    this.currentParticipants = 0,
    this.organizerId = '',
    required this.organizerName,
    this.organizerImageUrl = '',
    this.organizerRating = 0.0,
    this.organizerActivities = 0,
    required this.eventDateTime,
    this.location = '',
    this.locationName = '',
    this.latitude,
    this.longitude,
    this.tags = const [],
    this.isActive = true,
    this.durationMinutes,
    this.cost = 0.0,
    this.contributions = const [],
  });

  /// Calcula los cupos disponibles
  int get remainingSpots => maxParticipants - currentParticipants;

  /// Verifica si hay cupos disponibles
  bool get hasAvailableSpots => remainingSpots > 0;

  /// Calcula el porcentaje de ocupación (0.0 - 1.0)
  double get occupancyRate => currentParticipants / maxParticipants;

  /// Porcentaje de ocupación como entero (0-100)
  int get occupancyPercentage => (occupancyRate * 100).round();

  /// Si el evento ya pasó
  bool get isPast => eventDateTime.isBefore(DateTime.now());

  /// Crea un Activity desde un mapa JSON
  /// Compatible con el backend PHP (dateTime, locationName, organizerImage)
  /// y con el formato mock anterior (eventDateTime, location, organizerImageUrl)
  factory Activity.fromJson(Map<String, dynamic> json) {
    // Parsear fecha — backend manda 'dateTime', mock mandaba 'eventDateTime'
    final rawDate = (json['dateTime'] ?? json['eventDateTime']) as String?;
    final dateTime = rawDate != null
        ? DateTime.tryParse(rawDate) ?? DateTime.now()
        : DateTime.now();

    // Nombre del lugar
    final locName = (json['locationName'] ?? json['location'] ?? '') as String;

    // Imagen del organizador
    final orgImage =
        (json['organizerImage'] ?? json['organizerImageUrl'] ?? '') as String;

    return Activity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String,
      imageUrl: (json['imageUrl'] ?? '') as String,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      ageRange: json['ageRange'] as String? ?? 'Libre',
      maxParticipants: (json['maxParticipants'] as num?)?.toInt() ?? 1,
      currentParticipants:
          (json['participantCount'] ?? json['currentParticipants'] as num? ?? 0)
              .toInt(),
      organizerId: json['organizerId'] as String? ?? '',
      organizerName: json['organizerName'] as String? ?? '',
      organizerImageUrl: orgImage,
      organizerRating: (json['organizerRating'] as num?)?.toDouble() ?? 0.0,
      organizerActivities: (json['organizerActivities'] as num?)?.toInt() ?? 0,
      eventDateTime: dateTime,
      location: locName,
      locationName: locName,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      tags: _parseTags(json['tags']),
      isActive: json['isActive'] as bool? ?? true,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      contributions: (json['contributions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  static List<String> _parseTags(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return List<String>.from(raw);
    if (raw is String) return raw.split(',').map((s) => s.trim()).toList();
    return [];
  }

  /// Convierte el modelo a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'distance': distance,
      'ageRange': ageRange,
      'maxParticipants': maxParticipants,
      'participantCount': currentParticipants,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'organizerImage': organizerImageUrl,
      'organizerRating': organizerRating,
      'organizerActivities': organizerActivities,
      'dateTime': eventDateTime.toIso8601String(),
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'tags': tags,
      'isActive': isActive,
      'durationMinutes': durationMinutes,
      'cost': cost,
      'contributions': contributions,
    };
  }

  Activity copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    double? distance,
    String? ageRange,
    int? maxParticipants,
    int? currentParticipants,
    String? organizerId,
    String? organizerName,
    String? organizerImageUrl,
    double? organizerRating,
    int? organizerActivities,
    DateTime? eventDateTime,
    String? location,
    String? locationName,
    double? latitude,
    double? longitude,
    List<String>? tags,
    bool? isActive,
    int? durationMinutes,
    double? cost,
    List<String>? contributions,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      distance: distance ?? this.distance,
      ageRange: ageRange ?? this.ageRange,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      organizerImageUrl: organizerImageUrl ?? this.organizerImageUrl,
      organizerRating: organizerRating ?? this.organizerRating,
      organizerActivities: organizerActivities ?? this.organizerActivities,
      eventDateTime: eventDateTime ?? this.eventDateTime,
      location: location ?? this.location,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      cost: cost ?? this.cost,
      contributions: contributions ?? this.contributions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Activity && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Activity(id: $id, title: $title)';
}

import 'package:flutter/material.dart';

/// Configuración global de categorías e iconos para toda la app.
/// Sincronizado con los intereses del onboarding.
class CategoryConstants {
  static const List<String> all = [
    'Deportes',
    'Comida',
    'Naturaleza',
    'Chill',
    'Juntas',
    'Running',
    'Trekking',
    'Ciclismo',
    'Fútbol',
    'Natación',
    'Yoga',
    'Cocina',
    'Gastronomía',
    'Camping',
    'Playa',
    'Arte',
    'Fotografía',
    'Música',
    'Cine',
    'Lectura',
    'Gaming',
    'Viajes',
    'Mascotas',
    'Baile',
    'Juegos',
    'Ajedrez',
    'Skate',
    'Social',
    'Aventura',
    'Fiesta',
  ];

  static const Map<String, IconData> icons = {
    'Deportes': Icons.sports_baseball_rounded,
    'Comida': Icons.restaurant_rounded,
    'Naturaleza': Icons.forest_rounded,
    'Chill': Icons.local_cafe_rounded,
    'Juntas': Icons.celebration_rounded,
    'Running': Icons.directions_run_rounded,
    'Trekking': Icons.hiking_rounded,
    'Ciclismo': Icons.pedal_bike_rounded,
    'Fútbol': Icons.sports_soccer_rounded,
    'Natación': Icons.pool_rounded,
    'Yoga': Icons.self_improvement_rounded,
    'Cocina': Icons.restaurant_menu_rounded,
    'Gastronomía': Icons.outdoor_grill_rounded,
    'Camping': Icons.terrain_rounded,
    'Playa': Icons.beach_access_rounded,
    'Arte': Icons.brush_rounded,
    'Fotografía': Icons.camera_alt_rounded,
    'Música': Icons.music_note_rounded,
    'Cine': Icons.movie_rounded,
    'Lectura': Icons.menu_book_rounded,
    'Gaming': Icons.sports_esports_rounded,
    'Viajes': Icons.flight_rounded,
    'Mascotas': Icons.pets_rounded,
    'Baile': Icons.music_video_rounded,
    'Juegos': Icons.extension_rounded,
    'Ajedrez': Icons.grid_view_rounded,
    'Skate': Icons.skateboarding_rounded,
    'Social': Icons.groups_rounded,
    'Aventura': Icons.explore_rounded,
    'Fiesta': Icons.nightlife_rounded,
    'Para ti': Icons.auto_awesome_rounded,
    'Todos': Icons.category_rounded,
  };

  static const Map<String, Color> colors = {
    'Deportes': Color(0xFFE53935),
    'Comida': Color(0xFFFFA726),
    'Naturaleza': Color(0xFF43A047),
    'Chill': Color(0xFF5E35B1),
    'Juntas': Color(0xFFD81B60),
    'Running': Color(0xFFFF5722),
    'Trekking': Color(0xFF795548),
    'Ciclismo': Color(0xFF009688),
    'Fútbol': Color(0xFF4CAF50),
    'Natación': Color(0xFF03A9F4),
    'Yoga': Color(0xFF673AB7),
    'Cocina': Color(0xFFFF9800),
    'Gastronomía': Color(0xFFE91E63),
    'Camping': Color(0xFF388E3C),
    'Playa': Color(0xFFFFC107),
    'Arte': Color(0xFF9C27B0),
    'Fotografía': Color(0xFF6D4C41),
    'Música': Color(0xFF2196F3),
    'Cine': Color(0xFFF44336),
    'Lectura': Color(0xFF8BC34A),
    'Gaming': Color(0xFF00BCD4),
    'Viajes': Color(0xFF00ACC1),
    'Mascotas': Color(0xFF8D6E63),
    'Baile': Color(0xFFEC407A),
    'Juegos': Color(0xFFAB47BC),
    'Ajedrez': Color(0xFF455A64),
    'Skate': Color(0xFF546E7A),
    'Social': Color(0xFF1E88E5),
    'Aventura': Color(0xFF0097A7),
    'Fiesta': Color(0xFFC2185B),
    'Para ti': Color(0xFFFD7C36),
    'Todos': Color(0xFF607D8B),
  };
}

/// Mapeo entre intereses del usuario y las categorías de actividades.
class InterestMapper {
  static const Map<String, List<String>> _relations = {
    'Running': ['Deportes'],
    'Trekking': ['Deportes', 'Naturaleza', 'Aventura'],
    'Ciclismo': ['Deportes', 'Aventura'],
    'Fútbol': ['Deportes'],
    'Natación': ['Deportes'],
    'Yoga': ['Deportes', 'Chill'],
    'Skate': ['Deportes', 'Aventura'],
    'Cocina': ['Comida', 'Gastronomía'],
    'Gastronomía': ['Comida', 'Cocina'],
    'Camping': ['Naturaleza', 'Aventura'],
    'Playa': ['Naturaleza', 'Chill'],
    'Arte': ['Chill'],
    'Fotografía': ['Chill'],
    'Música': ['Chill', 'Juntas', 'Social'],
    'Cine': ['Chill'],
    'Lectura': ['Chill'],
    'Gaming': ['Juntas', 'Social', 'Juegos'],
    'Viajes': ['Naturaleza', 'Aventura'],
    'Mascotas': ['Naturaleza'],
    'Baile': ['Juntas', 'Social', 'Fiesta'],
    'Juegos': ['Juntas', 'Gaming'],
    'Ajedrez': ['Juntas', 'Chill', 'Juegos'],
    'Aventura': ['Naturaleza', 'Deportes'],
    'Social': ['Juntas', 'Fiesta'],
    'Fiesta': ['Juntas', 'Social'],
  };

  /// Obtiene las categorías relacionadas de forma insensible a mayúsculas.
  static Set<String> getCategoriesForInterests(Iterable<String> interests) {
    final result = <String>{};
    
    // Crear mapa de normalización (minúsculas -> Real Name)
    final normalizationMap = {for (var cat in CategoryConstants.all) cat.toLowerCase(): cat};
    
    for (var interest in interests) {
      final inputLower = interest.trim().toLowerCase();
      final realName = normalizationMap[inputLower];
      
      if (realName != null) {
        // Encontramos la categoría oficial
        result.add(realName);
        
        // Añadir categorías vinculadas/padre (usando el nombre real)
        if (_relations.containsKey(realName)) {
          result.addAll(_relations[realName]!);
        }
        
        // Relación inversa: si me interesa 'Deportes', me interesa 'Running', etc.
        _relations.forEach((sub, parents) {
          if (parents.contains(realName)) {
            result.add(sub);
          }
        });
      }
    }
    return result;
  }
}

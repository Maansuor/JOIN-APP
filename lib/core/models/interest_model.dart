import 'package:flutter/material.dart';

/// Configuración global de categorías e iconos para toda la app.
/// Sincronizado con los intereses del onboarding.
///
/// Los nombres que ya existían se conservan tal cual aunque cambien de grupo:
/// se guardan como texto en user_interests y en activities.category, así que
/// renombrarlos dejaría huérfanos los datos ya creados.
class CategoryConstants {
  /// Agrupación de subcategorías bajo las categorías principales.
  ///
  /// Una actividad marcada sólo con la principal es "general": aparece también
  /// al filtrar por cualquiera de sus subcategorías (vía InterestMapper).
  /// Elegir subcategorías la hace más específica.
  static const Map<String, List<String>> groups = {
    'Deportes': [
      'Running', 'Trekking', 'Ciclismo', 'Fútbol', 'Vóley', 'Básquet',
      'Natación', 'Tenis', 'Gimnasio', 'Yoga', 'Skate',
    ],
    'Comida': [
      'Cocina', 'Gastronomía', 'Parrilladas', 'Cafetería', 'Postres',
    ],
    'Naturaleza': [
      'Camping', 'Playa', 'Viajes', 'Aventura', 'Mascotas', 'Fogata',
    ],
    'Chill': [
      'Cine', 'Series', 'Lectura', 'Arte', 'Fotografía', 'Música',
      'Juegos', 'Ajedrez',
    ],
    'Juntas': [
      'Fiesta', 'Social', 'Baile', 'Karaoke', 'Conciertos', 'Cumpleaños',
    ],
    'Académico': [
      'Estudio', 'Idiomas', 'Programación', 'Ciencia', 'Debate', 'Tutorías',
      'Proyectos',
    ],
    'Juegos online': [
      'Videojuegos', 'Gaming', 'Esports', 'Torneos', 'Rol', 'Streaming',
    ],
  };

  static List<String> get mainCategories => groups.keys.toList();

  /// Todas las categorías, principales y subcategorías, sin repetir.
  ///
  /// Se deriva de [groups] para que añadir una subcategoría no obligue a
  /// acordarse de tocar también esta lista, que era de donde salían los
  /// desajustes entre lo que se ofrecía y lo que se podía filtrar.
  static List<String> get all => [
        for (final entry in groups.entries) ...[entry.key, ...entry.value],
      ];

  static const Map<String, String> mainDescriptions = {
    'Deportes': 'Fútbol, running, trekking, gimnasio, vóley...',
    'Comida': 'Restaurantes, parrilladas, cafés, postres...',
    'Naturaleza': 'Camping, playa, viajes, fogatas, mascotas...',
    'Chill': 'Café, películas, series, lectura, juegos de mesa...',
    'Juntas': 'Fiestas, bailes, karaoke, conciertos, cumpleaños...',
    'Académico': 'Grupos de estudio, idiomas, programación, tutorías...',
    'Juegos online': 'Partidas, torneos, esports, rol, streaming...',
  };

  static const Map<String, IconData> icons = {
    // ── Principales ─────────────────────────────────────────────
    'Deportes': Icons.sports_baseball_rounded,
    'Comida': Icons.restaurant_rounded,
    'Naturaleza': Icons.forest_rounded,
    'Chill': Icons.local_cafe_rounded,
    'Juntas': Icons.celebration_rounded,
    'Académico': Icons.school_rounded,
    'Juegos online': Icons.videogame_asset_rounded,

    // ── Deportes ────────────────────────────────────────────────
    'Running': Icons.directions_run_rounded,
    'Trekking': Icons.hiking_rounded,
    'Ciclismo': Icons.pedal_bike_rounded,
    'Fútbol': Icons.sports_soccer_rounded,
    'Vóley': Icons.sports_volleyball_rounded,
    'Básquet': Icons.sports_basketball_rounded,
    'Natación': Icons.pool_rounded,
    'Tenis': Icons.sports_tennis_rounded,
    'Gimnasio': Icons.fitness_center_rounded,
    'Yoga': Icons.self_improvement_rounded,
    'Skate': Icons.skateboarding_rounded,

    // ── Comida ──────────────────────────────────────────────────
    'Cocina': Icons.restaurant_menu_rounded,
    'Gastronomía': Icons.dinner_dining_rounded,
    'Parrilladas': Icons.outdoor_grill_rounded,
    'Cafetería': Icons.coffee_rounded,
    'Postres': Icons.cake_rounded,

    // ── Naturaleza ──────────────────────────────────────────────
    'Camping': Icons.terrain_rounded,
    'Playa': Icons.beach_access_rounded,
    'Viajes': Icons.flight_rounded,
    'Aventura': Icons.explore_rounded,
    'Mascotas': Icons.pets_rounded,
    'Fogata': Icons.local_fire_department_rounded,

    // ── Chill ───────────────────────────────────────────────────
    'Cine': Icons.movie_rounded,
    'Series': Icons.tv_rounded,
    'Lectura': Icons.menu_book_rounded,
    'Arte': Icons.brush_rounded,
    'Fotografía': Icons.camera_alt_rounded,
    'Música': Icons.music_note_rounded,
    'Juegos': Icons.extension_rounded,
    'Ajedrez': Icons.grid_view_rounded,

    // ── Juntas ──────────────────────────────────────────────────
    'Fiesta': Icons.nightlife_rounded,
    'Social': Icons.groups_rounded,
    'Baile': Icons.music_video_rounded,
    'Karaoke': Icons.mic_rounded,
    'Conciertos': Icons.queue_music_rounded,
    'Cumpleaños': Icons.card_giftcard_rounded,

    // ── Académico ───────────────────────────────────────────────
    'Estudio': Icons.edit_note_rounded,
    'Idiomas': Icons.translate_rounded,
    'Programación': Icons.code_rounded,
    'Ciencia': Icons.science_rounded,
    'Debate': Icons.record_voice_over_rounded,
    'Tutorías': Icons.co_present_rounded,
    'Proyectos': Icons.lightbulb_rounded,

    // ── Juegos online ───────────────────────────────────────────
    'Videojuegos': Icons.sports_esports_rounded,
    'Gaming': Icons.sports_esports_rounded,
    'Esports': Icons.emoji_events_rounded,
    'Torneos': Icons.military_tech_rounded,
    'Rol': Icons.casino_rounded,
    'Streaming': Icons.live_tv_rounded,

    // ── Filtros de la pantalla de inicio ────────────────────────
    'Para ti': Icons.auto_awesome_rounded,
    'Todos': Icons.category_rounded,
  };

  static const Map<String, Color> colors = {
    // ── Principales ─────────────────────────────────────────────
    'Deportes': Color(0xFFE53935),
    'Comida': Color(0xFFFFA726),
    'Naturaleza': Color(0xFF43A047),
    'Chill': Color(0xFF5E35B1),
    'Juntas': Color(0xFFD81B60),
    'Académico': Color(0xFF1565C0),
    'Juegos online': Color(0xFF00897B),

    // ── Deportes ────────────────────────────────────────────────
    'Running': Color(0xFFFF5722),
    'Trekking': Color(0xFF795548),
    'Ciclismo': Color(0xFF009688),
    'Fútbol': Color(0xFF4CAF50),
    'Vóley': Color(0xFFFF7043),
    'Básquet': Color(0xFFEF6C00),
    'Natación': Color(0xFF03A9F4),
    'Tenis': Color(0xFFC0CA33),
    'Gimnasio': Color(0xFF6D4C41),
    'Yoga': Color(0xFF673AB7),
    'Skate': Color(0xFF546E7A),

    // ── Comida ──────────────────────────────────────────────────
    'Cocina': Color(0xFFFF9800),
    'Gastronomía': Color(0xFFE91E63),
    'Parrilladas': Color(0xFFBF360C),
    'Cafetería': Color(0xFF8D6E63),
    'Postres': Color(0xFFF06292),

    // ── Naturaleza ──────────────────────────────────────────────
    'Camping': Color(0xFF388E3C),
    'Playa': Color(0xFFFFC107),
    'Viajes': Color(0xFF00ACC1),
    'Aventura': Color(0xFF0097A7),
    'Mascotas': Color(0xFF8D6E63),
    'Fogata': Color(0xFFE64A19),

    // ── Chill ───────────────────────────────────────────────────
    'Cine': Color(0xFFF44336),
    'Series': Color(0xFF7E57C2),
    'Lectura': Color(0xFF8BC34A),
    'Arte': Color(0xFF9C27B0),
    'Fotografía': Color(0xFF6D4C41),
    'Música': Color(0xFF2196F3),
    'Juegos': Color(0xFFAB47BC),
    'Ajedrez': Color(0xFF455A64),

    // ── Juntas ──────────────────────────────────────────────────
    'Fiesta': Color(0xFFC2185B),
    'Social': Color(0xFF1E88E5),
    'Baile': Color(0xFFEC407A),
    'Karaoke': Color(0xFFAD1457),
    'Conciertos': Color(0xFF7B1FA2),
    'Cumpleaños': Color(0xFFFF4081),

    // ── Académico ───────────────────────────────────────────────
    'Estudio': Color(0xFF1976D2),
    'Idiomas': Color(0xFF0288D1),
    'Programación': Color(0xFF37474F),
    'Ciencia': Color(0xFF00838F),
    'Debate': Color(0xFF5C6BC0),
    'Tutorías': Color(0xFF3949AB),
    'Proyectos': Color(0xFFFFB300),

    // ── Juegos online ───────────────────────────────────────────
    'Videojuegos': Color(0xFF00BCD4),
    'Gaming': Color(0xFF00BCD4),
    'Esports': Color(0xFF00695C),
    'Torneos': Color(0xFF004D40),
    'Rol': Color(0xFF512DA8),
    'Streaming': Color(0xFF6A1B9A),

    // ── Filtros de la pantalla de inicio ────────────────────────
    'Para ti': Color(0xFFFD7C36),
    'Todos': Color(0xFF607D8B),
  };

  /// Categoría principal a la que pertenece [categoria], o ella misma si ya
  /// es principal. Devuelve null si no se reconoce.
  ///
  /// Acepta también la lista separada por comas que guarda una actividad
  /// ("Deportes,Fútbol"), quedándose con la primera que reconozca.
  static String? mainCategoryOf(String categoria) {
    for (final parte in categoria.split(',').map((c) => c.trim().toLowerCase())) {
      if (parte.isEmpty) continue;
      for (final entry in groups.entries) {
        // Sin distinguir mayúsculas: la categoría puede venir de un seed, de
        // una importación o escrita a mano, no sólo del selector de la app.
        if (entry.key.toLowerCase() == parte) return entry.key;
        if (entry.value.any((sub) => sub.toLowerCase() == parte)) return entry.key;
      }
    }
    return null;
  }

  /// Deja una selección de categorías en la forma que espera el formulario:
  /// exactamente una principal y sólo subcategorías suyas.
  ///
  /// Hace falta porque los planes creados antes podían guardar varias
  /// principales, y porque una actividad puede llegar con subcategorías de
  /// ramas distintas. Se conserva la primera principal reconocida.
  static Set<String> normalizeSelection(Iterable<String> seleccion) {
    final limpias = seleccion.map((c) => c.trim()).where((c) => c.isNotEmpty);

    String? principal;
    for (final nombre in limpias) {
      principal = mainCategoryOf(nombre);
      if (principal != null) break;
    }
    principal ??= mainCategories.first;

    final subsValidas = groups[principal] ?? const <String>[];
    return {principal, ...limpias.where(subsValidas.contains)};
  }

  static const String _dir = 'assets/images/activities';

  /// Portadas sugeridas por categoría; la primera es la que se usa por defecto.
  ///
  /// Se eligieron pensando en que representen a **toda** la categoría y no a
  /// una actividad suelta, y que salgan grupos: Join va de planes en común, así
  /// que una silueta en solitario contradice la propia premisa de la app.
  static const Map<String, List<String>> covers = {
    'Deportes': [
      '$_dir/cover_deportes.jpg',
      '$_dir/activity_5_cycling.jpg',
      '$_dir/activity_4_yoga.jpg',
    ],
    'Comida': [
      '$_dir/cover_comida.jpg',
      '$_dir/activity_8_dinner.jpg',
      '$_dir/activity_3_bbq.jpg',
    ],
    'Naturaleza': [
      '$_dir/cover_naturaleza.jpg',
      '$_dir/activity_7_climbing.jpg',
      '$_dir/activity_1_hiking.jpg',
    ],
    'Chill': [
      '$_dir/cover_chill.jpg',
      '$_dir/activity_6_picnic.jpg',
    ],
    'Juntas': [
      '$_dir/cover_juntas.jpg',
      '$_dir/activity_6_picnic.jpg',
    ],
    'Académico': [
      '$_dir/cover_academico.jpg',
    ],
    'Juegos online': [
      '$_dir/cover_juegos_online.jpg',
    ],
  };

  /// Portadas que se le ofrecen a quien crea una actividad de [categoria].
  ///
  /// Primero las de su categoría y después el resto, para que siempre haya
  /// de dónde elegir aunque la categoría tenga pocas.
  static List<String> coversFor(String categoria) {
    final principal = mainCategoryOf(categoria);
    final propias = covers[principal] ?? const <String>[];
    final resto = [
      for (final entry in covers.entries)
        if (entry.key != principal) ...entry.value,
    ];
    // Un mismo archivo puede estar sugerido en dos categorías.
    return {...propias, ...resto}.toList();
  }

  /// Portada por defecto para [categoria] cuando no se eligió ninguna.
  static String defaultCoverFor(String categoria) {
    final principal = mainCategoryOf(categoria);
    final propias = covers[principal];
    if (propias != null && propias.isNotEmpty) return propias.first;
    return covers['Juntas']!.first;
  }
}

/// Mapeo entre intereses del usuario y las categorías de actividades.
class InterestMapper {
  /// Relaciones extra entre categorías que no se deducen de la jerarquía.
  ///
  /// La pertenencia a la categoría principal ya la aporta
  /// [CategoryConstants.groups]; aquí sólo se declaran los cruces entre ramas
  /// distintas, como que el trekking también sea naturaleza.
  static const Map<String, List<String>> _crossRelations = {
    'Trekking': ['Naturaleza', 'Aventura'],
    'Ciclismo': ['Aventura'],
    'Skate': ['Aventura'],
    'Yoga': ['Chill'],
    'Cocina': ['Gastronomía'],
    'Gastronomía': ['Cocina'],
    'Parrilladas': ['Juntas'],
    'Cafetería': ['Chill'],
    'Camping': ['Aventura', 'Fogata'],
    'Playa': ['Chill'],
    'Fogata': ['Camping', 'Juntas'],
    'Viajes': ['Aventura'],
    'Música': ['Juntas', 'Conciertos'],
    'Juegos': ['Juntas', 'Ajedrez'],
    'Ajedrez': ['Chill', 'Juegos'],
    'Baile': ['Fiesta', 'Social'],
    'Karaoke': ['Fiesta', 'Música'],
    'Conciertos': ['Música', 'Fiesta'],
    'Cumpleaños': ['Fiesta', 'Social'],
    'Social': ['Fiesta'],
    'Fiesta': ['Social'],
    'Aventura': ['Naturaleza', 'Deportes'],
    'Programación': ['Proyectos'],
    'Proyectos': ['Programación', 'Ciencia'],
    'Estudio': ['Tutorías'],
    'Tutorías': ['Estudio'],
    'Videojuegos': ['Gaming', 'Esports'],
    'Gaming': ['Videojuegos', 'Esports'],
    'Esports': ['Torneos', 'Videojuegos'],
    'Torneos': ['Esports'],
    'Streaming': ['Videojuegos'],
    'Rol': ['Juegos'],
  };

  /// Categorías relacionadas con los intereses dados, sin distinguir
  /// mayúsculas ni acentos de más.
  ///
  /// Incluye: el propio interés, su categoría principal, las relaciones
  /// cruzadas y, si el interés es una categoría principal, sus subcategorías.
  static Set<String> getCategoriesForInterests(Iterable<String> interests) {
    final result = <String>{};
    final normalizacion = {
      for (final cat in CategoryConstants.all) cat.toLowerCase(): cat,
    };

    for (final interest in interests) {
      final nombreReal = normalizacion[interest.trim().toLowerCase()];
      if (nombreReal == null) continue;

      result.add(nombreReal);

      // Su categoría principal.
      final principal = CategoryConstants.mainCategoryOf(nombreReal);
      if (principal != null) result.add(principal);

      // Si es una principal, también todas sus subcategorías.
      final subcategorias = CategoryConstants.groups[nombreReal];
      if (subcategorias != null) result.addAll(subcategorias);

      // Cruces entre ramas distintas.
      result.addAll(_crossRelations[nombreReal] ?? const []);
    }

    return result;
  }
}

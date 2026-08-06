/// Conocimiento geográfico del Perú que Join usa para decidir qué actividades
/// le quedan cerca a una persona.
///
/// Las ciudades llegan del geocodificador como texto libre ("El Tambo,
/// Huancayo"), no como identificadores, así que la cercanía se deduce
/// comparando distrito, provincia y región por palabras clave.
///
/// Vive aquí y no dentro de AppState porque el repositorio de actividades
/// necesita las mismas listas para filtrar en la consulta a Supabase: cuando
/// estaban duplicadas, añadir un distrito obligaba a recordar tocar dos
/// archivos.
class PeruGeography {
  PeruGeography._();

  /// Identificador de región para lugares que no reconocemos.
  static const String otherRegion = 'other';

  /// Palabras clave por región. Se comparan en minúsculas y sin exigir
  /// coincidencia exacta: basta con que aparezcan dentro del nombre.
  static const Map<String, List<String>> regionKeywords = {
    'junin': [
      'junin', 'junín', 'huancayo', 'tambo', 'chilca', 'jauja', 'tarma',
      'chupaca', 'concepcion', 'concepción', 'satipo', 'chanchamayo',
      'la merced', 'san ramon', 'san ramón', 'oroya', 'yauli', 'sicaya',
      'pilcomayo', 'sapallanga', 'cajas',
    ],
    'lima': [
      'lima', 'callao', 'miraflores', 'san isidro', 'lince', 'surco', 'san borja',
      'molina', 'barranco', 'chorrillos', 'rimac', 'rímac', 'breña', 'san miguel',
      'magdalena', 'pueblo libre', 'ate', 'victoria', 'surquillos', 'san martin',
      'comas', 'carabayllo', 'olivos', 'puente piedra', 'lurigancho', 'chosica',
      'vitarte', 'manchay', 'pachacamac', 'cieneguilla', 'lurin', 'lurín',
      'villa el salvador', 'villa maria', 'sanjuan',
    ],
    'arequipa': [
      'arequipa', 'cayma', 'yanahuara', 'bustamante', 'selva alegre', 'socabaya',
      'sachaca', 'miraflores arequipa',
    ],
    'cusco': [
      'cusco', 'cuzco', 'wanchaq', 'san sebastian', 'san sebastián', 'santiago',
      'poroy',
    ],
    'lambayeque': [
      'chiclayo', 'lambayeque', 'ferreñafe', 'pimentel', 'leonardo ortiz',
    ],
  };

  /// Nombre canónico con el que se guardan en la base de datos las actividades
  /// de cada región, para poder incluirlas en el filtro por ciudad.
  static const Map<String, String> canonicalRegionName = {
    'junin': 'Junín',
  };

  /// Región a la que pertenece [location], u [otherRegion] si no se reconoce.
  static String regionOf(String location) {
    final clean = location.toLowerCase();
    for (final entry in regionKeywords.entries) {
      if (entry.value.any(clean.contains)) return entry.key;
    }
    return otherRegion;
  }

  /// Región de un usuario a partir de su ciudad completa, su distrito y su
  /// provincia, que es como las tiene desglosadas el repositorio.
  static String regionOfParts({
    required String city,
    String district = '',
    String province = '',
  }) {
    for (final candidate in [city, district, province]) {
      if (candidate.isEmpty) continue;
      final region = regionOf(candidate);
      if (region != otherRegion) return region;
    }
    return otherRegion;
  }

  /// Cuánto de cerca le queda [activityLocation] a alguien que está en
  /// [userLocation]. Menor es más cerca; 100 significa "otra zona".
  ///
  /// 0 misma cadena · 1 mismo distrito · 2 misma provincia · 3 misma región.
  static int proximityScore(String userLocation, String? activityLocation) {
    if (activityLocation == null || activityLocation.isEmpty) return 100;

    final cleanUser = userLocation.toLowerCase().trim();
    final cleanActivity = activityLocation.toLowerCase().trim();

    if (cleanUser == cleanActivity) return 0;

    // "El Tambo, Huancayo" -> distrito "el tambo", provincia "huancayo"
    final userParts = cleanUser.split(',').map((s) => s.trim()).toList();
    final userDistrict = userParts.isNotEmpty ? userParts[0] : '';
    final userParent = userParts.length > 1 ? userParts[1] : '';

    final activityParts = cleanActivity.split(',').map((s) => s.trim()).toList();
    final activityDistrict = activityParts.isNotEmpty ? activityParts[0] : '';
    final activityParent = activityParts.length > 1 ? activityParts[1] : '';

    if (userDistrict.isNotEmpty &&
        (activityDistrict == userDistrict || cleanActivity.contains(userDistrict))) {
      return 1;
    }

    if (userParent.isNotEmpty &&
        (activityDistrict == userParent ||
            activityParent == userParent ||
            cleanActivity.contains(userParent))) {
      return 2;
    }

    final userRegion = regionOf(cleanUser);
    if (userRegion != otherRegion && userRegion == regionOf(cleanActivity)) {
      return 3;
    }

    // Último recurso: comparten el nombre de la provincia.
    if (userParent.isNotEmpty && cleanActivity.contains(userParent)) return 3;
    if (activityParent.isNotEmpty && cleanUser.contains(activityParent)) return 3;

    return 100;
  }

  /// ¿Las dos ubicaciones son lo bastante cercanas para mostrarse juntas?
  static bool areNearby(String userLocation, String? activityLocation) =>
      proximityScore(userLocation, activityLocation) < 100;
}

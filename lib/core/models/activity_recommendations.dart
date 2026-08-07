import 'interest_model.dart';

/// Qué conviene llevar o preparar para cada tipo de plan.
///
/// Es la única fuente de recomendaciones de la app: la usan tanto los atajos
/// que se le ofrecen al anfitrión al crear el plan como la lista de la iguana
/// que ve cada participante. Antes eran dos listas separadas, con contenidos
/// distintos para la misma actividad y sin las categorías nuevas.
///
/// Las recomendaciones se guardan sin emoji: cada pantalla decide si lo añade,
/// con [emojiFor].
class ActivityRecommendations {
  ActivityRecommendations._();

  /// Lo que sirve para cualquier plan, cuando no reconocemos la categoría.
  static const List<String> generic = [
    'Celular cargado',
    'Agua',
    'Puntualidad',
    'Buena actitud',
  ];

  /// Recomendaciones por categoría. Las de subcategoría mandan sobre las de su
  /// principal: para una pichanga es más útil "chimpunes" que "ropa deportiva".
  static const Map<String, List<String>> byCategory = {
    // ══ Deportes ═══════════════════════════════════════════════
    'Deportes': ['Ropa deportiva', 'Zapatillas', 'Agua', 'Toalla'],
    'Running': ['Zapatillas de running', 'Ropa transpirable', 'Agua', 'Estiramiento previo'],
    'Trekking': ['Zapatillas de trekking', 'Agua 1.5L', 'Bloqueador', 'Gorra', 'Snacks energéticos', 'Casaca ligera'],
    'Ciclismo': ['Casco', 'Bici revisada', 'Kit de parchado', 'Agua', 'Guantes'],
    'Fútbol': ['Chimpunes', 'Ropa deportiva', 'Canilleras', 'Agua'],
    'Vóley': ['Rodilleras', 'Zapatillas', 'Ropa cómoda', 'Agua'],
    'Básquet': ['Zapatillas de básquet', 'Ropa deportiva', 'Agua', 'Muñequera'],
    'Natación': ['Ropa de baño', 'Gorro de natación', 'Lentes de nadar', 'Toalla', 'Sandalias'],
    'Tenis': ['Raqueta', 'Pelotas', 'Zapatillas', 'Gorra', 'Agua'],
    'Gimnasio': ['Ropa deportiva', 'Toalla', 'Candado para el locker', 'Agua'],
    'Yoga': ['Mat', 'Ropa cómoda', 'Toalla pequeña', 'Agua'],
    'Skate': ['Patineta', 'Casco', 'Rodilleras', 'Agua'],

    // ══ Comida ═════════════════════════════════════════════════
    'Comida': ['Buen apetito', 'Efectivo o Yape', 'Bebida para compartir'],
    'Cocina': ['Delantal', 'Los ingredientes que te tocan', 'Tupper para llevar'],
    'Gastronomía': ['Efectivo o Yape', 'Buen apetito', 'Reserva confirmada'],
    'Parrilladas': ['Tu aporte a la parrilla', 'Bebidas frías', 'Hielo', 'Carbón'],
    'Cafetería': ['Efectivo o Yape', 'Laptop o un libro', 'Tema de conversación'],
    'Postres': ['Tu postre para compartir', 'Tupper', 'Antojo listo'],

    // ══ Naturaleza ═════════════════════════════════════════════
    'Naturaleza': ['Ropa por capas', 'Bloqueador', 'Repelente', 'Agua'],
    'Camping': ['Carpa', 'Sleeping', 'Linterna', 'Repelente', 'Abrigo para la noche', 'Agua', 'Snacks'],
    'Playa': ['Bloqueador', 'Toalla', 'Ropa de baño', 'Lentes de sol', 'Agua'],
    'Viajes': ['DNI', 'Efectivo', 'Cargador', 'Mochila ligera', 'Snacks'],
    'Aventura': ['Zapatillas con buen agarre', 'Mochila pequeña', 'Bloqueador', 'Agua'],
    'Mascotas': ['Correa', 'Bolsitas', 'Agua para tu mascota', 'Premios'],
    'Fogata': ['Abrigo', 'Leña o carbón', 'Malvaviscos', 'Linterna'],

    // ══ Chill ══════════════════════════════════════════════════
    'Chill': ['Puntualidad', 'Buena vibra', 'Snack para compartir'],
    'Cine': ['Efectivo o Yape', 'Snack', 'Llegar antes de que empiece'],
    'Series': ['Snacks', 'Manta', 'Ponerse cómodo'],
    'Lectura': ['Tu libro', 'Marcador', 'Ganas de comentar'],
    'Arte': ['Materiales', 'Ropa que puedas manchar', 'Referencias'],
    'Fotografía': ['Cámara o celular cargado', 'Batería extra', 'Memoria libre'],
    'Música': ['Audífonos', 'Playlist lista', 'Tu instrumento si tocas'],
    'Juegos': ['Tu juego de mesa favorito', 'Snacks', 'Paciencia'],
    'Ajedrez': ['Tablero', 'Reloj si juegan con tiempo', 'Concentración'],

    // ══ Juntas ═════════════════════════════════════════════════
    'Juntas': ['Bebidas', 'Snacks', 'Playlist', 'Energía al 100'],
    'Fiesta': ['Tu aporte', 'Ropa cómoda para bailar', 'Cargador', 'Movilidad de regreso'],
    'Social': ['Puntualidad', 'Tema de conversación', 'Buena actitud'],
    'Baile': ['Ropa cómoda', 'Zapatos para bailar', 'Toalla pequeña', 'Agua'],
    'Karaoke': ['Tu canción elegida', 'Garganta lista', 'Agua', 'Cero vergüenza'],
    'Conciertos': ['Entrada', 'DNI', 'Efectivo', 'Tapones para los oídos', 'Cargador'],
    'Cumpleaños': ['Regalo o aporte', 'Buena energía', 'Cámara'],

    // ══ Académico ══════════════════════════════════════════════
    'Académico': ['Laptop cargada', 'Cuaderno y lapicero', 'Material del curso', 'Agua'],
    'Estudio': ['Material del curso', 'Cuaderno', 'Audífonos', 'Snack ligero'],
    'Idiomas': ['Cuaderno', 'Ganas de hablar sin miedo', 'Diccionario o app'],
    'Programación': ['Laptop cargada', 'Cargador', 'Entorno ya instalado', 'Repositorio clonado'],
    'Ciencia': ['Calculadora', 'Cuaderno', 'Material de laboratorio'],
    'Debate': ['Tema investigado', 'Argumentos preparados', 'Mente abierta'],
    'Tutorías': ['Tus dudas anotadas', 'Material del curso', 'Cuaderno'],
    'Proyectos': ['Laptop', 'Tus avances listos', 'Tareas repartidas'],

    // ══ Juegos online ══════════════════════════════════════════
    'Juegos online': ['Cuenta lista', 'Internet estable', 'Audífonos con micro', 'Cargador'],
    'Videojuegos': ['Juego instalado y actualizado', 'Cuenta lista', 'Audífonos con micro'],
    'Gaming': ['Juego instalado y actualizado', 'Cuenta lista', 'Audífonos con micro'],
    'Esports': ['Equipo listo', 'Juego actualizado', 'Audífonos', 'Puntualidad para la partida'],
    'Torneos': ['Inscripción confirmada', 'Cuenta lista', 'Reglas leídas', 'Puntualidad'],
    'Rol': ['Ficha de personaje', 'Dados', 'Libreta', 'Imaginación'],
    'Streaming': ['Internet estable', 'Micrófono', 'Buena luz', 'Escena preparada'],
  };

  /// Recomendaciones para una actividad, de lo más específico a lo más general.
  ///
  /// Recorre las categorías del plan quedándose primero con las de
  /// subcategoría, que son las útiles de verdad: para una pichanga interesa
  /// "chimpunes", no "ropa deportiva".
  static List<String> forCategories(Iterable<String> categorias) {
    final principales = <String>[];
    final especificas = <String>[];

    for (final bruta in categorias) {
      for (final nombre in bruta.split(',').map((c) => c.trim())) {
        if (nombre.isEmpty) continue;
        final recomendaciones = byCategory[nombre];
        if (recomendaciones == null) continue;

        // Las principales van al final, como respaldo.
        if (CategoryConstants.groups.containsKey(nombre)) {
          principales.addAll(recomendaciones);
        } else {
          especificas.addAll(recomendaciones);
        }
      }
    }

    final resultado = <String>{...especificas, ...principales};
    return resultado.isEmpty ? generic : resultado.toList();
  }

  /// Atajos que se le sugieren al anfitrión al crear el plan.
  static List<String> quickPicksFor(Iterable<String> categorias) =>
      forCategories(categorias).take(8).toList();

  /// Emoji que acompaña a una recomendación, según lo que menciona.
  static String emojiFor(String text) {
    final lower = text.toLowerCase();

    // ── Calzado y ropa ────────────────────────────────────────
    if (lower.contains('chimpun') || lower.contains('zapati') || lower.contains('calzado') || lower.contains('bota')) return '👟';
    if (lower.contains('ropa de baño') || lower.contains('bañador')) return '🩳';
    if (lower.contains('ropa') || lower.contains('abrigo') || lower.contains('chaqueta') || lower.contains('casaca') || lower.contains('capas')) return '🧥';
    if (lower.contains('delantal')) return '🦺';
    if (lower.contains('gorra') || lower.contains('sombrero') || lower.contains('gorro')) return '🧢';
    if (lower.contains('lentes')) return '🕶️';

    // ── Protección y salud ────────────────────────────────────
    if (lower.contains('bloqueador') || lower.contains('solar') || lower.contains('protector')) return '🧴';
    if (lower.contains('repelente') || lower.contains('insecto')) return '🦟';
    if (lower.contains('casco') || lower.contains('rodillera') || lower.contains('canillera') || lower.contains('muñequera')) return '🛡️';
    if (lower.contains('tapones')) return '🎧';
    if (lower.contains('estiramiento')) return '🤸';

    // ── Equipo ────────────────────────────────────────────────
    if (lower.contains('carpa')) return '⛺';
    if (lower.contains('sleeping')) return '🛌';
    if (lower.contains('linterna') || lower.contains('frontal')) return '🔦';
    if (lower.contains('mat')) return '🧘';
    if (lower.contains('bici') || lower.contains('parchado')) return '🚲';
    if (lower.contains('patineta')) return '🛹';
    if (lower.contains('raqueta') || lower.contains('pelota')) return '🎾';
    if (lower.contains('correa') || lower.contains('mascota') || lower.contains('premios') || lower.contains('bolsitas')) return '🐾';
    if (lower.contains('sandalia')) return '🩴';
    if (lower.contains('candado') || lower.contains('locker')) return '🔐';
    if (lower.contains('leña') || lower.contains('carbón') || lower.contains('fogata')) return '🔥';
    if (lower.contains('sombrilla')) return '⛱️';
    if (lower.contains('toalla')) return '🧻';
    if (lower.contains('mochila') || lower.contains('bolso') || lower.contains('morral')) return '🎒';
    if (lower.contains('guantes')) return '🧤';

    // ── Académico y digital ───────────────────────────────────
    if (lower.contains('laptop') || lower.contains('repositorio') || lower.contains('entorno')) return '💻';
    if (lower.contains('cuaderno') || lower.contains('libreta') || lower.contains('lapicero') || lower.contains('material del curso')) return '📓';
    if (lower.contains('marcador')) return '🔖';
    if (lower.contains('libro') || lower.contains('diccionario')) return '📚';
    if (lower.contains('calculadora')) return '🧮';
    if (lower.contains('laboratorio')) return '🔬';
    if (lower.contains('dudas') || lower.contains('argumento') || lower.contains('investigado') || lower.contains('mente abierta')) return '💭';
    if (lower.contains('avances') || lower.contains('tareas repartidas')) return '📋';
    if (lower.contains('cargador') || lower.contains('batería')) return '🔌';
    if (lower.contains('internet') || lower.contains('conexión')) return '📶';
    if (lower.contains('cuenta') || lower.contains('inscripción') || lower.contains('juego instalado') || lower.contains('actualizado') || lower.contains('equipo listo')) return '🎮';
    if (lower.contains('audífonos') || lower.contains('micro')) return '🎧';
    if (lower.contains('dados') || lower.contains('ficha de personaje')) return '🎲';
    if (lower.contains('memoria') || lower.contains('cámara') || lower.contains('foto')) return '📸';
    if (lower.contains('luz')) return '🔆';
    if (lower.contains('escena')) return '🎬';
    if (lower.contains('micrófono') || lower.contains('microfono')) return '🎙️';
    if (lower.contains('reglas')) return '📜';
    if (lower.contains('imaginación')) return '✨';

    // ── Comida y bebida ───────────────────────────────────────
    if (lower.contains('agua') || lower.contains('hidrat')) return '💧';
    if (lower.contains('hielo')) return '🧊';
    if (lower.contains('malvavisco')) return '🍡';
    if (lower.contains('postre')) return '🍰';
    if (lower.contains('parrilla') || lower.contains('apetito')) return '🍖';
    if (lower.contains('ingrediente') || lower.contains('tupper')) return '🥘';
    if (lower.contains('bebida') || lower.contains('gaseosa') || lower.contains('trago')) return '🥤';
    if (lower.contains('snack') || lower.contains('piqueo') || lower.contains('antojo')) return '🍿';

    // ── Logística y actitud ───────────────────────────────────
    if (lower.contains('dni') || lower.contains('entrada') || lower.contains('reserva')) return '🎟️';
    if (lower.contains('dinero') || lower.contains('efectivo') || lower.contains('yape') || lower.contains('cambio')) return '💰';
    if (lower.contains('regalo')) return '🎁';
    if (lower.contains('aporte')) return '🤝';
    if (lower.contains('puntual') || lower.contains('hora') || lower.contains('temprano') || lower.contains('empiece')) return '⏰';
    if (lower.contains('movilidad') || lower.contains('estacion')) return '🚌';
    if (lower.contains('manta') || lower.contains('cómodo')) return '🛋️';
    if (lower.contains('playlist') || lower.contains('música') || lower.contains('canción') || lower.contains('parlante') || lower.contains('instrumento')) return '🎵';
    if (lower.contains('bailar')) return '💃';
    if (lower.contains('garganta') || lower.contains('vergüenza')) return '🎤';
    if (lower.contains('juego de mesa') || lower.contains('tablero') || lower.contains('cartas')) return '🎲';
    if (lower.contains('reloj') || lower.contains('concentración') || lower.contains('paciencia') || lower.contains('silencio')) return '🧠';
    if (lower.contains('vibra') || lower.contains('actitud') || lower.contains('energ') || lower.contains('ganas')) return '⚡';
    if (lower.contains('celular')) return '📱';
    if (lower.contains('conversación') || lower.contains('comentar') || lower.contains('hablar')) return '💬';
    if (lower.contains('referencias') || lower.contains('materiales')) return '🎨';

    return '💡';
  }

  /// Recomendación con su emoji al final, tal como se muestra.
  static String withEmoji(String text) => '$text ${emojiFor(text)}';
}

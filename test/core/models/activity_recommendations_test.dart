import 'package:flutter_test/flutter_test.dart';
import 'package:join_app/core/models/activity_recommendations.dart';
import 'package:join_app/core/models/interest_model.dart';

void main() {
  group('cobertura de categorías', () {
    test('toda categoría y subcategoría tiene recomendaciones propias', () {
      for (final nombre in CategoryConstants.all) {
        final recomendaciones = ActivityRecommendations.byCategory[nombre];
        expect(recomendaciones, isNotNull, reason: 'faltan para $nombre');
        expect(recomendaciones, isNotEmpty, reason: 'vacías para $nombre');
      }
    });

    test('ninguna categoría cae en el genérico', () {
      for (final nombre in CategoryConstants.all) {
        expect(
          ActivityRecommendations.forCategories([nombre]),
          isNot(ActivityRecommendations.generic),
          reason: '$nombre está cayendo en el genérico',
        );
      }
    });

    test('las categorías nuevas tienen recomendaciones con sentido', () {
      expect(
        ActivityRecommendations.forCategories(['Programación']),
        contains('Laptop cargada'),
      );
      expect(
        ActivityRecommendations.forCategories(['Esports']),
        contains('Audífonos'),
      );
    });
  });

  group('forCategories', () {
    test('lo específico va antes que lo general', () {
      // Una pichanga necesita chimpunes, no el genérico "ropa deportiva".
      final resultado = ActivityRecommendations.forCategories(['Deportes, Fútbol']);
      expect(resultado.first, 'Chimpunes');
      expect(resultado, contains('Ropa deportiva')); // La principal sigue estando
      expect(resultado.indexOf('Chimpunes'),
          lessThan(resultado.indexOf('Ropa deportiva')));
    });

    test('acepta la lista separada por comas de una actividad', () {
      final resultado = ActivityRecommendations.forCategories(['Naturaleza, Camping']);
      expect(resultado, contains('Carpa'));
    });

    test('combina varias categorías sin repetir', () {
      final resultado = ActivityRecommendations.forCategories(['Playa', 'Trekking']);
      expect(resultado.length, resultado.toSet().length);
      expect(resultado, contains('Toalla'));
      expect(resultado, contains('Zapatillas de trekking'));
    });

    test('una categoría desconocida devuelve el genérico', () {
      expect(
        ActivityRecommendations.forCategories(['Submarinismo lunar']),
        ActivityRecommendations.generic,
      );
    });

    test('sin categorías devuelve el genérico', () {
      expect(ActivityRecommendations.forCategories([]), ActivityRecommendations.generic);
    });
  });

  group('quickPicksFor', () {
    test('no abruma: como mucho ocho atajos', () {
      final atajos = ActivityRecommendations.quickPicksFor(
        ['Deportes', 'Comida', 'Naturaleza', 'Chill', 'Juntas'],
      );
      expect(atajos.length, lessThanOrEqualTo(8));
    });

    test('empieza por lo específico de la categoría elegida', () {
      final atajos = ActivityRecommendations.quickPicksFor(['Karaoke']);
      expect(atajos.first, 'Tu canción elegida');
    });
  });

  group('emojiFor', () {
    test('reconoce términos de las categorías nuevas', () {
      expect(ActivityRecommendations.emojiFor('Laptop cargada'), '💻');
      expect(ActivityRecommendations.emojiFor('Dados'), '🎲');
      expect(ActivityRecommendations.emojiFor('Audífonos con micro'), '🎧');
      expect(ActivityRecommendations.emojiFor('Internet estable'), '📶');
      expect(ActivityRecommendations.emojiFor('Cuaderno y lapicero'), '📓');
    });

    test('sigue reconociendo los de siempre', () {
      expect(ActivityRecommendations.emojiFor('Agua'), '💧');
      expect(ActivityRecommendations.emojiFor('Bloqueador'), '🧴');
      expect(ActivityRecommendations.emojiFor('Zapatillas'), '👟');
    });

    test('lo desconocido recibe el emoji de idea', () {
      expect(ActivityRecommendations.emojiFor('algo rarísimo'), '💡');
    });

    test('ninguna recomendación se queda sin emoji propio', () {
      // Si muchas caen en el comodín, la tabla se quedó corta.
      final todas = ActivityRecommendations.byCategory.values.expand((r) => r).toSet();
      final sinEmojiPropio =
          todas.where((r) => ActivityRecommendations.emojiFor(r) == '💡').toList();

      expect(sinEmojiPropio, isEmpty,
          reason: 'sin emoji propio: ${sinEmojiPropio.join(", ")}');
    });
  });

  group('withEmoji', () {
    test('deja el emoji al final del texto', () {
      expect(ActivityRecommendations.withEmoji('Agua'), 'Agua 💧');
    });
  });
}

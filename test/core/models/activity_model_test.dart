import 'package:flutter_test/flutter_test.dart';
import 'package:join_app/core/models/activity_model.dart';

void main() {
  group('portada por defecto', () {
    test('elige la imagen según la categoría', () {
      expect(defaultImageForCategory('Deportes'), contains('cover_deportes'));
      expect(defaultImageForCategory('Comida'), contains('cover_comida'));
      expect(defaultImageForCategory('Naturaleza'), contains('cover_naturaleza'));
      expect(defaultImageForCategory('Chill'), contains('cover_chill'));
      expect(defaultImageForCategory('Juntas'), contains('cover_juntas'));
      expect(defaultImageForCategory('Académico'), contains('cover_academico'));
      expect(defaultImageForCategory('Juegos online'), contains('cover_juegos_online'));
    });

    test('reconoce la categoría sin distinguir mayúsculas ni espacios', () {
      expect(defaultImageForCategory('  DEPORTES  '), contains('cover_deportes'));
    });

    test('una subcategoría hereda la portada de su principal', () {
      expect(defaultImageForCategory('Fútbol'), contains('cover_deportes'));
      expect(defaultImageForCategory('Programación'), contains('cover_academico'));
    });

    test('una categoría desconocida sigue devolviendo una imagen válida', () {
      final img = defaultImageForCategory('categoría inventada');
      expect(img, startsWith('assets/'));
      expect(img, isNotEmpty);
    });

    test('sin categoría también devuelve una imagen', () {
      expect(defaultImageForCategory(''), startsWith('assets/'));
    });
  });

  group('Activity.fromJson', () {
    test('una actividad sin portada recibe la de su categoría', () {
      // Es el caso de las filas creadas por un seed o una migración: dejaban
      // imageUrl vacío y los Image.asset de la interfaz fallaban.
      final actividad = Activity.fromJson(_fila(category: 'Deportes'));

      expect(actividad.imageUrl, isNotEmpty);
      expect(actividad.imageUrl, contains('cover_deportes'));
    });

    test('nunca deja la portada vacía, sea cual sea la categoría', () {
      for (final categoria in ['Deportes', 'Comida', 'Naturaleza', 'Chill', 'Juntas', 'otra']) {
        final actividad = Activity.fromJson(_fila(category: categoria));
        expect(actividad.imageUrl, isNotEmpty, reason: 'categoría $categoria');
      }
    });

    test('respeta la portada propia cuando existe', () {
      final actividad = Activity.fromJson(
        _fila(category: 'Deportes', coverUrl: 'https://ejemplo.test/mi-foto.jpg'),
      );

      expect(actividad.imageUrl, 'https://ejemplo.test/mi-foto.jpg');
    });
  });
}

Map<String, dynamic> _fila({required String category, String? coverUrl}) {
  return {
    'id': 'act-1',
    'title': 'Actividad de prueba',
    'category': category,
    'event_datetime': DateTime(2026, 8, 8).toIso8601String(),
    if (coverUrl != null) 'cover_image_url': coverUrl,
  };
}

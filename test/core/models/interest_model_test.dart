import 'package:flutter_test/flutter_test.dart';
import 'package:join_app/core/models/interest_model.dart';

void main() {
  group('estructura de categorías', () {
    test('están las siete categorías principales', () {
      expect(
        CategoryConstants.mainCategories,
        containsAll(['Deportes', 'Comida', 'Naturaleza', 'Chill', 'Juntas',
                     'Académico', 'Juegos online']),
      );
    });

    test('cada categoría y subcategoría tiene icono y color', () {
      for (final nombre in CategoryConstants.all) {
        expect(CategoryConstants.icons[nombre], isNotNull, reason: 'icono de $nombre');
        expect(CategoryConstants.colors[nombre], isNotNull, reason: 'color de $nombre');
      }
    });

    test('cada categoría principal tiene descripción', () {
      for (final principal in CategoryConstants.mainCategories) {
        expect(CategoryConstants.mainDescriptions[principal], isNotNull,
            reason: 'descripción de $principal');
      }
    });

    test('ninguna subcategoría está en dos categorías a la vez', () {
      final vistas = <String, String>{};
      CategoryConstants.groups.forEach((principal, subs) {
        for (final sub in subs) {
          expect(vistas.containsKey(sub), isFalse,
              reason: '$sub está en ${vistas[sub]} y en $principal');
          vistas[sub] = principal;
        }
      });
    });

    test('la lista completa no tiene repetidos', () {
      final todas = CategoryConstants.all;
      expect(todas.length, todas.toSet().length);
    });
  });

  group('mainCategoryOf', () {
    test('una principal se devuelve a sí misma', () {
      expect(CategoryConstants.mainCategoryOf('Deportes'), 'Deportes');
    });

    test('una subcategoría devuelve su principal', () {
      expect(CategoryConstants.mainCategoryOf('Fútbol'), 'Deportes');
      expect(CategoryConstants.mainCategoryOf('Programación'), 'Académico');
      expect(CategoryConstants.mainCategoryOf('Esports'), 'Juegos online');
    });

    test('acepta la lista separada por comas que guarda una actividad', () {
      expect(CategoryConstants.mainCategoryOf('Deportes, Fútbol'), 'Deportes');
      expect(CategoryConstants.mainCategoryOf('Fútbol, Deportes'), 'Deportes');
    });

    test('devuelve null si no reconoce nada', () {
      expect(CategoryConstants.mainCategoryOf('Submarinismo lunar'), isNull);
    });
  });

  group('portadas', () {
    test('cada categoría principal tiene al menos una portada', () {
      for (final principal in CategoryConstants.mainCategories) {
        final portadas = CategoryConstants.covers[principal];
        expect(portadas, isNotNull, reason: 'portadas de $principal');
        expect(portadas, isNotEmpty, reason: 'portadas de $principal');
      }
    });

    test('todas las rutas apuntan a la carpeta de actividades', () {
      for (final portadas in CategoryConstants.covers.values) {
        for (final ruta in portadas) {
          expect(ruta, startsWith('assets/images/activities/'));
          expect(ruta, endsWith('.jpg'));
        }
      }
    });

    test('la portada por defecto es la primera de su categoría', () {
      expect(
        CategoryConstants.defaultCoverFor('Académico'),
        CategoryConstants.covers['Académico']!.first,
      );
      expect(
        CategoryConstants.defaultCoverFor('Fútbol'),
        CategoryConstants.covers['Deportes']!.first,
      );
    });

    test('una categoría desconocida igual recibe una portada válida', () {
      final portada = CategoryConstants.defaultCoverFor('inventada');
      expect(portada, startsWith('assets/images/activities/'));
    });

    test('coversFor ofrece primero las de su categoría', () {
      final ofrecidas = CategoryConstants.coversFor('Académico');
      expect(ofrecidas.first, CategoryConstants.covers['Académico']!.first);
      // Y también deja elegir de otras categorías.
      expect(ofrecidas.length, greaterThan(1));
    });

    test('coversFor no repite rutas sugeridas en dos categorías', () {
      final ofrecidas = CategoryConstants.coversFor('Chill');
      expect(ofrecidas.length, ofrecidas.toSet().length);
    });
  });

  group('normalizeSelection', () {
    test('deja una sola principal cuando venían varias', () {
      // Los planes creados antes podían guardar hasta tres.
      final resultado = CategoryConstants.normalizeSelection(
        ['Deportes', 'Académico', 'Comida'],
      );

      final principales =
          resultado.where(CategoryConstants.groups.containsKey).toList();
      expect(principales, hasLength(1));
      expect(principales.first, 'Deportes');
    });

    test('conserva las subcategorías que pertenecen a la principal', () {
      final resultado = CategoryConstants.normalizeSelection(
        ['Deportes', 'Fútbol', 'Vóley'],
      );
      expect(resultado, containsAll(['Deportes', 'Fútbol', 'Vóley']));
    });

    test('descarta las subcategorías de otra rama', () {
      // "Camping" es de Naturaleza: no pinta nada en un plan de Deportes.
      final resultado = CategoryConstants.normalizeSelection(
        ['Deportes', 'Fútbol', 'Camping'],
      );
      expect(resultado, contains('Fútbol'));
      expect(resultado, isNot(contains('Camping')));
    });

    test('deduce la principal si sólo llegan subcategorías', () {
      final resultado = CategoryConstants.normalizeSelection(['Programación']);
      expect(resultado, contains('Académico'));
      expect(resultado, contains('Programación'));
    });

    test('siempre devuelve una principal, aunque no reconozca nada', () {
      final resultado = CategoryConstants.normalizeSelection(['algo raro']);
      final principales =
          resultado.where(CategoryConstants.groups.containsKey).toList();
      expect(principales, hasLength(1));
    });

    test('una selección vacía también recibe una principal', () {
      final resultado = CategoryConstants.normalizeSelection([]);
      expect(resultado, hasLength(1));
      expect(CategoryConstants.groups.containsKey(resultado.first), isTrue);
    });
  });

  group('InterestMapper', () {
    test('un interés arrastra su categoría principal', () {
      final resultado = InterestMapper.getCategoriesForInterests(['Fútbol']);
      expect(resultado, contains('Deportes'));
      expect(resultado, contains('Fútbol'));
    });

    test('una categoría principal arrastra sus subcategorías', () {
      final resultado = InterestMapper.getCategoriesForInterests(['Académico']);
      expect(resultado, containsAll(['Estudio', 'Programación', 'Tutorías']));
    });

    test('respeta los cruces entre ramas distintas', () {
      // El trekking es deporte, pero también naturaleza.
      final resultado = InterestMapper.getCategoriesForInterests(['Trekking']);
      expect(resultado, contains('Deportes'));
      expect(resultado, contains('Naturaleza'));
    });

    test('ignora mayúsculas y espacios', () {
      expect(
        InterestMapper.getCategoriesForInterests(['  fútbol  ']),
        contains('Deportes'),
      );
    });

    test('un interés desconocido no aporta nada', () {
      expect(InterestMapper.getCategoriesForInterests(['nada de esto']), isEmpty);
    });

    test('las categorías nuevas se relacionan entre sí', () {
      final resultado = InterestMapper.getCategoriesForInterests(['Esports']);
      expect(resultado, contains('Juegos online'));
      expect(resultado, contains('Torneos'));
    });
  });
}

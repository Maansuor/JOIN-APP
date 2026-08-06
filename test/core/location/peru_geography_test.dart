import 'package:flutter_test/flutter_test.dart';
import 'package:join_app/core/location/peru_geography.dart';

void main() {
  group('regionOf', () {
    test('reconoce distritos de Junín', () {
      expect(PeruGeography.regionOf('El Tambo'), 'junin');
      expect(PeruGeography.regionOf('Huancayo'), 'junin');
      expect(PeruGeography.regionOf('Chilca, Huancayo'), 'junin');
    });

    test('reconoce distritos de Lima y Callao', () {
      expect(PeruGeography.regionOf('Miraflores'), 'lima');
      expect(PeruGeography.regionOf('Callao'), 'lima');
    });

    test('ignora mayúsculas', () {
      expect(PeruGeography.regionOf('HUANCAYO'), 'junin');
      expect(PeruGeography.regionOf('Cusco'), 'cusco');
    });

    test('acepta el nombre con y sin tilde', () {
      expect(PeruGeography.regionOf('Junín'), 'junin');
      expect(PeruGeography.regionOf('Junin'), 'junin');
    });

    test('un lugar desconocido cae en "other"', () {
      expect(PeruGeography.regionOf('Tokio'), PeruGeography.otherRegion);
      expect(PeruGeography.regionOf(''), PeruGeography.otherRegion);
    });
  });

  group('regionOfParts', () {
    test('detecta la región aunque sólo la provincia sea reconocible', () {
      expect(
        PeruGeography.regionOfParts(city: 'Zona X', district: 'Zona X', province: 'Huancayo'),
        'junin',
      );
    });

    test('devuelve "other" si ninguna parte se reconoce', () {
      expect(
        PeruGeography.regionOfParts(city: 'Narnia', district: 'Narnia', province: ''),
        PeruGeography.otherRegion,
      );
    });
  });

  group('proximityScore', () {
    test('la misma ubicación puntúa 0', () {
      expect(PeruGeography.proximityScore('El Tambo, Huancayo', 'El Tambo, Huancayo'), 0);
    });

    test('el mismo distrito puntúa 1', () {
      expect(PeruGeography.proximityScore('El Tambo, Huancayo', 'El Tambo'), 1);
    });

    test('la misma provincia puntúa 2', () {
      expect(PeruGeography.proximityScore('El Tambo, Huancayo', 'Huancayo'), 2);
    });

    test('la misma región puntúa 3', () {
      expect(PeruGeography.proximityScore('El Tambo, Huancayo', 'Jauja'), 3);
    });

    test('otra región puntúa 100', () {
      expect(PeruGeography.proximityScore('El Tambo, Huancayo', 'Miraflores, Lima'), 100);
    });

    test('sin ciudad de actividad puntúa 100', () {
      expect(PeruGeography.proximityScore('Huancayo', null), 100);
      expect(PeruGeography.proximityScore('Huancayo', ''), 100);
    });

    test('lo cercano puntúa siempre menos que lo lejano', () {
      const yo = 'El Tambo, Huancayo';
      final mismoDistrito = PeruGeography.proximityScore(yo, 'El Tambo');
      final mismaRegion = PeruGeography.proximityScore(yo, 'Tarma');
      final otraRegion = PeruGeography.proximityScore(yo, 'Cusco');

      expect(mismoDistrito, lessThan(mismaRegion));
      expect(mismaRegion, lessThan(otraRegion));
    });
  });

  group('areNearby', () {
    test('dentro de la misma región se consideran cercanas', () {
      expect(PeruGeography.areNearby('El Tambo, Huancayo', 'Chilca'), isTrue);
    });

    test('entre regiones distintas no', () {
      expect(PeruGeography.areNearby('El Tambo, Huancayo', 'Arequipa'), isFalse);
    });
  });

  group('canonicalRegionName', () {
    test('Junín tiene nombre canónico para filtrar en la base de datos', () {
      expect(PeruGeography.canonicalRegionName['junin'], 'Junín');
    });
  });
}

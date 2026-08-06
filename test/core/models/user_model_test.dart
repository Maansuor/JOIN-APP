import 'package:flutter_test/flutter_test.dart';
import 'package:join_app/core/models/user_model.dart';

void main() {
  group('UserModel.fromJson', () {
    test('lee el formato snake_case que devuelve Supabase', () {
      final user = UserModel.fromJson({
        'id': 'abc-123',
        'display_name': 'Ana Torres',
        'profile_image_url': 'https://ejemplo.test/ana.jpg',
        'rating': 4.5,
        'activities_attended': 7,
        'activities_created': 2,
        'bio': 'Me gusta el trekking',
        'is_verified': true,
        'age_visible': false,
        'setup_completed': true,
        'user_role': 'corporate',
        'iguana_level': 3,
        'iguana_type': 'female',
        'search_code': 'J-ABC123',
        'gender': 'female',
        'birth_date': '1998-05-20',
      });

      expect(user.id, 'abc-123');
      expect(user.name, 'Ana Torres');
      expect(user.profileImageUrl, 'https://ejemplo.test/ana.jpg');
      expect(user.rating, 4.5);
      expect(user.activitiesAttended, 7);
      expect(user.activitiesCreated, 2);
      expect(user.isVerified, isTrue);
      expect(user.ageVisible, isFalse);
      expect(user.setupCompleted, isTrue);
      expect(user.userRole, 'corporate');
      expect(user.iguanaLevel, 3);
      expect(user.iguanaType, 'female');
      expect(user.searchCode, 'J-ABC123');
      expect(user.gender, UserGender.female);
      expect(user.birthDate, DateTime(1998, 5, 20));
    });

    test('aplica valores por defecto cuando faltan campos', () {
      final user = UserModel.fromJson({'id': 'solo-id'});

      expect(user.name, '');
      expect(user.rating, 0.0);
      expect(user.interests, isEmpty);
      expect(user.isVerified, isFalse);
      expect(user.setupCompleted, isFalse);
      expect(user.userRole, 'casual');
      expect(user.iguanaLevel, 1);
      expect(user.gender, UserGender.preferNotToSay);
      expect(user.birthDate, isNull);
    });

    test('extrae los intereses del embed user_interests de PostgREST', () {
      final user = UserModel.fromJson({
        'id': 'x',
        'user_interests': [
          {'tag': 'trekking'},
          {'tag': 'comida'},
          {'tag': ''}, // se descarta
        ],
      });

      expect(user.interests, ['trekking', 'comida']);
    });
  });

  group('edad', () {
    test('descuenta el año si aún no ha llegado el cumpleaños', () {
      final hoy = DateTime.now();
      final cumpleManana = hoy.add(const Duration(days: 1));
      final user = _userConNacimiento(
        DateTime(hoy.year - 30, cumpleManana.month, cumpleManana.day),
      );

      // Nació hace 30 años pero su cumpleaños es mañana: aún tiene 29.
      expect(user.age, 29);
    });

    test('cuenta el año completo si el cumpleaños ya pasó', () {
      final hoy = DateTime.now();
      final ayer = hoy.subtract(const Duration(days: 1));
      final user = _userConNacimiento(
        DateTime(hoy.year - 30, ayer.month, ayer.day),
      );

      expect(user.age, 30);
    });

    test('isAdult distingue mayores y menores de edad', () {
      final hoy = DateTime.now();
      expect(_userConNacimiento(DateTime(hoy.year - 25, 1, 1)).isAdult, isTrue);
      expect(_userConNacimiento(DateTime(hoy.year - 15, 1, 1)).isAdult, isFalse);
    });

    test('publicAge respeta la preferencia de privacidad', () {
      final hoy = DateTime.now();
      final nacimiento = DateTime(hoy.year - 25, 1, 1);

      expect(_userConNacimiento(nacimiento, ageVisible: true).publicAge, isNotNull);
      expect(_userConNacimiento(nacimiento, ageVisible: false).publicAge, isNull);
    });

    test('sin fecha de nacimiento la edad es nula', () {
      expect(_userBase().age, isNull);
    });
  });

  group('iniciales', () {
    test('usa la primera letra del nombre y del apellido', () {
      expect(_userBase(name: 'Ana Torres').initials, 'AT');
    });

    test('con un solo nombre usa una letra', () {
      expect(_userBase(name: 'Ana').initials, 'A');
    });

    test('con nombre vacío devuelve un interrogante', () {
      expect(_userBase(name: '').initials, '?');
    });
  });

  group('compañero iguana', () {
    test('cada tipo tiene su nombre y su asset', () {
      expect(_userBase(iguanaType: 'male').companionName, 'Drago');
      expect(_userBase(iguanaType: 'female').companionName, 'Eli');
      expect(_userBase(iguanaType: 'non_binary').companionName, 'Halo');

      expect(_userBase(iguanaType: 'male').companionAsset, contains('DRAGO'));
      expect(_userBase(iguanaType: 'female').companionAsset, contains('ELI'));
      expect(_userBase(iguanaType: 'non_binary').companionAsset, contains('HALO'));
    });
  });

  group('imagen de perfil', () {
    test('las rutas de assets no cuentan como foto real ni dan URL', () {
      final user = _userBase(imageUrl: 'assets/images/avatars/avatar_1.png');

      expect(user.isAssetImage, isTrue);
      expect(user.hasProfileImage, isFalse);
      expect(user.fullProfileImageUrl, '');
    });

    test('una URL http se considera foto real y se devuelve tal cual', () {
      final user = _userBase(imageUrl: 'https://ejemplo.test/foto.jpg');

      expect(user.isAssetImage, isFalse);
      expect(user.hasProfileImage, isTrue);
      expect(user.fullProfileImageUrl, 'https://ejemplo.test/foto.jpg');
    });
  });

  group('UserGender', () {
    test('el ida y vuelta a JSON conserva el valor', () {
      for (final genero in UserGender.values) {
        expect(UserGender.fromJson(genero.toJson()), genero);
      }
    });

    test('un valor desconocido cae en preferNotToSay', () {
      expect(UserGender.fromJson('marciano'), UserGender.preferNotToSay);
    });
  });
}

UserModel _userBase({
  String name = 'Ana Torres',
  String imageUrl = '',
  String iguanaType = 'non_binary',
}) {
  return UserModel(
    id: 'test-id',
    name: name,
    profileImageUrl: imageUrl,
    rating: 0,
    activitiesAttended: 0,
    activitiesCreated: 0,
    bio: '',
    interests: const [],
    isVerified: false,
    joinedDate: DateTime(2026, 1, 1),
    iguanaType: iguanaType,
  );
}

UserModel _userConNacimiento(DateTime nacimiento, {bool ageVisible = true}) {
  return _userBase().copyWith(birthDate: nacimiento, ageVisible: ageVisible);
}

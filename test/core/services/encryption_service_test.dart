import 'package:flutter_test/flutter_test.dart';
import 'package:join_app/core/services/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    test('el ida y vuelta devuelve el texto original', () {
      const original = 'Nos vemos en el parque a las 5';

      final cifrado = EncryptionService.encryptText(original);

      expect(cifrado, isNot(original));
      expect(EncryptionService.decryptText(cifrado), original);
    });

    test('conserva acentos, eñes y emojis', () {
      const original = '¡Vamos a la montaña, compañeros! 🦎🎉';

      expect(
        EncryptionService.decryptText(EncryptionService.encryptText(original)),
        original,
      );
    });

    test('cada cifrado usa un IV distinto, así que dos iguales no coinciden', () {
      const original = 'mensaje repetido';

      final primero = EncryptionService.encryptText(original);
      final segundo = EncryptionService.encryptText(original);

      // Mismo texto, distinto resultado: el IV es aleatorio por mensaje.
      expect(primero, isNot(segundo));
      // Y ambos se descifran igual.
      expect(EncryptionService.decryptText(primero), original);
      expect(EncryptionService.decryptText(segundo), original);
    });

    test('el formato es IV:cifrado, ambos en base64', () {
      final cifrado = EncryptionService.encryptText('hola');
      final partes = cifrado.split(':');

      expect(partes, hasLength(2));
      expect(partes[0], isNotEmpty);
      expect(partes[1], isNotEmpty);
    });

    test('el texto vacío se deja intacto', () {
      expect(EncryptionService.encryptText(''), '');
      expect(EncryptionService.decryptText(''), '');
    });

    test('un texto que no está cifrado se devuelve tal cual', () {
      // Los mensajes anteriores al cifrado siguen en la base de datos.
      const plano = 'mensaje viejo sin cifrar';

      expect(EncryptionService.decryptText(plano), plano);
    });

    test('un texto corrupto no lanza excepción', () {
      expect(
        () => EncryptionService.decryptText('no-es-base64-valido:tampoco'),
        returnsNormally,
      );
    });
  });
}

import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  // Master key - en un entorno final se usaría DHKE para llaves efímeras
  static final enc.Key _key = enc.Key.fromUtf8('JoinSecretE2EEKey2026!@#secure!!'); 
  static final enc.IV _staticIvFallback = enc.IV.fromLength(16);
  static final enc.Encrypter _encrypter = enc.Encrypter(enc.AES(_key));

  /// Cifra un texto plano a Base64 con un IV aleatorio único
  static String encryptText(String plaintext) {
    if (plaintext.isEmpty) return plaintext;
    try {
      // Generamos un IV completamente aleatorio y seguro para cada mensaje!
      final iv = enc.IV.fromSecureRandom(16);
      final encrypted = _encrypter.encrypt(plaintext, iv: iv);
      // Retornamos el formato: IV_EN_BASE64:CIFRADO_EN_BASE64
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      return plaintext;
    }
  }

  /// Descifra un Base64 a texto plano detectando si tiene IV dinámico o histórico
  static String decryptText(String base64Text) {
    if (base64Text.isEmpty) return base64Text;
    
    final cleanBase64 = base64Text.replaceAll(' ', '+').replaceAll('\n', '').replaceAll('\r', '').trim();
    
    // Si no parece un formato encriptado, devolvemos el original
    if (cleanBase64.contains(' ') || cleanBase64.length < 10) {
      return base64Text;
    }

    try {
      // ¿Es nuestro nuevo sistema seguro con IV dinámico? (IV:Cipher)
      if (cleanBase64.contains(':')) {
        final parts = cleanBase64.split(':');
        if (parts.length == 2) {
          final iv = enc.IV.fromBase64(parts[0]);
          return _encrypter.decrypt64(parts[1], iv: iv);
        }
      }
      
      // Fallback para mensajes anteriores con IV estático (retrocompatibilidad)
      return _encrypter.decrypt64(cleanBase64, iv: _staticIvFallback);
    } catch (e) {
      // Si todo falla devolvemos el texto que nos pasaron
      return base64Text;
    }
  }
}


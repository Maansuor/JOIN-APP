import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import '../services/api_client.dart';

// ══════════════════════════════════════════════════════════════
//  AuthRepository  — Autenticación con el backend PHP
//  Soporta: email/password + Google Sign-In
// ══════════════════════════════════════════════════════════════

class AuthResult {
  final UserModel user;
  final String token;
  const AuthResult({required this.user, required this.token});
}

class AuthRepository {
  final ApiClient _api;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    ApiClient? client,
    GoogleSignIn? googleSignIn,
  })  : _api = client ?? ApiClient.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              // Web Client ID — necesario para obtener el idToken verificable en backend
              serverClientId:
                  '73446753695-mguf0h4g2cro3p84q91fbsva9jpuf96c.apps.googleusercontent.com',
              scopes: ['email', 'profile'],
            );

  // ── Login email/password ────────────────────────────────────
  Future<AuthResult> login(String username, String password) async {
    final data = await _api.post('/auth.php', {
      'username': username,
      'password': password,
    }, queryParams: {
      'action': 'login'
    });

    final token = data['token'] as String;
    _api.setToken(token);

    return AuthResult(
      token: token,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  // ── Registro ────────────────────────────────────────────────
  Future<AuthResult> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final data = await _api.post('/auth.php', {
      'fullName': fullName,
      'username': username,
      'email': email,
      'password': password,
    }, queryParams: {
      'action': 'register'
    });

    final token = data['token'] as String;
    _api.setToken(token);

    return AuthResult(
      token: token,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  // ── Google Sign-In ──────────────────────────────────────────
  /// Abre el selector de cuentas de Google, obtiene el idToken
  /// y lo valida con nuestro backend PHP (sin Firebase).
  /// Retorna null si el usuario cancela el flujo.
  Future<AuthResult?> loginWithGoogle() async {
    // 1. Abre el popup de cuentas Google
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // usuario canceló

    // 2. Obtener credenciales con el idToken
    final auth = await account.authentication;
    final idToken = auth.idToken;

    if (idToken == null) {
      throw const ApiException(401, 'No se pudo obtener el token de Google');
    }

    // 3. Enviar idToken al backend PHP para verificar y crear sesión
    final data = await _api.post('/auth.php', {
      'idToken': idToken,
    }, queryParams: {
      'action': 'google_auth'
    });

    final token = data['token'] as String;
    _api.setToken(token);

    return AuthResult(
      token: token,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  // ── Logout ──────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await _api.post('/auth.php', {}, queryParams: {'action': 'logout'});
    } catch (_) {
      // Ignorar errores de red en logout
    } finally {
      _api.setToken(null);
      // Si había sesión Google activa, cerrarla también
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    }
  }

  // ── Perfil actual ───────────────────────────────────────────
  Future<UserModel?> getMe() async {
    try {
      final data = await _api.get('/auth.php', queryParams: {'action': 'me'});
      return UserModel.fromJson(data['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401) return null;
      rethrow;
    }
  }

  // ── Restaurar sesión desde token guardado ───────────────────
  Future<UserModel?> restoreSession(String token) async {
    _api.setToken(token);
    final user = await getMe();
    if (user == null) _api.setToken(null);
    return user;
  }

  // ── Magic Link / Code ──────────────────────────────────────
  Future<String?> requestMagicCode(String email) async {
    final data = await _api.post('/auth.php', {
      'email': email,
    }, queryParams: {
      'action': 'request_magic_code'
    });
    return data['debug_code'] as String?;
  }

  Future<AuthResult> verifyMagicCode(String email, String code) async {
    final data = await _api.post('/auth.php', {
      'email': email,
      'code': code,
    }, queryParams: {
      'action': 'verify_magic_code'
    });

    final token = data['token'] as String;
    _api.setToken(token);

    return AuthResult(
      token: token,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }
}

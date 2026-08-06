import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthResult {
  final UserModel user;
  const AuthResult({required this.user});
}

/// ══════════════════════════════════════════════════════════════
///  AuthRepository  — Implementación de Autenticación con Supabase
///
///  Soporta: email/password, Google Sign-In nativo y Magic OTP Link
/// ══════════════════════════════════════════════════════════════
class AuthRepository {
  final SupabaseClient _supabase;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    SupabaseClient? supabaseClient,
    GoogleSignIn? googleSignIn,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId:
                  '73446753695-mguf0h4g2cro3p84q91fbsva9jpuf96c.apps.googleusercontent.com',
              scopes: ['email', 'profile'],
            );

  // ── Login email/password ────────────────────────────────────
  Future<AuthResult> login(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('No se pudo iniciar sesión con Supabase.');
    }

    final profileData = await _supabase
        .from('profiles')
        .select('*, user_interests(tag)')
        .eq('id', response.user!.id)
        .single();

    return AuthResult(
      user: UserModel.fromJson(profileData),
    );
  }

  // ── Registro ────────────────────────────────────────────────
  Future<AuthResult> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'fullName': fullName,
        'name': fullName,
        'username': username,
      },
    );

    if (response.user == null) {
      throw Exception('Error al registrar usuario en Supabase.');
    }

    // Esperar un instante para garantizar que el Trigger de base de datos haya creado el perfil público
    await Future.delayed(const Duration(milliseconds: 500));

    // Asegurar que el nombre completo display_name esté actualizado en profiles
    await _supabase
        .from('profiles')
        .update({
          'display_name': fullName,
          'email': email,
        })
        .eq('id', response.user!.id);

    final profileData = await _supabase
        .from('profiles')
        .select('*, user_interests(tag)')
        .eq('id', response.user!.id)
        .single();

    return AuthResult(
      user: UserModel.fromJson(profileData),
    );
  }

  // ── Google Sign-In NATIVO ────────────────────────────────────
  Future<AuthResult?> loginWithGoogle() async {
    try {
      debugPrint('Google Sign-In nativo via Supabase: Iniciando...');
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('Google Sign-In: Cancelado por el usuario.');
        return null;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      if (idToken == null) {
        throw Exception('Google Sign-In: idToken no obtenido.');
      }

      debugPrint('Validando idToken con Supabase Auth...');
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        throw Exception('Supabase Google Auth falló.');
      }

      // Esperar a que el trigger de PostgreSQL cree la fila en profiles
      await Future.delayed(const Duration(milliseconds: 500));

      final profileData = await _supabase
          .from('profiles')
          .select('*, user_interests(tag)')
          .eq('id', response.user!.id)
          .single();

      return AuthResult(
        user: UserModel.fromJson(profileData),
        );
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  // ── Cierre de Sesión ─────────────────────────────────────────
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Logout warning: $e');
    }
  }

  // ── Perfil Actual ────────────────────────────────────────────
  Future<UserModel?> getMe() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final profileData = await _supabase
          .from('profiles')
          .select('*, user_interests(tag)')
          .eq('id', user.id)
          .single();
      return UserModel.fromJson(profileData);
    } catch (e) {
      debugPrint('Error obteniendo perfil desde profiles: $e');
      return null;
    }
  }

  // ── Restaurar Sesión ─────────────────────────────────────────
  /// Devuelve el perfil si Supabase tiene una sesión persistida, o null.
  ///
  /// Supabase guarda y renueva la sesión por su cuenta, así que la app no
  /// necesita conservar ningún token.
  Future<UserModel?> restoreSession() async {
    if (_supabase.auth.currentSession == null) return null;
    return getMe();
  }

  // ── Magic Link OTP ───────────────────────────────────────────
  Future<String?> requestMagicCode(String email) async {
    await _supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
    );
    // Retorna "" para indicar éxito. El código se puede consultar en el CLI local de Supabase.
    return '';
  }

  Future<AuthResult> verifyMagicCode(String email, String code) async {
    final response = await _supabase.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.magiclink,
    );

    if (response.user == null) {
      throw Exception('Verificación fallida.');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    final profileData = await _supabase
        .from('profiles')
        .select('*, user_interests(tag)')
        .eq('id', response.user!.id)
        .single();

    return AuthResult(
      user: UserModel.fromJson(profileData),
    );
  }
}

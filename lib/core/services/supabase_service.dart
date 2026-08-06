import 'package:supabase_flutter/supabase_flutter.dart';

/// ══════════════════════════════════════════════════════════════
///  SupabaseService  — Capa de servicios centralizada
///
///  – Simplifica el acceso al cliente oficial de Supabase
///  – Proporciona helpers rápidos para verificar el usuario actual
///  – Expone flujos de tiempo real (Realtime)
/// ══════════════════════════════════════════════════════════════
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  /// Cliente central de Supabase
  SupabaseClient get client => Supabase.instance.client;

  /// Sesión actual del usuario
  Session? get currentSession => client.auth.currentSession;

  /// Usuario actual autenticado en Supabase
  User? get currentUser => client.auth.currentUser;

  /// ID del usuario actual (si está autenticado)
  String? get currentUserId => currentUser?.id;

  /// ¿Hay un usuario con sesión activa?
  bool get hasSession => currentSession != null;

}

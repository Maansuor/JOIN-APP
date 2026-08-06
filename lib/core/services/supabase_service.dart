import 'package:flutter/foundation.dart';
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

  /// Helper para inicializar buckets de Storage de manera segura
  Future<void> ensureBucketsExist() async {
    try {
      final buckets = await client.storage.listBuckets();
      final hasAvatars = buckets.any((b) => b.id == 'avatars');
      final hasActivities = buckets.any((b) => b.id == 'activities');

      if (!hasAvatars) {
        await client.storage.createBucket(
          'avatars',
          const BucketOptions(public: true),
        );
        debugPrint('Bucket public "avatars" creado con éxito.');
      }

      if (!hasActivities) {
        await client.storage.createBucket(
          'activities',
          const BucketOptions(public: true),
        );
        debugPrint('Bucket public "activities" creado con éxito.');
      }
    } catch (e) {
      debugPrint('Warning: No se pudieron verificar/crear los buckets: $e');
    }
  }
}

import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_model.dart';
import '../models/event_photo_model.dart';
import '../models/join_request_model.dart';
import 'activity_repository.dart';
import '../location/peru_geography.dart';

/// ══════════════════════════════════════════════════════════════
///  SupabaseActivityRepository  — Implementación real con Supabase
///
///  Reemplaza al ApiActivityRepository anterior.
/// ══════════════════════════════════════════════════════════════
class SupabaseActivityRepository implements ActivityRepository {
  final SupabaseClient _supabase;

  SupabaseActivityRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  // ── Listar actividades ────────────────────────────────────
  @override
  Future<List<Activity>> getActivities({String? category, String? city}) async {
    try {
      // Sin ciudad no hay zona que filtrar: se piden todas las activas.
      if (city == null || city.isEmpty) {
        var query = _supabase
            .from('activities')
            .select(_activitySelect)
            .eq('is_active', true);

        if (category != null && category != 'Todos') {
          query = query.eq('category', category);
        }

        final data = await query.order('event_datetime', ascending: true);
        return data.map((e) => Activity.fromJson(_flattenActivityRow(e))).toList();
      }

      // Con ciudad se usa la función activities_near: los términos viajan como
      // parámetro en lugar de interpolarse dentro del filtro .or(), que se
      // rompía con las comas de nombres como "El Tambo, Huancayo".
      final data = await _supabase.rpc(
        'activities_near',
        params: {
          'p_terms': _zoneTerms(city),
          'p_category': category,
        },
      ).select(_activitySelect);

      return data.map((e) => Activity.fromJson(_flattenActivityRow(e))).toList();
    } catch (e) {
      debugPrint('Error en Supabase getActivities: $e');
      rethrow;
    }
  }

  static const String _activitySelect =
      '*, organizer:profiles(*), contributions(title)';

  /// Términos con los que se considera que una actividad cae en la zona del
  /// usuario: su ciudad completa, el distrito, la provincia y las palabras
  /// clave de su región.
  ///
  /// Incluir la región es lo que hace que el servidor coincida con el cálculo
  /// de cercanía del cliente: antes una actividad en Jauja no llegaba a quien
  /// estaba en El Tambo, aunque PeruGeography las da por cercanas, así que
  /// desaparecían actividades de la misma región.
  static List<String> _zoneTerms(String city) {
    final parts = city.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    final terms = <String>{city.trim(), ...parts};

    final region = PeruGeography.regionOfParts(
      city: city,
      district: parts.isNotEmpty ? parts.first : '',
      province: parts.length > 1 ? parts.elementAt(1) : '',
    );
    if (region != PeruGeography.otherRegion) {
      terms.addAll(PeruGeography.regionKeywords[region] ?? const []);
    }

    return terms.where((t) => t.isNotEmpty).toList();
  }

  // ── Detalle de actividad ──────────────────────────────────
  @override
  Future<Activity?> getActivityById(String id) async {
    try {
      final row = await _supabase
          .from('activities')
          .select('*, organizer:profiles(*), contributions(title)')
          .eq('id', id)
          .single();

      return Activity.fromJson(_flattenActivityRow(row));
    } catch (e) {
      debugPrint('Error en Supabase getActivityById($id): $e');
      return null;
    }
  }

  // ── Actividades por organizador ───────────────────────────
  @override
  Future<List<Activity>> getActivitiesByOrganizer(String organizerId) async {
    try {
      final data = await _supabase
          .from('activities')
          .select('*, organizer:profiles(*), contributions(title)')
          .eq('organizer_id', organizerId);

      return data
          .map((e) => Activity.fromJson(_flattenActivityRow(e)))
          .toList();
    } catch (e) {
      debugPrint('Error en Supabase getActivitiesByOrganizer: $e');
      rethrow;
    }
  }

  // ── Crear actividad ───────────────────────────────────────
  @override
  Future<Activity> createActivity(Activity activity) async {
    try {
      String coverUrl = activity.imageUrl;
      final activityId = activity.id.isEmpty ? _uuid() : activity.id;

      // 1. Obtener y validar el ID del organizador de manera robusta
      final currentUserId = _supabase.auth.currentUser?.id ?? activity.organizerId;
      if (currentUserId.isEmpty || currentUserId.length != 36) {
        throw Exception(
            'No hay un usuario autenticado válido para organizar esta actividad (UUID inválido). Por favor, inicia sesión.');
      }

      // 2. Subir imagen a Supabase Storage si es local
      if (coverUrl.isNotEmpty &&
          !coverUrl.startsWith('http') &&
          !coverUrl.startsWith('assets')) {
        final file = File(coverUrl);
        if (file.existsSync()) {
          final ext = coverUrl.split('.').last;
          final fileName = 'act_${activityId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
          
          await _supabase.storage.from('activities').upload(fileName, file);
          coverUrl = _supabase.storage.from('activities').getPublicUrl(fileName);
        } else {
          coverUrl = defaultImageForCategory(activity.category);
        }
      } else if (coverUrl.isEmpty) {
        coverUrl = defaultImageForCategory(activity.category);
      }

      // 3. Insertar actividad
      final insertMap = {
        'id': activityId,
        'title': activity.title,
        'description': activity.description,
        'category': activity.category,
        'cover_image_url': coverUrl,
        'location_name': activity.locationName,
        'latitude': activity.latitude,
        'longitude': activity.longitude,
        'event_datetime': activity.eventDateTime.toIso8601String(),
        'max_participants': activity.maxParticipants,
        'age_range': activity.ageRange,
        'cost': activity.cost,
        'duration_minutes': activity.durationMinutes,
        'tags': activity.tags.join(','),
        'suggestions': jsonEncode(activity.suggestions),
        'organizer_id': currentUserId,
        'city': activity.city,
        'meeting_location_name': activity.meetingLocationName,
        'meeting_latitude': activity.meetingLatitude,
        'meeting_longitude': activity.meetingLongitude,
        'has_separate_meeting_point': activity.hasSeparateMeetingPoint,
      };
      debugPrint('Inserting activity payload: $insertMap');
      final row = await _supabase.from('activities').insert(insertMap).select('*, organizer:profiles(*), contributions(title)').single();

      // 4. Registrar contribuciones en caso de existir
      if (activity.contributions.isNotEmpty) {
        final contributionsToInsert = activity.contributions.map((c) => {
          'id': _uuid(),
          'activity_id': activityId,
          'created_by_user_id': currentUserId,
          'title': c,
          'category': 'other',
          'is_required': false,
        }).toList();

        await _supabase.from('contributions').insert(contributionsToInsert);
      }

      return Activity.fromJson(_flattenActivityRow(row));
    } catch (e) {
      debugPrint('Error en Supabase createActivity: $e');
      rethrow;
    }
  }

  // ── Actualizar actividad ──────────────────────────────────
  @override
  Future<Activity> updateActivity(Activity activity) async {
    try {
      String coverUrl = activity.imageUrl;

      // 1. Subir imagen a Supabase Storage si es local
      if (coverUrl.isNotEmpty &&
          !coverUrl.startsWith('http') &&
          !coverUrl.startsWith('assets')) {
        final file = File(coverUrl);
        if (file.existsSync()) {
          final ext = coverUrl.split('.').last;
          final fileName = 'act_${activity.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
          
          await _supabase.storage.from('activities').upload(fileName, file);
          coverUrl = _supabase.storage.from('activities').getPublicUrl(fileName);
        } else {
          coverUrl = defaultImageForCategory(activity.category);
        }
      } else if (coverUrl.isEmpty) {
        coverUrl = defaultImageForCategory(activity.category);
      }

      // 2. Modificar actividad
      final row = await _supabase.from('activities').update({
        'title': activity.title,
        'description': activity.description,
        'category': activity.category,
        'cover_image_url': coverUrl,
        'location_name': activity.locationName,
        'latitude': activity.latitude,
        'longitude': activity.longitude,
        'event_datetime': activity.eventDateTime.toIso8601String(),
        'max_participants': activity.maxParticipants,
        'age_range': activity.ageRange,
        'cost': activity.cost,
        'duration_minutes': activity.durationMinutes,
        'tags': activity.tags.join(','),
        'suggestions': jsonEncode(activity.suggestions),
        'city': activity.city,
        'meeting_location_name': activity.meetingLocationName,
        'meeting_latitude': activity.meetingLatitude,
        'meeting_longitude': activity.meetingLongitude,
        'has_separate_meeting_point': activity.hasSeparateMeetingPoint,
      }).eq('id', activity.id).select('*, organizer:profiles(*), contributions(title)').single();

      // 3. Actualizar contribuciones (borrar viejas y registrar nuevas)
      await _supabase.from('contributions').delete().eq('activity_id', activity.id);
      if (activity.contributions.isNotEmpty) {
        final currentUserId = _supabase.auth.currentUser?.id ?? activity.organizerId;
        if (currentUserId.isEmpty || currentUserId.length != 36) {
          throw Exception(
              'No hay un usuario autenticado válido para actualizar las contribuciones.');
        }

        final contributionsToInsert = activity.contributions.map((c) => {
          'id': _uuid(),
          'activity_id': activity.id,
          'created_by_user_id': currentUserId,
          'title': c,
          'category': 'other',
          'is_required': false,
        }).toList();

        await _supabase.from('contributions').insert(contributionsToInsert);
      }

      return Activity.fromJson(_flattenActivityRow(row));
    } catch (e) {
      debugPrint('Error en Supabase updateActivity: $e');
      rethrow;
    }
  }

  // ── Cancelar actividad ────────────────────────────────────
  @override
  Future<void> cancelActivity(String activityId) async {
    try {
      await _supabase
          .from('activities')
          .update({'is_active': false, 'status': 'cancelled'})
          .eq('id', activityId);
    } catch (e) {
      debugPrint('Error en Supabase cancelActivity: $e');
      rethrow;
    }
  }

  // ── Eliminar actividad ────────────────────────────────────
  @override
  Future<void> deleteActivity(String activityId) async {
    try {
      await _supabase
          .from('activities')
          .delete()
          .eq('id', activityId);
    } catch (e) {
      debugPrint('Error en Supabase deleteActivity: $e');
      rethrow;
    }
  }

  // ── Solicitudes de una actividad ──────────────────────────
  @override
  Future<List<JoinRequest>> getRequestsForActivity(String activityId) async {
    try {
      final data = await _supabase
          .from('join_requests')
          .select('*, user:profiles!join_requests_user_id_fkey(*)')
          .eq('activity_id', activityId);

      return data
          .map((e) => JoinRequest.fromJson(_flattenJoinRequestRow(e)))
          .toList();
    } catch (e) {
      debugPrint('Error en Supabase getRequestsForActivity: $e');
      rethrow;
    }
  }

  // ── Mis solicitudes de unión ──────────────────────────────
  @override
  Future<List<JoinRequest>> getMyAllRequests() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) return [];

      final data = await _supabase
          .from('join_requests')
          .select('*, user:profiles!join_requests_user_id_fkey(*)')
          .eq('user_id', currentUserId);

      return data
          .map((e) => JoinRequest.fromJson(_flattenJoinRequestRow(e)))
          .toList();
    } catch (e) {
      debugPrint('Error en Supabase getMyAllRequests: $e');
      rethrow;
    }
  }

  // ── Enviar solicitud de unión ─────────────────────────────
  @override
  Future<JoinRequest> submitJoinRequest({
    required String activityId,
    required String userId,
    required String userName,
    required String userImageUrl,
    required String message,
  }) async {
    try {
      final row = await _supabase.from('join_requests').insert({
        'id': _uuid(),
        'activity_id': activityId,
        'user_id': userId,
        'message': message,
        'status': 'pending',
      }).select('*, user:profiles!join_requests_user_id_fkey(*)').single();

      return JoinRequest.fromJson(_flattenJoinRequestRow(row));
    } catch (e) {
      debugPrint('Error en Supabase submitJoinRequest: $e');
      rethrow;
    }
  }

  // ── Responder solicitud (Aceptar / Rechazar) ──────────────
  @override
  Future<JoinRequest> respondToRequest({
    required String requestId,
    required bool accepted,
    String? responseMessage,
    required String respondedBy,
  }) async {
    try {
      final row = await _supabase.from('join_requests').update({
        'status': accepted ? 'accepted' : 'rejected',
        'response_message': responseMessage ?? '',
        'responded_by': respondedBy,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId).select('*, user:profiles!join_requests_user_id_fkey(*)').single();

      return JoinRequest.fromJson(_flattenJoinRequestRow(row));
    } catch (e) {
      debugPrint('Error en Supabase respondToRequest: $e');
      rethrow;
    }
  }

  // ── Mi solicitud específica para una actividad ─────────────
  @override
  Future<JoinRequest?> getMyRequest({
    required String activityId,
    required String userId,
  }) async {
    try {
      final data = await _supabase
          .from('join_requests')
          .select('*, user:profiles!join_requests_user_id_fkey(*)')
          .eq('activity_id', activityId)
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) return null;
      return JoinRequest.fromJson(_flattenJoinRequestRow(data));
    } catch (e) {
      debugPrint('Error en Supabase getMyRequest: $e');
      return null;
    }
  }

  // ── Recuerdos / Mural de Actividades Real Supabase ────────────────

  @override
  Future<List<Activity>> getCompletedActivitiesForUser(String userId) async {
    try {
      // 1. Obtener creadas por el usuario con estado completed
      final createdRows = await _supabase
          .from('activities')
          .select('*, organizer:profiles(*), contributions(title)')
          .eq('organizer_id', userId)
          .eq('status', 'completed');

      // 2. Obtener asistidas por el usuario
      final participantRows = await _supabase
          .from('activity_participants')
          .select('activity_id, activities(*, organizer:profiles(*), contributions(title))')
          .eq('user_id', userId);

      final List<Activity> list = [];

      for (final row in createdRows) {
        list.add(Activity.fromJson(_flattenActivityRow(row)));
      }

      for (final row in participantRows) {
        final actData = row['activities'] as Map<String, dynamic>?;
        if (actData == null) continue;
        if ((actData['status'] as String?) != 'completed') continue;

        final act = Activity.fromJson(_flattenActivityRow(actData));
        if (!list.any((a) => a.id == act.id)) {
          list.add(act);
        }
      }

      list.sort((a, b) => b.eventDateTime.compareTo(a.eventDateTime));
      return list;
    } catch (e) {
      debugPrint('Error en Supabase getCompletedActivitiesForUser: $e');
      return [];
    }
  }

  @override
  Future<List<EventPhoto>> getEventPhotos(String activityId) async {
    try {
      final data = await _supabase
          .from('event_photos')
          .select('*, profiles(*), event_photo_likes(user_id)')
          .eq('activity_id', activityId)
          .eq('is_deleted', false)
          .order('uploaded_at', ascending: true);

      return data.map(EventPhoto.fromJson).toList();
    } catch (e) {
      debugPrint('Error en Supabase getEventPhotos: $e');
      return [];
    }
  }

  @override
  Future<void> uploadEventPhoto({
    required String activityId,
    required String userId,
    required String photoPath,
    String? caption,
  }) async {
    try {
      final file = File(photoPath);
      final fileExt = photoPath.split('.').last;
      final fileName = 'recap_photos/$activityId/${_uuid()}.$fileExt';
      
      // Subir archivo al storage de supabase (bucket 'activities')
      await _supabase.storage.from('activities').upload(fileName, file);
      final publicUrl = _supabase.storage.from('activities').getPublicUrl(fileName);

      // Insertar en base de datos
      await _supabase.from('event_photos').insert({
        'id': _uuid(),
        'activity_id': activityId,
        'user_id': userId,
        'photo_url': publicUrl,
        'caption': caption,
        'likes_count': 0,
        'is_deleted': false,
      });
    } catch (e) {
      debugPrint('Error en Supabase uploadEventPhoto: $e');
      rethrow;
    }
  }

  @override
  Future<void> toggleLikePhoto({
    required String photoId,
    required String userId,
    required bool like,
  }) async {
    try {
      if (like) {
        await _supabase.from('event_photo_likes').insert({
          'photo_id': photoId,
          'user_id': userId,
        });
      } else {
        await _supabase
            .from('event_photo_likes')
            .delete()
            .eq('photo_id', photoId)
            .eq('user_id', userId);
      }
    } catch (e) {
      debugPrint('Error en Supabase toggleLikePhoto: $e');
      rethrow;
    }
  }

  @override
  Future<bool> hasUserUploadedPhoto({
    required String activityId,
    required String userId,
  }) async {
    try {
      final data = await _supabase
          .from('event_photos')
          .select('id')
          .eq('activity_id', activityId)
          .eq('user_id', userId)
          .eq('is_deleted', false);
      
      return (data as List? ?? []).isNotEmpty;
    } catch (e) {
      debugPrint('Error en Supabase hasUserUploadedPhoto: $e');
      return false;
    }
  }

  @override
  Future<bool> isUserParticipant({
    required String activityId,
    required String userId,
  }) async {
    try {
      final data = await _supabase
          .from('activity_participants')
          .select('id')
          .eq('activity_id', activityId)
          .eq('user_id', userId)
          .maybeSingle();
      
      return data != null;
    } catch (e) {
      debugPrint('Error en Supabase isUserParticipant: $e');
      return false;
    }
  }

  // ── Mapeos Relacionales Planos (Flattening) ────────────────
  Map<String, dynamic> _flattenActivityRow(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    final organizer = row['organizer'] as Map<String, dynamic>?;

    if (organizer != null) {
      map['organizer_id'] = organizer['id'];
      map['organizer_name'] = organizer['display_name'];
      map['organizer_image_url'] = organizer['profile_image_url'];
      map['organizer_rating'] = organizer['rating'];
      map['organizer_activities'] = organizer['activities_created'];
    }

    // Flatten contributions from Supabase join
    final contribs = row['contributions'];
    if (contribs is List) {
      map['contributions'] = contribs
          .map((c) => c is Map ? (c['title'] ?? '').toString() : c.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    // Parse suggestions from JSON string
    final rawSuggestions = row['suggestions'];
    if (rawSuggestions is String && rawSuggestions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSuggestions);
        if (decoded is List) {
          map['suggestions'] = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        // If not valid JSON, ignore
      }
    }

    return map;
  }

  Map<String, dynamic> _flattenJoinRequestRow(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    final user = row['user'] as Map<String, dynamic>?;

    if (user != null) {
      map['user_name'] = user['display_name'];
      map['user_image_url'] = user['profile_image_url'];
      map['user_rating'] = user['rating'];
      map['user_birth_date'] = user['birth_date'];
      map['user_gender'] = user['gender'];
    }
    return map;
  }

  String _uuid() {
    final random = Random.secure();
    const hexDigits = '0123456789abcdef';
    
    String randomHex(int length) {
      return String.fromCharCodes(
        Iterable.generate(length, (_) => hexDigits.codeUnitAt(random.nextInt(16)))
      );
    }
    
    final yOptions = ['8', '9', 'a', 'b'];
    final y = yOptions[random.nextInt(4)];
    
    return '${randomHex(8)}-${randomHex(4)}-4${randomHex(3)}-$y${randomHex(3)}-${randomHex(12)}';
  }

}

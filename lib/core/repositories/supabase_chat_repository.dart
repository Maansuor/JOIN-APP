import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message_model.dart';
import '../models/contribution_model.dart';

/// ══════════════════════════════════════════════════════════════
///  SupabaseChatRepository — Chat de grupo y aportes de actividad
///
///  Reemplaza a la antigua API PHP (chat.php / contributions.php
///  sobre XAMPP + MySQL remoto). Todo corre en Supabase local.
/// ══════════════════════════════════════════════════════════════
class SupabaseChatRepository {
  final SupabaseClient _supabase;

  SupabaseChatRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  String get _currentUserId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw Exception('No hay sesión activa en Supabase.');
    return id;
  }

  // ── Listar mensajes del chat ──────────────────────────────
  Future<List<ChatMessage>> getMessages(String activityId) async {
    final rows = await _supabase
        .from('chat_messages')
        .select('''
          id, user_id, message, type, sent_at, is_pinned, is_edited,
          author:profiles!chat_messages_user_id_fkey(display_name, profile_image_url),
          images:chat_message_images(image_url),
          reactions:chat_message_reactions(user_id, reaction),
          reads:chat_message_reads(user_id, read_at, reader:profiles(display_name))
        ''')
        .eq('activity_id', activityId)
        .eq('is_deleted', false)
        .order('sent_at', ascending: false)
        .limit(100);

    return (rows as List).map((row) {
      final author = row['author'] as Map<String, dynamic>? ?? {};
      final images = (row['images'] as List? ?? [])
          .map((i) => i['image_url'] as String)
          .toList();

      // Mapear al formato que espera ChatMessage.fromJson
      return ChatMessage.fromJson({
        'id': row['id'],
        'user_id': row['user_id'],
        'userName': author['display_name'] ?? 'Usuario',
        'userImageUrl': author['profile_image_url'] ?? '',
        'message': row['message'],
        'sent_at': row['sent_at'],
        'is_pinned': row['is_pinned'],
        'is_edited': row['is_edited'],
        'type': row['type'],
        if (images.isNotEmpty) 'imageUrls': images,
        'reactions': (row['reactions'] as List? ?? [])
            .map((r) => {'userId': r['user_id'], 'reaction': r['reaction']})
            .toList(),
        'readBy': (row['reads'] as List? ?? [])
            .map((r) => {
                  'userId': r['user_id'],
                  'userName': (r['reader'] as Map<String, dynamic>?)?['display_name'] ?? 'Usuario',
                  'readAt': r['read_at'],
                })
            .toList(),
      });
    }).toList();
  }

  // ── Marcar todos los mensajes de la actividad como leídos ──
  Future<void> markRead(String activityId) async {
    try {
      await _supabase.rpc('mark_chat_read', params: {'p_activity_id': activityId});
    } catch (e) {
      debugPrint('Error en mark_chat_read: $e');
    }
  }

  // ── Enviar mensaje (texto y/o imagen) ─────────────────────
  /// [message] debe llegar ya cifrado por EncryptionService.
  /// Devuelve el id del mensaje insertado y la URL de la imagen si la hubo.
  Future<({String id, String? imageUrl})> sendMessage({
    required String activityId,
    required String message,
    File? image,
  }) async {
    final userId = _currentUserId;

    String type = 'text';
    String? imageUrl;
    if (image != null) {
      type = 'image';
      final ext = image.path.split('.').last;
      final fileName =
          'msg_${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from('chat').upload(fileName, image);
      imageUrl = _supabase.storage.from('chat').getPublicUrl(fileName);
    }

    final inserted = await _supabase
        .from('chat_messages')
        .insert({
          'activity_id': activityId,
          'user_id': userId,
          'message': message,
          'type': type,
        })
        .select('id')
        .single();

    final messageId = inserted['id'] as String;

    if (imageUrl != null) {
      await _supabase.from('chat_message_images').insert({
        'message_id': messageId,
        'image_url': imageUrl,
      });
    }

    return (id: messageId, imageUrl: imageUrl);
  }

  // ── Editar mensaje propio ─────────────────────────────────
  /// [newMessage] debe llegar ya cifrado.
  Future<void> editMessage(String messageId, String newMessage) async {
    await _supabase
        .from('chat_messages')
        .update({'message': newMessage, 'is_edited': true})
        .eq('id', messageId)
        .eq('user_id', _currentUserId);
  }

  // ── Eliminar mensaje (borrado suave) ──────────────────────
  Future<void> deleteMessage(String messageId) async {
    await _supabase.from('chat_messages').update({
      'is_deleted': true,
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId);
  }

  // ── Alternar reacción ─────────────────────────────────────
  /// Devuelve 'added' | 'updated' | 'removed'.
  Future<String> toggleReaction(String messageId, String reaction) async {
    final result = await _supabase.rpc('toggle_chat_reaction', params: {
      'p_message_id': messageId,
      'p_reaction': reaction,
    });
    return result as String? ?? 'added';
  }

  // ══════════════════════════════════════════════════════════
  //  Aportes / Contribuciones
  // ══════════════════════════════════════════════════════════

  Future<List<Contribution>> getContributions(String activityId) async {
    final rows = await _supabase
        .from('contributions')
        .select(
            '*, assignee:profiles!contributions_assigned_to_user_id_fkey(display_name, profile_image_url)')
        .eq('activity_id', activityId)
        .order('created_at', ascending: true);

    return (rows as List).map((r) {
      final assignee = r['assignee'] as Map<String, dynamic>?;
      return Contribution(
        id: r['id'] as String,
        activityId: r['activity_id'] as String,
        title: r['title'] as String,
        description: (r['description'] ?? '') as String,
        category: (r['category'] ?? 'other') as String,
        isRequired: (r['is_required'] ?? false) as bool,
        assignedToUserId: r['assigned_to_user_id'] as String?,
        assignedToUserName: assignee?['display_name'] as String?,
        assignedToUserImage: assignee?['profile_image_url'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
        createdByUserId: r['created_by_user_id'] as String,
      );
    }).toList();
  }

  Future<void> createContribution({
    required String activityId,
    required String title,
    String description = '',
    String category = 'other',
  }) async {
    await _supabase.from('contributions').insert({
      'activity_id': activityId,
      'created_by_user_id': _currentUserId,
      'title': title,
      'description': description,
      'category': category,
      'is_required': false,
    });
  }

  Future<void> assignContribution(String contributionId) async {
    await _supabase.from('contributions').update({
      'assigned_to_user_id': _currentUserId,
      'assigned_at': DateTime.now().toIso8601String(),
    }).eq('id', contributionId);
  }

  Future<void> unassignContribution(String contributionId) async {
    await _supabase.from('contributions').update({
      'assigned_to_user_id': null,
      'assigned_at': null,
    }).eq('id', contributionId);
  }
}

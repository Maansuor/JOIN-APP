import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clan_model.dart';
import '../models/user_model.dart';
import 'clan_repository.dart';

class SupabaseClanRepository implements ClanRepository {
  final SupabaseClient _supabase;

  SupabaseClanRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  @override
  Future<List<Clan>> getUserClans(String userId) async {
    try {
      final data = await _supabase
          .from('clan_members')
          .select('clan:clans(*)')
          .eq('user_id', userId);

      if (data == null || data is! List) return [];

      return data
          .map((row) => row['clan'])
          .where((c) => c != null)
          .map((c) => Clan.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error en SupabaseClanRepository.getUserClans: $e');
      return [];
    }
  }

  @override
  Future<List<ClanMember>> getClanMembers(String clanId) async {
    try {
      final data = await _supabase
          .from('clan_members')
          .select('*, user:profiles(*)')
          .eq('clan_id', clanId);

      if (data == null || data is! List) return [];

      return data
          .map((row) => ClanMember.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error en SupabaseClanRepository.getClanMembers: $e');
      return [];
    }
  }

  @override
  Future<Clan> createClan({
    required String name,
    required String creatorId,
    String? avatarUrl,
    required List<String> memberUserIds,
  }) async {
    try {
      // 1. Insertar el clan
      final clanRow = await _supabase.from('clans').insert({
        'name': name,
        'creator_id': creatorId,
        'avatar_url': avatarUrl,
      }).select().single();

      final clan = Clan.fromJson(clanRow);

      // 2. Agregar miembros al clan (incluyendo al creador)
      final allMembers = {creatorId, ...memberUserIds}.toList();
      final membersToInsert = allMembers.map((uid) => {
        'clan_id': clan.id,
        'user_id': uid,
      }).toList();

      await _supabase.from('clan_members').insert(membersToInsert);

      return clan;
    } catch (e) {
      debugPrint('Error en SupabaseClanRepository.createClan: $e');
      rethrow;
    }
  }

  @override
  Future<void> addClanMember(String clanId, String userId) async {
    try {
      await _supabase.from('clan_members').insert({
        'clan_id': clanId,
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('Error en SupabaseClanRepository.addClanMember: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeClanMember(String clanId, String userId) async {
    try {
      await _supabase.from('clan_members')
          .delete()
          .eq('clan_id', clanId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error en SupabaseClanRepository.removeClanMember: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteClan(String clanId) async {
    try {
      await _supabase.from('clans').delete().eq('id', clanId);
    } catch (e) {
      debugPrint('Error en SupabaseClanRepository.deleteClan: $e');
      rethrow;
    }
  }

  @override
  Future<List<UserModel>> searchProfiles(String query) async {
    try {
      if (query.trim().isEmpty) return [];
      final data = await _supabase
          .from('profiles')
          .select('*')
          .or('display_name.ilike.%$query%,email.ilike.%$query%,search_code.ilike.%$query%')
          .limit(15);

      if (data == null || data is! List) return [];

      return data
          .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error en SupabaseClanRepository.searchProfiles: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getSharedActivityCategories(String userIdA, String userIdB) async {
    try {
      final listA = await _supabase
          .from('activity_participants')
          .select('activity_id')
          .eq('user_id', userIdA);

      if (listA == null || listA is! List || listA.isEmpty) return [];
      final activityIdsA = listA.map((row) => row['activity_id'] as String).toList();

      final listB = await _supabase
          .from('activity_participants')
          .select('activities(category)')
          .eq('user_id', userIdB)
          .inFilter('activity_id', activityIdsA);

      if (listB == null || listB is! List) return [];

      final categories = <String>[];
      for (final row in listB) {
        final act = row['activities'];
        if (act != null && act is Map && act['category'] != null) {
          final catStr = act['category'] as String;
          categories.addAll(catStr.split(',').map((c) => c.trim()));
        }
      }
      return categories;
    } catch (e) {
      debugPrint('Error en SupabaseClanRepository.getSharedActivityCategories: $e');
      return [];
    }
  }
}

import '../models/clan_model.dart';
import '../models/user_model.dart';

abstract class ClanRepository {
  /// Obtiene los clanes a los que pertenece el usuario
  Future<List<Clan>> getUserClans(String userId);

  /// Obtiene los miembros de un clan específico (incluyendo perfiles)
  Future<List<ClanMember>> getClanMembers(String clanId);

  /// Crea un nuevo clan con miembros iniciales
  Future<Clan> createClan({
    required String name,
    required String creatorId,
    String? avatarUrl,
    required List<String> memberUserIds,
  });

  /// Añade un miembro a un clan
  Future<void> addClanMember(String clanId, String userId);

  /// Remueve un miembro del clan (o el miembro se sale)
  Future<void> removeClanMember(String clanId, String userId);

  /// Elimina un clan permanentemente (solo creador)
  Future<void> deleteClan(String clanId);

  /// Busca perfiles públicos de usuario para invitarlos al clan
  Future<List<UserModel>> searchProfiles(String query);

  /// Obtiene las categorías de actividades compartidas entre dos usuarios
  Future<List<String>> getSharedActivityCategories(String userIdA, String userIdB);
}

import 'user_model.dart';

class Clan {
  final String id;
  final String name;
  final String creatorId;
  final String? avatarUrl;
  final DateTime createdAt;

  const Clan({
    required this.id,
    required this.name,
    required this.creatorId,
    this.avatarUrl,
    required this.createdAt,
  });

  factory Clan.fromJson(Map<String, dynamic> json) {
    return Clan(
      id: json['id'] as String,
      name: json['name'] as String,
      creatorId: (json['creatorId'] ?? json['creator_id'] ?? '') as String,
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url']) as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : json['created_at_dt'] != null
              ? DateTime.parse(json['created_at_dt'] as String)
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'creator_id': creatorId,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Clan copyWith({
    String? name,
    String? creatorId,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return Clan(
      id: id,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ClanMember {
  final String id;
  final String clanId;
  final String userId;
  final DateTime joinedAt;
  final UserModel? userProfile;

  const ClanMember({
    required this.id,
    required this.clanId,
    required this.userId,
    required this.joinedAt,
    this.userProfile,
  });

  factory ClanMember.fromJson(Map<String, dynamic> json) {
    return ClanMember(
      id: json['id'] as String,
      clanId: (json['clanId'] ?? json['clan_id'] ?? '') as String,
      userId: (json['userId'] ?? json['user_id'] ?? '') as String,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime.now(),
      userProfile: json['user'] != null || json['profiles'] != null
          ? UserModel.fromJson((json['user'] ?? json['profiles']) as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clan_id': clanId,
      'user_id': userId,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}

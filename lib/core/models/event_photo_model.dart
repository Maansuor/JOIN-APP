/// Modelo para Foto compartida durante el evento
class EventPhoto {
  final String id;
  final String activityId;
  final String userId; // Quien subió la foto
  final String userName;
  final String userImageUrl;
  final String photoUrl;
  final String? caption; // Descripción opcional
  final DateTime uploadedAt;
  final int likes; // Cantidad de likes
  final List<String> likedByUserIds; // IDs de usuarios que han dado like

  EventPhoto({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.userName,
    required this.userImageUrl,
    required this.photoUrl,
    this.caption,
    required this.uploadedAt,
    required this.likes,
    required this.likedByUserIds,
  });

  /// ¿El usuario actual ha dado like?
  bool hasLikedByUser(String userId) => likedByUserIds.contains(userId);

  /// Crea un EventPhoto desde JSON, soportando joins de Supabase
  factory EventPhoto.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? json['profile'] as Map<String, dynamic>?;
    final likesList = json['event_photo_likes'] as List<dynamic>? ?? [];
    final likedIds = likesList
        .map((e) => e is Map ? (e['user_id'] ?? '').toString() : e.toString())
        .where((id) => id.isNotEmpty)
        .toList();

    return EventPhoto(
      id: (json['id'] ?? '') as String,
      activityId: (json['activity_id'] ?? json['activityId'] ?? '') as String,
      userId: (json['user_id'] ?? json['userId'] ?? '') as String,
      userName: (profile?['display_name'] ?? json['userName'] ?? 'Usuario') as String,
      userImageUrl: (profile?['profile_image_url'] ?? json['userImageUrl'] ?? '') as String,
      photoUrl: (json['photo_url'] ?? json['photoUrl'] ?? '') as String,
      caption: json['caption'] as String?,
      uploadedAt: DateTime.tryParse((json['uploaded_at'] ?? json['uploadedAt'] ?? '') as String) ?? DateTime.now(),
      likes: (json['likes_count'] ?? json['likes'] ?? likedIds.length) as int,
      likedByUserIds: likedIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activity_id': activityId,
      'user_id': userId,
      'photo_url': photoUrl,
      'caption': caption,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}


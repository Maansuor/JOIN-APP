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
}

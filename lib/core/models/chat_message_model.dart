import 'package:join_app/core/services/encryption_service.dart';

/// Modelo de Mensaje de Chat
class ChatMessage {
  final String id;
  final String userId;
  final String userName;
  final String userImageUrl;
  final String message;
  final DateTime timestamp;
  final bool isPinned;
  final bool isEdited;
  final String? organizerId;
  final List<MessageReaction> reactions;
  final List<MessageRead> readBy;
  final List<String>? imageUrls;
  final MessageType type;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImageUrl,
    required this.message,
    required this.timestamp,
    this.isPinned = false,
    this.isEdited = false,
    this.organizerId,
    this.reactions = const [],
    this.readBy = const [],
    this.imageUrls,
    this.type = MessageType.text,
  });

  /// Crea un ChatMessage desde un mapa JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      // Backend PHP manda 'user_id' (snake_case), modelo interno usa 'userId'
      userId: (json['userId'] ?? json['user_id']) as String,
      // Backend manda 'user_name' y nosotros lo mapeamos a 'userName' en PHP, aseguramos ambos
      userName: (json['userName'] ?? json['user_name'] ?? 'Usuario') as String,
      userImageUrl: (json['userImageUrl'] ?? json['user_image_url'] ?? '') as String,
      message: EncryptionService.decryptText((json['message'] ?? '') as String),
      // Backend manda 'sent_at' ó 'timestamp'
      timestamp: DateTime.parse((json['timestamp'] ?? json['sent_at']) as String),
      isPinned: (json['isPinned'] ?? json['is_pinned'] ?? false) as bool,
      isEdited: (json['isEdited'] ?? json['is_edited'] ?? false) as bool,
      organizerId: json['organizerId'] as String?,
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      readBy: (json['readBy'] as List<dynamic>?)
              ?.map((e) => MessageRead.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      imageUrls: json['image_url'] != null
          ? [json['image_url'] as String]
          : (json['imageUrls'] != null
              ? List<String>.from(json['imageUrls'] as List)
              : null),
      type: MessageTypeX.fromString(json['type'] as String? ?? 'text'),
    );
  }

  /// Convierte el modelo a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isPinned': isPinned,
      'isEdited': isEdited,
      'organizerId': organizerId,
      'reactions': reactions.map((e) => e.toJson()).toList(),
      'readBy': readBy.map((e) => e.toJson()).toList(),
      'type': type.name,
      if (imageUrls != null) 'imageUrls': imageUrls,
    };
  }

  /// Formatea el tiempo del mensaje de forma legible
  String getTimeString() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Ahora';
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes}m';
    if (difference.inHours < 24) return 'Hace ${difference.inHours}h';
    return 'Hace ${difference.inDays}d';
  }

  /// Indica si es un mensaje reciente (menos de 1 min)
  bool get isRecent => DateTime.now().difference(timestamp).inMinutes < 1;

  ChatMessage copyWith({
    bool? isPinned,
    bool? isEdited,
    String? message,
    List<MessageReaction>? reactions,
    List<MessageRead>? readBy,
    List<String>? imageUrls,
  }) {
    return ChatMessage(
      id: id,
      userId: userId,
      userName: userName,
      userImageUrl: userImageUrl,
      message: message ?? this.message,
      timestamp: timestamp,
      isPinned: isPinned ?? this.isPinned,
      isEdited: isEdited ?? this.isEdited,
      organizerId: organizerId,
      reactions: reactions ?? this.reactions,
      readBy: readBy ?? this.readBy,
      imageUrls: imageUrls ?? this.imageUrls,
      type: type,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatMessage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum MessageType { text, image, system }

extension MessageTypeX on MessageType {
  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => MessageType.text,
    );
  }
}

class MessageReaction {
  final String userId;
  final String reaction;

  MessageReaction({required this.userId, required this.reaction});

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      userId: json['userId'] as String,
      reaction: json['reaction'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'reaction': reaction,
    };
  }
}

class MessageRead {
  final String userId;
  final String userName;
  final DateTime readAt;

  MessageRead({required this.userId, required this.userName, required this.readAt});

  factory MessageRead.fromJson(Map<String, dynamic> json) {
    return MessageRead(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      readAt: DateTime.parse(json['readAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'readAt': readAt.toIso8601String(),
    };
  }
}


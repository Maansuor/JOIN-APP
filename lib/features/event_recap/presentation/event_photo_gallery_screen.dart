import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:join_app/core/data/mock_event_data.dart';
import 'package:join_app/core/models/event_photo_model.dart';

/// Pantalla de Galería de Fotos del Evento
class EventPhotoGalleryScreen extends StatefulWidget {
  final String activityId;

  const EventPhotoGalleryScreen({super.key, required this.activityId});

  @override
  State<EventPhotoGalleryScreen> createState() => _EventPhotoGalleryScreenState();
}

class _EventPhotoGalleryScreenState extends State<EventPhotoGalleryScreen> {
  late List<EventPhoto> photos;

  @override
  void initState() {
    super.initState();
    photos = List.from(mockEventPhotos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galería del Evento'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: photos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no hay fotos compartidas',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Galería del Evento',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          '${photos.length} fotos compartidas',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: photos.asMap().entries.map((entry) {
                      final index = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _PhotoCard(
                          photo: entry.value,
                          onLike: () => _toggleLike(entry.value),
                        ).animate().fadeIn(duration: 400.ms, delay: (index * 100).ms),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  void _toggleLike(EventPhoto photo) {
    final index = photos.indexWhere((p) => p.id == photo.id);
    if (index != -1) {
      setState(() {
        if (photo.hasLikedByUser('user_1')) {
          // Remover like
          photos[index] = EventPhoto(
            id: photo.id,
            activityId: photo.activityId,
            userId: photo.userId,
            userName: photo.userName,
            userImageUrl: photo.userImageUrl,
            photoUrl: photo.photoUrl,
            caption: photo.caption,
            uploadedAt: photo.uploadedAt,
            likes: (photo.likes - 1).clamp(0, double.infinity).toInt(),
            likedByUserIds: List.from(photo.likedByUserIds)..remove('user_1'),
          );
        } else {
          // Agregar like
          photos[index] = EventPhoto(
            id: photo.id,
            activityId: photo.activityId,
            userId: photo.userId,
            userName: photo.userName,
            userImageUrl: photo.userImageUrl,
            photoUrl: photo.photoUrl,
            caption: photo.caption,
            uploadedAt: photo.uploadedAt,
            likes: photo.likes + 1,
            likedByUserIds: List.from(photo.likedByUserIds)..add('user_1'),
          );
        }
      });
    }
  }
}

/// Widget para mostrar cada foto
class _PhotoCard extends StatelessWidget {
  final EventPhoto photo;
  final VoidCallback onLike;

  const _PhotoCard({
    required this.photo,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = photo.hasLikedByUser('user_1');

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Image.asset(
              photo.photoUrl,
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Contenido
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Usuario que compartió
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: AssetImage(photo.userImageUrl),
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          photo.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          _formatTime(photo.uploadedAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                if (photo.caption != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    photo.caption!,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
                const SizedBox(height: 12),
                // Likes y acciones
                Row(
                  children: [
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_outline,
                            color: isLiked ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${photo.likes}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isLiked ? Colors.red : Colors.grey[600],
                              fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Icon(Icons.mode_comment_outlined, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '0',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else {
      return 'Hace ${difference.inDays}d';
    }
  }
}

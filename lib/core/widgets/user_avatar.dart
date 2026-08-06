import 'package:flutter/material.dart';
import 'package:join_app/core/theme/app_colors.dart';

/// Avatar de una persona, tolerante a que no tenga foto.
///
/// Quien se registra sin foto —con correo, o con una cuenta de Google sin
/// imagen— queda con la URL vacía. Antes cada pantalla hacía
/// `AssetImage(url)` sin comprobarlo, así que un perfil sin foto reventaba
/// con "Unable to load asset". Aquí se cae a las iniciales del nombre.
class UserAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double radius;

  const UserAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.radius = 20,
  });

  /// Iniciales del nombre: "Ana Torres" -> "AT", "Ana" -> "A".
  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  ImageProvider? get _image {
    if (imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('http')) return NetworkImage(imageUrl);
    return AssetImage(imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.12),
      backgroundImage: image,
      // Si la foto existe pero falla al cargarse, se dejan ver las iniciales
      // que hay debajo en lugar de un hueco roto.
      onBackgroundImageError: image == null ? null : (_, __) {},
      child: image == null
          ? Text(
              _initials,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryOrange,
              ),
            )
          : null,
    );
  }
}

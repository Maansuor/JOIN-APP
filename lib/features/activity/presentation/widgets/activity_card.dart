import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:join_app/core/models/join_request_model.dart';

class ActivityCard extends StatefulWidget {
  final Activity activity;
  final VoidCallback onTap;
  final bool isOrganizer;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
    this.isOrganizer = false,
  });

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard> {
  bool _pressed = false;

  Color get _categoryColor {
    switch (widget.activity.category) {
      case 'Deportes':
        return const Color(0xFFE53935);
      case 'Comida':
        return const Color(0xFFFFA726);
      case 'Naturaleza':
        return const Color(0xFF2E7D32);
      case 'Chill':
        return const Color(0xFF5E35B1);
      case 'Juntas':
        return const Color(0xFFD81B60);
      default:
        return AppColors.primaryOrange;
    }
  }

  IconData get _categoryIcon {
    switch (widget.activity.category) {
      case 'Deportes':
        return Icons.sports_baseball_rounded;
      case 'Comida':
        return Icons.restaurant_rounded;
      case 'Naturaleza':
        return Icons.forest_rounded;
      case 'Chill':
        return Icons.local_cafe_rounded;
      case 'Juntas':
        return Icons.celebration_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  String get _dateLabel {
    final dt = widget.activity.eventDateTime;
    final now = DateTime.now();
    final diff = dt.difference(now).inDays;
    if (diff == 0) {
      return '¡Hoy, ${DateFormat('HH:mm').format(dt)}!';
    } else if (diff == 1) {
      return 'Mañana ${DateFormat('HH:mm').format(dt)}';
    } else if (diff < 7) {
      return '${_dayName(dt.weekday)}, ${DateFormat('dd MMM').format(dt)}';
    }
    return DateFormat('dd MMM · HH:mm').format(dt);
  }

  String _dayName(int weekday) {
    const days = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days[weekday];
  }

  @override
  Widget build(BuildContext context) {
    final slotsLeft = widget.activity.remainingSpots;
    final isFull = !widget.activity.hasAvailableSpots;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        transform: Matrix4.identity()..scale(_pressed ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: _categoryColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── IMAGEN HERO ────────────────────────────────────
              _buildImageSection(isFull, slotsLeft),

              // ── CONTENIDO ─────────────────────────────────────
              _buildInfoSection(),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }

  Widget _buildImageSection(bool isFull, int slotsLeft) {
    return Stack(
      children: [
        // Imagen
        Hero(
          tag: 'activity-image-${widget.activity.id}',
          child: widget.activity.imageUrl.startsWith('http')
              ? Image.network(
                  widget.activity.imageUrl,
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : Image.asset(
                  widget.activity.imageUrl,
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
        ),

        // Gradiente inferior (más pronunciado y elegante)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // ── Badges superiores ────────────────────────────
        Positioned(
          top: 14,
          left: 14,
          child: Row(
            children: [
              // Categoría
              _Badge(
                icon: _categoryIcon,
                label: widget.activity.category,
                color: _categoryColor,
                style: _BadgeStyle.filled,
              ),
              if (widget.isOrganizer) ...[
                const SizedBox(width: 8),
                const _Badge(
                  icon: Icons.verified_rounded,
                  label: 'Organizador',
                  color: AppColors.skyBlue,
                  style: _BadgeStyle.filled,
                ),
              ],
            ],
          ),
        ),

        // Cupos (arriba derecha)
        Positioned(
          top: 14,
          right: 14,
          child: _Badge(
            icon: isFull ? Icons.block_rounded : Icons.people_alt_rounded,
            label: isFull ? 'Lleno' : '$slotsLeft cupos',
            color: isFull ? Colors.red.shade700 : Colors.green.shade600,
            style: _BadgeStyle.glass,
          ),
        ),

        // Título y fecha sobre imagen
        Positioned(
          bottom: 14,
          left: 14,
          right: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.activity.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  shadows: [
                    Shadow(
                      blurRadius: 8,
                      color: Colors.black45,
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Fecha + hora sobre imagen
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _dateLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ubicación
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 15,
                color: _categoryColor,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.activity.locationName.isNotEmpty
                      ? widget.activity.locationName
                      : widget.activity.location,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Distancia real o texto Map
              Builder(
                builder: (context) {
                  final pos = context.watch<AppState>().currentPosition;
                  final lat = widget.activity.latitude;
                  final lng = widget.activity.longitude;
                  
                  String distanceText = '';
                  if (pos != null && lat != null && lng != null) {
                    final distMeters = Geolocator.distanceBetween(
                        pos.latitude, pos.longitude, lat, lng);
                    final distKm = distMeters / 1000.0;
                    distanceText = distKm < 1.0
                        ? '${distMeters.round()} m'
                        : '${distKm.toStringAsFixed(1)} km';
                  } else if (widget.activity.distance > 0) {
                     // Fallback a distancia estática
                     distanceText = '${widget.activity.distance.toStringAsFixed(1)} km';
                  }

                  if (distanceText.isEmpty) {
                    // Si no hay coordenadas ni fallback, mostrar indicador de mapa
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _categoryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.map_rounded, size: 12, color: _categoryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Ver mapa',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _categoryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _categoryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.near_me_rounded, size: 12, color: _categoryColor),
                        const SizedBox(width: 4),
                        Text(
                          distanceText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _categoryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Separador con tags
          Row(
            children: [
              // Rango de edad
              _InfoChip(
                icon: Icons.person_outline_rounded,
                label: widget.activity.ageRange,
              ),
              const SizedBox(width: 8),
              // Participantes
              _InfoChip(
                icon: Icons.people_alt_rounded,
                label:
                    '${widget.activity.currentParticipants}/${widget.activity.maxParticipants}',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Divisor
          Divider(color: Colors.grey[100], thickness: 1),

          const SizedBox(height: 10),

          // Organizador
          Row(
            children: [
              // Avatar con borde
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _categoryColor.withValues(alpha: 0.6),
                      _categoryColor.withValues(alpha: 0.3),
                    ],
                  ),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: widget.activity.organizerImageUrl.startsWith('http')
                      ? NetworkImage(widget.activity.organizerImageUrl) as ImageProvider
                      : AssetImage(widget.activity.organizerImageUrl),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.activity.organizerName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: AppColors.skyBlue,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          final rating = widget.activity.organizerRating;
                          return Icon(
                            i < rating.floor()
                                ? Icons.star_rounded
                                : (i < rating
                                    ? Icons.star_half_rounded
                                    : Icons.star_outline_rounded),
                            size: 12,
                            color: Colors.amber[600],
                          );
                        }),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.activity.organizerRating} · ${widget.activity.organizerActivities} eventos',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // CTA pequeño
              Builder(
                builder: (context) {
                  final appState = context.watch<AppState>();
                  final currentUserId = appState.currentUser?.id;
                  final isOrganizer = currentUserId != null && widget.activity.organizerId == currentUserId;
                  final reqStatus = appState.getMyRequestStatus(widget.activity.id);

                  String buttonText = 'Ver';
                  if (isOrganizer) {
                     buttonText = 'Administrar';
                  } else if (reqStatus == JoinRequestStatus.accepted) {
                     buttonText = 'Participante';
                  } else if (reqStatus == JoinRequestStatus.pending) {
                     buttonText = 'Pendiente';
                  }

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_categoryColor, _categoryColor.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _categoryColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Badge premium ─────────────────────────────────────────────
enum _BadgeStyle { filled, glass }

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final _BadgeStyle style;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = style == _BadgeStyle.filled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isFilled ? color : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFilled ? Colors.transparent : Colors.white.withValues(alpha: 0.3),
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

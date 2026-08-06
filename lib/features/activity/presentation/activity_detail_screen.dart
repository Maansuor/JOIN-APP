import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/features/activity/presentation/widgets/activity_not_found.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:join_app/core/models/join_request_model.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:join_app/core/models/interest_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:join_app/features/main/presentation/hennessy_iguana_widget.dart';

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;

  const ActivityDetailScreen({super.key, required this.activityId});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> with TickerProviderStateMixin {
  JoinRequestStatus? userRequestStatus;
  JoinRequest? userRequest;
  late final ScrollController _scrollController;
  late final AnimationController _pulseController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    userRequestStatus = null;
    userRequest = null;
    _scrollController = ScrollController()..addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activity = appState.activities
        .where((a) => a.id == widget.activityId)
        .firstOrNull;
    if (activity == null) return const ActivityNotFound();

    final currentUserId = context.read<AppState>().currentUser?.id;
    final isOrganizer =
        currentUserId != null && activity.organizerId == currentUserId;
    final currentStatus = userRequestStatus ?? appState.getMyRequestStatus(widget.activityId);
    final isAccepted = isOrganizer || currentStatus == JoinRequestStatus.accepted;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium Parallax Sliver App Bar
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                stretch: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF161920).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.85),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded,
                          color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/main');
                        }
                      },
                    ),
                  ),
                ),
                actions: isOrganizer
                    ? [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF161920).withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.85),
                          child: IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                color: Colors.blue),
                            onPressed: () => context
                                .push('/main/activity/${activity.id}/edit'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF161920).withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.85),
                          child: IconButton(
                            icon: const Icon(Icons.people_alt_rounded,
                                color: AppColors.primaryOrange),
                            onPressed: () => context
                                .push('/main/activity/${activity.id}/requests'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ]
                    : null,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        top: _scrollOffset > 0 ? -_scrollOffset * 0.32 : 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Hero(
                          tag: 'activity-image-${activity.id}',
                          child: activity.imageUrl.startsWith('http')
                              ? Image.network(
                                  activity.imageUrl,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  activity.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      // Elegante gradiente inferior negro a transparente
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.65),
                                Colors.black.withValues(alpha: 0.25),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 0.95],
                            ),
                          ),
                        ),
                      ),
                      // Info Overpuesta en Glassmorphism
                      Positioned(
                        bottom: 36,
                        left: 20,
                        right: 20,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.16),
                                    Colors.white.withValues(alpha: 0.04),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.24),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: activity.category.split(',').map((cat) {
                                      final cleanCat = cat.trim();
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _getCategoryColor(cleanCat),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(_getCategoryIcon(cleanCat), size: 12, color: Colors.white),
                                            const SizedBox(width: 6),
                                            Text(
                                              cleanCat,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ).animate().slideY(begin: 0.5, duration: 400.ms).fadeIn(),
                                  const SizedBox(height: 12),
                                  Text(
                                    activity.title,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                      letterSpacing: -0.4,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(alpha: 0.45),
                                          blurRadius: 12,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ).animate().scale(
                                    begin: const Offset(0.96, 0.96),
                                    end: const Offset(1.0, 1.0),
                                    duration: 500.ms,
                                    curve: Curves.easeOutBack,
                                  ).fadeIn(delay: 100.ms),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Contenido principal
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  transform: Matrix4.translationValues(0, -32, 0),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Organizador Row Premium
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.primaryOrange.withValues(
                                  alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.12),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black.withValues(alpha: 0.2)
                                    : const Color(0xFF041249).withValues(alpha: 0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // Micro-interacción: click en organizador
                                HapticFeedback.selectionClick();
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        AnimatedBuilder(
                                          animation: _pulseController,
                                          builder: (context, child) {
                                            final t = _pulseController.value;
                                            return Container(
                                              width: 52 + t * 12,
                                              height: 52 + t * 12,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.primaryOrange.withValues(alpha: 0.25 * (1 - t)),
                                                  width: 2,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: AppColors.primaryOrange, width: 2),
                                          ),
                                          child: CircleAvatar(
                                            radius: 24,
                                            backgroundImage: activity.organizerImageUrl
                                                    .startsWith('http')
                                                ? NetworkImage(activity.organizerImageUrl)
                                                    as ImageProvider
                                                : AssetImage(activity.organizerImageUrl),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Organizado por',
                                            style: GoogleFonts.outfit(
                                                fontSize: 10,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? const Color(0xFF94A3B8)
                                                    : Colors.grey[600],
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                activity.organizerName,
                                                style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: Theme.of(context).colorScheme.onSurface),
                                              ),
                                              const SizedBox(width: 5),
                                              const Icon(Icons.verified,
                                                  size: 16, color: Colors.blue),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.star_rounded,
                                                  size: 16, color: Colors.amber),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${activity.organizerRating}',
                                                style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11.5),
                                              ),
                                              Text(
                                                ' (${activity.organizerActivities} planes)',
                                                style: GoogleFonts.outfit(
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? const Color(0xFF94A3B8)
                                                        : Colors.grey[500],
                                                    fontSize: 10.5),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white.withValues(alpha: 0.35)
                                          : AppColors.navyBlue.withValues(alpha: 0.35),
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

                        const SizedBox(height: 32),

                        // Stats Grid Premium
                        GridView.count(
                          padding: EdgeInsets.zero,
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          children: [
                            _PremiumStatCard(
                              icon: Icons.calendar_today_rounded,
                              label: 'Fecha',
                              value:
                                  '${activity.eventDateTime.day}/${activity.eventDateTime.month}',
                              color: Colors.blue,
                            ),
                            _PremiumStatCard(
                              icon: Icons.group_rounded,
                              label: 'Participantes',
                              value:
                                  '${activity.currentParticipants}/${activity.maxParticipants}',
                              color: AppColors.primaryOrange,
                            ),
                            _PremiumStatCard(
                              icon: Icons.location_on_rounded,
                              label: 'Distancia',
                              value:
                                  '${activity.distance.toStringAsFixed(1)} km',
                              color: Colors.green,
                            ),
                            _PremiumStatCard(
                              icon: Icons.person_add_alt_1_rounded,
                              label: 'Edades',
                              value: activity.ageRange,
                              color: Colors.purple,
                            ),
                          ],
                        ).animate().fadeIn(duration: 600.ms, delay: 300.ms),

                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : AppColors.navyBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.info_outline_rounded,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : AppColors.navyBlue,
                                  size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Acerca del plan',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          activity.description,
                          style: GoogleFonts.outfit(
                            fontSize: 14.5,
                            height: 1.6,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF2D3748),
                          ),
                        ).animate().fadeIn(duration: 600.ms, delay: 400.ms),

                        // Fichas de Aportes Necesarios
                        if (activity.contributions.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.shopping_bag_rounded, color: Colors.purple, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Aportes para llevar',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Colors.purple.withValues(
                                      alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.12),
                                  width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withValues(alpha: 0.03),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: activity.contributions.map((c) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_rounded, color: Colors.green, size: 14),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          c,
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 450.ms),
                        ],

                        // Recomendaciones de Hennessy
                        if (activity.suggestions.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.tips_and_updates_rounded, color: AppColors.primaryOrange, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Recomendaciones',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.15), width: 1.5),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF0A0D14)
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const HennessyIguanaWidget(
                                      primaryColor: AppColors.primaryOrange,
                                      secondaryColor: AppColors.lightOrange,
                                      size: 40,
                                      hasHat: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: activity.suggestions.map((s) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Text(
                                          '🐾  $s',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14.5,
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontWeight: FontWeight.w500,
                                            height: 1.4,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 480.ms),
                        ],

                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.navyBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_on_outlined, color: AppColors.navyBlue, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Ubicación',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Premium Map Design (Real si es aceptado, blur si no)
                        if (isAccepted && activity.latitude != null && activity.longitude != null) ...[
                          if (activity.hasSeparateMeetingPoint) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1E222B)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2E323F)
                                        : Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryOrange.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.directions_run_rounded, color: AppColors.primaryOrange, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              '1. Punto de Encuentro Previo',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              activity.meetingLocationName.isNotEmpty ? activity.meetingLocationName : 'Punto de encuentro',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).colorScheme.onSurface),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: 2,
                                        height: 20,
                                        color: AppColors.primaryOrange.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.navyBlue.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.sports_score_rounded, color: AppColors.navyBlue, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              '2. Lugar de la Actividad',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              activity.locationName.isNotEmpty ? activity.locationName : activity.location,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).colorScheme.onSurface),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 600.ms, delay: 450.ms),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1E222B)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2E323F)
                                        : Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: AppColors.primaryOrange, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      activity.locationName.isNotEmpty ? activity.locationName : activity.location,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 600.ms, delay: 450.ms),
                          ],
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: SizedBox(
                              height: 220,
                              child: IgnorePointer(
                                ignoring: true,
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: activity.hasSeparateMeetingPoint && activity.meetingLatitude != null && activity.meetingLongitude != null
                                        ? LatLng(
                                            (activity.meetingLatitude! + activity.latitude!) / 2,
                                            (activity.meetingLongitude! + activity.longitude!) / 2,
                                          )
                                        : LatLng(activity.latitude!, activity.longitude!),
                                    initialZoom: activity.hasSeparateMeetingPoint ? 14.0 : 15.0,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                      subdomains: const ['a', 'b', 'c', 'd'],
                                      userAgentPackageName: 'com.join.app',
                                    ),
                                    if (activity.hasSeparateMeetingPoint && activity.meetingLatitude != null && activity.meetingLongitude != null)
                                      PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            points: [
                                              LatLng(activity.meetingLatitude!, activity.meetingLongitude!),
                                              LatLng(activity.latitude!, activity.longitude!),
                                            ],
                                            strokeWidth: 4.0,
                                            color: AppColors.primaryOrange,
                                            pattern: StrokePattern.dashed(segments: const [10, 5]),
                                          ),
                                        ],
                                      ),
                                    MarkerLayer(
                                      markers: [
                                        if (activity.hasSeparateMeetingPoint && activity.meetingLatitude != null && activity.meetingLongitude != null)
                                          Marker(
                                            point: LatLng(activity.meetingLatitude!, activity.meetingLongitude!),
                                            width: 50,
                                            height: 50,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryOrange.withValues(alpha: 0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryOrange,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 2),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppColors.primaryOrange.withValues(alpha: 0.4),
                                                        blurRadius: 6,
                                                        spreadRadius: 1,
                                                      )
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.directions_run_rounded,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ).animate(onPlay: (controller) => controller.repeat()).scaleXY(begin: 0.8, end: 1.2, duration: 1000.ms, curve: Curves.easeInOut).then().scaleXY(begin: 1.2, end: 0.8, duration: 1000.ms, curve: Curves.easeInOut),
                                          ),
                                        Marker(
                                          point: LatLng(activity.latitude!, activity.longitude!),
                                          width: 50,
                                          height: 50,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: activity.hasSeparateMeetingPoint
                                                  ? AppColors.navyBlue.withValues(alpha: 0.2)
                                                  : AppColors.primaryOrange.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: activity.hasSeparateMeetingPoint
                                                  ? Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: AppColors.navyBlue,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: Colors.white, width: 2),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: AppColors.navyBlue.withValues(alpha: 0.4),
                                                            blurRadius: 6,
                                                            spreadRadius: 1,
                                                          )
                                                        ],
                                                      ),
                                                      child: const Icon(
                                                        Icons.sports_score_rounded,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    )
                                                  : Container(
                                                      width: 24,
                                                      height: 24,
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primaryOrange,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: Colors.white, width: 3),
                                                        boxShadow: [BoxShadow(color: AppColors.primaryOrange.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)],
                                                      ),
                                                    ),
                                            ),
                                          ).animate(onPlay: (controller) => controller.repeat()).scaleXY(begin: 0.8, end: 1.2, duration: 1000.ms, curve: Curves.easeInOut).then().scaleXY(begin: 1.2, end: 0.8, duration: 1000.ms, curve: Curves.easeInOut),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final lat = activity.hasSeparateMeetingPoint && activity.meetingLatitude != null ? activity.meetingLatitude : activity.latitude;
                                  final lng = activity.hasSeparateMeetingPoint && activity.meetingLongitude != null ? activity.meetingLongitude : activity.longitude;
                                  final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                                  if (await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : AppColors.navyBlue,
                                  side: BorderSide(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2E323F)
                                        : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Icon(Icons.map_rounded, color: Colors.blue),
                                label: Text(
                                  activity.hasSeparateMeetingPoint
                                      ? 'Cómo llegar al Punto de Encuentro'
                                      : 'Abrir en Google Maps / Otras apps',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                          ),
                        ] else ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                Container(
                                  height: 180,
                                  decoration: const BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(
                                          'https://i.stack.imgur.com/vhoa0.jpg'), // Placeholder estilo mapa
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 4.0, sigmaY: 4.0),
                                    child: Container(
                                        color: Colors.black
                                            .withValues(alpha: 0.2)),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 16),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.1),
                                              blurRadius: 10)
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lock_rounded,
                                            color: Colors.grey[700],
                                            size: 32,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Ubicación exacta secreta',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
                        ],

                        const SizedBox(
                            height:
                                60), // Extra space to prevent hiding under bottom bar
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Bottom Action Bar Fixed in Frosted Glass
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF161920).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.85),
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        offset: const Offset(0, -6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: _buildBottomActions(
                      context,
                      activity,
                      isOrganizer,
                      userRequestStatus ??
                          appState.getMyRequestStatus(widget.activityId),
                    ),
                  ),
                ),
              ),
            ),
          )
              .animate()
              .slideY(begin: 1.0, duration: 500.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, Activity activity,
      bool isOrganizer, JoinRequestStatus? currentStatus) {
    if (isOrganizer) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () => context.push('/main/activity/${activity.id}/group'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          icon: const Icon(Icons.shield_rounded),
          label: Text(
            'Eres Organizador - Ver Grupo 🛡️',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (currentStatus == null) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = 1.0 + (_pulseController.value * 0.02);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _showJoinDialogPremium(context, activity),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  '¡Solicitar unirme ahora! 🚀',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else if (currentStatus == JoinRequestStatus.pending) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2E2214)
                : Colors.orange[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.orange[800]!
                    : Colors.orange[200]!)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pending_actions, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Petición enviada, esperando respuesta',
              style: GoogleFonts.outfit(
                  color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else if (currentStatus == JoinRequestStatus.accepted) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () => context.push('/main/activity/${activity.id}/group'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          icon: const Icon(Icons.chat_bubble_rounded),
          label: Text(
            'Eres Miembro - Ver Chat 💬',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showJoinDialogPremium(BuildContext context, Activity activity) {
    _buildJoinBottomSheet(context, activity);
  }

  void _buildJoinBottomSheet(BuildContext context, Activity activity) {
    final appState = context.read<AppState>();
    final msgCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        bool isBtnPressed = false;
        String participationType = 'individual';
        String? selectedClanId;

        return StatefulBuilder(
          builder: (context, setSubState) {
            final clans = appState.userClans;
            if (clans.isNotEmpty && selectedClanId == null) {
              selectedClanId = clans.first.id;
            }

            Widget buildQuickTag(String label, String textToAppend) {
              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final currentText = msgCtrl.text;
                  if (currentText.isEmpty) {
                    msgCtrl.text = '$textToAppend ';
                  } else if (currentText.endsWith(' ')) {
                    msgCtrl.text = '$currentText$textToAppend ';
                  } else {
                    msgCtrl.text = '$currentText $textToAppend ';
                  }
                  // Mover el cursor al final del campo
                  msgCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: msgCtrl.text.length),
                  );
                  setSubState(() {});
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryOrange.withValues(alpha: 0.16),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.add_rounded, size: 14, color: AppColors.primaryOrange),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
                left: 24,
                right: 24,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2E323F)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Cabecera Premium
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.rocket_launch_rounded, color: AppColors.primaryOrange, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preséntate 🤙',
                              style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Envía un mensaje a ${activity.organizerName}',
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey[500],
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified, size: 12, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              'Organizador',
                              style: GoogleFonts.outfit(fontSize: 9.5, color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Tarjeta Informativa de Tips
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.03)
                          : AppColors.navyBlue.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : AppColors.navyBlue.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tips_and_updates_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Un buen mensaje aumenta tus posibilidades de ser aceptado en el plan.',
                            style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFE2E8F0)
                                    : Colors.grey[700],
                                fontWeight: FontWeight.w500,
                                height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (clans.isNotEmpty) ...[
                    Text(
                      '¿Cómo deseas inscribirte? 👥',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setSubState(() {
                                participationType = 'individual';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: participationType == 'individual'
                                    ? AppColors.primaryOrange.withValues(alpha: 0.1)
                                    : (Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF1E222B)
                                        : Colors.grey[100]),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: participationType == 'individual'
                                      ? AppColors.primaryOrange
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    color: participationType == 'individual'
                                        ? AppColors.primaryOrange
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Individual',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: participationType == 'individual'
                                          ? AppColors.primaryOrange
                                          : (Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white
                                              : const Color(0xFF041249)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setSubState(() {
                                participationType = 'clan';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: participationType == 'clan'
                                    ? AppColors.primaryOrange.withValues(alpha: 0.1)
                                    : (Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF1E222B)
                                        : Colors.grey[100]),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: participationType == 'clan'
                                      ? AppColors.primaryOrange
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.groups_rounded,
                                    color: participationType == 'clan'
                                        ? AppColors.primaryOrange
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Con mi Clan',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: participationType == 'clan'
                                          ? AppColors.primaryOrange
                                          : (Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white
                                              : const Color(0xFF041249)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (participationType == 'clan') ...[
                      Text(
                        'Selecciona tu Clan:',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E222B)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedClanId,
                            isExpanded: true,
                            dropdownColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF161920)
                                : Colors.white,
                            items: clans.map((clan) {
                              return DropdownMenuItem<String>(
                                value: clan.id,
                                child: Text(
                                  clan.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setSubState(() {
                                  selectedClanId = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                  
                  // Campo de Texto de Alta Gama
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF0A0D14)
                          : const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.navyBlue.withValues(alpha: 0.08),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: msgCtrl,
                      maxLines: 4,
                      maxLength: 150,
                      onChanged: (_) => setSubState(() {}),
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: '¡Hola! Me encantaría unirme a esta increíble actividad porque...',
                        hintStyle: GoogleFonts.outfit(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF64748B)
                                : Colors.grey[400],
                            fontSize: 13.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: InputBorder.none,
                        counterStyle: GoogleFonts.outfit(
                            fontSize: 10,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF64748B)
                                : Colors.grey[400],
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Sugerencias Rápidas
                  Text(
                    'Sugerencias rápidas para añadir:',
                    style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey[500],
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildQuickTag('👋 Saludo', '¡Hola! Me encantaría unirme al plan.'),
                      buildQuickTag('🍕 Aporte', 'Puedo llevar algo para compartir.'),
                      buildQuickTag('🚗 Movilidad', 'Voy en auto y tengo espacio.'),
                    ],
                  ),
                  const SizedBox(height: 28),
                  
                  // Botón CTA Animado con Sombra de Neón y Rebote
                  GestureDetector(
                    onTapDown: (_) => setSubState(() => isBtnPressed = true),
                    onTapUp: (_) => setSubState(() => isBtnPressed = false),
                    onTapCancel: () => setSubState(() => isBtnPressed = false),
                    child: AnimatedScale(
                      scale: isBtnPressed ? 0.96 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryOrange, Color(0xFFFF8E53)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryOrange.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            context.pop(); // Cerrar BottomSheet

                            try {
                              final success = participationType == 'clan'
                                  ? await appState.submitClanJoinRequest(
                                      widget.activityId,
                                      selectedClanId!,
                                      msgCtrl.text,
                                    )
                                  : await appState.submitJoinRequest(
                                      widget.activityId,
                                      msgCtrl.text,
                                    );

                              if (success) {
                                setState(() {
                                  userRequestStatus = JoinRequestStatus.pending;
                                });

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.rocket_launch_rounded,
                                              color: Colors.white, size: 20),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              participationType == 'clan'
                                                  ? '¡Solicitudes de Clan enviadas con éxito! 🏕️'
                                                  : 'Solicitud enviada a ${activity.organizerName}',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFF2E7D32),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16)),
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                }
                              } else {
                                throw Exception(appState.error ?? 'Error desconocido');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Error al enviar la solicitud: $e'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            participationType == 'clan' ? 'Inscribir mi Clan' : 'Enviar Solicitud',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    return CategoryConstants.colors[category] ?? AppColors.primaryOrange;
  }

  IconData _getCategoryIcon(String category) {
    return CategoryConstants.icons[category] ?? Icons.category_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fichas de Estadísticas Premium e Interactivas (3D Reactivo)
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumStatCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _PremiumStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  State<_PremiumStatCard> createState() => _PremiumStatCardState();
}

class _PremiumStatCardState extends State<_PremiumStatCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.color.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withValues(alpha: 0.2),
                      widget.color.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, size: 20, color: widget.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.value,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

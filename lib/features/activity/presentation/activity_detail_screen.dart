import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/data/mock_data.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:join_app/core/models/join_request_model.dart';
import 'package:join_app/core/services/api_client.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;

  const ActivityDetailScreen({super.key, required this.activityId});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  JoinRequestStatus? userRequestStatus;
  JoinRequest? userRequest;

  @override
  void initState() {
    super.initState();
    userRequestStatus = null;
    userRequest = null;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activity = appState.activities.firstWhere(
      (a) => a.id == widget.activityId,
      orElse: () => mockActivities.firstWhere(
        (a) => a.id == widget.activityId,
        orElse: () => mockActivities[0],
      ),
    );
    final currentUserId = context.read<AppState>().currentUser?.id;
    final isOrganizer =
        currentUserId != null && activity.organizerId == currentUserId;
    final currentStatus = userRequestStatus ?? appState.getMyRequestStatus(widget.activityId);
    final isAccepted = isOrganizer || currentStatus == JoinRequestStatus.accepted;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium Sliver App Bar
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.white,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.8),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.black87),
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
                          backgroundColor: Colors.white.withValues(alpha: 0.8),
                          child: IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                color: Colors.blue),
                            onPressed: () => context
                                .push('/main/activity/${activity.id}/edit'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.8),
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
                    StretchMode.blurBackground
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
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
                      // Elegante gradiente inferior negro a transparente
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.black.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.4, 0.9],
                            ),
                          ),
                        ),
                      ),
                      // Info Overpuesta en Glassmorphism
                      Positioned(
                        bottom: 48,
                        left: 20,
                        right: 20,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(activity.category),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_getCategoryIcon(activity.category), size: 12, color: Colors.white),
                                        const SizedBox(width: 6),
                                        Text(
                                          activity.category,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                                        ),
                                      ],
                                    ),
                                  ).animate().slideY(begin: 0.5, duration: 400.ms).fadeIn(),
                                  const SizedBox(height: 12),
                                  Text(
                                    activity.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                      letterSpacing: -0.5,
                                    ),
                                  ).animate().slideY(begin: 0.3, duration: 500.ms).fadeIn(delay: 100.ms),
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8)),
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.primaryOrange, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundImage: activity.organizerImageUrl
                                          .startsWith('http')
                                      ? NetworkImage(activity.organizerImageUrl)
                                          as ImageProvider
                                      : AssetImage(activity.organizerImageUrl),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Organzado por',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          activity.organizerName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: AppColors.navyBlue),
                                        ),
                                        const SizedBox(width: 4),
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
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                        Text(
                                          ' (${activity.organizerActivities} planes creados)',
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                        const Text('Acerca del plan',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navyBlue)),
                        const SizedBox(height: 12),
                        Text(
                          activity.description,
                          style: TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: Colors.grey[800]),
                        ).animate().fadeIn(duration: 600.ms, delay: 400.ms),

                        const SizedBox(height: 32),
                        const Text('Ubicación',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navyBlue)),
                        const SizedBox(height: 12),

                        // Premium Map Design (Real si es aceptado, blur si no)
                        if (isAccepted && activity.latitude != null && activity.longitude != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded, color: AppColors.primaryOrange, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    activity.locationName.isNotEmpty ? activity.locationName : activity.location,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 600.ms, delay: 450.ms),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: SizedBox(
                              height: 220,
                              child: IgnorePointer(
                                ignoring: true,
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(activity.latitude!, activity.longitude!),
                                    initialZoom: 15.0,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}{r}.png',
                                      userAgentPackageName: 'com.join.app',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(activity.latitude!, activity.longitude!),
                                          width: 60,
                                          height: 60,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryOrange.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Container(
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
                                  final url = 'https://www.google.com/maps/search/?api=1&query=${activity.latitude},${activity.longitude}';
                                  if (await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.navyBlue,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Icon(Icons.map_rounded, color: Colors.blue),
                                label: const Text('Abrir en Google Maps / Otras apps', style: TextStyle(fontWeight: FontWeight.bold)),
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

          // Bottom Action Bar Fixed
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -10),
                      blurRadius: 20),
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
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/main/activity/${activity.id}/group'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: AppColors.primaryOrange.withValues(alpha: 0.4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          icon: const Icon(Icons.shield_rounded),
          label: const Text('Eres Organizador - Ver Grupo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    }

    if (currentStatus == null) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () => _showJoinDialogPremium(context, activity),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: AppColors.primaryOrange.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('¡Solicitar unirme ahora!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
    } else if (currentStatus == JoinRequestStatus.pending) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange[200]!)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pending_actions, color: Colors.orange),
            SizedBox(width: 8),
            Text('Petición enviada, esperando respuesta',
                style: TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (currentStatus == JoinRequestStatus.accepted) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/main/activity/${activity.id}/group'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.green.withValues(alpha: 0.4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          icon: const Icon(Icons.chat_bubble_rounded),
          label: const Text('Eres Miembro - Ver Chat',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showJoinDialogPremium(BuildContext context, Activity activity) {
    _buildJoinBottomSheet(context, activity);
  }

  void _buildJoinBottomSheet(BuildContext context, Activity activity) {
    final msgCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
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
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Preséntate 🤙',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyBlue),
              ),
              const SizedBox(height: 8),
              Text(
                'Un buen mensaje aumenta las chances de que ${activity.organizerName} te acepte en el plan.',
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: msgCtrl,
                decoration: InputDecoration(
                  hintText:
                      '¡Hola! Me encantaría unirme a esta increíble actividad porque...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                        color: AppColors.primaryOrange, width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  contentPadding: const EdgeInsets.all(20),
                ),
                maxLines: 4,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    context.pop(); // Close bottom sheet

                    try {
                      // Call the real backend to create the join request
                      final res = await ApiClient.instance.post(
                        '/join_requests.php?action=create',
                        {
                          'activityId': widget.activityId,
                          'message': msgCtrl.text,
                        },
                      );

                      // Si no tira error, es un éxito 100%. ApiClient ya verifica el "success".
                      setState(() {
                        userRequestStatus = JoinRequestStatus.pending;
                        userRequest = JoinRequest.fromJson(res['request']);
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
                                        'Solicitud enviada a ${activity.organizerName}')),
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
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppColors.primaryOrange.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 20),
                  label: const Text('Enviar Solicitud',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Deportes':
        return const Color(0xFFEF4444);
      case 'Comida':
        return AppColors.intenseOrange;
      case 'Naturaleza':
        return const Color(0xFF10B981);
      case 'Chill':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Deportes':
        return FontAwesomeIcons.football;
      case 'Comida':
        return FontAwesomeIcons.utensils;
      case 'Naturaleza':
        return FontAwesomeIcons.tree;
      case 'Chill':
        return FontAwesomeIcons.music;
      default:
        return FontAwesomeIcons.star;
    }
  }
}

class _PremiumStatCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

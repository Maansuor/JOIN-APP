import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _headerController;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final myActivities = appState.myActivities;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 95,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCollapsed = constraints.maxHeight <= kToolbarHeight + 10;
                    return FlexibleSpaceBar(
                      background: _buildHeader(),
                      titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      title: AnimatedOpacity(
                        opacity: isCollapsed ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.primaryOrange, Color(0xFFFF2D55)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            'Mis Planes',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppColors.navyBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.12)
                                : AppColors.navyBlue.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.add_rounded,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : AppColors.navyBlue,
                            size: 22,
                          ),
                          onPressed: () => context.push('/main/create'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          if (myActivities.isEmpty)
            SliverFillRemaining(child: _buildEmptyState(context))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _PremiumActivityCard(activity: myActivities[index], index: index),
                  ),
                  childCount: myActivities.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerController,
      builder: (context, _) {
        final t = _headerController.value;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF161920).withValues(alpha: 0.82)
                : Colors.white.withValues(alpha: 0.82),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.04),
                width: 1,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Orbe decorativo muy suave en la esquina
              Positioned(
                right: -20 + t * 15,
                top: -20 + t * 10,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryOrange.withValues(alpha: 0.15),
                        AppColors.primaryOrange.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 80, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryOrange, Color(0xFFFF2D55)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [AppColors.primaryOrange, Color(0xFFFF2D55)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              'Mis Planes',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Actividades en las que eres el anfitrión',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF94A3B8)
                              : AppColors.navyBlue.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rocket_launch_rounded, size: 48, color: AppColors.primaryOrange),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: 2.seconds),
          const SizedBox(height: 24),
          Text('Aún no has creado planes',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(
              'Conviértete en anfitrión y reúne personas\ncon tus mismos intereses',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF94A3B8)
                      : Colors.grey[600],
                  height: 1.5)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/main/create'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear mi primer plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 4,
              shadowColor: AppColors.primaryOrange.withValues(alpha: 0.4),
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}

class _PremiumActivityCard extends StatelessWidget {
  final Activity activity;
  final int index;

  const _PremiumActivityCard({required this.activity, required this.index});

  Color get _categoryColor {
    switch (activity.category) {
      case 'Deportes':
        return const Color(0xFFE53935);
      case 'Comida':
        return const Color(0xFFFFA726);
      case 'Naturaleza':
        return const Color(0xFF43A047);
      case 'Chill':
        return const Color(0xFF5E35B1);
      case 'Juntas':
        return const Color(0xFFD81B60);
      default:
        return AppColors.primaryOrange;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Deportes':
        return Icons.sports_baseball_outlined;
      case 'Comida':
        return Icons.restaurant_outlined;
      case 'Naturaleza':
        return Icons.forest_outlined;
      case 'Chill':
        return Icons.local_cafe_outlined;
      case 'Juntas':
        return Icons.celebration_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFull = activity.currentParticipants >= activity.maxParticipants;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFF041249).withValues(alpha: 0.05),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen Header con Overlays Premium
          SizedBox(
            height: 155,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Imagen de Fondo
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: activity.imageUrl.startsWith('http')
                      ? Image.network(activity.imageUrl, fit: BoxFit.cover)
                      : Image.asset(activity.imageUrl, fit: BoxFit.cover),
                ),
                // Gradiente oscuro sutil para legibilidad
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                ),
                // Badge de Categoría Premium en degradado (Arriba Izquierda)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _categoryColor,
                          _categoryColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _categoryColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCategoryIcon(activity.category),
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          activity.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Badge de Estado Abierto/Lleno en esmerilado (Arriba Derecha)
                Positioned(
                  top: 14,
                  right: 14,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isFull ? 'Lleno' : 'Abierto',
                          style: TextStyle(
                            color: isFull ? AppColors.lightOrange : Colors.green[300],
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cuerpo de la tarjeta
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título Premium
                Text(
                  activity.title,
                  style: GoogleFonts.outfit(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                // Chips de Información (Modernos y Delicados)
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    // Chip de Fecha
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.12),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('d MMM yyyy, HH:mm').format(activity.eventDateTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chip de Participantes
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryOrange.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.12),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 12,
                            color: AppColors.primaryOrange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${activity.currentParticipants}/${activity.maxParticipants} participantes',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFEDD5) : const Color(0xFF7C2D12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Fila de Botones de Acción Glassmórficos
                Row(
                  children: [
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.group_add_outlined,
                        label: 'Solicitudes',
                        color: AppColors.skyBlue,
                        onTap: () => context.push('/main/activity/${activity.id}/requests'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.forum_outlined,
                        label: 'Chat',
                        color: Colors.purple,
                        onTap: () => context.push('/main/activity/${activity.id}/group'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.edit_outlined,
                        label: 'Editar',
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey[700]!,
                        onTap: () => context.push('/main/activity/${activity.id}/edit'),
                      ),
                    ),
                    if (activity.currentParticipants <= 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionBtn(
                          icon: Icons.delete_outline_rounded,
                          label: 'Eliminar',
                          color: const Color(0xFFE53935),
                          onTap: () => _confirmDelete(context, activity),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: 100 * index)).slideY(begin: 0.2, curve: Curves.easeOut);
  }

  void _confirmDelete(BuildContext context, Activity activity) {
    HapticFeedback.heavyImpact();
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, a1, a2) => const SizedBox(),
      transitionBuilder: (ctx, animation, _, __) {
        final double scale = Curves.easeOutBack.transform(animation.value);
        final double opacity = Curves.easeIn.transform(animation.value);
        return Transform.scale(
          scale: scale.clamp(0.0, 1.0),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: AlertDialog(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 20,
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? const Color(0xFF2E1A1A)
                          : const Color(0xFFFDEDEC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Color(0xFFE53935),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '¿Eliminar plan?',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Esta acción no se puede deshacer. Tu plan "${activity.title}" se borrará permanentemente de Join.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? const Color(0xFF94A3B8)
                          : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? const Color(0xFF2E323F)
                                  : Colors.grey.shade300,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            'Cancelar',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? const Color(0xFFE2E8F0)
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(ctx);
                            
                            // Mostrar cargando
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Eliminando actividad...'),
                                duration: Duration(seconds: 1),
                              ),
                            );

                            try {
                              await context.read<AppState>().deleteActivity(activity.id);
                              
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🗑️ Plan eliminado correctamente'),
                                    backgroundColor: Color(0xFFE53935),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error al eliminar: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Eliminar',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.04),
            color.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.14),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          highlightColor: color.withValues(alpha: 0.05),
          splashColor: color.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

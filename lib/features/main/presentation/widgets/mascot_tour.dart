import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:join_app/core/theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════
///  MascotTour — Minitutorial guiado por la mascota
///
///  La primera vez que el usuario llega al home tras el onboarding,
///  su iguana le da la bienvenida y le explica las secciones clave
///  de la app en un recorrido de 5 pasos.
/// ══════════════════════════════════════════════════════════════
class MascotTour {
  MascotTour._();

  static const _prefsKey = 'mascot_tour_seen_v1';
  static bool _showing = false;

  /// Muestra el tour solo si el usuario nunca lo ha visto.
  static Future<void> maybeShow(
    BuildContext context, {
    required String mascotName,
    required String mascotAsset,
  }) async {
    if (_showing) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKey) ?? false) return;
    if (!context.mounted) return;

    _showing = true;
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'tour',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
      pageBuilder: (context, _, __) => _MascotTourDialog(
        mascotName: mascotName,
        mascotAsset: mascotAsset,
      ),
    );
    await prefs.setBool(_prefsKey, true);
    _showing = false;
  }
}

class _TourStep {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  const _TourStep(this.icon, this.color, this.title, this.message);
}

class _MascotTourDialog extends StatefulWidget {
  final String mascotName;
  final String mascotAsset;

  const _MascotTourDialog({
    required this.mascotName,
    required this.mascotAsset,
  });

  @override
  State<_MascotTourDialog> createState() => _MascotTourDialogState();
}

class _MascotTourDialogState extends State<_MascotTourDialog> {
  int _step = 0;

  late final List<_TourStep> _steps = [
    _TourStep(
      Icons.waving_hand_rounded,
      const Color(0xFFFFB300),
      '¡Hola! Soy ${widget.mascotName} 🦎',
      'Seré tu compañera de aventuras en Join. Déjame mostrarte la app en 1 minuto, ¿va?',
    ),
    const _TourStep(
      Icons.widgets_rounded,
      AppColors.primaryOrange,
      'Inicio',
      'Aquí descubres planes cerca de ti: pichangas, parrilladas, trekking y más. Filtra por lo que te gusta.',
    ),
    const _TourStep(
      Icons.add_circle_rounded,
      Color(0xFFFF2D55),
      'El botón naranja ➕',
      '¿Tienes una idea? Crea tu propio plan en segundos y deja que la gente se una.',
    ),
    const _TourStep(
      Icons.forum_rounded,
      Color(0xFF38BDF8),
      'Mensajes',
      'Cada plan tiene su grupo: chatea, organiza los aportes y rompe el hielo con minijuegos.',
    ),
    const _TourStep(
      Icons.person_rounded,
      Color(0xFFC084FC),
      'Perfil y tu Clan',
      'Crea tu clan de amigos, gana insignias y hazme crecer con cada aventura. ¡Vamos!',
    ),
  ];

  bool get _isLast => _step == _steps.length - 1;

  void _next() {
    HapticFeedback.selectionClick();
    if (_isLast) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Mascota flotando ─────────────────────────────
              Image.asset(
                widget.mascotAsset,
                height: 140,
                fit: BoxFit.contain,
                cacheWidth: 420,
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -8, duration: 1800.ms, curve: Curves.easeInOut),

              const SizedBox(height: 4),

              // ── Tarjeta del paso ─────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF161920) : Colors.white)
                          .withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: step.color.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Contenido del paso (animado al cambiar)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0.15, 0),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Column(
                            key: ValueKey(_step),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: step.color.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    Icon(step.icon, color: step.color, size: 30),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                step.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                step.message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Indicadores de paso ──────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_steps.length, (i) {
                            final active = i == _step;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: active ? 22 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: active
                                    ? step.color
                                    : (isDark
                                        ? const Color(0xFF334155)
                                        : Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 18),

                        // ── Botón principal ──────────────────────
                        GestureDetector(
                          onTap: _next,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primaryOrange,
                                  Color(0xFFFF2D55)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryOrange
                                      .withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isLast ? '¡A explorar!' : 'Siguiente',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _isLast
                                        ? Icons.rocket_launch_rounded
                                        : Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Saltar ───────────────────────────────
                        if (!_isLast)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Text(
                                'Saltar tour',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : Colors.grey.shade400,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

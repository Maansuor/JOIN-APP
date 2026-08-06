import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════
///  Componentes premium compartidos del formulario de actividad
///  (crear + editar) — header, encabezados de sección, botón de
///  tips con la mascota y diálogo de éxito con confeti.
/// ══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
//  Header premium (SliverAppBar)
// ─────────────────────────────────────────────────────────────────
SliverAppBar activityFormAppBar({
  required Color accent,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onClose,
}) {
  final dark = Color.lerp(accent, Colors.black, 0.28)!;
  final deep = Color.lerp(accent, Colors.black, 0.5)!;

  return SliverAppBar(
    toolbarHeight: 76,
    expandedHeight: 76,
    pinned: true,
    backgroundColor: dark,
    elevation: 0,
    automaticallyImplyLeading: false,
    leadingWidth: 60,
    leading: Center(
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _GlassIconButton(icon: Icons.close_rounded, onTap: onClose),
      ),
    ),
    centerTitle: true,
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    ],
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(30),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    flexibleSpace: FlexibleSpaceBar(
      background: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, dark, deep],
                ),
              ),
            ),
            Positioned(
              top: -40,
              right: -30,
              child: _orb(140, Colors.white.withValues(alpha: 0.12)),
            ),
            Positioned(
              bottom: -50,
              left: -40,
              child: _orb(150, Colors.black.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _orb(double size, Color color) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Encabezado de sección premium
// ─────────────────────────────────────────────────────────────────
class FormSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String? subtitle;

  const FormSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: 0.4)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.18),
                color.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              color: AppColors.navyBlue,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Botón flotante de Tips — dado por la MASCOTA del usuario
// ─────────────────────────────────────────────────────────────────
class MascotTipsButton extends StatefulWidget {
  final Color accent;
  final String category;

  const MascotTipsButton({
    super.key,
    required this.accent,
    required this.category,
  });

  @override
  State<MascotTipsButton> createState() => _MascotTipsButtonState();
}

class _MascotTipsButtonState extends State<MascotTipsButton> {
  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final recs = tipsForCategory(widget.category);
    if (recs.isEmpty) return const SizedBox.shrink();

    final user = context.watch<AppState>().currentUser;
    final mascotAsset =
        user?.companionAsset ?? 'assets/images/mascota/ELI.png';
    final mascotName = user?.companionName ?? 'Eli';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showHint)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 185),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Text(
              '¡Hola! ¿Ideas para tu plan? Tócame 💡',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.navyBlue,
                height: 1.3,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.2),
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() => _showHint = false);
            _showTips(context, recs, mascotAsset, mascotName);
          },
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  widget.accent,
                  Color.lerp(widget.accent, const Color(0xFFFF2D55), 0.5)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: Image.asset(
                      mascotAsset,
                      fit: BoxFit.contain,
                      cacheWidth: 160,
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC94D),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.lightbulb_rounded,
                        color: Colors.white, size: 11),
                  ),
                ),
              ],
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -6, duration: 1800.ms, curve: Curves.easeInOut),
      ],
    );
  }

  void _showTips(BuildContext context, List<MascotTip> recs,
      String mascotAsset, String mascotName) {
    int currentIndex = 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSheet) {
          final currentTip = recs[currentIndex];
          return Container(
            margin: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.accent,
                        Color.lerp(widget.accent, Colors.black, 0.3)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(
                          child: Image.asset(mascotAsset,
                              fit: BoxFit.contain, cacheWidth: 160),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .rotate(
                              begin: -0.03,
                              end: 0.03,
                              duration: 1400.ms,
                              curve: Curves.easeInOut),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$mascotName te aconseja',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tip ${currentIndex + 1} de ${recs.length} · ${widget.category}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    children: [
                      // Tarjeta interactiva con burbuja de diálogo
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.08, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          key: ValueKey<int>(currentIndex),
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFC),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: widget.accent.withValues(alpha: 0.15),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Emoji circular
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: widget.accent.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: widget.accent.withValues(alpha: 0.25),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    currentTip.emoji,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Título del Tip
                              Text(
                                currentTip.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navyBlue,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Descripción detallada
                              Text(
                                currentTip.description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Indicador de pasos (dots)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(recs.length, (index) {
                          final isSelected = index == currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isSelected ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.accent
                                  : widget.accent.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),

                      // Botones de navegación
                      Row(
                        children: [
                          if (currentIndex > 0)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: OutlinedButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    setStateSheet(() {
                                      currentIndex--;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: widget.accent,
                                    side: BorderSide(color: widget.accent.withValues(alpha: 0.5), width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_back_ios_new_rounded, size: 13),
                                      SizedBox(width: 6),
                                      Text(
                                        'Anterior',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                if (currentIndex < recs.length - 1) {
                                  setStateSheet(() {
                                    currentIndex++;
                                  });
                                } else {
                                  Navigator.pop(ctx);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      widget.accent,
                                      Color.lerp(widget.accent, const Color(0xFFFF2D55), 0.4)!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.accent.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      currentIndex < recs.length - 1
                                          ? 'Siguiente'
                                          : '¡Listo, gracias!',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (currentIndex < recs.length - 1) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 13),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MascotTip {
  final String emoji;
  final String title;
  final String description;

  const MascotTip({
    required this.emoji,
    required this.title,
    required this.description,
  });
}

/// Recomendaciones del asistente según la categoría principal.
List<MascotTip> tipsForCategory(String category) {
  switch (category) {
    case 'Deportes':
      return const [
        MascotTip(
          emoji: '💧',
          title: 'Hidratación constante',
          description: 'Lleva agua suficiente y recuérdales a los demás traer la suya. Mantenerse hidratado evita fatigas y calambres.',
        ),
        MascotTip(
          emoji: '🧴',
          title: 'Protección solar',
          description: 'El bloqueador solar, gorra y lentes son indispensables si juegan al aire libre, ¡incluso en días nublados!',
        ),
        MascotTip(
          emoji: '⛑️',
          title: 'Primeros auxilios',
          description: 'Un botiquín básico con curitas y desinfectante nunca está de más para pequeños imprevistos o raspones.',
        ),
        MascotTip(
          emoji: '💪',
          title: 'Nivel físico del grupo',
          description: 'Aclara si es para principiantes, intermedios o avanzados para que todos se sientan cómodos y seguros jugando.',
        ),
        MascotTip(
          emoji: '⏱️',
          title: 'Calentamiento previo',
          description: 'Establece un margen de 10-15 minutos para calentar juntos antes de empezar el partido o entrenamiento.',
        ),
        MascotTip(
          emoji: '🎒',
          title: 'Equipamiento necesario',
          description: 'Especifica si deben llevar su propio balón, raqueta o implementos para evitar malentendidos.',
        ),
      ];
    case 'Comida':
      return const [
        MascotTip(
          emoji: '🌱',
          title: 'Restricciones y alergias',
          description: 'Consulta antes si algún participante tiene alergias, es vegetariano, vegano o celíaco para adaptar el menú.',
        ),
        MascotTip(
          emoji: '🍴',
          title: 'Utensilios extra',
          description: 'Llevar servilletas, cubiertos o vasos adicionales siempre salva la tarde si alguien olvida los suyos.',
        ),
        MascotTip(
          emoji: '🥗',
          title: 'Menú variado',
          description: 'Ofrece opciones ligeras y bebidas variadas (con y sin alcohol) para que todos encuentren algo a su gusto.',
        ),
        MascotTip(
          emoji: '🗑️',
          title: 'Bolsas para basura',
          description: 'Prepara bolsas de basura de antemano para dejar el espacio impecable al terminar de comer.',
        ),
        MascotTip(
          emoji: '📍',
          title: 'Reservas anticipadas',
          description: 'Si es en restaurante, asegúrate de reservar con tiempo y confirmar la asistencia un día antes.',
        ),
        MascotTip(
          emoji: '💳',
          title: 'Cuentas claras',
          description: 'Indica previamente cómo se dividirán los gastos o si cada uno paga su consumo para evitar momentos incómodos.',
        ),
      ];
    case 'Naturaleza':
      return const [
        MascotTip(
          emoji: '🦟',
          title: 'Repelente y protección',
          description: 'El repelente de insectos y bloqueador solar son tus mejores aliados en senderos, bosques o parques.',
        ),
        MascotTip(
          emoji: '🧺',
          title: 'Comodidad al sentarse',
          description: 'Una manta gruesa para el pasto o sillas plegables harán que el descanso sea mucho más placentero.',
        ),
        MascotTip(
          emoji: '🌿',
          title: 'Respeto al medio ambiente',
          description: 'No dejes huella: lleva bolsas para recolectar tus residuos y respeta la flora y fauna local.',
        ),
        MascotTip(
          emoji: '🔦',
          title: 'Batería y linterna',
          description: 'Una linterna o batería portátil son vitales si la caminata se extiende más de lo planeado.',
        ),
        MascotTip(
          emoji: '🥾',
          title: 'Calzado y calces',
          description: 'Recomienda zapatillas con buen agarre para evitar resbalones en terrenos húmedos o empinados.',
        ),
        MascotTip(
          emoji: '🗺️',
          title: 'Mapas sin conexión',
          description: 'Descarga el mapa de la zona con anticipación, ya que la señal suele fallar en áreas naturales.',
        ),
      ];
    case 'Chill':
      return const [
        MascotTip(
          emoji: '🎵',
          title: 'Playlist compartida',
          description: 'Crea una playlist colaborativa para que cada participante pueda agregar sus canciones favoritas.',
        ),
        MascotTip(
          emoji: '🎲',
          title: 'Rompehielos divertidos',
          description: 'Lleva un juego de cartas o de mesa sencillo y rápido para romper el hielo y desatar risas.',
        ),
        MascotTip(
          emoji: '☕',
          title: 'Bebidas a la mano',
          description: 'Tener a la mano una variedad de infusiones, café o jugos fríos crea un ambiente acogedor al instante.',
        ),
        MascotTip(
          emoji: '🛋️',
          title: 'Espacios cómodos',
          description: 'Elige un lugar con buena ventilación o mantas por si refresca, la comodidad invita a conversar.',
        ),
        MascotTip(
          emoji: '💬',
          title: 'Temas para conversar',
          description: 'Propón temas divertidos o preguntas curiosas para integrar a los más tímidos del grupo.',
        ),
        MascotTip(
          emoji: '📸',
          title: 'Foto del recuerdo',
          description: 'Toma una foto grupal al final del evento; los planes chill suelen dejar hermosas memorias.',
        ),
      ];
    case 'Juntas':
      return const [
        MascotTip(
          emoji: '📍',
          title: 'Punto claro de reunión',
          description: 'Elige un lugar de reunión clásico, visible y con punto de referencia claro para evitar pérdidas.',
        ),
        MascotTip(
          emoji: '🚗',
          title: 'Movilidad compartida',
          description: 'Coordina autos compartidos (carpooling) o indica qué líneas de transporte público llegan al lugar.',
        ),
        MascotTip(
          emoji: '🌧️',
          title: 'Plan de respaldo (Plan B)',
          description: 'Ten a la mano una cafetería o centro comercial cercano por si el clima decide cambiar repentinamente.',
        ),
        MascotTip(
          emoji: '🔋',
          title: 'Carga completa',
          description: 'Sugiere llevar un powerbank para que nadie se quede incomunicado a mitad de la junta.',
        ),
        MascotTip(
          emoji: '👥',
          title: 'Bienvenida al grupo',
          description: 'Llega unos minutos antes para recibir a los primeros y hacerlos sentir bienvenidos desde el inicio.',
        ),
        MascotTip(
          emoji: '🏷️',
          title: 'Facilidad de encuentro',
          description: 'Si es un grupo grande que no se conoce, un distintivo o color de ropa ayuda a reconocerse rápidamente.',
        ),
      ];
    default:
      return const [
        MascotTip(
          emoji: '✍️',
          title: 'Detalles completos',
          description: 'Describe el objetivo del plan detalladamente para atraer a personas con los mismos intereses.',
        ),
        MascotTip(
          emoji: '🗓️',
          title: 'Coordinación clara',
          description: 'Define fecha, hora y lugar precisos; la ambigüedad suele desalentar a los participantes.',
        ),
        MascotTip(
          emoji: '🎒',
          title: '¿Qué llevar?',
          description: 'Diles claramente si deben traer algo específico para que vengan bien preparados.',
        ),
        MascotTip(
          emoji: '💬',
          title: 'Mantén activo el chat',
          description: 'Utiliza el chat de la actividad para responder dudas y mantener el entusiasmo antes del día del evento.',
        ),
        MascotTip(
          emoji: '👍',
          title: 'Confirmación final',
          description: 'Pide a todos confirmar su asistencia 24 horas antes para optimizar la organización del evento.',
        ),
        MascotTip(
          emoji: '⭐',
          title: 'Buena actitud',
          description: '¡Lo más importante es disfrutar y conocer gente nueva! Ve con la mejor energía.',
        ),
      ];
  }
}

// ─────────────────────────────────────────────────────────────────
//  Diálogo premium de éxito — mascota celebrando + confeti
// ─────────────────────────────────────────────────────────────────
void showActivitySuccessDialog(
  BuildContext context, {
  required Color accent,
  required String title,
  required String message,
  required VoidCallback onPrimary,
}) {
  final user = context.read<AppState>().currentUser;
  final mascotAsset = user?.companionAsset ?? 'assets/images/mascota/ELI.png';

  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: '',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (ctx, _, __) => const SizedBox(),
    transitionBuilder: (ctx, animation, _, __) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(
          opacity: animation,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _ConfettiPainter(accent)),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 48),
                      padding: const EdgeInsets.fromLTRB(24, 62, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.navyBlue,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 22),
                          GestureDetector(
                            onTap: onPrimary,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  accent,
                                  Color.lerp(
                                      accent, const Color(0xFFFF2D55), 0.4)!,
                                ]),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '¡Genial!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -6,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              accent,
                              Color.lerp(accent, const Color(0xFFFF2D55), 0.5)!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.5),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(5),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(5),
                          child: ClipOval(
                            child: Image.asset(
                              mascotAsset,
                              fit: BoxFit.contain,
                              cacheWidth: 280,
                            ),
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(
                              begin: 0,
                              end: -7,
                              duration: 1300.ms,
                              curve: Curves.easeInOut),
                    ),
                    Positioned(
                      top: 60,
                      right: 92,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14),
                      ).animate().scale(
                            delay: 350.ms,
                            duration: 400.ms,
                            curve: Curves.easeOutBack,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ConfettiPainter extends CustomPainter {
  final Color accent;
  _ConfettiPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      accent,
      const Color(0xFFFF2D55),
      const Color(0xFFFFC94D),
      const Color(0xFF38BDF8),
      const Color(0xFF22C55E),
    ];
    final rnd = math.Random(7);
    for (var i = 0; i < 28; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.7;
      final paint = Paint()..color = colors[i % colors.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rnd.nextDouble() * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 7, height: 4),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────
//  Selectores modernos de fecha y hora (ruedas, en español)
// ─────────────────────────────────────────────────────────────────
const _kMonths = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

Future<DateTime?> showPremiumDatePicker(
  BuildContext context, {
  required Color accent,
  required DateTime initial,
}) {
  final now = DateTime.now();
  final years = [now.year, now.year + 1];
  final sel = initial.isBefore(now) ? now : initial;
  int day = sel.day, month = sel.month;
  int year = sel.year.clamp(years.first, years.last);

  int daysIn(int y, int m) => DateTime(y, m + 1, 0).day;

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => _PickerSheet(
        accent: accent,
        icon: Icons.calendar_month_rounded,
        title: '¿Qué día es el plan? 📅',
        onConfirm: () => Navigator.pop(
            ctx, DateTime(year, month, day.clamp(1, daysIn(year, month)))),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _wheel(
                initialItem: day - 1,
                count: daysIn(year, month),
                label: (i) => '${i + 1}'.padLeft(2, '0'),
                onChanged: (i) => setSheet(() => day = i + 1),
              ),
            ),
            Expanded(
              flex: 4,
              child: _wheel(
                initialItem: month - 1,
                count: 12,
                label: (i) => _kMonths[i],
                onChanged: (i) => setSheet(() => month = i + 1),
              ),
            ),
            Expanded(
              flex: 3,
              child: _wheel(
                initialItem: years.indexOf(year),
                count: years.length,
                label: (i) => '${years[i]}',
                onChanged: (i) => setSheet(() => year = years[i]),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<TimeOfDay?> showPremiumTimePicker(
  BuildContext context, {
  required Color accent,
  required TimeOfDay initial,
}) {
  int hour = initial.hour;
  int minute = initial.minute - (initial.minute % 5);

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PickerSheet(
      accent: accent,
      icon: Icons.access_time_rounded,
      title: '¿A qué hora empieza? ⏰',
      onConfirm: () =>
          Navigator.pop(ctx, TimeOfDay(hour: hour, minute: minute)),
      child: Row(
        children: [
          Expanded(
            child: _wheel(
              initialItem: hour,
              count: 24,
              label: (i) => '$i'.padLeft(2, '0'),
              onChanged: (i) => hour = i,
            ),
          ),
          const Text(
            ':',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.navyBlue),
          ),
          Expanded(
            child: _wheel(
              initialItem: minute ~/ 5,
              count: 12,
              label: (i) => '${i * 5}'.padLeft(2, '0'),
              onChanged: (i) => minute = i * 5,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _wheel({
  required int initialItem,
  required int count,
  required String Function(int) label,
  required ValueChanged<int> onChanged,
}) {
  return CupertinoPicker.builder(
    scrollController: FixedExtentScrollController(initialItem: initialItem),
    itemExtent: 42,
    diameterRatio: 1.4,
    squeeze: 1.1,
    selectionOverlay: const SizedBox.shrink(),
    onSelectedItemChanged: (i) {
      HapticFeedback.selectionClick();
      onChanged(i);
    },
    childCount: count,
    itemBuilder: (_, i) => Center(
      child: Text(
        label(i),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.navyBlue,
        ),
      ),
    ),
  );
}

class _PickerSheet extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String title;
  final VoidCallback onConfirm;
  final Widget child;

  const _PickerSheet({
    required this.accent,
    required this.icon,
    required this.title,
    required this.onConfirm,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 19),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navyBlue,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.25)),
                      ),
                    ),
                  ),
                  child,
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onConfirm();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    accent,
                    Color.lerp(accent, const Color(0xFFFF2D55), 0.4)!,
                  ]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Confirmar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

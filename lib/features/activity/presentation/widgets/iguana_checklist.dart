import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════
///  IguanaChecklist — "¿Llevas todo?" según el tipo de actividad
///
///  La mascota sugiere qué preparar según la categoría del plan.
///  El usuario marca casillas (persisten por actividad) y, al
///  completar todo, la iguana celebra: "¡Listos para salir!" 🎒
/// ══════════════════════════════════════════════════════════════
class IguanaChecklist extends StatefulWidget {
  final Activity activity;

  const IguanaChecklist({super.key, required this.activity});

  @override
  State<IguanaChecklist> createState() => _IguanaChecklistState();
}

class _IguanaChecklistState extends State<IguanaChecklist> {
  late final List<String> _items;
  final Set<int> _checked = {};
  bool _loaded = false;

  String get _prefsKey => 'iguana_checklist_${widget.activity.id}';

  @override
  void initState() {
    super.initState();
    _items = _itemsForActivity(widget.activity);
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = (json.decode(raw) as List).cast<int>();
      _checked.addAll(list.where((i) => i < _items.length));
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(_checked.toList()));
  }

  /// Sugerencias según categoría / etiquetas de la actividad
  static List<String> _itemsForActivity(Activity activity) {
    final haystack =
        '${activity.category} ${activity.tags.join(' ')} ${activity.title}'
            .toLowerCase();

    bool has(List<String> keys) => keys.any(haystack.contains);

    if (has(['camping', 'campamento'])) {
      return ['Carpa ⛺', 'Sleeping 🛌', 'Linterna 🔦', 'Agua 💧', 'Repelente 🦟', 'Snacks 🍫'];
    }
    if (has(['trekking', 'hiking', 'caminata', 'naturaleza', 'aventura'])) {
      return ['Zapatillas de trekking 🥾', 'Agua 💧', 'Bloqueador 🧴', 'Gorra 🧢', 'Snacks energéticos 🍫'];
    }
    if (has(['playa'])) {
      return ['Bloqueador 🧴', 'Toalla 🏖️', 'Ropa de baño 🩳', 'Agua 💧', 'Lentes de sol 🕶️'];
    }
    if (has(['parrillada', 'parrilla', 'bbq', 'comida', 'gastronomía', 'picnic'])) {
      return ['Tu aporte del grupo 🍗', 'Bebidas frías 🥤', 'Hielo 🧊', 'Buen apetito 😋'];
    }
    if (has(['deportes', 'fútbol', 'futbol', 'pichanga', 'running', 'ciclismo', 'natación'])) {
      return ['Ropa deportiva 👕', 'Zapatillas 👟', 'Agua 💧', 'Toalla 🤍', 'Muchas ganas 🔥'];
    }
    if (has(['fiesta', 'juntas', 'cumple', 'karaoke', 'chill'])) {
      return ['Tu aporte 🥤', 'Parlante o playlist 🎵', 'Juegos de mesa 🎲', 'Energía al 100 ⚡'];
    }
    // Genérico
    return ['Celular cargado 🔋', 'Agua 💧', 'Puntualidad ⏰', 'Buena actitud 😎'];
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final user = context.watch<AppState>().currentUser;
    final mascotName = user?.companionName ?? 'Eli';
    final mascotAsset = user?.companionAsset ?? 'assets/images/mascota/ELI.png';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final done = _checked.length;
    final total = _items.length;
    final completed = done == total;
    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: completed
              ? [
                  const Color(0xFF22C55E).withValues(alpha: 0.12),
                  const Color(0xFF22C55E).withValues(alpha: 0.04),
                ]
              : [
                  AppColors.primaryOrange.withValues(alpha: 0.10),
                  AppColors.primaryOrange.withValues(alpha: 0.03),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: completed
              ? const Color(0xFF22C55E).withValues(alpha: 0.4)
              : AppColors.primaryOrange.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera: mascota + título + progreso ─────────────
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (completed
                          ? const Color(0xFF22C55E)
                          : AppColors.primaryOrange)
                      .withValues(alpha: 0.15),
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: Image.asset(
                    mascotAsset,
                    fit: BoxFit.contain,
                    cacheWidth: 140,
                  ),
                ),
              )
                  .animate(
                    target: completed ? 1 : 0,
                    onPlay: (c) {},
                  )
                  .shake(hz: 3, rotation: 0.06, duration: 600.ms),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      completed
                          ? '¡Mochila lista! 🎒'
                          : '$mascotName pregunta: ¿llevas todo?',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      completed
                          ? '¡Ya estamos listos para salir!'
                          : 'Marca lo que ya tienes preparado',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Progreso x/y
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: completed
                      ? const Color(0xFF22C55E)
                      : AppColors.primaryOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  completed ? '✓' : '$done/$total',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: completed ? Colors.white : AppColors.primaryOrange,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Barra de progreso ────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation(
                  completed ? const Color(0xFF22C55E) : AppColors.primaryOrange,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Casillas ─────────────────────────────────────────
          ..._items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final isChecked = _checked.contains(i);

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  isChecked ? _checked.remove(i) : _checked.add(i);
                });
                _persist();
                if (_checked.length == _items.length) {
                  HapticFeedback.mediumImpact();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isChecked
                            ? const Color(0xFF22C55E)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: isChecked
                              ? const Color(0xFF22C55E)
                              : (isDark
                                  ? const Color(0xFF475569)
                                  : Colors.grey.shade400),
                          width: 1.8,
                        ),
                      ),
                      child: isChecked
                          ? const Icon(Icons.check_rounded,
                              size: 15, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isChecked ? FontWeight.w500 : FontWeight.w600,
                          decoration:
                              isChecked ? TextDecoration.lineThrough : null,
                          color: isChecked
                              ? (isDark
                                  ? const Color(0xFF64748B)
                                  : Colors.grey[500])
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        child: Text(item),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06);
  }
}

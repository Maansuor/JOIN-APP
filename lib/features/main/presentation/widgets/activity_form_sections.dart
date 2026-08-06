import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:join_app/core/models/interest_model.dart';
import 'package:join_app/core/theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════
///  Secciones compartidas del formulario de actividad
///
///  Usadas por CreateActivityScreen y EditActivityScreen para que
///  ambas pantallas se mantengan SIEMPRE idénticas:
///   · GroupedCategoryPicker  — principales + subcategorías agrupadas
///   · MeetingPointSection    — lugar del plan vs punto de encuentro
///   · HostSuggestionsSection — recomendaciones del anfitrión
/// ══════════════════════════════════════════════════════════════

const _kMaxMains = 3;
const _kMaxSubs = 5;

// ─────────────────────────────────────────────────────────────────
//  Selector de categorías agrupadas
// ─────────────────────────────────────────────────────────────────
class GroupedCategoryPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const GroupedCategoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  Set<String> get _mains =>
      selected.where(CategoryConstants.groups.containsKey).toSet();
  Set<String> get _subs =>
      selected.where((c) => !CategoryConstants.groups.containsKey(c)).toSet();

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.primaryOrange,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _toggleMain(BuildContext context, String cat) {
    HapticFeedback.selectionClick();
    final next = Set<String>.from(selected);
    if (next.contains(cat)) {
      if (_mains.length <= 1) {
        _snack(context, 'Tu plan necesita al menos 1 categoría principal.');
        return;
      }
      next.remove(cat);
      // Al quitar la principal se quitan sus subcategorías
      next.removeAll(CategoryConstants.groups[cat] ?? const []);
    } else {
      if (_mains.length >= _kMaxMains) {
        _snack(context, 'Máximo $_kMaxMains categorías principales.');
        return;
      }
      next.add(cat);
    }
    onChanged(next);
  }

  void _toggleSub(BuildContext context, String cat) {
    HapticFeedback.selectionClick();
    final next = Set<String>.from(selected);
    if (next.contains(cat)) {
      next.remove(cat);
    } else {
      if (_subs.length >= _kMaxSubs) {
        _snack(context, 'Máximo $_kMaxSubs subcategorías.');
        return;
      }
      next.add(cat);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final mains = CategoryConstants.mainCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Tarjetas de categorías principales ──────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: mains.length,
          itemBuilder: (context, index) {
            final cat = mains[index];
            final isSelected = selected.contains(cat);
            final color = CategoryConstants.colors[cat] ?? AppColors.primaryOrange;
            final icon = CategoryConstants.icons[cat] ?? Icons.category_rounded;
            final desc = CategoryConstants.mainDescriptions[cat] ?? '';

            return GestureDetector(
              onTap: () => _toggleMain(context, cat),
              child: AnimatedScale(
                scale: isSelected ? 1.03 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade200,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.18),
                              blurRadius: 16,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.12)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              icon,
                              size: 22,
                              color: isSelected ? color : Colors.grey.shade600,
                            ),
                          ),
                          AnimatedScale(
                            scale: isSelected ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat,
                            style: const TextStyle(
                              color: AppColors.navyBlue,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // ── Subcategorías agrupadas por cada principal elegida ──
        ..._mains.map((main) {
          final subs = CategoryConstants.groups[main] ?? const [];
          if (subs.isEmpty) return const SizedBox.shrink();
          final mainColor =
              CategoryConstants.colors[main] ?? AppColors.primaryOrange;

          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CategoryConstants.icons[main] ?? Icons.category_rounded,
                      size: 14,
                      color: mainColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Específicas de $main',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: mainColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· opcional',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Si no eliges ninguna, tu plan aparece en todo $main.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: subs.map((sub) {
                    final isSelected = selected.contains(sub);
                    final color =
                        CategoryConstants.colors[sub] ?? AppColors.primaryOrange;
                    final icon =
                        CategoryConstants.icons[sub] ?? Icons.category_rounded;
                    return GestureDetector(
                      onTap: () => _toggleSub(context, sub),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? color : Colors.grey.shade200,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                size: 14,
                                color: isSelected ? Colors.white : color),
                            const SizedBox(width: 6),
                            Text(
                              sub,
                              style: TextStyle(
                                color: isSelected ? Colors.white : color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Punto de encuentro: mismo lugar vs punto previo
// ─────────────────────────────────────────────────────────────────
class MeetingPointSection extends StatelessWidget {
  final Color accentColor;
  final bool hasSeparate;
  final ValueChanged<bool> onChanged;
  final TextEditingController controller;
  final VoidCallback onPickOnMap;

  const MeetingPointSection({
    super.key,
    required this.accentColor,
    required this.hasSeparate,
    required this.onChanged,
    required this.controller,
    required this.onPickOnMap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Dónde se encuentran?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _optionCard(
                context,
                selected: !hasSeparate,
                icon: Icons.flag_rounded,
                title: 'En el lugar\ndel plan',
                onTap: () => onChanged(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _optionCard(
                context,
                selected: hasSeparate,
                icon: Icons.directions_walk_rounded,
                title: 'Punto de\nencuentro previo',
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
        // ── Campo del punto de encuentro (con mapa) ─────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: hasSeparate
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: onPickOnMap,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: controller.text.isEmpty
                                  ? Colors.grey.shade300
                                  : accentColor.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.pin_drop_rounded,
                                  color: accentColor, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  controller.text.isEmpty
                                      ? 'Toca para elegir el punto de encuentro...'
                                      : controller.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: controller.text.isEmpty
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                    color: controller.text.isEmpty
                                        ? Colors.grey.shade400
                                        : AppColors.navyBlue,
                                  ),
                                ),
                              ),
                              Icon(Icons.map_rounded,
                                  color: accentColor.withValues(alpha: 0.6),
                                  size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Los participantes verán ambos puntos: encuentro y lugar del plan.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _optionCard(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accentColor : Colors.grey.shade200,
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? accentColor.withValues(alpha: 0.15)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? accentColor : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.navyBlue : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Sugerencias del anfitrión (con atajos según categorías)
// ─────────────────────────────────────────────────────────────────
class HostSuggestionsSection extends StatefulWidget {
  final Color accentColor;
  final Set<String> selectedCategories;
  final List<String> suggestions;
  final ValueChanged<String> onAdd; // recibe el texto YA con emoji
  final ValueChanged<String> onRemove;

  const HostSuggestionsSection({
    super.key,
    required this.accentColor,
    required this.selectedCategories,
    required this.suggestions,
    required this.onAdd,
    required this.onRemove,
  });

  /// Emoji contextual según el contenido de la sugerencia
  static String emojiFor(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('zapati') || lower.contains('calzado') || lower.contains('tenis') || lower.contains('bota')) return '👟';
    if (lower.contains('bloqueador') || lower.contains('solar') || lower.contains('protector')) return '🧴';
    if (lower.contains('ropa') || lower.contains('abrigo') || lower.contains('chaqueta') || lower.contains('casaca') || lower.contains('capas')) return '🧥';
    if (lower.contains('agua') || lower.contains('hidrat')) return '💧';
    if (lower.contains('gorra') || lower.contains('sombrero') || lower.contains('lente')) return '🧢';
    if (lower.contains('puntual') || lower.contains('hora') || lower.contains('temprano')) return '⏰';
    if (lower.contains('repelente') || lower.contains('insecto')) return '🦟';
    if (lower.contains('linterna') || lower.contains('frontal') || lower.contains('luz')) return '🔦';
    if (lower.contains('mochila') || lower.contains('bolso') || lower.contains('morral')) return '🎒';
    if (lower.contains('dinero') || lower.contains('efectivo') || lower.contains('yape') || lower.contains('cambio')) return '💰';
    if (lower.contains('comer') || lower.contains('desayun') || lower.contains('almuerz') || lower.contains('apetito')) return '🍽️';
    if (lower.contains('estacion') || lower.contains('parque') || lower.contains('movilidad')) return '🚌';
    if (lower.contains('foto') || lower.contains('cámara') || lower.contains('celular')) return '📸';
    if (lower.contains('toalla') || lower.contains('cambio de ropa')) return '🧳';
    if (lower.contains('bebida') || lower.contains('gaseosa') || lower.contains('trago')) return '🥤';
    if (lower.contains('snack') || lower.contains('piqueo')) return '🍿';
    if (lower.contains('juego') || lower.contains('cartas') || lower.contains('mesa')) return '🎲';
    if (lower.contains('vibra') || lower.contains('actitud') || lower.contains('energ')) return '⚡';
    if (lower.contains('playlist') || lower.contains('música') || lower.contains('parlante')) return '🎵';
    return '💡';
  }

  /// Atajos de sugerencias según las categorías principales del plan
  static const Map<String, List<String>> _quickByMain = {
    'Deportes': ['Ropa deportiva', 'Zapatillas cómodas', 'Agua', 'Toalla'],
    'Comida': ['Buen apetito', 'Efectivo o Yape', 'Bebida para compartir'],
    'Naturaleza': ['Ropa por capas', 'Zapatillas de trekking', 'Bloqueador', 'Repelente', 'Agua 1L+'],
    'Chill': ['Puntualidad', 'Buena vibra', 'Snack para compartir'],
    'Juntas': ['Bebidas', 'Snacks', 'Juegos de mesa', 'Playlist'],
  };

  @override
  State<HostSuggestionsSection> createState() => _HostSuggestionsSectionState();
}

class _HostSuggestionsSectionState extends State<HostSuggestionsSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    final withEmoji = '${HostSuggestionsSection.emojiFor(text)} $text';
    if (widget.suggestions.contains(withEmoji)) return;
    widget.onAdd(withEmoji);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    // Atajos según las principales elegidas (que aún no estén agregadas)
    final quicks = <String>[];
    for (final main in widget.selectedCategories) {
      for (final q in HostSuggestionsSection._quickByMain[main] ?? const <String>[]) {
        final withEmoji = '${HostSuggestionsSection.emojiFor(q)} $q';
        if (!widget.suggestions.contains(withEmoji) && !quicks.contains(q)) {
          quicks.add(q);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Input + botón agregar ────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: _add,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: '¿Qué recomiendas traer o saber?',
                  hintText: 'Ej: Llevar bloqueador, ropa cómoda...',
                  labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.tips_and_updates_rounded,
                      color: accent, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: accent, width: 1.8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _add(_controller.text),
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),

        // ── Atajos contextuales según la categoría ───────────
        if (quicks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Sugerencias rápidas para tu plan:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quicks.take(8).map((q) {
              return GestureDetector(
                onTap: () => _add(q),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.grey.shade300,
                        style: BorderStyle.solid),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '${HostSuggestionsSection.emojiFor(q)} $q',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        // ── Sugerencias agregadas ────────────────────────────
        if (widget.suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.suggestions.map((s) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onRemove(s);
                      },
                      child: Icon(Icons.close, size: 14, color: accent),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

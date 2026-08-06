import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:join_app/core/theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════
///  Juegos Rompehielo — "¿Listos para animar la reu?" 🎉
///
///  Minijuegos de grupo accesibles desde el chat de la actividad:
///   🎲 Dados virtuales   🕵️ El Impostor   🔤 Reto por inicial
/// ══════════════════════════════════════════════════════════════
void showIcebreakerSheet(BuildContext context) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _IcebreakerSheet(),
  );
}

enum _GameView { menu, dice, impostor, initial }

class _IcebreakerSheet extends StatefulWidget {
  const _IcebreakerSheet();

  @override
  State<_IcebreakerSheet> createState() => _IcebreakerSheetState();
}

class _IcebreakerSheetState extends State<_IcebreakerSheet> {
  _GameView _view = _GameView.menu;
  final _random = Random();

  // ── Dados ──────────────────────────────────────────────────
  int _die1 = 1;
  int _die2 = 6;
  int _rollCount = 0;

  // ── Impostor ───────────────────────────────────────────────
  int _players = 4;
  int _impostorIndex = 0;
  int _currentPlayer = 0;
  bool _revealed = false;
  bool _impostorStarted = false;
  String _secretWord = '';
  static const _secretWords = [
    'Pollería', 'Karaoke', 'Ceviche', 'La cancha', 'Cumbia', 'Machu Picchu',
    'Pisco sour', 'El profe', 'Anticuchos', 'La playa', 'Marinera', 'Chifa',
  ];

  // ── Reto por inicial ───────────────────────────────────────
  String _letter = '?';
  String _challenge = 'Presiona el botón para empezar';
  int _challengeCount = 0;
  static const _challenges = [
    'cuenta su mejor chisme 🍵',
    'canta el coro de una canción 🎤',
    'baila 10 segundos 💃',
    'imita a alguien del grupo 🎭',
    'cuenta su peor cita 😬',
    'hace 5 sentadillas 🏋️',
    'muestra la última foto de su galería 📸',
    'dice un dato curioso de sí mismo 🤓',
    'elige quién sigue y le pone un reto 😈',
    'invita la siguiente ronda 🥤',
  ];

  void _rollDice() {
    HapticFeedback.heavyImpact();
    setState(() {
      _die1 = _random.nextInt(6) + 1;
      _die2 = _random.nextInt(6) + 1;
      _rollCount++;
    });
  }

  void _startImpostor() {
    setState(() {
      _impostorStarted = true;
      _impostorIndex = _random.nextInt(_players);
      _secretWord = _secretWords[_random.nextInt(_secretWords.length)];
      _currentPlayer = 0;
      _revealed = false;
    });
  }

  void _newChallenge() {
    HapticFeedback.mediumImpact();
    const letters = 'ABCDEFGHIJKLMNOPRSTUV';
    setState(() {
      _letter = letters[_random.nextInt(letters.length)];
      _challenge = _challenges[_random.nextInt(_challenges.length)];
      _challengeCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161920) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Asa
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              switch (_view) {
                _GameView.menu => _buildMenu(isDark),
                _GameView.dice => _buildDice(isDark),
                _GameView.impostor => _buildImpostor(isDark),
                _GameView.initial => _buildInitial(isDark),
              },
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════ MENÚ ═══════════════════════════
  Widget _buildMenu(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎉', style: TextStyle(fontSize: 38))
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.15, 1.15),
                duration: 900.ms,
                curve: Curves.easeInOut),
        const SizedBox(height: 8),
        Text(
          '¿Listos para animar la reu?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Juegos rápidos para romper el hielo',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 22),
        _gameCard(
          emoji: '🎲',
          title: 'Dados virtuales',
          subtitle: 'Para decidir quién empieza... o quién paga',
          color: const Color(0xFF38BDF8),
          onTap: () => setState(() => _view = _GameView.dice),
          delay: 0,
        ),
        _gameCard(
          emoji: '🕵️',
          title: 'El Impostor',
          subtitle: 'Todos saben la palabra secreta... menos uno',
          color: const Color(0xFFC084FC),
          onTap: () {
            setState(() {
              _view = _GameView.impostor;
              _impostorStarted = false;
            });
          },
          delay: 80,
        ),
        _gameCard(
          emoji: '🔤',
          title: 'Reto por inicial',
          subtitle: 'La suerte elige una letra... y un castigo',
          color: const Color(0xFFFB7185),
          onTap: () => setState(() => _view = _GameView.initial),
          delay: 160,
        ),
      ],
    );
  }

  Widget _gameCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required int delay,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.10 : 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
            ],
          ),
        ),
      ),
    ).animate(delay: delay.ms).fadeIn().slideX(begin: 0.08);
  }

  // ════════════════════════════ DADOS ══════════════════════════
  Widget _buildDice(bool isDark) {
    const faces = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _gameHeader('🎲 Dados virtuales', isDark),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dieFace(faces[_die1 - 1], isDark),
            const SizedBox(width: 18),
            _dieFace(faces[_die2 - 1], isDark),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Total: ${_die1 + _die2}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 18),
        _primaryButton(
          label: 'Lanzar dados',
          icon: Icons.casino_rounded,
          onTap: _rollDice,
        ),
      ],
    );
  }

  Widget _dieFace(String face, bool isDark) {
    return Container(
      key: ValueKey('$face-$_rollCount'),
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryOrange.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          face,
          style: TextStyle(
            fontSize: 60,
            height: 1,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    )
        .animate()
        .rotate(begin: -0.15, end: 0, duration: 450.ms, curve: Curves.easeOutBack)
        .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack);
  }

  // ═══════════════════════════ IMPOSTOR ════════════════════════
  Widget _buildImpostor(bool isDark) {
    if (!_impostorStarted) {
      // Configuración: número de jugadores
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gameHeader('🕵️ El Impostor', isDark),
          const SizedBox(height: 8),
          Text(
            'Todos verán la palabra secreta, menos el impostor.\nPasen el celular y descubran quién miente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _counterButton(Icons.remove_rounded, () {
                if (_players > 3) setState(() => _players--);
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      '$_players',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'jugadores',
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
              _counterButton(Icons.add_rounded, () {
                if (_players < 12) setState(() => _players++);
              }),
            ],
          ),
          const SizedBox(height: 20),
          _primaryButton(
            label: 'Repartir roles',
            icon: Icons.play_arrow_rounded,
            onTap: () {
              HapticFeedback.mediumImpact();
              _startImpostor();
            },
          ),
        ],
      );
    }

    final finished = _currentPlayer >= _players;
    if (finished) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gameHeader('🕵️ El Impostor', isDark),
          const SizedBox(height: 16),
          const Text('🗣️', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text(
            '¡Que empiece el debate!',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hagan preguntas sobre la palabra secreta.\n¿Quién no sabe de qué hablan? 👀',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          _primaryButton(
            label: 'Jugar de nuevo',
            icon: Icons.refresh_rounded,
            onTap: _startImpostor,
          ),
        ],
      );
    }

    final isImpostor = _currentPlayer == _impostorIndex;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _gameHeader('🕵️ El Impostor', isDark),
        const SizedBox(height: 6),
        Text(
          'Jugador ${_currentPlayer + 1} de $_players',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() {
              if (_revealed) {
                _currentPlayer++;
                _revealed = false;
              } else {
                _revealed = true;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _revealed
                    ? (isImpostor
                        ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
                        : [const Color(0xFF22C55E), const Color(0xFF15803D)])
                    : [const Color(0xFF6366F1), const Color(0xFF4338CA)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              key: ValueKey('$_currentPlayer-$_revealed'),
              children: _revealed
                  ? [
                      Text(
                        isImpostor ? '🤫' : '🤝',
                        style: const TextStyle(fontSize: 40),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isImpostor ? '¡ERES EL IMPOSTOR!' : _secretWord,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isImpostor
                            ? 'Disimula y descubre la palabra'
                            : 'Esa es la palabra secreta, shhh',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Toca para pasar al siguiente →',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]
                  : [
                      const Text('🔒', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 10),
                      const Text(
                        'Toca para revelar tu rol',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Que nadie más mire 👀',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
            ),
          ).animate().fadeIn(duration: 250.ms),
        ),
      ],
    );
  }

  // ═══════════════════════ RETO POR INICIAL ════════════════════
  Widget _buildInitial(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _gameHeader('🔤 Reto por inicial', isDark),
        const SizedBox(height: 18),
        Container(
          key: ValueKey('$_letter-$_challengeCount'),
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryOrange, Color(0xFFFF2D55)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _letter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        )
            .animate()
            .scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack)
            .rotate(begin: -0.08, end: 0),
        const SizedBox(height: 16),
        Text(
          _letter == '?'
              ? _challenge
              : 'Quien tenga nombre con "$_letter"\n$_challenge',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        _primaryButton(
          label: _letter == '?' ? 'Sortear letra' : 'Otra letra',
          icon: Icons.shuffle_rounded,
          onTap: _newChallenge,
        ),
      ],
    );
  }

  // ═════════════════════════ Helpers UI ════════════════════════
  Widget _gameHeader(String title, bool isDark) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _view = _GameView.menu);
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 34), // balance visual del botón atrás
      ],
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primaryOrange.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primaryOrange.withValues(alpha: 0.35),
          ),
        ),
        child: Icon(icon, color: AppColors.primaryOrange, size: 22),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryOrange, Color(0xFFFF2D55)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

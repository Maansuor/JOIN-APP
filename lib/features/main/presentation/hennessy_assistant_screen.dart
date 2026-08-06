import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/models/interest_model.dart';

class HennessyAssistantScreen extends StatefulWidget {
  const HennessyAssistantScreen({super.key});

  @override
  State<HennessyAssistantScreen> createState() => _HennessyAssistantScreenState();
}

enum Season { summer, autumn, winter, spring }

class _HennessyAssistantScreenState extends State<HennessyAssistantScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _messages = [];
  bool _showOptions = true;
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();

  // Colores activos para el Hennessy en esta pantalla (se inicializan por temporada)
  late Color _iguanaPrimary;
  late Color _iguanaSecondary;
  late Season _currentSeason;
  late String _seasonName;
  late String _seasonEmoji;

  final List<Color> _availableColors = CategoryConstants.colors.values.toList();

  /// Imagen real de la mascota elegida por el usuario
  Widget _mascotImage(double size, {bool circle = true}) {
    final asset = context.read<AppState>().currentUser?.companionAsset ??
        'assets/images/mascota/ELI.png';
    final img = Image.asset(
      asset,
      fit: BoxFit.contain,
      cacheWidth: (size * 3).round(),
    );
    return SizedBox(
      width: size,
      height: size,
      child: circle ? ClipOval(child: img) : img,
    );
  }


  @override
  void initState() {
    super.initState();
    _initializeSeasonColors();

    // Inicializar con el saludo personalizado aleatorio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AppState>().currentUser;
      final name = user?.name.split(' ').first ?? 'Explorador';
      final greeting = _getRandomGreeting(name);
      
      setState(() {
        _messages.add({'isBot': true, 'text': greeting});
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getRandomGreeting(String name) {
    final hour = DateTime.now().hour;
    String timeGreeting;
    if (hour >= 5 && hour < 12) {
      timeGreeting = '¡Buenos días';
    } else if (hour >= 12 && hour < 18) {
      timeGreeting = '¡Buenas tardes';
    } else {
      timeGreeting = '¡Buenas noches';
    }

    final companionName = context.read<AppState>().currentUser?.companionName ?? 'Eli';
    final greetings = [
      '$timeGreeting, $name! 🦎🐾 Soy **$companionName**, tu iguana aventurera.\n\nEstamos en temporada de **$_seasonName** y me he mimetizado con estos colores para acompañarte. ¿Qué descubrimos hoy?',
      '$timeGreeting, $name! 🦎✨ ¡Tu guía camaleónico está listo!\n\nTemporada actual: **$_seasonName** $_seasonEmoji\n\nToca sobre mí para cambiar mis colores, o elige una pregunta abajo. ¡Vamos a explorar!',
      '$timeGreeting, $name! 🐾 $companionName al habla.\n\nMe he puesto mis mejores colores de **$_seasonName** para recibirte. ¿En qué te puedo ayudar hoy? 🦎',
    ];
    return greetings[Random().nextInt(greetings.length)];
  }

  Season _getCurrentSeason() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    // Estaciones climáticas para el Hemisferio Sur (donde se ubica Chiclayo, Perú)
    if ((month == 12 && day >= 21) || month == 1 || month == 2 || (month == 3 && day < 21)) {
      return Season.summer;
    } else if ((month == 3 && day >= 21) || month == 4 || month == 5 || (month == 6 && day < 21)) {
      return Season.autumn;
    } else if ((month == 6 && day >= 21) || month == 7 || month == 8 || (month == 9 && day < 21)) {
      return Season.winter;
    } else {
      return Season.spring;
    }
  }

  void _initializeSeasonColors() {
    _currentSeason = _getCurrentSeason();
    switch (_currentSeason) {
      case Season.summer:
        _iguanaPrimary = const Color(0xFFFD7C36);
        _iguanaSecondary = const Color(0xFFFDBA1B);
        _seasonName = 'Verano';
        _seasonEmoji = '☀️';
        break;
      case Season.autumn:
        _iguanaPrimary = const Color(0xFFD84B16);
        _iguanaSecondary = const Color(0xFFE5A93C);
        _seasonName = 'Otoño';
        _seasonEmoji = '🍂';
        break;
      case Season.winter:
        _iguanaPrimary = const Color(0xFF0E7BCF);
        _iguanaSecondary = const Color(0xFF02C9DC);
        _seasonName = 'Invierno';
        _seasonEmoji = '❄️';
        break;
      case Season.spring:
        _iguanaPrimary = const Color(0xFF43A047);
        _iguanaSecondary = const Color(0xFF81C784);
        _seasonName = 'Primavera';
        _seasonEmoji = '🌸';
        break;
    }
  }

  void _triggerChameleonColorShift() {
    HapticFeedback.lightImpact();
    final random = Random();
    
    final color1 = _availableColors[random.nextInt(_availableColors.length)];
    Color color2 = _availableColors[random.nextInt(_availableColors.length)];
    while (color1 == color2) {
      color2 = _availableColors[random.nextInt(_availableColors.length)];
    }

    setState(() {
      _iguanaPrimary = color1;
      _iguanaSecondary = color2;
    });

    final companionName = context.read<AppState>().currentUser?.companionName ?? 'Eli';
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.palette_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              '🎨 ¡$companionName se mimetizó con nuevos tonos!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: color1,
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 70),
      ),
    );
  }

  // ── Answer builders (centralized to avoid duplication) ───────
  String _answerJoin(AppState state) {
    final companionName = state.currentUser?.companionName ?? 'Eli';
    return '¡Hola! Soy **$companionName** 🦎, tu asistente de aventuras en Join.\n\n**Join** es la red social de la **vida real** 🌍. Aquí no encontrarás feeds infinitos ni algoritmos diseñados para retenerte en la pantalla. Nuestro propósito es simple:\n\n✨ **Reconectar en el mundo real:** Facilitamos la creación de actividades grupales en Chiclayo para reunir gente de verdad.\n\n🎨 **Mimetismo natural:** Al igual que yo cambio de color, la app se adapta a tus intereses y gustos en tiempo real.\n\n¡Menos pantalla, más vida real! 🚀';
  }

  String _answerCreate(AppState state) =>
    '¡Es súper fácil, explorador! 🎒\n\n➕ **1. Inicia el plan:** Toca el botón naranja gigante con el símbolo **`+`** en la barra inferior del inicio.\n\n📝 **2. Llena los detalles:** Ponle un título atractivo, elige la categoría, ubicación, fecha y hora.\n\n🎒 **3. Aportes y Roles:** Especifica qué debe traer cada uno (parlantes, piqueos, cuotas) para organizarse mejor.\n\n🚀 **4. Publica:** ¡Y listo! Tu plan aparecerá en Chiclayo y recibirás solicitudes al instante.';

  String _answerCleanup(AppState state) =>
    '¡Es nuestra política estrella para mantener todo limpio y privado! 🧼🧹\n\n**¿Cómo funciona?**\nExactly **5 horas después** de que termina el día de una actividad:\n- Eliminamos toda la actividad del feed.\n- Se borra el grupo de chat correspondiente.\n- Se eliminan todas las solicitudes y fotos.\n\n**¿Por qué?**\nPara proteger tu privacidad, ahorrar espacio en la nube y asegurar que todos los planes que veas en Join sean **frescos y activos**, sin registros basura del pasado.';

  String _answerRecommendations(AppState state) {
    final name = state.currentUser?.name.split(' ').first ?? 'Explorador';
    final myInterests = state.currentUser?.interests ?? [];
    if (myInterests.isEmpty) {
      return '¡Hola, $name! 🦎 Actualmente no tienes intereses registrados en tu perfil.\n\nTe recomiendo ir a tu Perfil -> Editar Perfil y seleccionar tus gustos favoritos. ¡Así podré darte recomendaciones a tu medida en tiempo real!';
    }
    
    final resolvedCategories = InterestMapper.getCategoriesForInterests(myInterests);
    final catsStr = resolvedCategories.join(', ');

    return '🦎 Analizando tus preferencias, $name...\n\nVeo que tienes un gran espíritu aventurero y te interesan cosas como: **${myInterests.join(', ')}**!\n\nSegún esto, tus categorías principales recomendadas son: **$catsStr**.\n\nTe sugiero crear hoy mismo una actividad en **${resolvedCategories.first}** o buscar tarjetas del mismo color en tu feed de inicio. ¡Seguro encuentras un grupo increíble!';
  }

  void _handleOptionSelected(String title, String Function(AppState) answerBuilder) {
    if (!_showOptions) return;
    HapticFeedback.mediumImpact();
    final appState = context.read<AppState>();
    final answer = answerBuilder(appState);

    setState(() {
      _showOptions = false;
      _messages.add({'isBot': false, 'text': title});
      _isTyping = true;
    });
    
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({'isBot': true, 'text': answer});
        });
        _scrollToBottom();

        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _showOptions = true;
            });
            _scrollToBottom();
          }
        });
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    final name = user?.name.split(' ').first ?? 'Aventurero';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF6F8FC),
      // ── AppBar en efecto Glassmorphic ──────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 8),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0A0D14).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.chevron_left_rounded, color: isDark ? Colors.white : const Color(0xFF041249), size: 24),
                        onPressed: () => context.pop(),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.companionName ?? 'Eli',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF041249),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Guía de aventura activo',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.grey[600],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  // Hennessy interactivo con badge de temporada
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: GestureDetector(
                      onTap: _triggerChameleonColorShift,
                      child: Tooltip(
                        message: '¡Tócame para cambiar mi color! 🦎',
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _iguanaPrimary.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: _mascotImage(38),
                            ),
                            // Season badge
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF161920) : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(_seasonEmoji, style: const TextStyle(fontSize: 10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .rotate(begin: -0.02, end: 0.02, duration: 2.seconds, curve: Curves.easeInOut),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Stream de Chat Expandido ─────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: 1 + _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      _buildWelcomeHeroCard(name, isDark),
                      if (_messages.isEmpty) const SizedBox(height: 16),
                    ],
                  );
                }
                
                final messageIndex = index - 1;
                if (messageIndex == _messages.length && _isTyping) {
                  return _buildTypingIndicator(isDark);
                }

                final msg = _messages[messageIndex];
                final isLastInitialGreeting = messageIndex == 0 && _messages.length <= 1;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMessageBubble(msg['text'], msg['isBot'], isDark),
                    if (isLastInitialGreeting) ...[
                      const SizedBox(height: 10),
                      _buildInitialOptionsGrid(appState, isDark),
                    ],
                  ],
                );
              },
            ),
          ),

          // ── Panel Inferior ──
          if (_messages.length > 1)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161920) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildHorizontalChips(appState, isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeroCard(String name, bool isDark) {
    final user = context.read<AppState>().currentUser;
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 8, 4, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF161920), const Color(0xFF1A1E28)]
              : [Colors.white, const Color(0xFFFAFBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _iguanaPrimary.withValues(alpha: isDark ? 0.2 : 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _iguanaPrimary.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        children: [
          // La iguana gigante interactiva con círculos de onda premium
          GestureDetector(
            onTap: _triggerChameleonColorShift,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulsing ring
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _iguanaPrimary.withValues(alpha: 0.06),
                        _iguanaPrimary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat())
                 .scaleXY(begin: 0.8, end: 1.2, duration: 2500.ms, curve: Curves.easeInOut)
                 .fadeOut(begin: 0.6, duration: 2500.ms),
                // Second ring offset
                Container(
                  width: 145,
                  height: 145,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _iguanaSecondary.withValues(alpha: 0.05),
                        _iguanaSecondary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat())
                 .scaleXY(begin: 0.85, end: 1.15, duration: 2000.ms, delay: 500.ms, curve: Curves.easeInOut)
                 .fadeOut(begin: 0.5, duration: 2000.ms),
                // Static inner glow
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _iguanaPrimary.withValues(alpha: isDark ? 0.08 : 0.05),
                        _iguanaPrimary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                // Hennessy
                _mascotImage(120, circle: false)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: 0, end: -6, duration: 2000.ms, curve: Curves.easeInOut),
                // Touch indicator
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222B) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Icon(Icons.touch_app_rounded, size: 14, color: _iguanaPrimary),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .scaleXY(begin: 0.9, end: 1.1, duration: 1200.ms, curve: Curves.easeInOut),
                ),
              ],
            ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
          ),
          const SizedBox(height: 20),
          // Season badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _iguanaPrimary.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _iguanaPrimary.withValues(alpha: isDark ? 0.25 : 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_seasonEmoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text(
                  'Temporada de $_seasonName',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _iguanaPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(begin: 0.3),
          const SizedBox(height: 16),
          Text(
            '¡Hola, $name! 🦎🐾',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF041249),
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
          const SizedBox(height: 10),
          Text(
            'Soy ${user?.companionName ?? 'Eli'}, tu iguana camaleónica y guía oficial en Join.\nPresiona sobre mí para cambiar mis colores.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white54 : Colors.grey[600],
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildInitialOptionsGrid(AppState appState, bool isDark) {
    int animIndex = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Row(
            children: [
              Icon(Icons.explore_rounded, size: 16, color: _iguanaPrimary),
              const SizedBox(width: 8),
              Text(
                'PREGUNTAS RECOMENDADAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white70 : const Color(0xFF041249),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        _buildInitialOptionCard(
          '🦎 ¿Qué es Join y cómo funciona?',
          'Conoce la filosofía de la red social de la vida real.',
          Icons.help_center_rounded,
          _iguanaPrimary,
          () => _handleOptionSelected('🦎 ¿Qué es Join y cómo funciona?', _answerJoin),
          isDark,
          animIndex++,
        ),
        _buildInitialOptionCard(
          '✨ ¿Cómo crear una actividad?',
          'Pasos rápidos para planificar tu próxima aventura grupal.',
          Icons.add_circle_rounded,
          _iguanaPrimary,
          () => _handleOptionSelected('✨ ¿Cómo crear una actividad?', _answerCreate),
          isDark,
          animIndex++,
        ),
        _buildInitialOptionCard(
          '🧹 ¿Qué es la limpieza de 5 horas?',
          'Entiende cómo mantenemos fresco y seguro tu feed.',
          Icons.cleaning_services_rounded,
          _iguanaPrimary,
          () => _handleOptionSelected('🧹 ¿Qué es la limpieza de 5 horas?', _answerCleanup),
          isDark,
          animIndex++,
        ),
        _buildInitialOptionCard(
          '🗺️ Recomendaciones personalizadas',
          'Consejos según tus intereses de perfil.',
          Icons.auto_awesome_rounded,
          _iguanaPrimary,
          () => _handleOptionSelected('🗺️ Recomendaciones para mí', _answerRecommendations),
          isDark,
          animIndex++,
        ),
      ],
    );
  }

  Widget _buildInitialOptionCard(
    String title,
    String subtitle,
    IconData icon,
    Color activeColor,
    VoidCallback onTap,
    bool isDark,
    int animIndex,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161920) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? activeColor.withValues(alpha: 0.15)
                    : activeColor.withValues(alpha: 0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : activeColor.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: isDark ? 0.12 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: activeColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF041249),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: activeColor, size: 20),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (animIndex * 80).ms).slideX(begin: 0.05);
  }

  Widget _buildHorizontalChips(AppState appState, bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildQuickChip('🦎 ¿Qué es Join?', Icons.help_center_rounded,
            () => _handleOptionSelected('🦎 ¿Qué es Join y cómo funciona?', _answerJoin), isDark),
          _buildQuickChip('✨ Crear Actividad', Icons.add_circle_rounded,
            () => _handleOptionSelected('✨ ¿Cómo crear una actividad?', _answerCreate), isDark),
          _buildQuickChip('🧹 Limpieza 5h', Icons.cleaning_services_rounded,
            () => _handleOptionSelected('🧹 ¿Qué es la limpieza de 5 horas?', _answerCleanup), isDark),
          _buildQuickChip('🗺️ Mis Recomendaciones', Icons.auto_awesome_rounded,
            () => _handleOptionSelected('🗺️ Recomendaciones para mí', _answerRecommendations), isDark),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String text, IconData icon, VoidCallback onTap, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _iguanaPrimary.withValues(alpha: isDark ? 0.3 : 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.01),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: _iguanaPrimary, size: 14),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF041249),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(duration: 200.ms);
  }


  Widget _buildMessageBubble(String text, bool isBot, bool isDark) {
    final companionName = context.read<AppState>().currentUser?.companionName ?? 'Eli';
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBot) ...[
              Container(
                margin: const EdgeInsets.only(top: 4, right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _iguanaPrimary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: _mascotImage(32),
              ),
            ],
            
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
                decoration: isBot
                    ? BoxDecoration(
                        color: isDark ? const Color(0xFF161920) : Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(0),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.withValues(alpha: 0.05),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.015),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      )
                    : BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_iguanaPrimary, _iguanaPrimary.withValues(alpha: 0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _iguanaPrimary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                child: isBot
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.explore_rounded, color: _iguanaPrimary, size: 12),
                              const SizedBox(width: 6),
                              Text(
                                '$companionName Asistente',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _iguanaPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildRichText(text, _iguanaPrimary, isDark),
                        ],
                      )
                    : Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideX(begin: isBot ? -0.05 : 0.05);
  }

  Widget _buildRichText(String text, Color primaryColor, bool isDark) {
    final List<String> lines = text.split('\n');
    final List<Widget> children = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        if (i < lines.length - 1) {
          children.add(const SizedBox(height: 8));
        }
        continue;
      }

      // Emoji headers — use Characters to safely extract emoji
      if (line.startsWith('🦎') || line.startsWith('✨') || line.startsWith('🧹') || line.startsWith('🗺️') || line.startsWith('🎒') || line.startsWith('🧼') || line.startsWith('🗑️') || line.startsWith('🔒') || line.startsWith('📅') || line.startsWith('🎨')) {
        // Find the first space to split emoji from text
        final spaceIdx = line.indexOf(' ');
        final emoji = spaceIdx > 0 ? line.substring(0, spaceIdx) : line.substring(0, 2);
        final rest = spaceIdx > 0 ? line.substring(spaceIdx).trim() : line.substring(2).trim();
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rest,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF041249),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Numbered items
      final numRegExp = RegExp(r'^(\d+)\.\s(.*)$');
      if (numRegExp.hasMatch(line)) {
        final match = numRegExp.firstMatch(line)!;
        final numStr = match.group(1)!;
        final textContent = match.group(2)!;

        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      numStr,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildLineWithBoldSupport(textContent, isDark, fontSize: 13.5),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Bullet points
      if (line.startsWith('- ') || line.startsWith('* ')) {
        final textContent = line.substring(2).trim();
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildLineWithBoldSupport(textContent, isDark, fontSize: 13.5),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Normal line
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildLineWithBoldSupport(line, isDark, fontSize: 13.5),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildLineWithBoldSupport(String text, bool isDark, {double fontSize = 13.5}) {
    final List<TextSpan> spans = [];
    final boldRegExp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    final normalColor = isDark ? Colors.white70 : Colors.black87;
    final boldColor = isDark ? Colors.white : const Color(0xFF041249);

    for (final match in boldRegExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(color: normalColor, fontSize: fontSize, height: 1.45),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(color: boldColor, fontWeight: FontWeight.bold, fontSize: fontSize, height: 1.45),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(color: normalColor, fontSize: fontSize, height: 1.45),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161920) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(0),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _iguanaPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.smart_toy_rounded, size: 12, color: _iguanaPrimary),
              ),
            ),
            const SizedBox(width: 10),
            Row(
              children: List.generate(3, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _iguanaPrimary.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .scaleXY(
                  begin: 0.5,
                  end: 1.2,
                  duration: 500.ms,
                  delay: (i * 150).ms,
                  curve: Curves.easeInOut,
                )
                .then()
                .scaleXY(
                  begin: 1.2,
                  end: 0.5,
                  duration: 500.ms,
                  curve: Curves.easeInOut,
                );
              }),
            ),
            const SizedBox(width: 10),
            Text(
              '${context.read<AppState>().currentUser?.companionName ?? 'Eli'} está escribiendo...',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: -0.05);
  }
}

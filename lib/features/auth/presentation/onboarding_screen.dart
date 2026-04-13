import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/models/user_model.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/services/api_client.dart';
import 'package:join_app/core/theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════
//  OnboardingScreen — Estilo Instagram Stories
//
//  Cada paso ocupa pantalla completa con un color/gradiente propio.
//  La barra de progreso en la parte superior es segmentada (como Stories).
//  Cuando el usuario completa un paso, la barra se rellena y
//  automáticamente desliza al siguiente con animación suave.
//
//  Pasos:
//   1. Ubicación  (azul marino)
//   2. Nacimiento (naranja cálido)
//   3. Género     (rosado/púrpura)
//   4. Intereses  (verde bosque)
//   5. Notif.     (amarillo/dorado)
//   → Loading → MainScreen
// ══════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // ── PageController ─────────────────────────────────────────
  final PageController _pageCtrl = PageController();
  int _step = 0;
  static const int _total = 5;
  bool _completing = false;

  // ── AnimationController para la barra de Stories ───────────
  late AnimationController _storyBar;

  // ── Data de cada paso ─────────────────────────────────────
  bool _locationGranted = false;
  DateTime? _birthDate;
  UserGender _gender = UserGender.preferNotToSay;
  final Set<String> _interests = {};
  bool _notifGranted = false;

  // ── Configuración visual de cada paso ──────────────────────
  static const _steps = [
    _StepConfig(
      gradient: [Color(0xFF041249), Color(0xFF12357B)],
      accent: AppColors.skyBlue,
      icon: Icons.location_on_rounded,
    ),
    _StepConfig(
      gradient: [Color(0xFF4A1942), Color(0xFFB03A6B)],
      accent: Color(0xFFF9A8D4),
      icon: Icons.cake_rounded,
    ),
    _StepConfig(
      gradient: [Color(0xFF1A3A2A), Color(0xFF2D6A4F)],
      accent: Color(0xFF95D5B2),
      icon: Icons.wc_rounded,
    ),
    _StepConfig(
      gradient: [Color(0xFF1A1A2E), Color(0xFF16213E)],
      accent: AppColors.primaryOrange,
      icon: Icons.interests_rounded,
    ),
    _StepConfig(
      gradient: [Color(0xFF4A2C00), Color(0xFFB36200)],
      accent: Color(0xFFFFD166),
      icon: Icons.notifications_active_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _storyBar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Verificar permisos ya concedidos al abrir
    _checkExistingPermissions();
  }

  Future<void> _checkExistingPermissions() async {
    // Ubicación
    final locPerm = await Geolocator.checkPermission();
    if (locPerm == LocationPermission.always ||
        locPerm == LocationPermission.whileInUse) {
      setState(() => _locationGranted = true);
      // Obtener la ubicación en background sin bloquear el flujo
      _fetchCurrentLocation();
      // Auto-avanzar después de un breve delay para que el usuario
      // vea la confirmación visual (si estamos en el paso 0)
      if (_step == 0) {
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted && _step == 0) _advance();
      }
    }
    // Notificaciones
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isGranted) {
      setState(() => _notifGranted = true);
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      // Usamos timeout para no bloquear la UI si el GPS tarda mucho
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 8));
      debugPrint(
          '📍 Ubicación capturada: ${position.latitude}, ${position.longitude}');
      if (mounted) {
        context.read<AppState>().updatePosition(position);
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout GPS — intentando última posición conocida...');
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && mounted) {
          context.read<AppState>().updatePosition(last);
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error obteniendo coordenadas: $e');
      // No bloqueamos el flujo si falla la ubicación
    }
  }

  // ──  Solicitar permiso de ubicación  ────────────────────
  Future<void> _requestLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      setState(() => _locationGranted = true);
      // Obtener ubicación en background sin bloquear
      _fetchCurrentLocation().ignore();
      // Auto-avanzar al siguiente paso tras un breve delay visual
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted && _step == 0) _advance();
    }
  }

  // ──  Solicitar permiso de notificaciones  ────────────────
  Future<void> _requestNotifications() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      setState(() => _notifGranted = true);
      Future.delayed(const Duration(milliseconds: 700), _advance);
    } else if (status.isPermanentlyDenied) {
      // Ofrecer ir a Settings
      await openAppSettings();
    }
    // Si denegado (pero no permanente), el usuario puede omitir
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _storyBar.dispose();
    super.dispose();
  }

  // ── Lógica de avance ────────────────────────────────────────

  bool get _stepReady {
    switch (_step) {
      case 0:
        return true; // La ubicación es opcional — puede omitirse
      case 1:
        return _birthDate != null && _isAdult;
      case 2:
        return true;
      case 3:
        return _interests.length >= 3;
      case 4:
        return true;
      default:
        return false;
    }
  }

  bool get _isAdult {
    if (_birthDate == null) return false;
    final now = DateTime.now();
    int age = now.year - _birthDate!.year;
    if (now.month < _birthDate!.month ||
        (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
      age--;
    }
    return age >= 18;
  }

  Future<void> _advance() async {
    if (!_stepReady) return;
    HapticFeedback.lightImpact();

    // Animación de la barra de progreso
    await _storyBar.animateTo(1.0,
        duration: const Duration(milliseconds: 350), curve: Curves.easeIn);

    if (_step < _total - 1) {
      setState(() => _step++);
      _storyBar.reset();
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _complete();
    }
  }

  void _back() {
    if (_step == 0) return;
    HapticFeedback.lightImpact();
    setState(() => _step--);
    _storyBar.reset();
    _pageCtrl.animateToPage(
      _step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _complete() async {
    setState(() => _completing = true);
    HapticFeedback.mediumImpact();

    // Preparar los datos del onboarding
    final birthDateStr = _birthDate?.toIso8601String().split('T').first;
    final genderStr = _gender.toJson();
    final interestsList = _interests.toList();

    try {
      // 1. Guardar datos en el backend
      await ApiClient.instance.post('/onboarding.php', {
        'birthDate': birthDateStr,
        'gender': genderStr,
        'interests': interestsList,
        'ageVisible': true,
      }, queryParams: {'action': 'complete'});
      debugPrint('✅ Onboarding guardado en backend');
    } catch (e) {
      // Si falla la red o el backend, seguimos de todas formas
      // El perfil se puede completar luego desde Editar Perfil
      debugPrint('⚠️ Onboarding save error: $e');
    }

    // 2. Actualizar AppState local con los datos del onboarding
    //    Esto es crítico para que el router no redirija de vuelta
    if (mounted) {
      final appState = context.read<AppState>();
      // Actualizar perfil en memoria con los datos completados
      await appState.updateLocalProfile(
        birthDate: _birthDate,
        gender: _gender,
        interests: interestsList,
      );
      // Marcar como completado en AppState (debe ir después de updateLocalProfile)
      appState.markSetupCompleted();
    }

    // 3. Esperar la animación de conclusión
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    context.go('/main');
  }

  @override
  Widget build(BuildContext context) {
    if (_completing) return const _CompletionScreen();

    final cfg = _steps[_step];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cfg.gradient,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── Barra de stories ──────────────────────────
                _StoryProgressBar(
                  total: _total,
                  current: _step,
                  controller: _storyBar,
                  accent: cfg.accent,
                ),

                // ── Top row: back + skip ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      if (_step > 0)
                        _PillButton(
                          icon: Icons.arrow_back_ios_rounded,
                          onTap: _back,
                          accent: cfg.accent,
                        ),
                      const Spacer(),
                      if (_step == 2 || _step == 4)
                        GestureDetector(
                          onTap: _advance,
                          child: Text(
                            'Omitir',
                            style: TextStyle(
                              color: cfg.accent.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Contenido del paso (swipeable) ─────────────
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StepLocation(
                        accent: cfg.accent,
                        icon: _steps[0].icon,
                        granted: _locationGranted,
                        onGranted: _requestLocation, // ← permiso real del SO
                      ),
                      _StepBirthDate(
                        accent: _steps[1].accent,
                        icon: _steps[1].icon,
                        selected: _birthDate,
                        isAdult: _isAdult,
                        onSelected: (d) {
                          setState(() => _birthDate = d);
                          if (_isAdult) {
                            Future.delayed(
                                const Duration(milliseconds: 800), _advance);
                          }
                        },
                      ),
                      _StepGender(
                        accent: _steps[2].accent,
                        icon: _steps[2].icon,
                        selected: _gender,
                        onSelected: (g) {
                          setState(() => _gender = g);
                          Future.delayed(
                              const Duration(milliseconds: 600), _advance);
                        },
                      ),
                      _StepInterests(
                        accent: _steps[3].accent,
                        icon: _steps[3].icon,
                        selected: _interests,
                        onToggle: (t) => setState(() {
                          _interests.contains(t)
                              ? _interests.remove(t)
                              : _interests.add(t);
                        }),
                      ),
                      _StepNotifications(
                        accent: _steps[4].accent,
                        icon: _steps[4].icon,
                        granted: _notifGranted,
                        onGranted:
                            _requestNotifications, // ← permiso real del SO
                        onSkip: _advance,
                      ),
                    ],
                  ),
                ),

                // ── Botón inferior (solo cuando el paso lo requiere) ─
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: _buildCTA(cfg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCTA(_StepConfig cfg) {
    // Paso 0 (ubicación): siempre muestra el botón para no dejar al usuario atascado
    // Pasos 1, 2, 4: auto-avance (no necesitan botón)
    final autoSteps = {1, 2, 4};
    if (autoSteps.contains(_step)) {
      return const SizedBox.shrink();
    }

    // Paso 0 (ubicación): siempre visible — el usuario puede omitir aunque no dé permiso
    // Paso 3 (intereses): siempre visible
    // Paso 4 (notificaciones): visible si no auto-avanzó
    final show = _step == 0 || _step == 3 || (_step == 4 && !_notifGranted);
    if (!show) return const SizedBox.shrink();

    final ready = _stepReady;
    return AnimatedOpacity(
      opacity: ready ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: ready ? _advance : null,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: ready ? cfg.accent : cfg.accent.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(28),
            boxShadow: ready
                ? [
                    BoxShadow(
                      color: cfg.accent.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _step == 3
                    ? (_interests.length >= 3
                        ? 'Continuar (${_interests.length})'
                        : 'Elige al menos 3')
                    : _step == 0 && !_locationGranted
                        ? 'Omitir ubicación'
                        : _step == _total - 1
                            ? '¡Comenzar!'
                            : 'Continuar',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (ready) ...[
                const SizedBox(width: 8),
                Icon(
                  _step == _total - 1
                      ? Icons.rocket_launch_rounded
                      : Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Barra de progreso estilo Stories
// ══════════════════════════════════════════════════════════════
class _StoryProgressBar extends StatelessWidget {
  final int total;
  final int current;
  final AnimationController controller;
  final Color accent;

  const _StoryProgressBar({
    required this.total,
    required this.current,
    required this.controller,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(total, (i) {
          final isDone = i < current;
          final isActive = i == current;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: 3,
                  color: Colors.white.withValues(alpha: 0.25),
                  child: isDone
                      ? Container(color: accent)
                      : isActive
                          ? AnimatedBuilder(
                              animation: controller,
                              builder: (_, __) => FractionallySizedBox(
                                widthFactor: controller.value,
                                alignment: Alignment.centerLeft,
                                child: Container(color: accent),
                              ),
                            )
                          : const SizedBox.shrink(),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PASO 1 — Ubicación
// ══════════════════════════════════════════════════════════════
class _StepLocation extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final bool granted;
  final VoidCallback onGranted;

  const _StepLocation(
      {required this.accent,
      required this.icon,
      required this.granted,
      required this.onGranted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          _StepIcon(icon: icon, accent: accent, size: 90),

          const SizedBox(height: 32),

          const Text(
            '¿Dónde\nestás tú?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

          const SizedBox(height: 16),

          Text(
            'Activamos tu ubicación para mostrarte\nplanes cerca de ti en tiempo real.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 350.ms),

          const Spacer(),

          // Beneficios rápidos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MiniChip(Icons.near_me_rounded, 'Cerca de ti', accent),
              _MiniChip(Icons.map_outlined, 'Ver mapa', accent),
              _MiniChip(Icons.lock_outline_rounded, 'Privado', accent),
            ],
          ).animate().fadeIn(delay: 500.ms),

          const SizedBox(height: 24),

          if (!granted)
            _StoryButton(
              label: 'Permitir ubicación',
              icon: Icons.location_on_rounded,
              accent: accent,
              onTap: onGranted,
            )
          else
            _SuccessBanner(accent: accent, text: '¡Ubicación lista!'),

          const Spacer(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PASO 2 — Fecha de nacimiento
// ══════════════════════════════════════════════════════════════
class _StepBirthDate extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final DateTime? selected;
  final bool isAdult;
  final ValueChanged<DateTime> onSelected;

  const _StepBirthDate({
    required this.accent,
    required this.icon,
    required this.selected,
    required this.isAdult,
    required this.onSelected,
  });

  int _calcAge(DateTime b) {
    final now = DateTime.now();
    int age = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) age--;
    return age;
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selected ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 13),
      helpText: '¿Cuándo naciste?',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: accent,
            onPrimary: Colors.white,
            surface: const Color(0xFF4A1942),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = selected != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          _StepIcon(icon: icon, accent: accent, size: 80),

          const SizedBox(height: 28),

          const Text(
            '¿Cuándo\nnaciste?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

          const SizedBox(height: 12),

          Text(
            'Tu edad nos ayuda a conectarte con\npersonas y actividades afines.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 350.ms),

          const Spacer(),

          // Selector de fecha
          GestureDetector(
            onTap: () => _pick(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              decoration: BoxDecoration(
                color: hasDate
                    ? accent.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasDate ? accent : Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color:
                        hasDate ? accent : Colors.white.withValues(alpha: 0.5),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    hasDate ? _fmt(selected!) : 'Toca para seleccionar',
                    style: TextStyle(
                      color: hasDate
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      fontSize: 18,
                      fontWeight: hasDate ? FontWeight.bold : FontWeight.normal,
                      letterSpacing: hasDate ? 1.5 : 0,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 450.ms),

          const SizedBox(height: 14),

          // Feedback de edad
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: hasDate
                ? Container(
                    key: ValueKey(selected),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isAdult
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAdult
                              ? Icons.check_circle_rounded
                              : Icons.block_rounded,
                          color:
                              isAdult ? Colors.greenAccent : Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAdult
                              ? '${_calcAge(selected!)} años — ¡Bienvenido!'
                              : 'Debes tener mínimo 18 años',
                          style: TextStyle(
                            color:
                                isAdult ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(curve: Curves.elasticOut)
                : const SizedBox(height: 44),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PASO 3 — Género
// ══════════════════════════════════════════════════════════════
class _StepGender extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final UserGender selected;
  final ValueChanged<UserGender> onSelected;

  const _StepGender(
      {required this.accent,
      required this.icon,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final options = [
      (UserGender.male, Icons.male_rounded, 'Masculino'),
      (UserGender.female, Icons.female_rounded, 'Femenino'),
      (UserGender.nonBinary, Icons.transgender_rounded, 'No binario'),
      (
        UserGender.preferNotToSay,
        Icons.remove_circle_outline_rounded,
        'Prefiero no decir'
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _StepIcon(icon: icon, accent: accent, size: 76),
          const SizedBox(height: 24),
          const Text(
            '¿Tu género?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            'Opcional · puedes cambiarlo cuando quieras',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
            ),
          ).animate().fadeIn(delay: 320.ms),
          const Spacer(),
          ...options.asMap().entries.map((e) {
            final i = e.key;
            final (gender, gIcon, label) = e.value;
            final isSel = selected == gender;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onSelected(gender),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: isSel
                        ? accent.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          isSel ? accent : Colors.white.withValues(alpha: 0.2),
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSel
                              ? accent.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(gIcon,
                            color: isSel
                                ? accent
                                : Colors.white.withValues(alpha: 0.6),
                            size: 22),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSel
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.7),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSel ? accent : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel
                                ? accent
                                : Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: isSel
                            ? const Icon(Icons.check,
                                size: 12, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                )
                    .animate(delay: (i * 70 + 200).ms)
                    .slideX(begin: 0.15)
                    .fadeIn(),
              ),
            );
          }),
          const Spacer(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PASO 4 — Intereses
// ══════════════════════════════════════════════════════════════
class _StepInterests extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  static const _tags = [
    'Running',
    'Trekking',
    'Ciclismo',
    'Fútbol',
    'Natación',
    'Yoga',
    'Cocina',
    'Gastronomía',
    'Naturaleza',
    'Camping',
    'Playa',
    'Aventura',
    'Fiesta',
    'Arte',
    'Fotografía',
    'Música',
    'Cine',
    'Lectura',
    'Gaming',
    'Viajes',
    'Mascotas',
    'Baile',
    'Juegos',
    'Ajedrez',
    'Skate',
    'Social',
  ];

  const _StepInterests(
      {required this.accent,
      required this.icon,
      required this.selected,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final count = selected.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Qué te\napasiona?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: count >= 3
                      ? accent
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  count >= 3 ? '$count ✓' : '$count / 3 mín.',
                  style: TextStyle(
                    color: count >= 3
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 8),
          Text(
            'Selecciona mínimo 3 temas que te gusten',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
            ),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _tags.asMap().entries.map((e) {
                  final i = e.key;
                  final tag = e.value;
                  final isSel = selected.contains(tag);

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onToggle(tag);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSel
                            ? accent
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSel
                              ? accent
                              : Colors.white.withValues(alpha: 0.25),
                          width: isSel ? 0 : 1,
                        ),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: isSel
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.7),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ).animate(delay: (i * 25).ms).scale(
                          begin: const Offset(0.8, 0.8),
                          curve: Curves.easeOutBack,
                        ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PASO 5 — Notificaciones
// ══════════════════════════════════════════════════════════════
class _StepNotifications extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final bool granted;
  final VoidCallback onGranted;
  final VoidCallback onSkip;

  const _StepNotifications({
    required this.accent,
    required this.icon,
    required this.granted,
    required this.onGranted,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.check_circle_outline_rounded,
        '¡Te aceptaron en un plan!',
        'Sabrás al instante'
      ),
      (
        Icons.person_add_outlined,
        'Alguien quiere unirse',
        'Gestiona tus solicitudes'
      ),
      (
        Icons.chat_bubble_outline_rounded,
        'Mensaje del grupo',
        'No te pierdas nada'
      ),
      (
        Icons.alarm_rounded,
        'Recordatorio del evento',
        '24h antes para no olvidarte'
      ),
      (
        Icons.emoji_events_outlined,
        'Nueva medalla',
        'Reconocimientos de tus compañeros'
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),

          _StepIcon(icon: icon, accent: accent, size: 80),

          const SizedBox(height: 24),

          const Text(
            '¡Mantente\nal día!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

          const SizedBox(height: 8),

          Text(
            'Te avisamos de lo que importa',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 15,
            ),
          ).animate().fadeIn(delay: 320.ms),

          const Spacer(),

          // Lista compacta
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final (icon, title, sub) = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text(sub,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12)),
                    ],
                  ),
                ],
              ).animate(delay: (i * 70 + 300).ms).slideX(begin: 0.2).fadeIn(),
            );
          }),

          const Spacer(flex: 2),

          if (!granted)
            _StoryButton(
              label: 'Activar notificaciones',
              icon: Icons.notifications_active_rounded,
              accent: accent,
              onTap: onGranted,
            )
          else
            _SuccessBanner(accent: accent, text: 'Notificaciones activadas'),

          if (!granted) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onSkip,
              child: Text(
                'Ahora no',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 14,
                ),
              ),
            ),
          ],

          const Spacer(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Pantalla de completion
// ══════════════════════════════════════════════════════════════
class _CompletionScreen extends StatefulWidget {
  const _CompletionScreen();

  @override
  State<_CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<_CompletionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _msgIdx = 0;

  static const _msgs = [
    'Guardando tu perfil...',
    'Configurando tu ubicación...',
    'Personalizando intereses...',
    'Activando notificaciones...',
    '¡Todo listo! Bienvenido a Join',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: 450.ms)..forward();
    _cycle();
  }

  void _cycle() async {
    for (var i = 0; i < _msgs.length; i++) {
      await Future.delayed(520.ms);
      if (!mounted) return;
      setState(() => _msgIdx = i);
      _ctrl.reset();
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.deepBlue, AppColors.navyBlue],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withValues(alpha: 0.5),
                        blurRadius: 50,
                        spreadRadius: 15,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Image.asset('assets/images/join.png'),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
                    begin: 0,
                    end: -8,
                    duration: 1500.ms,
                    curve: Curves.easeInOut),
                const SizedBox(height: 48),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primaryOrange,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: _ctrl,
                  child: Text(
                    _msgs[_msgIdx],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_msgIdx + 1) / _msgs.length,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primaryOrange),
                    ),
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

// ══════════════════════════════════════════════════════════════
//  Widgets comunes
// ══════════════════════════════════════════════════════════════

class _StepConfig {
  final List<Color> gradient;
  final Color accent;
  final IconData icon;
  const _StepConfig(
      {required this.gradient, required this.accent, required this.icon});
}

class _StepIcon extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;

  const _StepIcon(
      {required this.icon, required this.accent, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.6,
      height: size * 1.6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          accent.withValues(alpha: 0.35),
          accent.withValues(alpha: 0.05),
        ]),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: accent, size: size * 0.52),
      ),
    )
        .animate()
        .scale(duration: 700.ms, curve: Curves.elasticOut)
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -6, duration: 2000.ms, curve: Curves.easeInOut);
  }
}

class _StoryButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color accent;
  final VoidCallback onTap;

  const _StoryButton(
      {required this.label,
      required this.accent,
      required this.onTap,
      this.icon});

  @override
  State<_StoryButton> createState() => _StoryButtonState();
}

class _StoryButtonState extends State<_StoryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()..scale(_pressed ? 0.96 : 1.0),
        transformAlignment: Alignment.center,
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: widget.accent,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final Color accent;
  final String text;

  const _SuccessBanner({required this.accent, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF00C853).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF00C853), size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF00C853),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ).animate().scale(curve: Curves.elasticOut);
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _MiniChip(this.icon, this.label, this.accent);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;

  const _PillButton(
      {required this.icon, required this.onTap, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              'Atrás',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

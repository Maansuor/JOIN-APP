import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/models/user_model.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════
//  OnboardingScreen — Experiencia Premium
//
//  Cada paso ocupa pantalla completa con un gradiente "aurora"
//  propio y un acento de color. Barra de progreso segmentada
//  (estilo Stories) + chip de paso actual.
//
//  El usuario SIEMPRE confirma con el botón inferior — sin
//  auto-avances sorpresivos. Selección de fecha con ruedas
//  estilo iOS integradas en la pantalla.
//
//  Pasos:
//   0. Compañero iguana            (violeta real)
//   1. Bienvenida + tipo de eventos (esmeralda)
//   2. Ubicación                   (zafiro)
//   3. Nacimiento                  (rosa terciopelo)
//   4. Género                      (teal profundo)
//   5. Intereses                   (carbón + naranja)
//   6. Notificaciones              (oro bruñido)
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
  static const int _total = 7;
  bool _completing = false;

  // ── AnimationController para la barra de Stories ───────────
  late AnimationController _storyBar;

  // ── Data de cada paso ─────────────────────────────────────
  bool _locationGranted = false;
  String? _detectedCity;
  DateTime? _birthDate;
  UserGender _gender = UserGender.preferNotToSay;
  final Set<String> _interests = {};
  bool _notifGranted = false;
  String _userRole = 'casual';
  String _iguanaType = 'female'; // Compañera por defecto: Eli

  // ── Configuración visual de cada paso ──────────────────────
  static const _steps = [
    // 0 · Compañero — violeta real
    _StepConfig(
      gradient: [Color(0xFF120A26), Color(0xFF251347), Color(0xFF3B1E63)],
      accent: Color(0xFFE0B64C),
      icon: Icons.auto_awesome_rounded,
    ),
    // 1 · Bienvenida — esmeralda noir
    _StepConfig(
      gradient: [Color(0xFF051711), Color(0xFF0A2E22), Color(0xFF11402F)],
      accent: Color(0xFF34D399),
      icon: Icons.person_outline_rounded,
    ),
    // 2 · Ubicación — zafiro de medianoche
    _StepConfig(
      gradient: [Color(0xFF020E2B), Color(0xFF0A2452), Color(0xFF123B7E)],
      accent: Color(0xFF60C5FF),
      icon: Icons.location_on_rounded,
    ),
    // 3 · Nacimiento — rosa terciopelo
    _StepConfig(
      gradient: [Color(0xFF260C1F), Color(0xFF4D1739), Color(0xFF7E2654)],
      accent: Color(0xFFFF9EC8),
      icon: Icons.cake_rounded,
    ),
    // 4 · Género — teal profundo
    _StepConfig(
      gradient: [Color(0xFF04201C), Color(0xFF0E4038), Color(0xFF176054)],
      accent: Color(0xFF7BEAC8),
      icon: Icons.wc_rounded,
    ),
    // 5 · Intereses — carbón con brasas
    _StepConfig(
      gradient: [Color(0xFF120F1C), Color(0xFF1D1830), Color(0xFF2A2142)],
      accent: AppColors.primaryOrange,
      icon: Icons.interests_rounded,
    ),
    // 6 · Notificaciones — oro bruñido
    _StepConfig(
      gradient: [Color(0xFF1E1102), Color(0xFF3F2606), Color(0xFF6B430C)],
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
      // Obtener la ubicación y ciudad en background sin bloquear el flujo
      _fetchCurrentLocation();
      // NO auto-avanzar - esperar confirmación del usuario
    }
    // Notificaciones
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isGranted) {
      setState(() => _notifGranted = true);
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&accept-language=es');
      final response = await http.get(url, headers: {
        'User-Agent': 'JoinApp-LocalDev',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        if (address != null) {
          final city = address['city'] ??
                       address['town'] ??
                       address['village'] ??
                       address['suburb'] ??
                       address['county'] ??
                       address['state'] ??
                       '';
          if (city.isNotEmpty) return city;
        }
      }
    } catch (e) {
      debugPrint('Resilient Geocoding Error: $e');
    }
    return null;
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      // Usamos timeout para no bloquear la UI si el GPS tarda mucho
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 8));
      debugPrint(
          '📍 Ubicación capturada: ${position.latitude}, ${position.longitude}');

      double lat = position.latitude;
      double lon = position.longitude;

      // Detectar si es la ubicación por defecto del emulador (Googleplex en Mountain View)
      final isGoogleplex = (lat >= 37.421 && lat <= 37.423) && (lon >= -122.086 && lon <= -122.082);

      String? city;

      if (isGoogleplex) {
        debugPrint('🕵️ Ubicación por defecto del emulador detectada (Mountain View). Resolviendo ubicación real por IP del Host...');
        try {
          final ipResponse = await http.get(Uri.parse('http://ip-api.com/json')).timeout(const Duration(seconds: 3));
          if (ipResponse.statusCode == 200) {
            final ipData = json.decode(ipResponse.body);
            final ipCity = ipData['city'];
            final ipLat = ipData['lat'];
            final ipLon = ipData['lon'];

            if (ipCity != null) {
              city = ipCity;
              if (ipLat != null && ipLon != null) {
                lat = ipLat is num ? ipLat.toDouble() : double.parse(ipLat.toString());
                lon = ipLon is num ? ipLon.toDouble() : double.parse(ipLon.toString());
              }
              debugPrint('🏠 Ciudad real resuelta por IP del host: $city ($lat, $lon)');
            }
          }
        } catch (ipErr) {
          debugPrint('No se pudo determinar ubicación real por IP: $ipErr');
        }
      }

      if (city == null || city.isEmpty) {
        // Obtener ciudad con OpenStreetMap Nominatim primero para forzar idioma español
        city = await _reverseGeocode(lat, lon);

        // Fallback a geocodificador nativo si Nominatim falló
        if (city == null || city.isEmpty) {
          try {
            List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon).timeout(const Duration(seconds: 4));
            if (placemarks.isNotEmpty) {
              city = placemarks.first.locality ?? placemarks.first.subAdministrativeArea;
            }
          } catch (geocodingErr) {
            debugPrint('Geocoder nativo de fallback falló en el emulador: $geocodingErr');
          }
        }
      }

      if (mounted) {
        setState(() => _detectedCity = city ?? 'Ubicación detectada');
        // Guardamos la posición real para que los eventos correspondan al país del usuario
        context.read<AppState>().updatePosition(
          Position(
            latitude: lat,
            longitude: lon,
            timestamp: DateTime.now(),
            accuracy: position.accuracy,
            altitude: position.altitude,
            altitudeAccuracy: position.altitudeAccuracy,
            heading: position.heading,
            headingAccuracy: position.headingAccuracy,
            speed: position.speed,
            speedAccuracy: position.speedAccuracy,
          ),
        );
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout GPS — intentando última posición conocida...');
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          double lat = last.latitude;
          double lon = last.longitude;
          final isGoogleplex = (lat >= 37.421 && lat <= 37.423) && (lon >= -122.086 && lon <= -122.082);
          String? city;

          if (isGoogleplex) {
            try {
              final ipResponse = await http.get(Uri.parse('http://ip-api.com/json')).timeout(const Duration(seconds: 3));
              if (ipResponse.statusCode == 200) {
                final ipData = json.decode(ipResponse.body);
                city = ipData['city'];
                final ipLat = ipData['lat'];
                final ipLon = ipData['lon'];
                if (ipLat != null && ipLon != null) {
                  lat = ipLat is num ? ipLat.toDouble() : double.parse(ipLat.toString());
                  lon = ipLon is num ? ipLon.toDouble() : double.parse(ipLon.toString());
                }
              }
            } catch (_) {}
          }

          if (city == null || city.isEmpty) {
            city = await _reverseGeocode(lat, lon);
          }

          if (mounted) {
            context.read<AppState>().updatePosition(
              Position(
                latitude: lat,
                longitude: lon,
                timestamp: DateTime.now(),
                accuracy: last.accuracy,
                altitude: last.altitude,
                altitudeAccuracy: last.altitudeAccuracy,
                heading: last.heading,
                headingAccuracy: last.headingAccuracy,
                speed: last.speed,
                speedAccuracy: last.speedAccuracy,
              ),
            );
            setState(() => _detectedCity = city ?? 'Última ubicación conocida');
          }
        } else {
          if (mounted) {
            setState(() => _detectedCity = 'Ubicación no detectada');
          }
        }
      } catch (_) {
        if (mounted) {
          setState(() => _detectedCity = 'Ubicación no detectada');
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo coordenadas: $e');
      // Intento final con última posición conocida por seguridad e IP lookup
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          double lat = last.latitude;
          double lon = last.longitude;
          final isGoogleplex = (lat >= 37.421 && lat <= 37.423) && (lon >= -122.086 && lon <= -122.082);
          String? city;

          if (isGoogleplex) {
            try {
              final ipResponse = await http.get(Uri.parse('http://ip-api.com/json')).timeout(const Duration(seconds: 3));
              if (ipResponse.statusCode == 200) {
                final ipData = json.decode(ipResponse.body);
                city = ipData['city'];
                final ipLat = ipData['lat'];
                final ipLon = ipData['lon'];
                if (ipLat != null && ipLon != null) {
                  lat = ipLat is num ? ipLat.toDouble() : double.parse(ipLat.toString());
                  lon = ipLon is num ? ipLon.toDouble() : double.parse(ipLon.toString());
                }
              }
            } catch (_) {}
          }

          if (city == null || city.isEmpty) {
            city = await _reverseGeocode(lat, lon);
          }

          if (mounted) {
            context.read<AppState>().updatePosition(
              Position(
                latitude: lat,
                longitude: lon,
                timestamp: DateTime.now(),
                accuracy: last.accuracy,
                altitude: last.altitude,
                altitudeAccuracy: last.altitudeAccuracy,
                heading: last.heading,
                headingAccuracy: last.headingAccuracy,
                speed: last.speed,
                speedAccuracy: last.speedAccuracy,
              ),
            );
            setState(() => _detectedCity = city ?? 'Última ubicación conocida');
          }
        }
      } catch (_) {}
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
      // NO auto-avanzar - esperar confirmación del usuario
    }
  }

  // ──  Solicitar permiso de notificaciones  ────────────────
  Future<void> _requestNotifications() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      setState(() => _notifGranted = true);
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
        return true;
      case 1:
        return true;
      case 2:
        // La ubicación es opcional — puede omitirse o confirmar ciudad detectada
        return true;
      case 3:
        return _birthDate != null && _isAdult;
      case 4:
        return true;
      case 5:
        return _interests.length >= 3;
      case 6:
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

  String get _mascotName => switch (_iguanaType) {
        'male' => 'Drago',
        'female' => 'Eli',
        _ => 'Halo',
      };

  String get _mascotAsset => switch (_iguanaType) {
        'male' => 'assets/images/mascota/DRAGO.png',
        'female' => 'assets/images/mascota/ELI.png',
        _ => 'assets/images/mascota/HALO.png',
      };

  // ── Etiqueta e ícono del botón de confirmación inferior ─────
  String get _ctaLabel {
    switch (_step) {
      case 0:
        return 'Elegir a $_mascotName';
      case 1:
        return 'Continuar';
      case 2:
        if (_locationGranted && _detectedCity != null) {
          return 'Confirmar ubicación';
        }
        if (_locationGranted) return 'Continuar';
        return 'Continuar sin ubicación';
      case 3:
        if (_birthDate == null) return 'Desliza para elegir tu fecha';
        return _isAdult ? 'Confirmar fecha' : 'Debes ser mayor de 18';
      case 4:
        return 'Continuar';
      case 5:
        final n = _interests.length;
        if (n >= 3) return 'Continuar · $n elegidos';
        final left = 3 - n;
        return left == 1 ? 'Elige 1 más' : 'Elige $left más';
      case 6:
        return '¡Comenzar mi aventura!';
      default:
        return 'Continuar';
    }
  }

  IconData get _ctaIcon {
    if (_step == _total - 1) return Icons.rocket_launch_rounded;
    if (_step == 2 && _locationGranted && _detectedCity != null) {
      return Icons.check_rounded;
    }
    return Icons.arrow_forward_rounded;
  }

  Future<void> _advance() async {
    if (!_stepReady) {
      HapticFeedback.heavyImpact();
      return;
    }
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
    final interestsList = _interests.toList();

    try {
      if (mounted) {
        final appState = context.read<AppState>();
        // Guardar todos los datos del onboarding directamente en Supabase
        await appState.updateProfile(
          birthDate: _birthDate,
          gender: _gender,
          interests: interestsList,
          setupCompleted: true,
          userRole: _userRole,
          completedOnboarding: true,
          iguanaType: _iguanaType,
        );
        debugPrint('✅ Onboarding guardado en Supabase con éxito');
      }
    } catch (e) {
      debugPrint('⚠️ Error al guardar Onboarding en Supabase: $e');
      // Fallback local por seguridad para que pueda continuar de todas formas
      if (mounted) {
        final appState = context.read<AppState>();
        await appState.updateLocalProfile(
          birthDate: _birthDate,
          gender: _gender,
          interests: interestsList,
          userRole: _userRole,
          completedOnboarding: true,
          iguanaType: _iguanaType,
        );
        appState.markSetupCompleted();
      }
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
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cfg.gradient,
            ),
          ),
          child: Stack(
            children: [
              // ── Fondo aurora animado ─────────────────────────
              _AuroraBackground(accent: cfg.accent, key: ValueKey(_step)),

              SafeArea(
                child: Column(
                  children: [
                    // ── Barra de stories ──────────────────────────
                    _StoryProgressBar(
                      total: _total,
                      current: _step,
                      controller: _storyBar,
                      accent: cfg.accent,
                    ),

                    // ── Top row: back + chip de paso ──────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: _step > 0 ? 1 : 0,
                            child: _PillButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: _step > 0 ? _back : () {},
                              accent: cfg.accent,
                            ),
                          ),
                          const Spacer(),
                          _StepChip(
                            current: _step + 1,
                            total: _total,
                            accent: cfg.accent,
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
                          _StepMascotSelection(
                            accent: _steps[0].accent,
                            selectedMascot: _iguanaType,
                            onSelected: (type) =>
                                setState(() => _iguanaType = type),
                          ),
                          _StepWelcomeAndSegmentation(
                            accent: _steps[1].accent,
                            mascotName: _mascotName,
                            mascotAsset: _mascotAsset,
                            selectedRole: _userRole,
                            onSelected: (role) =>
                                setState(() => _userRole = role),
                          ),
                          _StepLocation(
                            accent: _steps[2].accent,
                            icon: _steps[2].icon,
                            granted: _locationGranted,
                            detectedCity: _detectedCity,
                            onGranted: _requestLocation, // ← permiso real del SO
                          ),
                          _StepBirthDate(
                            accent: _steps[3].accent,
                            icon: _steps[3].icon,
                            selected: _birthDate,
                            isAdult: _isAdult,
                            onSelected: (d) => setState(() => _birthDate = d),
                          ),
                          _StepGender(
                            accent: _steps[4].accent,
                            icon: _steps[4].icon,
                            selected: _gender,
                            onSelected: (g) => setState(() => _gender = g),
                          ),
                          _StepInterests(
                            accent: _steps[5].accent,
                            icon: _steps[5].icon,
                            selected: _interests,
                            onToggle: (t) => setState(() {
                              _interests.contains(t)
                                  ? _interests.remove(t)
                                  : _interests.add(t);
                            }),
                          ),
                          _StepNotifications(
                            accent: _steps[6].accent,
                            icon: _steps[6].icon,
                            granted: _notifGranted,
                            onGranted:
                                _requestNotifications, // ← permiso real del SO
                          ),
                        ],
                      ),
                    ),

                    // ── Botón de confirmación inferior (siempre) ──
                    _BottomConfirmBar(
                      label: _ctaLabel,
                      icon: _ctaIcon,
                      accent: cfg.accent,
                      enabled: _stepReady,
                      onTap: _advance,
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

// ══════════════════════════════════════════════════════════════
//  Botón de confirmación inferior — premium, con gradiente,
//  glow pulsante y flecha en cápsula.
// ══════════════════════════════════════════════════════════════
class _BottomConfirmBar extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  const _BottomConfirmBar({
    required this.label,
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_BottomConfirmBar> createState() => _BottomConfirmBarState();
}

class _BottomConfirmBarState extends State<_BottomConfirmBar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final enabled = widget.enabled;

    // Color de texto legible sobre el acento
    final onAccent =
        accent.computeLuminance() > 0.55 ? const Color(0xFF12121A) : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.965 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: enabled
                  ? LinearGradient(
                      colors: [
                        accent,
                        Color.lerp(accent, Colors.white, 0.22)!,
                        accent,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: enabled ? null : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: enabled
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.45),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Text(
                    widget.label,
                    key: ValueKey(widget.label),
                    style: TextStyle(
                      color: enabled
                          ? onAccent
                          : Colors.white.withValues(alpha: 0.45),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Cápsula con ícono
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: enabled
                        ? onAccent.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    enabled ? widget.icon : Icons.lock_outline_rounded,
                    color: enabled
                        ? onAccent
                        : Colors.white.withValues(alpha: 0.4),
                    size: 18,
                  ),
                )
                    .animate(
                      target: enabled ? 1 : 0,
                      onPlay: (c) {},
                    )
                    .shake(hz: 2, rotation: 0.04, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    ).animate(target: enabled ? 1 : 0.92).fade(begin: 0.92, end: 1);
  }
}

// ══════════════════════════════════════════════════════════════
//  Fondo "aurora" — orbes de luz suaves que respiran
// ══════════════════════════════════════════════════════════════
class _AuroraBackground extends StatelessWidget {
  final Color accent;

  const _AuroraBackground({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _orb(300, accent.withValues(alpha: 0.30))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.25, 1.25),
                    duration: 5000.ms,
                    curve: Curves.easeInOut),
          ),
          Positioned(
            bottom: 110,
            left: -110,
            child: _orb(280, accent.withValues(alpha: 0.18))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: 36, duration: 6000.ms, curve: Curves.easeInOut),
          ),
          Positioned(
            top: 240,
            left: 40,
            child: _orb(120, Colors.white.withValues(alpha: 0.06))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveX(begin: 0, end: 24, duration: 7000.ms, curve: Curves.easeInOut),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Chip "PASO X / Y"
// ══════════════════════════════════════════════════════════════
class _StepChip extends StatelessWidget {
  final int current;
  final int total;
  final Color accent;

  const _StepChip(
      {required this.current, required this.total, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 0.4, end: 1, duration: 900.ms),
          const SizedBox(width: 7),
          Text(
            'PASO $current DE $total',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
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
              padding: EdgeInsets.only(right: i < total - 1 ? 5 : 0),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white.withValues(alpha: 0.18),
                  boxShadow: isDone || isActive
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 6,
                          )
                        ]
                      : [],
                ),
                clipBehavior: Clip.antiAlias,
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
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PASO 2 — Ubicación
// ══════════════════════════════════════════════════════════════
class _StepLocation extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final bool granted;
  final String? detectedCity;
  final VoidCallback onGranted;

  const _StepLocation({
    required this.accent,
    required this.icon,
    required this.granted,
    required this.detectedCity,
    required this.onGranted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          _StepIcon(icon: icon, accent: accent, size: 86),

          const SizedBox(height: 30),

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
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2)
          else if (detectedCity != null)
            _GlassCard(
              accent: accent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.location_city_rounded, color: accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TE ENCONTRAMOS EN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detectedCity!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.verified_rounded, color: accent, size: 22)
                      .animate()
                      .scale(delay: 300.ms, curve: Curves.elasticOut),
                ],
              ),
            ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms)
          else
            Column(
              children: [
                _GlassCard(
                  accent: accent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Detectando tu ciudad...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PASO 3 — Fecha de nacimiento (ruedas estilo iOS, en pantalla)
// ══════════════════════════════════════════════════════════════
class _StepBirthDate extends StatefulWidget {
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

  @override
  State<_StepBirthDate> createState() => _StepBirthDateState();
}

class _StepBirthDateState extends State<_StepBirthDate> {
  static const _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  late int _day;
  late int _month;
  late int _year;
  late List<int> _years;
  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _yearCtrl;

  int get _maxYear => DateTime.now().year - 18;

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  @override
  void initState() {
    super.initState();
    _years = List.generate(_maxYear - 1920 + 1, (i) => _maxYear - i);

    final base = widget.selected ?? DateTime(2000, 1, 1);
    _day = base.day;
    _month = base.month;
    _year = base.year.clamp(1920, _maxYear);

    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _yearCtrl =
        FixedExtentScrollController(initialItem: _years.indexOf(_year));

    // Emitir la fecha inicial para habilitar el botón de confirmación
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final maxDay = _daysInMonth(_year, _month);
    if (_day > maxDay) {
      _day = maxDay;
      _dayCtrl.jumpToItem(_day - 1);
    }
    widget.onSelected(DateTime(_year, _month, _day));
  }

  int _calcAge() {
    final b = DateTime(_year, _month, _day);
    final now = DateTime.now();
    int age = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final isAdult = widget.isAdult;
    final daysCount = _daysInMonth(_year, _month);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(),

          _StepIcon(icon: widget.icon, accent: accent, size: 66),

          const SizedBox(height: 20),

          const Text(
            '¿Cuándo\nnaciste?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

          const SizedBox(height: 10),

          Text(
            'Desliza las ruedas · solo mayores de 18',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 320.ms),

          const Spacer(),

          // ── Ruedas de fecha premium ─────────────────────────
          Container(
            height: 216,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Franja de selección central
                Center(
                  child: Container(
                    height: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    // Día
                    Expanded(
                      flex: 2,
                      child: _wheel(
                        controller: _dayCtrl,
                        childCount: daysCount,
                        onChanged: (i) {
                          setState(() => _day = i + 1);
                          _emit();
                        },
                        builder: (i) => _wheelText(
                          '${i + 1}'.padLeft(2, '0'),
                          selected: i + 1 == _day,
                        ),
                      ),
                    ),
                    // Mes
                    Expanded(
                      flex: 4,
                      child: _wheel(
                        controller: _monthCtrl,
                        childCount: 12,
                        onChanged: (i) {
                          setState(() => _month = i + 1);
                          _emit();
                        },
                        builder: (i) => _wheelText(
                          _months[i],
                          selected: i + 1 == _month,
                        ),
                      ),
                    ),
                    // Año
                    Expanded(
                      flex: 3,
                      child: _wheel(
                        controller: _yearCtrl,
                        childCount: _years.length,
                        onChanged: (i) {
                          setState(() => _year = _years[i]);
                          _emit();
                        },
                        builder: (i) => _wheelText(
                          '${_years[i]}',
                          selected: _years[i] == _year,
                        ),
                      ),
                    ),
                  ],
                ),
                // Degradados superior/inferior para profundidad
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 420.ms).slideY(begin: 0.08),

          const SizedBox(height: 18),

          // ── Feedback de edad ────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: child,
            ),
            child: Container(
              key: ValueKey('$_day-$_month-$_year-$isAdult'),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: isAdult
                    ? const Color(0xFF22C55E).withValues(alpha: 0.16)
                    : const Color(0xFFEF4444).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isAdult
                      ? const Color(0xFF22C55E).withValues(alpha: 0.45)
                      : const Color(0xFFEF4444).withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAdult
                        ? Icons.celebration_rounded
                        : Icons.block_rounded,
                    color: isAdult
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171),
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    isAdult
                        ? '${_calcAge()} años · ¡Bienvenido!'
                        : 'Debes tener mínimo 18 años',
                    style: TextStyle(
                      color: isAdult
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFF87171),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int childCount,
    required ValueChanged<int> onChanged,
    required Widget Function(int) builder,
  }) {
    return CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: 46,
      diameterRatio: 1.4,
      squeeze: 1.1,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: (i) {
        HapticFeedback.selectionClick();
        onChanged(i);
      },
      childCount: childCount,
      itemBuilder: (_, i) => Center(child: builder(i)),
    );
  }

  Widget _wheelText(String text, {required bool selected}) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 150),
      style: TextStyle(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.4),
        fontSize: selected ? 20 : 17,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      ),
      child: Text(text),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PASO 4 — Género (grid 2×2 con tarjetas gradiente)
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
      (UserGender.male, Icons.male_rounded, 'Masculino', const Color(0xFF60A5FA)),
      (UserGender.female, Icons.female_rounded, 'Femenino', const Color(0xFFF472B6)),
      (UserGender.nonBinary, Icons.transgender_rounded, 'No binario', const Color(0xFFC084FC)),
      (
        UserGender.preferNotToSay,
        Icons.visibility_off_rounded,
        'Prefiero\nno decir',
        const Color(0xFF94A3B8)
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _StepIcon(icon: icon, accent: accent, size: 70),
          const SizedBox(height: 22),
          const Text(
            '¿Tu género?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
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

          // ── Grid 2×2 ────────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.35,
            children: options.asMap().entries.map((e) {
              final i = e.key;
              final (gender, gIcon, label, color) = e.value;
              final isSel = selected == gender;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(gender);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    gradient: isSel
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: 0.35),
                              color.withValues(alpha: 0.12),
                            ],
                          )
                        : null,
                    color: isSel ? null : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSel
                          ? color
                          : Colors.white.withValues(alpha: 0.14),
                      width: isSel ? 2 : 1,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            )
                          ]
                        : [],
                  ),
                  child: Stack(
                    children: [
                      // Check superior derecho
                      Positioned(
                        top: 10,
                        right: 10,
                        child: AnimatedScale(
                          scale: isSel ? 1 : 0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isSel
                                    ? color.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.09),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                gIcon,
                                color: isSel
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.55),
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.65),
                                fontWeight:
                                    isSel ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate(delay: (i * 80 + 250).ms)
                  .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack)
                  .fadeIn();
            }).toList(),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PASO 5 — Intereses (chips con emoji + anillo de progreso)
// ══════════════════════════════════════════════════════════════
class _StepInterests extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  // (etiqueta guardada, emoji visual)
  static const _tags = [
    ('Running', '🏃'),
    ('Trekking', '🥾'),
    ('Ciclismo', '🚴'),
    ('Fútbol', '⚽'),
    ('Natación', '🏊'),
    ('Yoga', '🧘'),
    ('Cocina', '🍳'),
    ('Gastronomía', '🍽️'),
    ('Naturaleza', '🌿'),
    ('Camping', '⛺'),
    ('Playa', '🏖️'),
    ('Aventura', '🧗'),
    ('Fiesta', '🎉'),
    ('Arte', '🎨'),
    ('Fotografía', '📸'),
    ('Música', '🎵'),
    ('Cine', '🎬'),
    ('Lectura', '📚'),
    ('Gaming', '🎮'),
    ('Viajes', '✈️'),
    ('Mascotas', '🐶'),
    ('Baile', '💃'),
    ('Juegos', '🎲'),
    ('Ajedrez', '♟️'),
    ('Skate', '🛹'),
    ('Social', '🗣️'),
  ];

  const _StepInterests(
      {required this.accent,
      required this.icon,
      required this.selected,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final count = selected.length;
    final progress = (count / 3).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  '¿Qué te\napasiona?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
              // Anillo de progreso hacia el mínimo de 3
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: v,
                          strokeWidth: 4,
                          strokeCap: StrokeCap.round,
                          color: count >= 3 ? const Color(0xFF4ADE80) : accent,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: count >= 3
                          ? const Icon(Icons.check_rounded,
                              key: ValueKey('ok'),
                              color: Color(0xFF4ADE80),
                              size: 24)
                          : Text(
                              '$count/3',
                              key: ValueKey(count),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ],
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
                  final (tag, emoji) = e.value;
                  final isSel = selected.contains(tag);

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onToggle(tag);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: isSel
                            ? LinearGradient(colors: [
                                accent,
                                Color.lerp(accent, const Color(0xFFFF2D55), 0.45)!,
                              ])
                            : null,
                        color:
                            isSel ? null : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSel
                              ? Colors.transparent
                              : Colors.white.withValues(alpha: 0.22),
                        ),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.45),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            tag,
                            style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.7),
                              fontWeight:
                                  isSel ? FontWeight.w800 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: (i * 22).ms).scale(
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
//  PASO 6 — Notificaciones
// ══════════════════════════════════════════════════════════════
class _StepNotifications extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final bool granted;
  final VoidCallback onGranted;

  const _StepNotifications({
    required this.accent,
    required this.icon,
    required this.granted,
    required this.onGranted,
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

          _StepIcon(icon: icon, accent: accent, size: 76),

          const SizedBox(height: 22),

          const Text(
            '¡Mantente\nal día!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

          const SizedBox(height: 8),

          Text(
            'Te avisamos solo de lo que importa',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 15,
            ),
          ).animate().fadeIn(delay: 320.ms),

          const Spacer(),

          // Lista compacta
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final (nIcon, title, sub) = e.value;
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
                    child: Icon(nIcon, color: accent, size: 18),
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
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2)
          else
            _SuccessBanner(accent: accent, text: 'Notificaciones activadas'),

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
    'Despertando a tu compañero...',
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
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Icon(icon, color: accent, size: size * 0.5),
        ),
      ),
    )
        .animate()
        .scale(duration: 700.ms, curve: Curves.elasticOut)
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -6, duration: 2000.ms, curve: Curves.easeInOut);
  }
}

class _GlassCard extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _GlassCard({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: child,
        ),
      ),
    );
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
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.accent,
                Color.lerp(widget.accent, Colors.white, 0.2)!,
              ],
            ),
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
                Icon(widget.icon,
                    color: widget.accent.computeLuminance() > 0.55
                        ? const Color(0xFF12121A)
                        : Colors.white,
                    size: 20),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.accent.computeLuminance() > 0.55
                      ? const Color(0xFF12121A)
                      : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
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

// ══════════════════════════════════════════════════════════════
//  PASO 0 — Selección de compañero (iguana)
// ══════════════════════════════════════════════════════════════
class _StepMascotSelection extends StatelessWidget {
  final Color accent;
  final String selectedMascot;
  final ValueChanged<String> onSelected;

  const _StepMascotSelection({
    required this.accent,
    required this.selectedMascot,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        'male',
        'Drago',
        '🔥',
        'Enérgico, audaz y aventurero. Nunca le dice que no a un plan.',
        'assets/images/mascota/DRAGO.png',
        const Color(0xFF38BDF8),
      ),
      (
        'female',
        'Eli',
        '🌸',
        'Inteligente, observadora y súper curiosa. Siempre un paso adelante.',
        'assets/images/mascota/ELI.png',
        const Color(0xFFF472B6),
      ),
      (
        'non_binary',
        'Halo',
        '✨',
        'Carismático, empático y amante del misterio. Brilla con luz propia.',
        'assets/images/mascota/HALO.png',
        const Color(0xFFC084FC),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 1),

          _StepIcon(icon: Icons.auto_awesome_rounded, accent: accent, size: 64),

          const SizedBox(height: 20),
          const Text(
            'Elige tu compañero',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            'Te acompañará en tus aventuras, te dará consejos\ny cambiará de color según tus gustos.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 320.ms),

          const Spacer(flex: 2),

          ...options.asMap().entries.map((e) {
            final i = e.key;
            final (type, name, emoji, desc, asset, color) = e.value;
            final isSel = selectedMascot == type;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onSelected(type);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isSel
                        ? LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              color.withValues(alpha: 0.22),
                              color.withValues(alpha: 0.08),
                            ],
                          )
                        : null,
                    color: isSel ? null : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color:
                          isSel ? color : Colors.white.withValues(alpha: 0.12),
                      width: isSel ? 2 : 1,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              color.withValues(alpha: isSel ? 0.4 : 0.12),
                              color.withValues(alpha: 0.04),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel
                                ? color
                                : Colors.white.withValues(alpha: 0.15),
                            width: isSel ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(
                          child: Image.asset(
                            asset,
                            fit: BoxFit.contain,
                            // Decodifica el PNG gigante a tamaño útil (memoria/jank)
                            cacheWidth: 180,
                          ),
                        ),
                      ).animate(target: isSel ? 1 : 0).scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.1, 1.1),
                            duration: 300.ms,
                            curve: Curves.easeOutBack,
                          ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: isSel
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(emoji,
                                    style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedScale(
                        scale: isSel ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 15, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate(delay: (i * 90 + 250).ms).slideX(begin: 0.1).fadeIn();
          }),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PASO 1 — Welcome & Segmentation (con la mascota elegida)
// ══════════════════════════════════════════════════════════════
class _StepWelcomeAndSegmentation extends StatelessWidget {
  final Color accent;
  final String mascotName;
  final String mascotAsset;
  final String selectedRole;
  final ValueChanged<String> onSelected;

  const _StepWelcomeAndSegmentation({
    required this.accent,
    required this.mascotName,
    required this.mascotAsset,
    required this.selectedRole,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(),

          // Mascota elegida & Speech Bubble
          Column(
            children: [
              // Mascot Image (cacheWidth: decodifica el PNG gigante a tamaño útil)
              Image.asset(
                mascotAsset,
                height: 150,
                fit: BoxFit.contain,
                cacheWidth: 450,
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(
                      begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                      begin: 0,
                      end: -8,
                      duration: 2000.ms,
                      curve: Curves.easeInOut),

              const SizedBox(height: 16),

              // Speech Bubble
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Triangle pointing up
                    Positioned(
                      top: -24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: CustomPaint(
                          size: const Size(20, 10),
                          painter: _TrianglePainter(
                              Colors.white.withValues(alpha: 0.95)),
                        ),
                      ),
                    ),
                    Text(
                      '¡Hola! Soy $mascotName 🦎\n¿Qué tipo de eventos te interesa más organizar o asistir?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
            ],
          ),

          const Spacer(),

          // Option Cards
          _buildOptionCard(
            context,
            role: 'casual',
            icon: Icons.celebration_rounded,
            title: 'Eventos Casuales',
            subtitle:
                'Pichangas, salidas al cine, parrilladas o juntas informales con amigos.',
            isSelected: selectedRole == 'casual',
          ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1),

          const SizedBox(height: 16),

          _buildOptionCard(
            context,
            role: 'corporate',
            icon: Icons.business_center_rounded,
            title: 'Eventos Corporativos',
            subtitle:
                'Conferencias, networking, tickets pagos o validación QR de accesos.',
            isSelected: selectedRole == 'corporate',
          ).animate().fadeIn(delay: 650.ms).slideX(begin: 0.1),

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onSelected(role);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.24),
                    accent.withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? accent : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? accent : Colors.white70,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Selection indicator
            AnimatedScale(
              scale: isSelected ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color strokeColor;

  _TrianglePainter(this.strokeColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

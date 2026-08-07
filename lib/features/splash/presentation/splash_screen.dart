import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/theme/app_colors.dart';

/// Pantalla de carga con el logo cayendo y rebotando.
///
/// El splash nativo sólo pinta el fondo, así que esta es la primera pantalla
/// de Flutter: continúa el mismo color y el logo entra cayendo, sin saltos.
///
/// Decide ella misma cuándo salir, en lugar de dejárselo al redirect del
/// router, para que la animación no se corte a media caída si la sesión
/// termina de restaurarse antes de tiempo. Sale cuando se cumplen las dos
/// cosas: la animación llegó al final y AppState terminó de inicializar.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // ── Línea de tiempo ───────────────────────────────────────────────────────
  // Un solo controlador de 2.100 ms con tramos solapados: así los elementos se
  // encadenan sin depender de Future.delayed, que se desincroniza si el
  // dispositivo va lento.
  static const Duration _duracion = Duration(milliseconds: 2100);

  /// Caída con rebote. Ocupa el primer tercio para que el resto respire.
  static const Interval _tramoCaida = Interval(0.00, 0.38, curve: Curves.bounceOut);

  /// La opacidad entra antes de que el logo llegue: aparece ya cayendo.
  static const Interval _tramoAparicion = Interval(0.00, 0.12, curve: Curves.easeOut);

  /// Aplastado al tocar el suelo, justo cuando la caída termina.
  static const Interval _tramoImpacto = Interval(0.30, 0.52, curve: Curves.easeOut);

  /// El texto entra cuando el logo ya se asentó.
  static const Interval _tramoTexto = Interval(0.42, 0.62, curve: Curves.easeOut);

  /// Y la barra al final, para que la lectura sea logo -> texto -> progreso.
  static const Interval _tramoBarra = Interval(0.52, 1.00, curve: Curves.easeInOut);

  /// Hasta dónde llega la barra con la animación. El último tramo se reserva
  /// para cuando la carga real termina, así el 100% significa algo.
  static const double _progresoAnimado = 0.85;

  bool _saliendo = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duracion)
      ..addStatusListener((estado) {
        if (estado == AnimationStatus.completed) _intentarSalir();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sale sólo si la animación acabó y la app ya está lista.
  void _intentarSalir() {
    if (_saliendo || !mounted) return;

    final appState = context.read<AppState>();
    if (!appState.isInitialized) return; // Esperamos; nos reintenta el listener
    if (!_controller.isCompleted) return;

    _saliendo = true;
    context.go(_destino(appState));
  }

  /// A dónde llevar al usuario según su estado de sesión.
  static String _destino(AppState appState) {
    if (!appState.isLoggedIn) return '/login';
    if (!(appState.currentUser?.setupCompleted ?? false)) return '/onboarding';
    return '/main';
  }

  @override
  Widget build(BuildContext context) {
    // Si la carga termina después de la animación, este watch nos despierta.
    final appState = context.watch<AppState>();
    if (appState.isInitialized && _controller.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _intentarSalir());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fondo = isDark ? const Color(0xFF0A0D14) : Colors.white;

    return Scaffold(
      backgroundColor: fondo,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(),
            const SizedBox(height: 36),
            _buildTexto(isDark),
            const SizedBox(height: 20),
            _buildBarra(isDark, appState.isInitialized),
          ],
        ),
      ),
    );
  }

  // ── Logo que cae y rebota ─────────────────────────────────────────────────

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        // Curves.bounceOut ya trae la caída acelerada y los rebotes; se aplica
        // sobre el desplazamiento vertical para que caiga desde fuera de la
        // pantalla hasta su sitio.
        final caida = _tramoCaida.transform(t);
        final desplazamiento = (1 - caida) * -260;

        final opacidad = _tramoAparicion.transform(t);

        // Al aterrizar se achata un poco y se recupera: es lo que hace que el
        // rebote se sienta con peso en lugar de un simple deslizamiento.
        final impacto = _tramoImpacto.transform(t);
        final achatado = _pulso(impacto) * 0.10;

        return Opacity(
          opacity: opacidad,
          child: Transform.translate(
            offset: Offset(0, desplazamiento),
            child: Transform.scale(
              scaleX: 1 + achatado,
              scaleY: 1 - achatado,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: Image.asset(
        'assets/images/join.png',
        width: 150,
        height: 150,
        fit: BoxFit.contain,
      ),
    );
  }

  /// Sube de 0 a 1 y vuelve a 0: sirve para deformar y recuperar la forma.
  static double _pulso(double t) => t <= 0 || t >= 1 ? 0 : (1 - (2 * t - 1).abs());

  // ── Texto ─────────────────────────────────────────────────────────────────

  Widget _buildTexto(bool isDark) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _tramoTexto.transform(_controller.value);
        return Opacity(
          opacity: t,
          // Un empujón corto hacia arriba acompaña la aparición.
          child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
        );
      },
      child: Text(
        'Cargando experiencia',
        style: GoogleFonts.outfit(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryOrange,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Barra de progreso ─────────────────────────────────────────────────────

  Widget _buildBarra(bool isDark, bool cargaLista) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final avance = _tramoBarra.transform(_controller.value);

        // Mientras carga avanza hasta el 85%; el tramo final sólo se completa
        // cuando la app está lista de verdad.
        final progreso = cargaLista
            ? _progresoAnimado + (1 - _progresoAnimado) * avance
            : _progresoAnimado * avance;

        return Opacity(
          opacity: avance == 0 ? 0 : 1,
          child: SizedBox(
            width: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 5,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.primaryOrange.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(AppColors.primaryOrange),
              ),
            ),
          ),
        );
      },
    );
  }
}

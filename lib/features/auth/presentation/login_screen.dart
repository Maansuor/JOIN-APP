import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════
//  LoginScreen — Rediseñada Premium con glassmorphism avanzado
// ══════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  String _view = 'home';

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isRegister = false;
  bool _useMagicLink = true; // Por defecto Magic Link para verificar correos reales

  late AnimationController _bgController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _bgController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() async {
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      _showSnack('Por favor completa todos los campos');
      return;
    }
    final appState = context.read<AppState>();
    final success = await appState.login(email, pass);
    if (!mounted) return;
    if (success) {
      // El GoRouter redirect decide automáticamente:
      // setupCompleted=true  → /main
      // setupCompleted=false → /onboarding
      // Solo necesitamos que el router se re-evalúe (notifyListeners ya ocurrió)
    } else {
      _showSnack(appState.error ?? 'Credenciales incorrectas');
    }
  }

  Future<void> _registerWithEmail() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      _showSnack('Por favor completa todos los campos');
      return;
    }
    final appState = context.read<AppState>();
    final success = await appState.register(
      fullName: name,
      username: email,
      email: email,
      password: pass,
    );
    if (!mounted) return;
    if (!success) {
      _showSnack(appState.error ?? 'Error al crear la cuenta');
    }
    // Si success=true, el router redirect lleva automáticamente al onboarding
  }

  Future<void> _requestOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Introduce un correo válido');
      return;
    }
    final appState = context.read<AppState>();
    final result = await appState.requestMagicCode(email);
    if (!mounted) return;
    
    if (result != null) {
      // Éxito: result es "" o el código real (debug)
      setState(() {
        _view = 'otp';
        if (result.isNotEmpty) {
           _otpCtrl.text = result; // Auto-relleno profesional en desarrollo
        }
      });
      _showSnack('Código enviado a $email');
    } else {
      _showSnack(appState.error ?? 'Error al enviar el código');
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailCtrl.text.trim();
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      _showSnack('El código debe tener 6 dígitos');
      return;
    }
    final appState = context.read<AppState>();
    final success = await appState.verifyMagicCode(email, code);
    if (!mounted) return;
    if (!success) {
      _showSnack(appState.error ?? 'Código incorrecto');
    }
  }

  Future<void> _loginWithGoogle() async {
    HapticFeedback.mediumImpact();
    final appState = context.read<AppState>();
    try {
      final success = await appState.loginWithGoogle();
      if (!mounted) return;
      if (!success) return; // Usuario canceló
      // El router redirect decide automáticamente a dónde ir,
      // según setupCompleted del usuario
    } catch (e) {
      if (!mounted) return;
      _showSnack(appState.error ?? 'Error al iniciar sesión con Google');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      backgroundColor: AppColors.primaryOrange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      elevation: 8,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLoading = context.select<AppState, bool>((s) => s.isLoading);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.deepBlue,
        body: Stack(
          children: [
            // ── Fondo animado avanzado ──────────────────────────
            _PremiumBackground(
              bgController: _bgController,
              particleController: _particleController,
              size: size,
            ),

            // ── Contenido ──────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildHero(),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: anim, curve: Curves.easeOutCubic)),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: _view == 'email'
                        ? _EmailPanel(
                            key: const ValueKey('email'),
                            emailCtrl: _emailCtrl,
                            passwordCtrl: _passwordCtrl,
                            nameCtrl: _nameCtrl,
                            obscurePass: _obscurePass,
                            isRegister: _isRegister,
                            useMagicLink: _useMagicLink,
                            isLoading: isLoading,
                            onToggleObscure: () =>
                                setState(() => _obscurePass = !_obscurePass),
                            onToggleMode: () =>
                                setState(() => _isRegister = !_isRegister),
                            onToggleMagic: () =>
                                setState(() => _useMagicLink = !_useMagicLink),
                            onBack: () => setState(() => _view = 'home'),
                            onSubmit: _useMagicLink 
                                ? _requestOtp
                                : (_isRegister ? _registerWithEmail : _loginWithEmail),
                          )
                        : (_view == 'otp'
                            ? _OtpPanel(
                                key: const ValueKey('otp'),
                                email: _emailCtrl.text,
                                otpCtrl: _otpCtrl,
                                isLoading: isLoading,
                                onBack: () => setState(() => _view = 'email'),
                                onResend: _requestOtp,
                                onSubmit: _verifyOtp,
                              )
                            : _SocialPanel(
                                key: const ValueKey('social'),
                                onGoogle: _loginWithGoogle,
                                onEmail: () => setState(() => _view = 'email'),
                              )),
                  ),
                ],
              ),
            ),

            // ── Loading overlay ────────────────────────────────
            if (isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.primaryOrange,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Un momento...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildHero() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo con brillo animado
        Stack(
          alignment: Alignment.center,
          children: [
            // Halo exterior
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryOrange.withValues(alpha: 0.3),
                    AppColors.primaryOrange.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.5),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.15),
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Image.asset('assets/images/join.png', fit: BoxFit.contain),
            ),
          ],
        )
            .animate()
            .scale(duration: 800.ms, curve: Curves.elasticOut)
            .then()
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -8, duration: 3000.ms, curve: Curves.easeInOut),

        const SizedBox(height: 24),

        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFFFD4A8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'Join',
            style: TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
            ),
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

        const SizedBox(height: 10),

        // Tagline con dots decorativos
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Conecta · Vive · Disfruta',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 600.ms, delay: 400.ms),

        const SizedBox(height: 12),

        Text(
          'Experiencias grupales increíbles\ncon personas increíbles',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 600.ms, delay: 550.ms),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Panel principal — opciones de login social (premium)
// ══════════════════════════════════════════════════════════════
class _SocialPanel extends StatelessWidget {
  final VoidCallback onGoogle;
  final VoidCallback onEmail;

  const _SocialPanel({
    super.key,
    required this.onGoogle,
    required this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000B3C).withValues(alpha: 0.4),
            blurRadius: 60,
            offset: const Offset(0, -15),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar premium
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.navyBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 22),

            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡Bienvenido!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navyBlue,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Elige cómo quieres continuar',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.navyBlue.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    color: AppColors.primaryOrange,
                    size: 24,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Google
            _SocialButton(
              icon: FontAwesomeIcons.google,
              label: 'Continuar con Google',
              color: const Color(0xFFEA4335),
              bgColor: const Color(0xFFFFF0EE),
              accentColor: const Color(0xFFEA4335),
              onTap: onGoogle,
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms)
                .slideY(begin: 0.15, curve: Curves.easeOutCubic),

            const SizedBox(height: 12),

            // Email
            _SocialButton(
              icon: Icons.email_rounded,
              label: 'Continuar con correo',
              color: AppColors.navyBlue,
              bgColor: AppColors.navyBlue.withValues(alpha: 0.06),
              accentColor: AppColors.navyBlue,
              onTap: onEmail,
              isMaterial: true,
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 250.ms)
                .slideY(begin: 0.15, curve: Curves.easeOutCubic),

            const SizedBox(height: 20),

            // Divisor
            Row(
              children: [
                Expanded(
                    child: Divider(color: Colors.grey[200], thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Al continuar aceptas los Términos y Privacidad',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.navyBlue.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Expanded(
                    child: Divider(color: Colors.grey[200], thickness: 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Panel de email / contraseña (premium)
// ══════════════════════════════════════════════════════════════
class _EmailPanel extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController nameCtrl;
  final bool obscurePass;
  final bool isRegister;
  final bool useMagicLink;
  final bool isLoading;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleMode;
  final VoidCallback onToggleMagic;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _EmailPanel({
    super.key,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.nameCtrl,
    required this.obscurePass,
    required this.isRegister,
    required this.useMagicLink,
    required this.isLoading,
    required this.onToggleObscure,
    required this.onToggleMode,
    required this.onToggleMagic,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000B3C).withValues(alpha: 0.4),
            blurRadius: 60,
            offset: const Offset(0, -15),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle + back
            Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.navyBlue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: AppColors.navyBlue),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                // Badge modo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isRegister ? 'Registro' : 'Login',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            Text(
              isRegister ? '¡Únete a Join!' : 'Bienvenido de vuelta',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.navyBlue,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              useMagicLink 
                ? 'Introduce tu email para enviarte un código'
                : (isRegister
                    ? 'Crea tu cuenta y empieza a vivir experiencias'
                    : 'Ingresa para ver qué planes te esperan'),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.navyBlue.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            // Nombre (solo registro con pass)
            if (isRegister && !useMagicLink) ...[
              _PremiumInputField(
                controller: nameCtrl,
                label: 'Nombre completo',
                hint: 'Ej: María García',
                icon: Icons.person_outline_rounded,
                inputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
            ],

            _PremiumInputField(
              controller: emailCtrl,
              label: 'Correo electrónico',
              hint: 'tu@email.com',
              icon: Icons.alternate_email_rounded,
              inputType: TextInputType.emailAddress,
              inputAction: useMagicLink ? TextInputAction.done : TextInputAction.next,
              onFieldSubmitted: useMagicLink ? (_) => onSubmit() : null,
            ),
            
            if (!useMagicLink) ...[
              const SizedBox(height: 14),
              _PremiumInputField(
                controller: passwordCtrl,
                label: 'Contraseña',
                hint: isRegister ? 'Mínimo 6 caracteres' : '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: obscurePass,
                inputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSubmit(),
                suffix: IconButton(
                  icon: Icon(
                    obscurePass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.navyBlue.withValues(alpha: 0.4),
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Botón principal con gradiente
            GestureDetector(
              onTap: isLoading ? null : onSubmit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  gradient: isLoading
                      ? LinearGradient(
                          colors: [
                            AppColors.primaryOrange.withValues(alpha: 0.6),
                            AppColors.lightOrange.withValues(alpha: 0.6),
                          ],
                        )
                      : const LinearGradient(
                          colors: [AppColors.primaryOrange, AppColors.lightOrange],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isLoading
                      ? []
                      : [
                          BoxShadow(
                            color: AppColors.primaryOrange.withValues(alpha: 0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              useMagicLink ? 'Enviar código' : (isRegister ? 'Crear cuenta' : 'Ingresar'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              useMagicLink ? Icons.send_rounded : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: onToggleMagic,
                    child: Text(
                      useMagicLink ? 'Usar contraseña en su lugar' : 'Usar código por email (más seguro)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!useMagicLink)
                    GestureDetector(
                      onTap: onToggleMode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.navyBlue.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.navyBlue.withValues(alpha: 0.6),
                            ),
                            children: [
                              TextSpan(
                                text: isRegister
                                    ? '¿Ya tienes cuenta? '
                                    : '¿No tienes cuenta? ',
                              ),
                              TextSpan(
                                text: isRegister ? 'Inicia sesión' : 'Regístrate gratis',
                                style: const TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Panel de ingreso de código OTP (premium)
// ══════════════════════════════════════════════════════════════
class _OtpPanel extends StatelessWidget {
  final String email;
  final TextEditingController otpCtrl;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onResend;
  final VoidCallback onSubmit;

  const _OtpPanel({
    super.key,
    required this.email,
    required this.otpCtrl,
    required this.isLoading,
    required this.onBack,
    required this.onResend,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000B3C).withValues(alpha: 0.4),
            blurRadius: 60,
            offset: const Offset(0, -15),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.navyBlue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: AppColors.navyBlue),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 40), // Balance back button
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Verifica tu correo',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.navyBlue,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.navyBlue.withValues(alpha: 0.5),
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Hemos enviado un código a '),
                  TextSpan(
                    text: email,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Input de OTP premium
            _PremiumInputField(
              controller: otpCtrl,
              label: 'Código de 6 dígitos',
              hint: '000000',
              icon: Icons.lock_person_rounded,
              inputType: TextInputType.number,
              inputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              // Podríamos añadir formating para que solo acepte 6 núms
            ),
            
            const SizedBox(height: 32),
            
            GestureDetector(
              onTap: isLoading ? null : onSubmit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryOrange, AppColors.lightOrange],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Verificar e ingresar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Center(
              child: TextButton(
                onPressed: isLoading ? null : onResend,
                child: const Text(
                  '¿No recibiste nada? Reenviar código',
                  style: TextStyle(
                    color: AppColors.navyBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

// ══════════════════════════════════════════════════════════════
//  Widgets premium
// ══════════════════════════════════════════════════════════════

class _SocialButton extends StatefulWidget {
  final dynamic icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isMaterial;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.accentColor,
    required this.onTap,
    this.isMaterial = false,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0, _pressed ? 0.97 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.color.withValues(alpha: _pressed ? 0.4 : 0.15),
            width: 1.5,
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: widget.isMaterial
                    ? Icon(widget.icon as IconData, color: widget.color, size: 20)
                    : FaIcon(widget.icon as IconData, color: widget.color, size: 18),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: widget.color.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? inputType;
  final TextInputAction? inputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffix;

  const _PremiumInputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.inputType,
    this.inputAction,
    this.onFieldSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: inputType,
          textInputAction: inputAction,
          onSubmitted: onFieldSubmitted,
          style: const TextStyle(
            color: AppColors.navyBlue,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.navyBlue.withValues(alpha: 0.3),
              fontSize: 14,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryOrange, size: 18),
            ),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.navyBlue.withValues(alpha: 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: AppColors.navyBlue.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: AppColors.navyBlue.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppColors.primaryOrange, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Fondo premium con partículas y blobs
// ══════════════════════════════════════════════════════════════
class _PremiumBackground extends StatelessWidget {
  final AnimationController bgController;
  final AnimationController particleController;
  final Size size;

  const _PremiumBackground({
    required this.bgController,
    required this.particleController,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradiente base profundo
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF020D3A),
                Color(0xFF041249),
                Color(0xFF0D1F6E),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Blob naranja principal
        AnimatedBuilder(
          animation: bgController,
          builder: (_, __) {
            final t = bgController.value;
            return Positioned(
              top: size.height * 0.03 + t * 50,
              right: -100 + t * 40,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.primaryOrange.withValues(alpha: 0.4),
                    AppColors.primaryOrange.withValues(alpha: 0.0),
                  ]),
                ),
              ),
            );
          },
        ),

        // Blob azul claro
        AnimatedBuilder(
          animation: bgController,
          builder: (_, __) {
            final t = bgController.value;
            return Positioned(
              top: size.height * 0.15 - t * 40,
              left: -80 + t * 30,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.skyBlue.withValues(alpha: 0.25),
                    AppColors.skyBlue.withValues(alpha: 0.0),
                  ]),
                ),
              ),
            );
          },
        ),

        // Blob turquesa inferior
        AnimatedBuilder(
          animation: bgController,
          builder: (_, __) {
            final t = bgController.value;
            return Positioned(
              bottom: size.height * 0.2 + t * 30,
              left: size.width * 0.2 - t * 20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.turquoise.withValues(alpha: 0.15),
                    AppColors.turquoise.withValues(alpha: 0.0),
                  ]),
                ),
              ),
            );
          },
        ),

        // Partículas flotantes
        AnimatedBuilder(
          animation: particleController,
          builder: (_, __) {
            return CustomPaint(
              size: size,
              painter: _ParticlePainter(
                progress: particleController.value,
              ),
            );
          },
        ),
      ],
    );
  }
}

// Pintor de partículas
class _ParticlePainter extends CustomPainter {
  final double progress;

  _ParticlePainter({required this.progress});

  static final _rand = math.Random(42);
  static final _particles = List.generate(18, (i) {
    return {
      'x': _rand.nextDouble(),
      'y': _rand.nextDouble(),
      'r': 1.5 + _rand.nextDouble() * 3,
      'speed': 0.3 + _rand.nextDouble() * 0.7,
      'phase': _rand.nextDouble(),
    };
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final phase = (p['phase'] as double);
      final speed = (p['speed'] as double);
      final yOffset = ((progress * speed + phase) % 1.0);
      final x = (p['x'] as double) * size.width;
      final y = (1.0 - yOffset) * size.height;
      final r = p['r'] as double;
      final alpha = (math.sin(yOffset * math.pi) * 0.6).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

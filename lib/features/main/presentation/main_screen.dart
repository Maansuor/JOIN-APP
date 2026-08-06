import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:join_app/features/home/presentation/home_screen.dart';
import 'package:join_app/features/profile/presentation/profile_screen.dart';
import 'package:join_app/features/main/presentation/my_activities_screen.dart';
import 'package:join_app/features/main/presentation/chats_screen.dart';
import 'package:join_app/features/main/presentation/widgets/mascot_tour.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';

/// Pantalla principal con navegación inferior y FAB flotante
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Iniciar la verificación de discrepancia de ubicación al arrancar la pantalla principal
      context.read<AppState>().checkLocationAndDetectDiscrepancy();

      // Minitutorial de bienvenida guiado por la mascota (solo la primera vez)
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        final user = context.read<AppState>().currentUser;
        if (user != null) {
          MascotTour.maybeShow(
            context,
            mascotName: user.companionName,
            mascotAsset: user.companionAsset,
          );
        }
      });
    });
  }

  List<Widget> _screens(BuildContext context) {
    return [
      const HomeScreen(),
      const ChatsScreen(), // Página de chats funcional
      const MyActivitiesScreen(), // Actividades creadas por el usuario
      const ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showAddActivityDialog() {
    // Navegar al formulario de creación de actividad
    context.push('/main/create');
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios de ciudad
    final appState = context.watch<AppState>();

    // Si detectamos una discrepancia en tiempo real entre la ciudad guardada y la actual física
    if (appState.hasLocationDiscrepancy && !_isDialogShowing) {
      _isDialogShowing = true;
      final markedCity = appState.currentCity ?? 'Desconocida';
      final actualCity = appState.discrepancyCity!;
      final newPos = appState.discrepancyPosition!;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLocationDiscrepancyDialog(markedCity, actualCity, newPos);
      });
    }

    return Scaffold(
      extendBody: true, // Permite que el contenido siga detrás de la barra redondeada (como mapas/listas)
      body: Stack(
        children: [
          _screens(context)[_selectedIndex],
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  /// Diálogo de alerta premium para discrepancia de ubicación
  void _showLocationDiscrepancyDialog(
    String markedCity,
    String actualCity,
    Position newPosition,
  ) {
    final appState = context.read<AppState>();
    
    showDialog(
      context: context,
      barrierDismissible: false, // Forzar a elegir una opción para una mejor UX
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 10,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono elegante superior
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFD7C36).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: Color(0xFFFD7C36),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Título
                Text(
                  '¿Cambiaste de aire? ✈️',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Contenido explicativo
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14.5,
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF4A5568),
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'Parece que estás en '),
                      TextSpan(
                        text: actualCity,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFD7C36),
                        ),
                      ),
                      const TextSpan(text: ', pero tu aplicación actualmente marca '),
                      TextSpan(
                        text: markedCity,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF818CF8) : const Color(0xFF041249),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Actualiza tu ubicación para descubrir increíbles planes y personas en tu zona actual.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF718096),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Botón Primario: Actualizar
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFD9D2E), Color(0xFFFD7C36)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFD7C36).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        // El messenger se toma antes de cerrar el diálogo: al
                        // volver del await este context ya no está montado.
                        final messenger = ScaffoldMessenger.of(context);
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                        setState(() {
                          _isDialogShowing = false;
                        });
                        await appState.updateSelectedCity(actualCity, newPosition);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '¡Ubicación actualizada a $actualCity! 🌟',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          ),
                        );
                      },
                      customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: const Center(
                        child: Text(
                          'SÍ, ACTUALIZAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Botón Secundario: Mantener anterior
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                    setState(() {
                      _isDialogShowing = false;
                    });
                    appState.clearDiscrepancy();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'MANTENER $markedCity'.toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : Colors.grey[600],
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isDialogShowing = false;
        });
      }
    });
  }

  /// Construir barra de navegación inferior mejorada ultra premium
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF041249).withValues(alpha: 0.08),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.widgets_outlined,
                activeIcon: Icons.widgets_rounded,
                label: 'Inicio',
                selected: _selectedIndex == 0,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.forum_outlined,
                activeIcon: Icons.forum_rounded,
                label: 'Mensajes',
                selected: _selectedIndex == 1,
              ),
              const SizedBox(width: 64), // Espacio ancho perfecto para el FAB en el centro
              _buildNavItem(
                index: 2,
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today_rounded,
                label: 'Mis Planes',
                selected: _selectedIndex == 2,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Perfil',
                selected: _selectedIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construir item de navegación premium — cápsula con gradiente al activarse
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool selected,
  }) {
    const activeGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFD7C36), Color(0xFFFF2D55)],
    );
    final inactiveColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF64748B)
        : Colors.grey[400]!;

    Widget iconWidget = Icon(
      selected ? activeIcon : icon,
      color: selected ? Colors.white : inactiveColor,
      size: 22,
    );
    if (selected) {
      // Respiración suave y lenta del ícono activo
      iconWidget = iconWidget
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.08, 1.08),
            duration: 2200.ms,
            curve: Curves.easeInOut,
          );
    }

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cápsula del ícono: se expande con gradiente al activarse.
            // Curva sin rebote: easeOutBack sobrepasaba el valor final al
            // encogerse y causaba un glitch visual en la cápsula anterior.
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 18 : 4,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                gradient: selected ? activeGradient : null,
                borderRadius: BorderRadius.circular(20),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF2D55).withValues(alpha: 0.32),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              child: iconWidget,
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? const Color(0xFFFE4D43) : inactiveColor,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  /// Construir botón FAB flotante personalizado super premium
  Widget _buildFloatingActionButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 28), // Empujar ligeramente hacia abajo en el dock para más integración
      child: Container(
        height: 60, // Tamaño balanceado
        width: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFD7C36), Color(0xFFFF2D55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showAddActivityDialog,
            customBorder: const CircleBorder(),
            highlightColor: Colors.white.withValues(alpha: 0.2),
            splashColor: Colors.white.withValues(alpha: 0.3),
            child: const Center(
              child: Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla placeholder para futuras implementaciones
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Próximamente disponible',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

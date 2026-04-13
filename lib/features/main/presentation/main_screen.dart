import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:join_app/features/home/presentation/home_screen.dart';
import 'package:join_app/features/profile/presentation/profile_screen.dart';
import 'package:join_app/features/main/presentation/my_activities_screen.dart';
import 'package:join_app/features/main/presentation/chats_screen.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/features/main/presentation/kamil_mascot_widget.dart';

/// Pantalla principal con navegación inferior y FAB flotante
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? _lastNotifiedCity;

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

    // Si detectamos una ciudad nueva distinta a la anterior
    if (appState.currentCity != null &&
        appState.currentCity != _lastNotifiedCity) {
      if (_lastNotifiedCity != null) {
        // Ejecutar después del frame para evitar errores de BuildContext
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCityChangeModal(appState.currentCity!);
        });
      }
      _lastNotifiedCity = appState.currentCity;
    }

    return Scaffold(
      extendBody: true, // Permite que el contenido siga detrás de la barra redondeada (como mapas/listas)
      body: Stack(
        children: [
          _screens(context)[_selectedIndex],
          const KamilMascotWidget(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  void _showCityChangeModal(String cityName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¿Cambiaste de aire? Parece que estás en $cityName. ¿Actualizar ubicación?',
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'SÍ, ACTUALIZAR',
          textColor: Colors.white,
          onPressed: () {
            // Aquí puedes lanzar una actualización del perfil con la nueva ciudad
            debugPrint('Usuario aceptó actualizar a $cityName');
          },
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin:
            const EdgeInsets.fromLTRB(16, 0, 16, 80), // Encima de la nav bar
        duration: const Duration(seconds: 6),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  /// Construir barra de navegación inferior mejorada ultra premium
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF041249).withValues(alpha: 0.08),
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
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Inicio',
                selected: _selectedIndex == 0,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Mensajes',
                selected: _selectedIndex == 1,
              ),
              const SizedBox(width: 64), // Espacio ancho perfecto para el FAB en el centro
              _buildNavItem(
                index: 2,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
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

  /// Construir item de navegación mejorado con iconos outline/filled y cápsula
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 76, // Fijar ancho para evitar saltos y organizar el layout
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFF0E6) // Naranja pastel elegante de fondo exclusivo del ítem activo
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(
                selected ? activeIcon : icon,
                color: selected
                    ? const Color(0xFFFD7C36)
                    : Colors.grey[400],
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? const Color(0xFFFD7C36)
                    : Colors.grey[400],
              ),
              child: Text(label),
            ),
            // Punto indicador sutil animado
            AnimatedOpacity(
              opacity: selected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFFFD7C36),
                  shape: BoxShape.circle,
                ),
              ),
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
            colors: [Color(0xFFFD9D2E), Color(0xFFFD7C36)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          // quitamos el brillo exterior grande
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
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

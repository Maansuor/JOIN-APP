import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:join_app/features/notifications/presentation/notifications_screen.dart';
import 'package:join_app/core/services/notification_service.dart';
import 'package:join_app/core/services/weather_service.dart';
import 'package:join_app/features/activity/presentation/widgets/activity_card.dart';
import 'package:join_app/features/home/presentation/widgets/dynamic_sky_banner.dart';
import 'package:join_app/core/models/interest_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Configuración visual del banner de bienvenida según hora/estación
class _BannerVibe {
  final List<Color> gradient;
  final IconData badgeIcon;
  final String badgeLabel;
  final String timeShort;
  final Color badgeColor;

  const _BannerVibe({
    required this.gradient,
    required this.badgeIcon,
    required this.badgeLabel,
    required this.timeShort,
    required this.badgeColor,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'Para ti';
  bool _showHennessyTooltip = false;
  WeatherKind? _weather;
  bool _weatherFetchStarted = false;

  final List<String> categories = CategoryConstants.all;
  final Map<String, IconData> categoryIcons = CategoryConstants.icons;
  final Map<String, Color> categoryColors = CategoryConstants.colors;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.fetchNotifications();
    });

    // Mostrar globo de saludo de Hennessy tras 1.8 segundos
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _showHennessyTooltip = true);
        // Ocultar globo automáticamente después de 7 segundos
        Future.delayed(const Duration(seconds: 7), () {
          if (mounted) {
            setState(() => _showHennessyTooltip = false);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentUser = appState.currentUser;
    final currentUserName = currentUser?.name ?? 'Usuario';
    final gpsCity = appState.actualCity;
    final userLocation = appState.currentCity;
    final rawDisplayCity = (userLocation != null && userLocation.isNotEmpty)
        ? userLocation
        : ((gpsCity != null && gpsCity.isNotEmpty) ? gpsCity : 'Chiclayo');

    String displayCity = rawDisplayCity;
    final cityParts = rawDisplayCity.split(',');
    if (cityParts.length > 1) {
      final district = cityParts[0].trim();
      final province = cityParts[1].trim();
      if (district.length > 12) {
        displayCity = '${district.substring(0, 10)}..., $province';
      }
    }

    final hasInterests = (currentUser?.interests ?? []).isNotEmpty;
    final vibe = _getBannerVibe();

    // Clima real de la ciudad (una sola consulta, caché de 15 min)
    final pos = appState.currentPosition ?? appState.actualPosition;
    if (!_weatherFetchStarted && pos != null) {
      _weatherFetchStarted = true;
      WeatherService.fetch(pos.latitude, pos.longitude).then((kind) {
        if (mounted) setState(() => _weather = kind);
      });
    }
    final weather = _weather ?? WeatherKind.clear;

    // Cápsula del banner: condición climática + momento del día
    final (IconData badgeIcon, String badgeLabel, Color badgeColor) =
        switch (weather) {
      WeatherKind.clear => (vibe.badgeIcon, vibe.badgeLabel, vibe.badgeColor),
      WeatherKind.clouds => (
          Icons.cloud_rounded,
          'Nublado · ${vibe.timeShort}',
          const Color(0xFFCBD5E1)
        ),
      WeatherKind.rain => (
          Icons.water_drop_rounded,
          'Lluvia · ${vibe.timeShort}',
          const Color(0xFF9CC8FF)
        ),
      WeatherKind.snow => (
          Icons.ac_unit_rounded,
          'Nieve · ${vibe.timeShort}',
          const Color(0xFFD7ECFF)
        ),
      WeatherKind.wind => (
          Icons.air_rounded,
          'Ventoso · ${vibe.timeShort}',
          const Color(0xFFA7E8D0)
        ),
    };

    // En la cápsula de ubicación solo va el distrito (sin truncar feo);
    // la provincia completa aparece en el subtítulo del banner.
    final pillCity = rawDisplayCity.split(',').first.trim();

    // Categoría efectiva: Si seleccionó 'Para ti' pero no tiene intereses, usar 'Todos'
    final effectiveCategory = (selectedCategory == 'Para ti' && !hasInterests) 
        ? 'Todos' 
        : selectedCategory;

    // Categorías en la barra superior
    final dynamicCategories = [
      if (hasInterests) 'Para ti',
      'Todos',
      ...categories,
    ];

    // Filtrar actividades usando la categoría efectiva y mapeo inteligente
    final allActivities = appState.activities;
    final filteredActivities = effectiveCategory == 'Para ti'
        ? allActivities.where((a) {
            final userInterests = currentUser?.interests ?? [];
            if (userInterests.isEmpty) return false;
            
            // 1. Mapear intereses del usuario a categorías expandidas
            final expandedCategories = InterestMapper.getCategoriesForInterests(userInterests);
            
            // 2. Coincidencia por categoría de la actividad
            final activityCats = a.category.split(',').map((c) => c.trim()).toSet();
            final matchesCategory = activityCats.any((cat) => 
                expandedCategories.any((ec) => ec.toLowerCase() == cat.toLowerCase())
            );
            if (matchesCategory) return true;
            
            // 3. Coincidencia exacta por etiquetas (tags) — solo palabras completas
            final matchesTag = a.tags.any((tag) => 
                userInterests.any((interest) => interest.toLowerCase() == tag.toLowerCase()) ||
                expandedCategories.any((ec) => ec.toLowerCase() == tag.toLowerCase())
            );
            return matchesTag;
          }).toList()
        : effectiveCategory == 'Todos'
            ? allActivities
            : allActivities.where((a) {
                final activityCats = a.category.split(',').map((c) => c.trim().toLowerCase()).toList();
                final mainCategories = ['Deportes', 'Comida', 'Naturaleza', 'Chill', 'Juntas', 'Arte', 'Música', 'Otro'];
                if (mainCategories.contains(effectiveCategory)) {
                  return activityCats.contains(effectiveCategory.toLowerCase());
                }
                final relatedCategories = InterestMapper.getCategoriesForInterests([effectiveCategory]);
                return relatedCategories.any((cat) => activityCats.contains(cat.toLowerCase()));
              }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => appState.loadActivities(force: true),
              color: AppColors.primaryOrange,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
            // ── AppBar personalizado ─────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              centerTitle: false,
              title: Row(
                children: [
                  Image.asset('assets/images/join.png', height: 32, width: 32),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.primaryOrange, Color(0xFFFF2D55)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      'Join',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 32,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                Builder(
                  builder: (context) {
                    final Color color = selectedCategory == 'Para ti'
                        ? AppColors.primaryOrange
                        : selectedCategory == 'Todos'
                            ? AppColors.deepBlue
                            : (categoryColors[selectedCategory] ?? AppColors.primaryOrange);
                    return _buildHennessyButton(context, color);
                  }
                ),
                const SizedBox(width: 8),
                _buildNotificationIcon(context),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryOrange,
                          Color(0xFFFF2D55),
                          Color(0xFFE040FB),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      child: CircleAvatar(
                        radius: 16,
                      backgroundColor: Colors.transparent,
                      backgroundImage: currentUser != null && currentUser.hasProfileImage
                          ? (currentUser.fullProfileImageUrl.isNotEmpty == true
                              ? NetworkImage(currentUser.fullProfileImageUrl) as ImageProvider
                              : null)
                          : null,
                      child: currentUser != null && !currentUser.hasProfileImage
                          ? Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [AppColors.primaryOrange, Color(0xFFE040FB)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                currentUserName.isNotEmpty
                                    ? currentUserName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ── Hero Banner Saludo ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: vibe.gradient.first.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: DynamicSkyBanner(
                          time: skyTimeNow(),
                          season: skySeasonNow(),
                          weather: weather,
                          child: Padding(
                              padding: const EdgeInsets.all(26),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Frosted glass location capsule pointing to marked city
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.22),
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.2),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFFD7C36)),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  pillCity,
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Cápsula de clima + momento del día
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.22),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: badgeColor.withValues(alpha: 0.35),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(badgeIcon, color: badgeColor, size: 14)
                                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                                .fade(begin: 0.65, end: 1, duration: 1800.ms),
                                            const SizedBox(width: 5),
                                            Text(
                                              badgeLabel,
                                              style: TextStyle(
                                                color: badgeColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '¡Hola, ',
                                          style: TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w200,
                                            color: Colors.white.withValues(alpha: 0.85),
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '${currentUserName.split(' ').first}!',
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: Padding(
                                            padding: const EdgeInsets.only(left: 10),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFB300).withValues(alpha: 0.16),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.waving_hand_rounded,
                                                color: Color(0xFFFFC94D),
                                                size: 20,
                                              ),
                                            )
                                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                                .rotate(
                                                  begin: -0.04,
                                                  end: 0.06,
                                                  duration: 1300.ms,
                                                  curve: Curves.easeInOut,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFD7C36).withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.explore_rounded,
                                          size: 15,
                                          color: Color(0xFFFD7C36),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Encuentra ',
                                                style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14.5),
                                              ),
                                              TextSpan(
                                                text: '${allActivities.length} increíbles planes ',
                                                style: const TextStyle(
                                                  color: Color(0xFFFFB800),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14.5,
                                                ),
                                              ),
                                               TextSpan(
                                                  text: 'en $displayCity.',
                                                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14.5),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ),
                      ),
                    ),
                    if (!hasInterests) ...[
                      const SizedBox(height: 12),
                      _buildInterestsBanner(context),
                    ],
                  ],
                ),
              ),
            ),

            // ── Filtros de categorías ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  // Padding vertical interno: evita que el chip activo
                  // (escalado + sombra) se recorte arriba/abajo
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: dynamicCategories.map((category) {
                      final isSelected = selectedCategory == category;
                      final color =
                          categoryColors[category] ?? AppColors.primaryOrange;

                      return Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => selectedCategory = category);
                          },
                          child: AnimatedScale(
                            scale: isSelected ? 1.04 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        color,
                                        Color.lerp(color, Colors.black, 0.18)!,
                                      ],
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : (Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2E323F)
                                        : Colors.grey.shade200),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Mini cápsula del ícono
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.22)
                                        : color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    categoryIcons[category] ??
                                        Icons.category_rounded,
                                    size: 14,
                                    color: isSelected
                                        ? Colors.white
                                        : color,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    letterSpacing: 0.1,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : (Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF475569)),
                                  ),
                                ),
                                // Badge de "Para ti"
                                if (category == 'Para ti' && hasInterests)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                              .withValues(alpha: 0.25)
                                          : color.withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${allActivities.where((a) { final uc = currentUser?.interests ?? []; if (uc.isEmpty) return false; final ec = InterestMapper.getCategoriesForInterests(uc); final ac = a.category.split(',').map((c) => c.trim()).toSet(); return ac.any((cat) => ec.any((e) => e.toLowerCase() == cat.toLowerCase())) || a.tags.any((tag) => uc.any((i) => i.toLowerCase() == tag.toLowerCase()) || ec.any((e) => e.toLowerCase() == tag.toLowerCase())); }).length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : color,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // ── Lista de actividades ─────────────────────────────
            appState.isLoading && filteredActivities.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 120),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                  )
                : filteredActivities.isEmpty
                    ? SliverToBoxAdapter(
                        child: _buildEmptyState(selectedCategory, hasInterests),
                      )
                : SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final activity = filteredActivities[index];
                          final isOrganizer =
                              appState.isActivityOrganizer(activity.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ActivityCard(
                              activity: activity,
                              isOrganizer: isOrganizer,
                              onTap: () => context
                                  .push('/main/activity/${activity.id}'),
                            ),
                          );
                        },
                        childCount: filteredActivities.length,
                      ),
                    ),
                  ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
        if (_showHennessyTooltip)
          Builder(
            builder: (context) {
              final Color color = selectedCategory == 'Para ti'
                  ? AppColors.primaryOrange
                  : selectedCategory == 'Todos'
                      ? AppColors.deepBlue
                      : (categoryColors[selectedCategory] ?? AppColors.primaryOrange);
              return _buildFloatingHennessyTooltip(color);
            },
          ),
      ],
    ),
  ),
);
  }

  Widget _buildInterestsBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryOrange.withValues(alpha: 0.1),
            AppColors.primaryOrange.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primaryOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.primaryOrange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Completa tus intereses para ver actividades recomendadas',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/main/profile/edit'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Completar',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String category, bool hasInterests) {
    final isParaTi = category == 'Para ti' && hasInterests;
    final icon =
        isParaTi ? Icons.explore_off_rounded : Icons.travel_explore_rounded;
    final title = isParaTi
        ? 'Sin actividades para ti'
        : category == 'Todos'
            ? 'Aún no hay planes por aquí'
            : 'Sin actividades en "$category"';
    final subtitle = isParaTi
        ? 'Aún no hay planes que coincidan con tus intereses. Explora todas las actividades o crea la tuya.'
        : category == 'Todos'
            ? 'Tu ciudad espera su primer plan épico. ¡Anímate a crearlo tú!'
            : 'No hay planes en esta categoría por ahora. Mira las demás o crea el primero.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 32),
      child: Column(
        children: [
          // Ícono con halo brillante
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryOrange.withValues(alpha: 0.14),
                  AppColors.primaryOrange.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryOrange.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, size: 32, color: AppColors.primaryOrange),
              ),
            ),
          )
              .animate()
              .scale(duration: 600.ms, curve: Curves.easeOutBack)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -5, duration: 2400.ms, curve: Curves.easeInOut),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Theme.of(context).colorScheme.onSurface),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.15),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF94A3B8)
                    : Colors.grey[500]),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 20),
          // CTA principal — gradiente premium
          if (category != 'Todos')
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => selectedCategory = 'Todos');
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryOrange, Color(0xFFFF2D55)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.travel_explore_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Ver todas las actividades',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.2),
          const SizedBox(height: 14),
          // CTA secundario — crear plan
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/main/create');
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: AppColors.primaryOrange, size: 17),
                  SizedBox(width: 7),
                  Text(
                    'Crear mi propio plan',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.unreadCount,
      builder: (context, unreadCount, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E222B)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2E323F)
                      : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.notifications_none_rounded, size: 22),
                color: Theme.of(context).colorScheme.onSurface,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ).then((_) {
                    // Actualizar badge al volver por si leyó alguna
                    NotificationService.unreadCount.value = NotificationService.getUnreadCount();
                  });
                },
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF0A0D14)
                          : Colors.white,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHennessyButton(BuildContext context, Color color) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _showHennessyTooltip = false);
        context.push('/main/hennessy');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              color,
              color.withValues(alpha: 0.3),
              color,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 1.5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF161920)
                : Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: SizedBox(
              width: 32,
              height: 32,
              child: Image.asset(
                context.watch<AppState>().currentUser?.companionAsset ??
                    'assets/images/mascota/ELI.png',
                fit: BoxFit.contain,
                cacheWidth: 96,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ambiente visual del banner según la hora del día y la estación
  /// del año (hemisferio sur — Perú).
  _BannerVibe _getBannerVibe() {
    final now = DateTime.now();
    final hour = now.hour;

    // Estación del año (hemisferio sur)
    final String season;
    switch (now.month) {
      case 12 || 1 || 2:
        season = 'verano';
      case 3 || 4 || 5:
        season = 'otoño';
      case 6 || 7 || 8:
        season = 'invierno';
      default:
        season = 'primavera';
    }

    if (hour >= 5 && hour < 12) {
      // Amanecer — azul celeste con destellos dorados
      return _BannerVibe(
        gradient: const [Color(0xFF052236), Color(0xFF0B3B5C), Color(0xFF11587E)],
        badgeIcon: Icons.wb_twilight_rounded,
        badgeLabel: 'Mañana de $season',
        timeShort: 'mañana',
        badgeColor: const Color(0xFFFFD54F),
      );
    } else if (hour >= 12 && hour < 18) {
      // Atardecer — índigo hacia magenta cálido
      return _BannerVibe(
        gradient: const [Color(0xFF1B0E3D), Color(0xFF3D1460), Color(0xFF6E2557)],
        badgeIcon: Icons.wb_sunny_rounded,
        badgeLabel: 'Tarde de $season',
        timeShort: 'tarde',
        badgeColor: const Color(0xFFFFC069),
      );
    }
    // Noche — azul medianoche profundo
    return _BannerVibe(
      gradient: const [Color(0xFF020B30), Color(0xFF071448), Color(0xFF0D1E60)],
      badgeIcon: Icons.nights_stay_rounded,
      badgeLabel: 'Noche de $season',
      timeShort: 'noche',
      badgeColor: const Color(0xFF93C5FD),
    );
  }

  String _getRandomHennessyGreeting() {
    final hour = DateTime.now().hour;
    final List<String> greetings;
    
    if (hour >= 5 && hour < 12) {
      greetings = [
        '🦎 ¡Buenos días! ¿Listo para un plan épico hoy? Toca aquí y hablemos 💬',
        '☀️ ¡Arriba, explorador! Tengo ideas frescas para tu mañana 🦎✨',
        '🐾 ¡Hey! El día recién empieza y ya tengo planes para ti 💬🚀',
      ];
    } else if (hour >= 12 && hour < 18) {
      greetings = [
        '🦎 ¡Buenas tardes! ¿Buscas algo qué hacer? ¡Pregúntame! 💬✨',
        '🐾 ¡La tarde está perfecta para un plan! Toca aquí y armemos algo 🚀',
        '💬 ¡Hey! Tengo recomendaciones increíbles para esta tarde 🦎🎉',
      ];
    } else {
      greetings = [
        '🦎 ¡Buenas noches! ¿Plan nocturno? Toca aquí y te ayudo 💬🌙',
        '🐾 ¡La noche es joven! Descubre planes épicos conmigo 🦎✨',
        '💬 ¿Noche libre? ¡Tengo ideas geniales para ti! Toca aquí 🚀🌃',
      ];
    }
    
    final index = (DateTime.now().second + DateTime.now().minute) % greetings.length;
    return greetings[index];
  }

  Widget _buildFloatingHennessyTooltip(Color activeColor) {
    final companionName = context.read<AppState>().currentUser?.companionName ?? 'Eli';
    final tooltipText = _getRandomHennessyGreeting();
    return Positioned(
      top: 60,
      right: 120, // Perfectly aligned so the tail points to the mascot
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutBack,
        builder: (context, value, _) {
          return Transform.scale(
            scale: value,
            alignment: Alignment.topRight,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _showHennessyTooltip = false);
                  context.push('/main/hennessy');
                },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Speech bubble tail pointing up-right towards the Hennessy icon
                      Positioned(
                        top: -5,
                        right: 20, // Center of Mascot button relative to right: 120
                        child: RotationTransition(
                          turns: const AlwaysStoppedAnimation(45 / 360),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF161920)
                                  : Colors.white,
                              border: Border(
                                left: BorderSide(color: activeColor.withValues(alpha: 0.15), width: 1),
                                top: BorderSide(color: activeColor.withValues(alpha: 0.15), width: 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Main card with glassmorphism esmerilado
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF161920).withValues(alpha: 0.92)
                                  : Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: activeColor.withValues(alpha: 0.18),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Mascot avatar with dynamic active green dot
                                Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: activeColor.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.forum_rounded,
                                        color: activeColor,
                                        size: 16,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFF161920)
                                                : Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            companionName,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'ACTIVO',
                                              style: TextStyle(
                                                color: Color(0xFF4CAF50),
                                                fontSize: 7.5,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tooltipText,
                                        style: TextStyle(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFFE2E8F0)
                                              : const Color(0xFF344054),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Close button
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _showHennessyTooltip = false);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Color(0xFF98A2B3),
                                      size: 12,
                                    ),
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
              ),
            ),
          );
        },
      ),
    );
  }
}

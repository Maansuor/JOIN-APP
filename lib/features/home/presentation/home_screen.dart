import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:join_app/features/notifications/presentation/notifications_screen.dart';
import 'package:join_app/core/services/notification_service.dart';
import 'package:join_app/features/activity/presentation/widgets/activity_card.dart';
import 'package:join_app/core/models/interest_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'Para ti';

  final List<String> categories = CategoryConstants.all;
  final Map<String, IconData> categoryIcons = CategoryConstants.icons;
  final Map<String, Color> categoryColors = CategoryConstants.colors;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentUser = appState.currentUser;
    final currentUserName = currentUser?.name ?? 'Usuario';
    final userLocation = appState.currentCity;

    final userCategories = InterestMapper.getCategoriesForInterests(currentUser?.interests ?? []);
    final hasInterests = (currentUser?.interests ?? []).isNotEmpty;

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
            final activityCat = a.category.trim().toLowerCase();
            return userCategories.any((uCat) => uCat.toLowerCase() == activityCat);
          }).toList()
        : effectiveCategory == 'Todos'
            ? allActivities
            : allActivities.where((a) => a.category.trim().toLowerCase() == effectiveCategory.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── AppBar personalizado ─────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: Row(
                children: [
                  Image.asset('assets/images/join.png', height: 32, width: 32),
                  const SizedBox(width: 8),
                  const Text(
                    'Join',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
              actions: [
                _buildNotificationIcon(context),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppColors.primaryOrange.withValues(alpha: 0.1),
                    backgroundImage: currentUser?.isAssetImage == true
                        ? AssetImage(currentUser!.profileImageUrl)
                        : (currentUser?.fullProfileImageUrl.isNotEmpty == true
                            ? NetworkImage(currentUser!.fullProfileImageUrl)
                                as ImageProvider
                            : null),
                    child: currentUser != null &&
                            !currentUser.hasProfileImage &&
                            !currentUser.isAssetImage
                        ? Text(
                            currentUserName.isNotEmpty
                                ? currentUserName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryOrange,
                            ),
                          )
                        : null,
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
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF041249),
                            const Color(0xFF0D1F6E),
                            AppColors.deepBlue.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF041249).withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      userLocation ?? 'Calculando...',
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFFD54F), size: 24),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '¡Hola, ${currentUserName.split(' ').first}! 👋',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.95),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Encuentra ${filteredActivities.length} increíbles planes en tu zona.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: dynamicCategories.map((category) {
                      final isSelected = selectedCategory == category;
                      final color =
                          categoryColors[category] ?? AppColors.primaryOrange;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => selectedCategory = category),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? color : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : Colors.grey.shade200,
                                width: isSelected ? 0 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  categoryIcons[category] ??
                                      Icons.category_rounded,
                                  size: 15,
                                  color: isSelected
                                      ? Colors.white
                                      : color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : color,
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
                                      '${allActivities.where((a) => userCategories.any((uCat) => uCat.toLowerCase() == a.category.trim().toLowerCase())).length}',
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
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // ── Lista de actividades ─────────────────────────────
            filteredActivities.isEmpty
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
          const Expanded(
            child: Text(
              'Completa tus intereses para ver actividades recomendadas',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF041249),
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
    if (category == 'Para ti' && hasInterests) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        child: Column(
          children: [
            Icon(Icons.explore_off_rounded,
                size: 70, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Sin actividades para ti',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF041249)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No hay actividades disponibles que coincidan con tus intereses por el momento.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => setState(() => selectedCategory = 'Todos'),
              icon: const Icon(Icons.category_rounded, size: 16),
              label: const Text('Ver todas las actividades'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                side: const BorderSide(color: AppColors.primaryOrange),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Sin actividades en "$category"',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF041249)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'No hay actividades disponibles en esta categoría.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.unreadCount,
      builder: (context, unreadCount, child) {
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              color: Colors.grey[700],
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ).then((_) {
                // Actualizar badge al volver por si leyó alguna
                NotificationService.unreadCount.value = NotificationService.getUnreadCount();
              }),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

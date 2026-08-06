import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:join_app/core/models/clan_model.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/services/encryption_service.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pantalla de Chats Premium
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerController;
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _headerController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final chatActivities = appState.activities
        .where((activity) => appState.canAccessChat(activity.id))
        .where((a) =>
            _searchQuery.isEmpty ||
            a.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    // Clanes del usuario — acceso rápido a sus chats privados
    final clans = appState.userClans
        .where((c) =>
            _searchQuery.isEmpty ||
            c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    final totalChats = chatActivities.length + clans.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar premium con gradiente ──────────────────────
          SliverAppBar(
            expandedHeight: 95,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCollapsed = constraints.maxHeight <= kToolbarHeight + 10;
                    return FlexibleSpaceBar(
                      background: _buildHeader(),
                      titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      title: AnimatedOpacity(
                        opacity: isCollapsed ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.primaryOrange, Color(0xFFFF2D55)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            'Mensajes',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppColors.navyBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.12)
                                : AppColors.navyBlue.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              _showSearch ? Icons.close : Icons.search_rounded,
                              key: ValueKey(_showSearch),
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : AppColors.navyBlue,
                              size: 20,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _showSearch = !_showSearch;
                              if (!_showSearch) {
                                _searchQuery = '';
                                _searchCtrl.clear();
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Barra de búsqueda animada ─────────────────────────
          if (_showSearch)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar en chats...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF94A3B8)
                          : AppColors.navyBlue.withValues(alpha: 0.4),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryOrange,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E222B)
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),
            ),

          // ── Contador de chats activos ─────────────────────────
          if (totalChats > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '$totalChats chat${totalChats == 1 ? '' : 's'} activo${totalChats == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$totalChats',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Sección: Clanes ───────────────────────────────────
          if (clans.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionLabel(
                  context, Icons.shield_rounded, 'Tus Clanes', clans.length),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ClanChatCard(
                    clan: clans[index],
                    index: index,
                    onTap: () => context.push(
                        '/clan/${clans[index].id}/chat',
                        extra: clans[index]),
                  ),
                  childCount: clans.length,
                ),
              ),
            ),
          ],

          // ── Sección: Planes / actividades ─────────────────────
          if (chatActivities.isNotEmpty && clans.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildSectionLabel(context, Icons.event_rounded,
                  'Tus Planes', chatActivities.length),
            ),

          // ── Contenido ─────────────────────────────────────────
          totalChats == 0
              ? SliverFillRemaining(
                  child: _buildEmptyState(context),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final activity = chatActivities[index];
                        final isOrganizer =
                            appState.isActivityOrganizer(activity.id);
                        return _PremiumChatCard(
                          activity: activity,
                          isOrganizer: isOrganizer,
                          index: index,
                          onTap: () => context.push(
                              '/main/activity/${activity.id}/group'),
                        );
                      },
                      childCount: chatActivities.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(
      BuildContext context, IconData icon, String label, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primaryOrange),
          const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerController,
      builder: (context, _) {
        final t = _headerController.value;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF161920).withValues(alpha: 0.82)
                : Colors.white.withValues(alpha: 0.82),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.04),
                width: 1,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Orbe decorativo muy suave y elegante en la esquina
              Positioned(
                right: -20 + t * 15,
                top: -20 + t * 10,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryOrange.withValues(alpha: 0.15),
                        AppColors.primaryOrange.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Contenido
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 80, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryOrange, Color(0xFFFF2D55)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.chat_bubble_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [AppColors.primaryOrange, Color(0xFFFF2D55)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              'Mensajes',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Conversaciones de tus actividades',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF94A3B8)
                              : AppColors.navyBlue.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryOrange.withValues(alpha: 0.15),
                  AppColors.lightOrange.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryOrange.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 46,
              color: AppColors.primaryOrange,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 2000.ms,
                  curve: Curves.easeInOut),
          const SizedBox(height: 28),
          Text(
            'Sin chats por ahora',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Únete a una actividad para\nchatear con el grupo',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF94A3B8)
                  : AppColors.navyBlue.withValues(alpha: 0.5),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => context.go('/main'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryOrange, AppColors.lightOrange],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Explorar Actividades',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Card de chat premium
// ══════════════════════════════════════════════════════════════
class _PremiumChatCard extends StatefulWidget {
  final Activity activity;
  final bool isOrganizer;
  final int index;
  final VoidCallback onTap;

  const _PremiumChatCard({
    required this.activity,
    required this.isOrganizer,
    required this.index,
    required this.onTap,
  });

  @override
  State<_PremiumChatCard> createState() => _PremiumChatCardState();
}

class _PremiumChatCardState extends State<_PremiumChatCard> {
  bool _pressed = false;

  Color get _categoryColor {
    switch (widget.activity.category) {
      case 'Deportes':
        return const Color(0xFFE53935);
      case 'Comida':
        return const Color(0xFFFFA726);
      case 'Naturaleza':
        return const Color(0xFF43A047);
      case 'Chill':
        return const Color(0xFF5E35B1);
      case 'Juntas':
        return const Color(0xFFD81B60);
      default:
        return AppColors.primaryOrange;
    }
  }

  // Simula un último mensaje
  String get _lastMessage {
    final messages = [
      '¡Qué ganas de que llegue el día! 🎉',
      'Nos vemos el sábado, no se olviden 👋',
      '¿Alguien sabe dónde nos juntamos exactamente?',
      '¡Excelente plan! Ya confirmé mi asistencia ✅',
      '¿Hay que llevar algo en especial?',
    ];
    return messages[widget.index % messages.length];
  }

  String get _timeLabel {
    final now = DateTime.now();
    final diff = now.difference(widget.activity.eventDateTime);
    if (diff.inDays < 0) {
      // Evento en el futuro
      final daysUntil = -diff.inDays;
      if (daysUntil == 0) return 'Hoy';
      if (daysUntil == 1) return 'Mañana';
      return 'En $daysUntil días';
    }
    return DateFormat('dd/MM').format(widget.activity.eventDateTime);
  }

  int get _unread => widget.isOrganizer ? 3 : (widget.index % 3 == 0 ? 0 : 1);

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
        transform: Matrix4.diagonal3Values(_pressed ? 0.98 : 1.0, _pressed ? 0.98 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar con borde de categoría
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _categoryColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: widget.activity.imageUrl.startsWith('http')
                          ? Image.network(
                              widget.activity.imageUrl,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              widget.activity.imageUrl,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  // Indicador online / categoría
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _categoryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF161920)
                              : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          _getCategoryIcon(widget.activity.category),
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Badge de no leídos
                  if (_unread > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryOrange, AppColors.lightOrange],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF161920)
                                : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryOrange.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$_unread',
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
              ),

              const SizedBox(width: 14),

              // Info principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.activity.title,
                            style: TextStyle(
                              fontWeight: _unread > 0
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isOrganizer) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.skyBlue.withValues(alpha: 0.9),
                                  AppColors.mediumBlue.withValues(alpha: 0.9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    size: 9, color: Colors.white),
                                SizedBox(width: 3),
                                Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: _unread > 0
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFF8FAFC)
                                : AppColors.navyBlue.withValues(alpha: 0.75))
                            : (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF64748B)
                                : Colors.grey[400]),
                        fontWeight: _unread > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 13,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF64748B)
                              : Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.activity.currentParticipants} participantes',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2E323F)
                                : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: _categoryColor.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: _categoryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Flecha
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.primaryOrange.withValues(alpha: 0.15)
                      : AppColors.primaryOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primaryOrange,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: Duration(milliseconds: widget.index * 60))
        .slideX(begin: 0.05, curve: Curves.easeOutCubic);
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Deportes':
        return Icons.sports_baseball;
      case 'Comida':
        return Icons.restaurant;
      case 'Naturaleza':
        return Icons.forest;
      case 'Chill':
        return Icons.local_cafe;
      case 'Juntas':
        return Icons.celebration;
      default:
        return Icons.category;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  Tarjeta de chat de Clan — acceso rápido desde Mensajes
// ══════════════════════════════════════════════════════════════
class _ClanChatCard extends StatefulWidget {
  final Clan clan;
  final int index;
  final VoidCallback onTap;

  const _ClanChatCard({
    required this.clan,
    required this.index,
    required this.onTap,
  });

  @override
  State<_ClanChatCard> createState() => _ClanChatCardState();
}

class _ClanChatCardState extends State<_ClanChatCard> {
  bool _pressed = false;
  late final Future<Map<String, dynamic>?> _lastMessageFuture;

  @override
  void initState() {
    super.initState();
    _lastMessageFuture = Supabase.instance.client
        .from('clan_messages')
        .select('message, sent_at')
        .eq('clan_id', widget.clan.id)
        .order('sent_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  static const _clanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFFFD7C36)],
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        transform: Matrix4.diagonal3Values(
            _pressed ? 0.98 : 1.0, _pressed ? 0.98 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ??
              Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : const Color(0xFF7C3AED).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar del clan con escudo
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: _clanGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: widget.clan.avatarUrl != null &&
                            widget.clan.avatarUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(widget.clan.avatarUrl!,
                                fit: BoxFit.cover),
                          )
                        : Center(
                            child: Text(
                              widget.clan.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isDark ? const Color(0xFF161920) : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Nombre + último mensaje
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF041249),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _lastMessageFuture,
                      builder: (context, snap) {
                        final raw = snap.data?['message'] as String?;
                        final preview = raw == null
                            ? 'Sé el primero en escribir 👋'
                            : EncryptionService.decryptText(raw);
                        return Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey[600],
                            fontStyle: raw == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Hora + insignia CLAN
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _lastMessageFuture,
                    builder: (context, snap) {
                      final sentAt = snap.data?['sent_at'] as String?;
                      if (sentAt == null) return const SizedBox(height: 14);
                      final dt = DateTime.tryParse(sentAt)?.toLocal();
                      if (dt == null) return const SizedBox(height: 14);
                      final now = DateTime.now();
                      final sameDay = dt.year == now.year &&
                          dt.month == now.month &&
                          dt.day == now.day;
                      return Text(
                        sameDay
                            ? DateFormat('HH:mm').format(dt)
                            : DateFormat('dd/MM').format(dt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : Colors.grey[500],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: _clanGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'CLAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: (widget.index * 60).ms).fadeIn().slideY(begin: 0.08);
  }
}

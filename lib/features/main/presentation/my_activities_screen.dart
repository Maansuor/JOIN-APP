import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _headerController;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final myActivities = appState.myActivities;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              title: LayoutBuilder(builder: (ctx, constr) {
                final isCollapsed = constr.maxHeight <= kToolbarHeight + 10;
                return AnimatedOpacity(
                  opacity: isCollapsed ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Text('Mis Planes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                );
              }),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                  onPressed: () => context.push('/main/create'),
                ),
              ),
            ],
          ),
          
          if (myActivities.isEmpty)
            SliverFillRemaining(child: _buildEmptyState(context))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _PremiumActivityCard(activity: myActivities[index], index: index),
                  ),
                  childCount: myActivities.length,
                ),
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
             gradient: LinearGradient(
               begin: Alignment.topRight,
               end: Alignment.bottomLeft,
               colors: [
                 AppColors.primaryOrange,
                 Color.lerp(AppColors.intenseOrange, const Color(0xFFE53935), t * 0.5)!,
               ],
             ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -20 - (t * 20),
                top: -30 + (t * 20),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.0)],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                       Row(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                             child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                           ),
                           const SizedBox(width: 12),
                           const Text(
                             'Mis Planes',
                             style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                           ),
                         ],
                       ),
                       const SizedBox(height: 6),
                       Text(
                         'Actividades en las que eres el anfitrión',
                         style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
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
              color: AppColors.primaryOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rocket_launch_rounded, size: 48, color: AppColors.primaryOrange),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: 2.seconds),
          const SizedBox(height: 24),
          const Text('Aún no has creado planes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
          const SizedBox(height: 8),
          Text('Conviértete en anfitrión y reúne personas\ncon tus mismos intereses', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/main/create'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear mi primer plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 4,
              shadowColor: AppColors.primaryOrange.withValues(alpha: 0.4),
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}

class _PremiumActivityCard extends StatelessWidget {
  final Activity activity;
  final int index;

  const _PremiumActivityCard({required this.activity, required this.index});

  @override
  Widget build(BuildContext context) {
    final isFull = activity.currentParticipants >= activity.maxParticipants;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // Imagen Header
          SizedBox(
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: activity.imageUrl.startsWith('http')
                      ? Image.network(activity.imageUrl, fit: BoxFit.cover)
                      : Image.asset(activity.imageUrl, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      isFull ? 'Lleno' : 'Abierto',
                      style: TextStyle(color: isFull ? AppColors.lightOrange : Colors.green[300], fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info Info Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navyBlue, height: 1.2)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.blue)),
                    const SizedBox(width: 8),
                    Text(DateFormat('d MMM yyyy, HH:mm').format(activity.eventDateTime), style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.primaryOrange.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.people_rounded, size: 14, color: AppColors.primaryOrange)),
                    const SizedBox(width: 8),
                    Text('${activity.currentParticipants}/${activity.maxParticipants}', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _ActionBtn(icon: Icons.people_alt_rounded, label: 'Solicitudes', color: AppColors.skyBlue, onTap: () => context.push('/main/activity/${activity.id}/requests'))),
                    const SizedBox(width: 12),
                    Expanded(child: _ActionBtn(icon: Icons.chat_bubble_rounded, label: 'Chat', color: Colors.purple, onTap: () => context.push('/main/activity/${activity.id}/group'))),
                    const SizedBox(width: 12),
                    Expanded(child: _ActionBtn(icon: Icons.edit_rounded, label: 'Editar', color: Colors.grey[700]!, onTap: () => context.push('/main/activity/${activity.id}/edit'))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: 100 * index)).slideY(begin: 0.2, curve: Curves.easeOut);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

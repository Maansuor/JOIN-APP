import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/models/join_request_model.dart';
import 'package:join_app/core/models/user_model.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:join_app/core/widgets/user_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class JoinRequestsScreen extends StatefulWidget {
  final String activityId;

  const JoinRequestsScreen({super.key, required this.activityId});

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<JoinRequest> activityRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRequests();
  }
  
  Future<void> _loadRequests() async {
    try {
      final appState = context.read<AppState>();
      await appState.loadRequestsForActivity(widget.activityId);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error cargando solicitudes')));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activityRequests = appState.getRequestsForActivity(widget.activityId);

    if (_isLoading) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF8F9FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF161920) : Colors.white,
          centerTitle: true,
          title: Text('Solicitudes', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.navyBlue, fontSize: 20)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
      );
    }

    final pendingRequests = activityRequests.where((r) => r.status == JoinRequestStatus.pending).toList();
    final acceptedRequests = activityRequests.where((r) => r.status == JoinRequestStatus.accepted).toList();
    final rejectedRequests = activityRequests.where((r) => r.status == JoinRequestStatus.rejected).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF8F9FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF161920) : Colors.white,
        centerTitle: true,
        title: Text(
          'Solicitudes',
          style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.navyBlue, fontSize: 20),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E222B) : Colors.grey[100], shape: BoxShape.circle),
              child: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: isDark ? const Color(0xFF161920) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0D14) : Colors.grey[100],
                borderRadius: BorderRadius.circular(22),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF161920) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.primaryOrange,
                unselectedLabelColor: isDark ? Colors.white38 : Colors.grey[500],
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  _buildTab('Nuevas', pendingRequests.length, AppColors.primaryOrange),
                  _buildTab('Aceptadas', acceptedRequests.length, const Color(0xFF2E7D32)),
                  _buildTab('Rechazadas', rejectedRequests.length, Colors.red),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildRequestsList(pendingRequests, true),
          _buildRequestsList(acceptedRequests, false),
          _buildRequestsList(rejectedRequests, false),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count, Color activeColor) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(color: activeColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildRequestsList(List<JoinRequest> requests, bool isPending) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161920) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
              ),
              child: Icon(isPending ? Icons.inbox_outlined : Icons.inventory_2_outlined, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
            ),
            const SizedBox(height: 24),
            Text(
              isPending ? 'Sin solicitudes pendientes' : 'Zona despejada',
              style: TextStyle(color: isDark ? Colors.white : AppColors.navyBlue, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isPending ? 'Aquí aparecerán quienes quieran unirse' : 'No hay nadie en esta lista',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[500], fontSize: 14),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      physics: const BouncingScrollPhysics(),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final request = requests[index];

        return _RequestCardPremium(
          request: request,
          isPending: isPending,
          onTapUser: () async {
            // Mostrar indicador de carga circular traslúcido
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryOrange),
              ),
            );
            
            final realUser = await _fetchUserProfile(request.userId);
            
            if (context.mounted) {
              context.pop(); // Cerrar indicador de carga
              
              if (realUser != null) {
                _showUserProfilePreview(realUser);
              } else {
                // Fallback elegante a los datos básicos de la solicitud si falla la red
                _showUserProfilePreview(UserModel(
                   id: request.userId,
                   name: request.userName,
                   email: '',
                   phone: '',
                   profileImageUrl: request.userImageUrl,
                   rating: request.userRating,
                   activitiesAttended: 0,
                   activitiesCreated: 0,
                   interests: [],
                   isVerified: false,
                   joinedDate: DateTime.now(),
                   bio: '¡Hola! Quiero unirme a esta actividad.',
                   birthDate: request.userBirthDate,
                   gender: request.userGender != null ? UserGender.fromJson(request.userGender!) : UserGender.preferNotToSay,
                   setupCompleted: true,
                ));
              }
            }
          },
          onAccept: isPending ? () => _handleAccept(request) : null,
          onReject: isPending ? () => _handleReject(request) : null,
        ).animate().fadeIn(duration: 400.ms, delay: (index * 50).ms).slideY(begin: 0.1, curve: Curves.easeOutCubic);
      },
    );
  }

  Future<UserModel?> _fetchUserProfile(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('*, user_interests(tag)')
          .eq('id', userId)
          .single();
      return UserModel.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  void _showUserProfilePreview(UserModel? user) {
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final socialLevel = 1 + (user.activitiesAttended * 2 + user.activitiesCreated * 3) ~/ 2;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161920) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
              ),
              const SizedBox(height: 24),
              Hero(
                tag: 'avatar_${user.id}',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryOrange, width: 3),
                    boxShadow: [BoxShadow(color: AppColors.primaryOrange.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: UserAvatar(
                    imageUrl: user.profileImageUrl,
                    name: user.name,
                    radius: 50,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(user.name, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.navyBlue)),
                  if (user.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 20, color: Colors.blue),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text('${user.age ?? '--'} años • ${user.gender.label}', style: GoogleFonts.outfit(fontSize: 14.5, color: isDark ? Colors.white60 : Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProfileStat(context, Icons.star_rounded, '${user.rating > 0 ? user.rating : "Nuevo"}', 'Reputación', Colors.amber),
                  _buildProfileStat(context, Icons.verified_rounded, '${user.activitiesAttended}', 'Eventos', Colors.blue),
                  _buildProfileStat(context, Icons.local_fire_department_rounded, 'Nvl $socialLevel', 'Social', AppColors.intenseOrange),
                ],
              ),
              const SizedBox(height: 24),
              if (user.bio.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sobre mí',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : AppColors.navyBlue),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E222B) : AppColors.navyBlue.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.navyBlue.withValues(alpha: 0.05)),
                  ),
                  child: Text(
                    user.bio,
                    style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.grey[700], height: 1.5, fontSize: 13.5, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (user.interests.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Intereses',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : AppColors.navyBlue),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: user.interests.map((interest) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: isDark ? 0.15 : 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryOrange.withValues(alpha: isDark ? 0.3 : 0.12),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          interest,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.primaryOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300, width: 1.5),
                    foregroundColor: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                  child: Text(
                    'Cerrar perfil',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileStat(BuildContext context, IconData icon, String value, String label, Color color) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     return Column(
       children: [
          Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               gradient: LinearGradient(
                 colors: [
                   color.withValues(alpha: isDark ? 0.25 : 0.15),
                   color.withValues(alpha: isDark ? 0.08 : 0.05),
                 ],
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
               ),
               shape: BoxShape.circle,
             ),
             child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : AppColors.navyBlue),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(color: isDark ? Colors.white38 : Colors.grey[500], fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
       ],
     );
  }

  Future<void> _handleAccept(JoinRequest request) async {
    try {
      final appState = context.read<AppState>();
      await appState.respondToRequest(
        request.id,
        accepted: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aceptar la solicitud: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('¡Has aceptado a un nuevo integrante!')),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _handleReject(JoinRequest request) {
    _showRejectDialog(request);
  }

  void _showRejectDialog(JoinRequest request) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161920) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Rechazar solicitud', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Quieres dejarle un mensaje? (opcional)', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Ej: Ya está lleno, lo siento...',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E222B) : const Color(0xFFF5F6FA),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => context.pop(), child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey))),
            FilledButton(
              onPressed: () async {
                // Se capturan antes de cerrar el diálogo y de esperar: después,
                // este context ya no pertenece a un widget montado.
                final messenger = ScaffoldMessenger.of(context);
                final appState = context.read<AppState>();
                context.pop(); // close dialog
                try {
                  await appState.respondToRequest(
                    request.id,
                    accepted: false,
                    responseMessage: reasonController.text.isEmpty ? null : reasonController.text,
                  );

                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Solicitud rechazada'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    )
                  );
                } catch (_) {
                  messenger.showSnackBar(const SnackBar(content: Text('Error al rechazar')));
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );
  }
}

class _RequestCardPremium extends StatelessWidget {
  final JoinRequest request;
  final bool isPending;
  final VoidCallback onTapUser;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _RequestCardPremium({
    required this.request,
    required this.isPending,
    required this.onTapUser,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = request.userName.isNotEmpty ? request.userName : 'Usuario Anónimo';
    final userImage = request.userImageUrl.isNotEmpty ? request.userImageUrl : 'https://i.pravatar.cc/150?img=1';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161920) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onTapUser,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Hero(
                    tag: 'avatar_${request.userId}',
                    child: UserAvatar(
                      imageUrl: userImage,
                      name: request.userName,
                      radius: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : AppColors.navyBlue)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text('${request.userRating > 0 ? request.userRating : "Nuevo"}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(color: isDark ? Colors.white30 : Colors.grey, fontSize: 12)),
                            const SizedBox(width: 8),
                            Icon(Icons.cake_rounded, size: 14, color: isDark ? Colors.white30 : Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text('${_calculateAge(request.userBirthDate) ?? "--"} años', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white30 : Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      Icon(Icons.format_quote_rounded, color: isDark ? Colors.white24 : Colors.grey[400], size: 18),
                      const SizedBox(width: 8),
                      Text('Dice:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    request.message,
                    style: TextStyle(fontSize: 14.5, height: 1.5, color: isDark ? Colors.white70 : Colors.grey[800], fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withValues(alpha: isDark ? 0.3 : 0.2), width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),

             if (!isPending && request.responseMessage != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange[50], borderRadius: BorderRadius.circular(12)),
                child: Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                         child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               const Text('Tu respuesta:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                               const SizedBox(height: 2),
                               Text(request.responseMessage!, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                            ]
                         )
                      )
                   ]
                )
              )
          ],
        ),
      ),
    );
  }
}

int? _calculateAge(DateTime? birthDate) {
  if (birthDate == null) return null;
  final today = DateTime.now();
  int years = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    years--;
  }
  return years;
}

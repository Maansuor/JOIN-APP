import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/models/join_request_model.dart';
import 'package:join_app/core/models/user_model.dart';
import 'package:join_app/core/services/api_client.dart';
import 'package:join_app/core/repositories/api_activity_repository.dart';
import 'package:join_app/core/theme/app_colors.dart';

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
      final repo = ApiActivityRepository();
      final requests = await repo.getRequestsForActivity(widget.activityId);
      if (mounted) {
        setState(() {
          activityRequests = requests;
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          centerTitle: true,
          title: const Text('Solicitudes', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navyBlue, fontSize: 20)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
      );
    }

    final pendingRequests = activityRequests.where((r) => r.status == JoinRequestStatus.pending).toList();
    final acceptedRequests = activityRequests.where((r) => r.status == JoinRequestStatus.accepted).toList();
    final rejectedRequests = activityRequests.where((r) => r.status == JoinRequestStatus.rejected).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Solicitudes',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navyBlue, fontSize: 20),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(22),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.primaryOrange,
                unselectedLabelColor: Colors.grey[500],
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
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
              child: Icon(isPending ? Icons.inbox_outlined : Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
            ),
            const SizedBox(height: 24),
            Text(
              isPending ? 'Sin solicitudes pendientes' : 'Zona despejada',
              style: const TextStyle(color: AppColors.navyBlue, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isPending ? 'Aquí aparecerán quienes quieran unirse' : 'No hay nadie en esta lista',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
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
          onTapUser: () {
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
          },
          onAccept: isPending ? () => _handleAccept(request) : null,
          onReject: isPending ? () => _handleReject(request) : null,
        ).animate().fadeIn(duration: 400.ms, delay: (index * 50).ms).slideY(begin: 0.1, curve: Curves.easeOutCubic);
      },
    );
  }

  void _showUserProfilePreview(UserModel? user) {
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
            ),
            const SizedBox(height: 24),
            Hero(
              tag: 'avatar_${user.id}',
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryOrange, width: 3),
                  boxShadow: [BoxShadow(color: AppColors.primaryOrange.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: user.profileImageUrl.startsWith('http') ? NetworkImage(user.profileImageUrl) as ImageProvider : AssetImage(user.profileImageUrl),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navyBlue)),
            Text('${user.age ?? '--'} años • ${user.gender.label}', style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildProfileStat(Icons.star_rounded, '${user.rating}', 'Reputación', Colors.amber),
                _buildProfileStat(Icons.verified_rounded, '${user.activitiesAttended}', 'Eventos', Colors.blue),
                _buildProfileStat(Icons.local_fire_department_rounded, 'Nvl 3', 'Social', AppColors.intenseOrange),
              ],
            ),
             const SizedBox(height: 24),
             if (user.bio.isNotEmpty) ...[
                Align(alignment: Alignment.centerLeft, child: Text('Sobre mí', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800]))),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: Text(user.bio, style: TextStyle(color: Colors.grey[600], height: 1.5, fontSize: 14))),
                const SizedBox(height: 24),
             ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.grey.shade300, width: 2),
                ),
                child: const Text('Cerrar perfil', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat(IconData icon, String value, String label, Color color) {
     return Column(
       children: [
          Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
             child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
       ],
     );
  }

  Future<void> _handleAccept(JoinRequest request) async {
    try {
      final repo = ApiActivityRepository();
      final updatedRequest = await repo.respondToRequest(
        requestId: request.id,
        accepted: true,
        respondedBy: context.read<AppState>().currentUser?.id ?? 'organizer',
      );
      
      setState(() {
        final index = activityRequests.indexWhere((r) => r.id == request.id);
        if (index != -1) activityRequests[index] = updatedRequest;
      });
      
      // Logica real de notificación 
      final appState = context.read<AppState>();
      final actList = appState.activities;
      final activity = actList.isNotEmpty ? actList.firstWhere((a) => a.id == widget.activityId, orElse: () => actList.first) : null;
      final activityTitle = activity?.title ?? 'tu plan';

      await ApiClient.instance.post('/notifications.php', {
          'action': 'create',
          'userId': request.userId,
          'type': 'acceptedToGroup',
          'title': '¡Fuiste aceptado! 🎉',
          'message': 'Ya formas parte del plan "$activityTitle". Ingresa para coordinar en el chat.',
          'activityId': widget.activityId,
          'activityTitle': activityTitle,
      });
    } catch (e) {
       // Ignorar fallo de api
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Rechazar solicitud', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Quieres dejarle un mensaje? (opcional)', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Ej: Ya está lleno, lo siento...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          FilledButton(
            onPressed: () async {
              context.pop(); // close dialog
              try {
                final repo = ApiActivityRepository();
                final updatedRequest = await repo.respondToRequest(
                  requestId: request.id,
                  accepted: false,
                  responseMessage: reasonController.text.isEmpty ? null : reasonController.text,
                  respondedBy: context.read<AppState>().currentUser?.id ?? 'organizer',
                );

                setState(() {
                  final index = activityRequests.indexWhere((r) => r.id == request.id);
                  if (index != -1) activityRequests[index] = updatedRequest;
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Solicitud rechazada'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    )
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al rechazar')));
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Rechazar'),
          ),
        ],
      ),
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
    final userName = request.userName.isNotEmpty ? request.userName : 'Usuario Anónimo';
    final userImage = request.userImageUrl.isNotEmpty ? request.userImageUrl : 'https://i.pravatar.cc/150?img=1';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.grey.shade100),
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
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage: userImage.startsWith('http') ? NetworkImage(userImage) as ImageProvider : AssetImage(userImage),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text('${request.userRating > 0 ? request.userRating : "Nuevo"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 8),
                            const Text('•', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(width: 8),
                            Icon(Icons.cake_rounded, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text('${_calculateAge(request.userBirthDate) ?? "--"} años', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      Icon(Icons.format_quote_rounded, color: Colors.grey[400], size: 18),
                      const SizedBox(width: 8),
                      Text('Dice:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    request.message,
                    style: TextStyle(fontSize: 14.5, height: 1.5, color: Colors.grey[800], fontStyle: FontStyle.italic),
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
                        side: BorderSide(color: Colors.red.shade100, width: 2),
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
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12)),
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
                               Text(request.responseMessage!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
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

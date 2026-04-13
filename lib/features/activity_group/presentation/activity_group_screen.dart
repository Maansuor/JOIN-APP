import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/data/mock_data.dart';
import 'package:join_app/core/services/api_client.dart';
import 'package:join_app/core/services/encryption_service.dart';
import 'package:join_app/core/models/chat_message_model.dart';
import 'package:join_app/core/models/contribution_model.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ActivityGroupScreen extends StatefulWidget {
  final String activityId;

  const ActivityGroupScreen({super.key, required this.activityId});

  @override
  State<ActivityGroupScreen> createState() => _ActivityGroupScreenState();
}

class _ActivityGroupScreenState extends State<ActivityGroupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<ChatMessage> messages;
  late List<Contribution> contributions;
  final TextEditingController _messageController = TextEditingController();

  bool _isLoadingChat = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    messages = [];
    contributions = [];
    _loadChatMessages();
    _loadContributions();
  }

  Future<void> _loadContributions() async {
    try {
      final response = await ApiClient.instance.get('/contributions.php?action=list&activityId=${widget.activityId}');
      final List<dynamic> json = response['contributions'] ?? [];
      
      if (mounted) {
        setState(() {
          contributions = json.map((data) => Contribution(
            id: data['id'],
            activityId: data['activityId'],
            title: data['title'],
            description: data['description'] ?? '',
            category: data['category'] ?? 'other',
            isRequired: data['isRequired'] ?? false,
            assignedToUserId: data['assignedToUserId'],
            assignedToUserName: data['assignedToUserName'],
            assignedToUserImage: data['assignedToUserImage'],
            createdAt: DateTime.parse(data['createdAt']),
            createdByUserId: data['createdByUserId']
          )).toList();
        });
      }
    } catch (e) {
      debugPrint('Error cargando aportes: $e');
    }
  }

  Future<void> _loadChatMessages() async {
    try {
      final response = await ApiClient.instance.get('/chat.php?action=list&activityId=${widget.activityId}');
      // Marcar como leído
      ApiClient.instance.post('/chat.php?action=mark_read', {'activityId': widget.activityId}).catchError((_) => null);

      final List<dynamic> msgsJson = response['messages'] ?? [];
      final msgs = msgsJson.map((json) => ChatMessage.fromJson(json)).toList();
      
      if (mounted) {
        setState(() {
          messages = msgs;
          _isLoadingChat = false;
        });
      }
    } catch (e, stack) {
      if (mounted) setState(() => _isLoadingChat = false);
      debugPrint('Error loading chat messages: $e');
      debugPrint('Stacktrace: $stack');
    }
  }

  Future<void> _sendMessage({File? image}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && image == null) return;
    
    _messageController.clear();
    
    try {
      final encryptedText = EncryptionService.encryptText(text);
      final response = await ApiClient.instance.postMultipart(
        '/chat.php?action=send',
        {'activityId': widget.activityId, 'message': encryptedText},
        file: image,
      );
      
      // Añadir de forma optimista mientras recargamos todo
      setState(() {
        messages.insert(0, ChatMessage(
          id: response['id'],
          userId: context.read<AppState>().currentUser?.id ?? 'me',
          userName: context.read<AppState>().currentUser?.name ?? 'Tú',
          userImageUrl: context.read<AppState>().currentUser?.profileImageUrl ?? '',
          message: text,
          timestamp: DateTime.now(),
          type: image != null ? MessageType.image : MessageType.text,
          imageUrls: response['imageUrl'] != null ? [response['imageUrl']] : null,
        ));
      });
      
      _loadChatMessages(); // Recargar orden oficial
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar: $e')));
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      await _sendMessage(image: File(image.path));
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      await ApiClient.instance.post('/chat.php?action=delete', {
        'messageId': message.id,
      });
      setState(() => messages.removeWhere((m) => m.id == message.id));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mensaje eliminado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editMessage(ChatMessage message, String newText) async {
    try {
      final encryptedText = EncryptionService.encryptText(newText);
      await ApiClient.instance.post('/chat.php?action=edit', {
        'messageId': message.id,
        'message': encryptedText,
      });
      setState(() {
        final index = messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          messages[index] = messages[index].copyWith(message: newText, isEdited: true);
        }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mensaje editado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _reactToMessage(ChatMessage message, String reaction) async {
    final currentUserId = context.read<AppState>().currentUser?.id ?? 'me';
    try {
      final response = await ApiClient.instance.post('/chat.php?action=react', {
        'messageId': message.id,
        'reaction': reaction,
      });
      
      setState(() {
        final index = messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          final msg = messages[index];
          final reactions = List<MessageReaction>.from(msg.reactions);
          final existingIndex = reactions.indexWhere((r) => r.userId == currentUserId && r.reaction == reaction);
          
          if (response['action'] == 'removed') {
             if (existingIndex != -1) reactions.removeAt(existingIndex);
          } else if (response['action'] == 'added' || response['action'] == 'updated') {
             if (existingIndex == -1) {
                reactions.removeWhere((r) => r.userId == currentUserId);
                reactions.add(MessageReaction(userId: currentUserId, reaction: reaction));
             }
          }
          messages[index] = msg.copyWith(reactions: reactions);
        }
      });
    } catch (e) {
      // Ignorar
    }
  }

  void _showMessageOptions(ChatMessage message) {
    final currentUserId = context.read<AppState>().currentUser?.id;
    final isMine = message.userId == currentUserId;
    
    // Asumir que si el appState dice que el organizador soy yo, isOrganizer=true.
    final activity = context.read<AppState>().activities.firstWhere(
      (a) => a.id == widget.activityId,
      orElse: () => mockActivities.firstWhere((a) => a.id == widget.activityId, orElse: () => mockActivities[0])
    );
    final isOrganizer = activity.organizerId == currentUserId;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍', '❤️', '😂', '😮', '😢', '👏'].map((emoji) => 
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _reactToMessage(message, emoji);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                )
              ).toList(),
            ),
            const Divider(),
            if (isMine && DateTime.now().difference(message.timestamp).inSeconds <= 50)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Editar (50s)'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(message);
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                title: const Text('Info. del mensaje'),
                onTap: () {
                  Navigator.pop(context);
                  _showReadByInfo(message);
                },
              ),
            if (isMine || isOrganizer)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showReadByInfo(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Visto por (${message.readBy.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              if (message.readBy.isEmpty)
                const Expanded(child: Center(child: Text('Nadie ha visto este mensaje aún.')))
              else
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: message.readBy.length,
                    itemBuilder: (context, index) {
                      final read = message.readBy[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person, color: Colors.white), backgroundColor: Color(0xFFFD7C36)),
                        title: Text(read.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Leído el ${read.readAt.toString().substring(0, 16)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(ChatMessage message) {
    final controller = TextEditingController(text: message.message);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar mensaje'),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.trim().isNotEmpty) {
                _editMessage(message, controller.text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activity = appState.activities.firstWhere(
      (a) => a.id == widget.activityId,
      orElse: () => mockActivities.firstWhere(
        (a) => a.id == widget.activityId,
        orElse: () => mockActivities[0],
      ),
    );

    // Aquí ya no sobrescribimos "contributions" con la data estática.
    // Lo dejamos tal cual lo carga _loadContributions de la base de datos.


    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${activity.currentParticipants} participantes',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Premium Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFD7C36), Color(0xFFF95B00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFD7C36).withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 0, offset: const Offset(0, 2))
                ]
              ),
              tabs: const [
                Tab(
                  child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.chat_bubble_rounded, size: 16),
                       SizedBox(width: 6),
                       Text('Chat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                     ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Aportes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Ubic.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: -0.2, duration: 400.ms).fadeIn(),
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Chat Tab
                _buildChatTab(),
                // Contributions Tab
                _buildContributionsTab(),
                // Location Tab
                _buildLocationTab(activity),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab de Chat
  Widget _buildChatTab() {
    final pinnedMessages = messages.where((m) => m.isPinned).toList();

    return Column(
      children: [
        // Banner E2EE Estilo Premium
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDE68A)),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4)
              ),
            ]
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Mensajes cifrados de extremo a extremo',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3
                ),
              ),
            ],
          ),
        ).animate().slideY(begin: -0.5, duration: 400.ms, curve: Curves.easeOut).fadeIn(delay: 200.ms),
        
        // Mensajes fijados (si los hay)
        if (pinnedMessages.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.amber[50],
            child: Row(
              children: [
                Icon(Icons.push_pin, size: 16, color: Colors.amber[800]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${pinnedMessages.length} mensaje(s) fijado(s)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Lista de mensajes
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/wallpaper/join-fondo.jpg'),
                fit: BoxFit.cover,
                opacity: 0.15,
              ),
            ),
            child: _isLoadingChat
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index]; // ListView.builder(reverse: true) ya los lee desde abajo
                return GestureDetector(
                  onLongPress: () => _showMessageOptions(message),
                  child: _ChatMessageBubble(message: message).animate().fadeIn(duration: 300.ms),
                );
              },
            ),
          ),
        ),
        // Premium Input Box
        Container(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -5)
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFFD7C36), size: 22),
                    onPressed: _pickImage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey[200]!, width: 1.5),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Escribe algo increíble...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFD7C36), Color(0xFFEA4E00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFD7C36).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ).animate().slideY(begin: 1.0, duration: 400.ms, curve: Curves.easeOutCubic),
      ],
    );
  }

  /// Tab de Aportes
  Widget _buildContributionsTab() {
    final coveredContributions = contributions.where((c) => c.isCovered).toList();
    final uncoveredContributions = contributions.where((c) => !c.isCovered).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progreso general
          _buildProgressSection(coveredContributions, contributions),
          const SizedBox(height: 24),

          // Aportes Cubiertos
          if (coveredContributions.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Cubiertos (${coveredContributions.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: coveredContributions.asMap().entries.map((entry) {
                final index = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ContributionCard(
                    contribution: entry.value,
                    onToggle: () => _toggleContribution(entry.value),
                  ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms),
                );
              }).toList(),
            ),
            const Divider(height: 32),
          ],

          // Aportes Pendientes
          if (uncoveredContributions.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.pending_actions, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Pendientes (${uncoveredContributions.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: uncoveredContributions.asMap().entries.map((entry) {
                final index = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ContributionCard(
                    contribution: entry.value,
                    onToggle: () => _toggleContribution(entry.value),
                  ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 24),

          // Botón para sugerir nuevo aporte
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddContributionDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Sugerir Aporte'),
            ),
          ),
        ],
      ),
    );
  }

  /// Tab de Ubicación
  Widget _buildLocationTab(Activity activity) {
    if (activity.latitude == null || activity.longitude == null) {
      return const Center(child: Text('Ubicación exacta no disponible.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    activity.locationName.isNotEmpty ? activity.locationName : activity.location,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(activity.latitude!, activity.longitude!),
                  initialZoom: 15.0,
                ),
                children: [
                   TileLayer(
                     urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}{r}.png',
                     userAgentPackageName: 'com.join.app',
                   ),
                   MarkerLayer(
                     markers: [
                       Marker(
                         point: LatLng(activity.latitude!, activity.longitude!),
                         width: 60,
                         height: 60,
                         child: Container(
                           decoration: BoxDecoration(
                             color: Colors.blue.withValues(alpha: 0.2),
                             shape: BoxShape.circle,
                           ),
                           child: Center(
                             child: Container(
                               width: 24,
                               height: 24,
                               decoration: BoxDecoration(
                                 color: Colors.blue,
                                 shape: BoxShape.circle,
                                 border: Border.all(color: Colors.white, width: 3),
                                 boxShadow: [
                                   BoxShadow(
                                     color: Colors.blue.withValues(alpha: 0.5),
                                     blurRadius: 8,
                                     spreadRadius: 2,
                                   )
                                 ],
                               ),
                             ),
                           ),
                         ).animate(onPlay: (controller) => controller.repeat()).scaleXY(begin: 0.8, end: 1.2, duration: 1000.ms, curve: Curves.easeInOut).then().scaleXY(begin: 1.2, end: 0.8, duration: 1000.ms, curve: Curves.easeInOut),
                       ),
                     ],
                   ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final url = 'https://www.google.com/maps/search/?api=1&query=${activity.latitude},${activity.longitude}';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.map_rounded, color: Colors.blue),
                label: const Text('Abrir en Google Maps / Otras apps', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
          ),
        ],
      ),
    );
  }

  /// Sección de progreso
  Widget _buildProgressSection(List<Contribution> covered, List<Contribution> total) {
    final percentage = (covered.length / total.length * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progreso de Aportes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$percentage%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: covered.length / total.length,
              minHeight: 8,
              backgroundColor: Colors.green[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${covered.length} de ${total.length} aportes comprometidos',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  /// Alternar un aporte (asignarse / desasignarse)
  Future<void> _toggleContribution(Contribution contribution) async {
    final currentUserId = context.read<AppState>().currentUser?.id;
    if (currentUserId == null) return;

    final isMine = contribution.assignedToUserId == currentUserId;
    final url = isMine ? '/contributions.php?action=unassign' : '/contributions.php?action=assign';
    
    // Optimista
    final index = contributions.indexWhere((c) => c.id == contribution.id);
    if (index == -1) return;

    final original = contributions[index];
    setState(() {
      if (isMine) {
        contributions[index] = original.unassign();
      } else {
        contributions[index] = original.copyWith(
          assignedToUserId: currentUserId,
          assignedToUserName: context.read<AppState>().currentUser?.name ?? 'Tú',
          assignedToUserImage: context.read<AppState>().currentUser?.profileImageUrl ?? '',
        );
      }
    });

    try {
      await ApiClient.instance.post(url, {
        'contributionId': contribution.id
      });
      // Volvemos a cargarlos para sincronizar
      _loadContributions();
    } catch (e) {
      // Revertir
      if (mounted) {
        setState(() => contributions[index] = original);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  /// Mostrar diálogo para agregar aporte
  void _showAddContributionDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'food';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          titleController.addListener(() {
            final text = titleController.text.toLowerCase();
            String? newCat;
            if (text.contains('comida') || text.contains('pizza') || text.contains('hamburguesa') || text.contains('taco') || text.contains('snack') || text.contains('piqueo') || text.contains('pollo') || text.contains('parrilla') || text.contains('carne')) {
              newCat = 'food';
            } else if (text.contains('bebida') || text.contains('gaseosa') || text.contains('agua') || text.contains('vino') || text.contains('cerveza') || text.contains('pisco') || text.contains('hielo') || text.contains('trago')) {
              newCat = 'drinks';
            } else if (text.contains('parlante') || text.contains('musica') || text.contains('juego') || text.contains('mesa') || text.contains('carta') || text.contains('pelota') || text.contains('balon')) {
              newCat = 'entertainment';
            } else if (text.contains('bloqueador') || text.contains('solar') || text.contains('repelente') || text.contains('vaso') || text.contains('plato') || text.contains('servilleta') || text.contains('bolsa') || text.contains('carbon')) {
              newCat = 'supplies';
            }

            if (newCat != null && newCat != selectedCategory) {
              setDialogState(() => selectedCategory = newCat!);
            }
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text('Sugerir Aporte'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '¿Qué falta para que el plan sea perfecto?',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: '¿Qué llevarás?',
                      hintText: 'Ej: Pastel de chocolate',
                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Descripción / Detalles',
                      hintText: 'Opcional: Marca, cantidad...',
                      prefixIcon: const Icon(Icons.info_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: const [
                      DropdownMenuItem(value: 'food', child: Text('🍕 Comida')),
                      DropdownMenuItem(value: 'drinks', child: Text('🥤 Bebidas')),
                      DropdownMenuItem(value: 'supplies', child: Text('🎒 Suministros')),
                      DropdownMenuItem(value: 'entertainment', child: Text('🎵 Entretenimiento')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedCategory = value ?? 'food');
                    },
                    decoration: InputDecoration(
                      labelText: 'Categoría coincidente',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              FilledButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    try {
                      await ApiClient.instance.post('/contributions.php?action=create', {
                        'activityId': widget.activityId,
                        'title': titleController.text,
                        'description': descriptionController.text,
                        'category': selectedCategory,
                      });

                      if (context.mounted) {
                        context.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Aporte sugerido!'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        _loadContributions();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al crear aporte: $e')),
                        );
                      }
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFD7C36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Sugerir'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Widget para mostrar un mensaje en el chat
class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AppState>().currentUser?.id;
    final isCurrentUser = message.userId == currentUserId;

    return Column(
      crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (message.isPinned)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                const Icon(Icons.push_pin, size: 12, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  'Fijado',
                  style: TextStyle(fontSize: 10, color: Colors.amber[700], fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isCurrentUser) ...[
                CircleAvatar(
                  backgroundImage: message.userImageUrl.startsWith('http')
                      ? NetworkImage(message.userImageUrl) as ImageProvider
                      : AssetImage('assets/images/placeholder.png'),
                  radius: 20,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      margin: EdgeInsets.only(bottom: message.reactions.isNotEmpty ? 12 : 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isCurrentUser ? const LinearGradient(colors: [Color(0xFFFD7C36), Color(0xFFEA4E00)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                        color: isCurrentUser ? null : Colors.grey[100],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isCurrentUser ? 20 : 0),
                          bottomRight: Radius.circular(isCurrentUser ? 0 : 20),
                        ),
                        border: isCurrentUser ? null : Border.all(color: Colors.grey[200]!, width: 1.5),
                        boxShadow: isCurrentUser ? [
                          BoxShadow(color: const Color(0xFFFD7C36).withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1, offset: const Offset(0, 4))
                        ] : [],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isCurrentUser)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                message.userName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (message.type == MessageType.image && message.imageUrls != null && message.imageUrls!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  message.imageUrls!.first,
                                  width: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          if (message.message.isNotEmpty)
                            Text(
                              message.message,
                              style: TextStyle(
                                color: isCurrentUser ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  message.getTimeString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                                  ),
                                ),
                                if (message.isEdited)
                                  Text(
                                    ' (editado)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    message.readBy.isNotEmpty ? Icons.done_all : Icons.done,
                                    size: 14,
                                    color: message.readBy.isNotEmpty ? Colors.blue[100] : Colors.white70,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (message.reactions.isNotEmpty)
                      Positioned(
                        bottom: 0,
                        right: isCurrentUser ? 10 : null,
                        left: isCurrentUser ? null : 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: () {
                               final map = <String, int>{};
                               for (var r in message.reactions) {
                                  map[r.reaction] = (map[r.reaction] ?? 0) + 1;
                               }
                               return map.entries.map((e) => Padding(
                                 padding: const EdgeInsets.symmetric(horizontal: 2),
                                 child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 10)),
                               )).toList();
                            }(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isCurrentUser) const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget para mostrar un aporte
class _ContributionCard extends StatelessWidget {
  final Contribution contribution;
  final VoidCallback onToggle;

  const _ContributionCard({
    required this.contribution,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final categoryEmoji = _getCategoryEmoji(contribution.category);
    final isCovered = contribution.isCovered;
    
    // Si el título ya tiene un emoji al inicio, no mostramos el de la categoría para evitar duplicados
    final bool hasEmojiInTitle = contribution.title.isNotEmpty && 
        RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true).hasMatch(contribution.title.characters.first);

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: isCovered ? Colors.green.withValues(alpha: 0.4) : const Color(0xFFFD7C36).withValues(alpha: 0.3), width: 1.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isCovered ? Colors.green.withValues(alpha: 0.05) : const Color(0xFFFD7C36).withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!hasEmojiInTitle) ...[
                  Text(categoryEmoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contribution.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (contribution.description.isNotEmpty)
                        Text(
                          contribution.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                    ],
                  ),
                ),
                if (contribution.isRequired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.redAccent, Colors.red]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: const Text(
                      'URGENTE',
                      style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
              ],
            ),
            if (contribution.isCovered) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16)
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.green, width: 2)),
                      child: CircleAvatar(
                        backgroundImage: (contribution.assignedToUserImage?.startsWith('http') ?? false)
                            ? NetworkImage(contribution.assignedToUserImage!) as ImageProvider
                            : const AssetImage('assets/images/placeholder.png'),
                        radius: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contribution.assignedToUserName ?? 'Usuario',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    if (contribution.assignedToUserId == context.read<AppState>().currentUser?.id)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Yo lo llevo',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFD7C36), Color(0xFFEA4E00)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: const Color(0xFFFD7C36).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.front_hand_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '¡Yo pongo esto!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'comida':
        return '🍕';
      case 'drinks':
      case 'bebidas':
        return '🥤';
      case 'supplies':
      case 'suministros':
        return '🎒';
      case 'entertainment':
      case 'entretenimiento':
        return '🎵';
      case 'deportes':
      case 'sports':
        return '⚽';
      case 'naturaleza':
        return '🌿';
      case 'chill':
        return '🥤';
      case 'juntas':
        return '🎉';
      default:
        return '✨';
    }
  }
}

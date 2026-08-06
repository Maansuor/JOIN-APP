import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/models/clan_model.dart';
import 'package:join_app/core/models/user_model.dart';
import 'package:join_app/core/services/encryption_service.dart';
import 'package:flutter/services.dart';
import 'package:join_app/core/theme/app_colors.dart';

class ClanChatScreen extends StatefulWidget {
  final String clanId;
  final Clan clan;

  const ClanChatScreen({
    super.key,
    required this.clanId,
    required this.clan,
  });

  @override
  State<ClanChatScreen> createState() => _ClanChatScreenState();
}

class _ClanChatScreenState extends State<ClanChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _reactions = [];
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  RealtimeChannel? _reactionsChannel;
  
  Map<String, UserModel> _membersMap = {};
  bool _isLoadingMembers = true;
  bool _isLoadingMessages = true;

  @override
  void initState() {
    super.initState();
    _loadClanMembers();
    
    // Suscripción al stream de mensajes del clan en tiempo real
    _messagesSubscription = Supabase.instance.client
        .from('clan_messages')
        .stream(primaryKey: ['id'])
        .eq('clan_id', widget.clanId)
        .order('sent_at', ascending: false)
        .listen((data) {
          if (mounted) {
            setState(() {
              _messages = data;
              _isLoadingMessages = false;
            });
            final messageIds = data.map((m) => m['id'] as String).toList();
            _loadReactions(messageIds);
          }
        });

    // Suscripción a los cambios en tiempo real en la tabla de reacciones
    _reactionsChannel = Supabase.instance.client
        .channel('public:clan_message_reactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clan_message_reactions',
          callback: (payload) {
            final messageIds = _messages.map((m) => m['id'] as String).toList();
            _loadReactions(messageIds);
          },
        )
        .subscribe();
  }

  Future<void> _loadReactions(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      final data = await Supabase.instance.client
          .from('clan_message_reactions')
          .select('message_id, user_id, reaction')
          .inFilter('message_id', messageIds);
      if (mounted) {
        setState(() {
          _reactions = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error cargando reacciones del clan: $e');
    }
  }

  Future<void> _loadClanMembers() async {
    try {
      final appState = context.read<AppState>();
      final members = await appState.getClanMembers(widget.clanId);
      final Map<String, UserModel> membersMap = {};
      for (final m in members) {
        if (m.userProfile != null) {
          membersMap[m.userId] = m.userProfile!;
        }
      }
      if (mounted) {
        setState(() {
          _membersMap = membersMap;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading clan members for chat mapping: $e');
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    if (_reactionsChannel != null) {
      Supabase.instance.client.removeChannel(_reactionsChannel!);
    }
    super.dispose();
  }

  Future<void> _sendMessage({File? image}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && image == null) return;

    _messageController.clear();
    final appState = context.read<AppState>();
    final currentUserId = appState.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final encryptedText = EncryptionService.encryptText(text);

      String type = 'text';
      String? imageUrl;
      if (image != null) {
        type = 'image';
        final ext = image.path.split('.').last;
        final fileName = 'msg_${currentUserId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await Supabase.instance.client.storage.from('chat').upload(fileName, image);
        imageUrl = Supabase.instance.client.storage.from('chat').getPublicUrl(fileName);
      }

      await Supabase.instance.client.from('clan_messages').insert({
        'clan_id': widget.clanId,
        'user_id': currentUserId,
        'message': encryptedText,
        'type': type,
        if (imageUrl != null) 'image_url': imageUrl,
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      await _sendMessage(image: File(image.path));
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
                  child: const Icon(Icons.photo_camera_rounded, color: AppColors.primaryOrange),
                ),
                title: const Text('Cámara'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primaryOrange),
                ),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatMessageTime(String timestampStr) {
    try {
      final timestamp = DateTime.parse(timestampStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(timestamp);

      if (difference.inMinutes < 1) return 'Ahora';
      if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes}m';
      if (difference.inHours < 24) return 'Hace ${difference.inHours}h';
      return 'Hace ${difference.inDays}d';
    } catch (_) {
      return '';
    }
  }

  Future<void> _reactToMessage(String messageId, String reaction) async {
    HapticFeedback.mediumImpact();
    try {
      await Supabase.instance.client.rpc('toggle_clan_message_reaction', params: {
        'p_message_id': messageId,
        'p_reaction': reaction,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reaccionar: $e')),
        );
      }
    }
  }

  Future<void> _editMessage(String messageId, String newText) async {
    final encryptedText = EncryptionService.encryptText(newText);
    try {
      await Supabase.instance.client
          .from('clan_messages')
          .update({
            'message': encryptedText,
            'is_edited': true,
          })
          .eq('id', messageId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al editar mensaje: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await Supabase.instance.client
          .from('clan_messages')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar mensaje: $e')),
        );
      }
    }
  }

  void _showMessageOptions(Map<String, dynamic> message, String decryptedText) {
    final currentUserId = context.read<AppState>().currentUser?.id;
    final senderId = message['user_id'] as String;
    final isMine = senderId == currentUserId;
    final isCreator = widget.clan.creatorId == currentUserId;
    final messageId = message['id'] as String;
    final sentAtStr = message['sent_at'] as String;
    final sentAt = DateTime.parse(sentAtStr).toLocal();

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
                    _reactToMessage(messageId, emoji);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                )
              ).toList(),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.blueGrey),
              title: const Text('Copiar texto'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: decryptedText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mensaje copiado al portapapeles')),
                );
              },
            ),
            if (isMine && DateTime.now().difference(sentAt).inSeconds <= 50)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Editar (50s)'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(messageId, decryptedText);
                },
              ),
            if (isMine || isCreator)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openClanInfo() {
    context.push('/clan/${widget.clanId}/info?fromChat=true', extra: widget.clan);
  }

  void _showEditDialog(String messageId, String currentText) {
    final controller = TextEditingController(text: currentText);
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
                _editMessage(messageId, controller.text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = context.read<AppState>().currentUser?.id;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF6F8FC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 8),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161920) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF041249)),
              onPressed: () => context.pop(),
            ),
            title: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openClanInfo,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
                    backgroundImage: widget.clan.avatarUrl != null && widget.clan.avatarUrl!.isNotEmpty
                        ? NetworkImage(widget.clan.avatarUrl!)
                        : null,
                    child: widget.clan.avatarUrl == null || widget.clan.avatarUrl!.isEmpty
                        ? Text(
                            widget.clan.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryOrange,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.clan.name,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF041249),
                          ),
                        ),
                        Text(
                          _isLoadingMembers
                              ? 'Cargando miembros...'
                              : '${_membersMap.length} miembros activos',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Stream de mensajes de chat
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/wallpaper/join-fondo.jpg'),
                  fit: BoxFit.cover,
                  opacity: 0.15,
                ),
              ),
              child: _isLoadingMessages && _messages.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.primaryOrange),
                    )
                  : _messages.where((m) => m['is_deleted'] != true).isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.forum_rounded,
                                  color: AppColors.primaryOrange,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '¡Comienza la conversación!',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF041249),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Envía un mensaje privado a tu clan.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Builder(builder: (context) {
                          final visibleMsgs = _messages.where((m) => m['is_deleted'] != true).toList();
                          return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: visibleMsgs.length + 1,
                          itemBuilder: (context, index) {
                            if (index == visibleMsgs.length) {
                              // Aviso de cifrado: parte del scroll — aparece al inicio del
                              // chat y se oculta naturalmente cuando hay más mensajes.
                              return Center(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2D2A10) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark ? Colors.amber.withValues(alpha: 0.15) : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock_rounded,
                                        size: 11,
                                        color: isDark ? Colors.amber[200] : const Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Chat de clan encriptado de extremo a extremo',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? Colors.amber[200] : const Color(0xFFB45309),
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            final msg = visibleMsgs[index];
                            final senderId = msg['user_id'] as String;
                            final isMe = senderId == currentUserId;
                            final encryptedText = msg['message'] as String;
                            final decryptedText = EncryptionService.decryptText(encryptedText);
                            final timestampStr = msg['sent_at'] as String;
                            final messageId = msg['id'] as String;

                            // Resolve sender profile info
                            final senderProfile = _membersMap[senderId];
                            final senderName = senderProfile?.name ?? 'Miembro';
                            final senderImageUrl = senderProfile?.profileImageUrl ?? '';

                            // Resolve message reactions
                            final msgReactions = _reactions.where((r) => r['message_id'] == messageId).toList();

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!isMe) ...[
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.grey[300],
                                        backgroundImage: senderImageUrl.isNotEmpty
                                            ? NetworkImage(senderImageUrl)
                                            : null,
                                        child: senderImageUrl.isEmpty
                                            ? Text(senderName.substring(0, 1).toUpperCase())
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Flexible(
                                      child: GestureDetector(
                                        onLongPress: () => _showMessageOptions(msg, decryptedText),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              margin: EdgeInsets.only(bottom: msgReactions.isNotEmpty ? 12 : 0),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              decoration: BoxDecoration(
                                                gradient: isMe
                                                    ? const LinearGradient(
                                                        colors: [Color(0xFFFD7C36), Color(0xFFEA4E00)],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                      )
                                                    : null,
                                                color: isMe
                                                    ? null
                                                    : (isDark ? const Color(0xFF1E222B) : Colors.grey[100]),
                                                border: isMe
                                                    ? null
                                                    : Border.all(
                                                        color: isDark
                                                            ? Colors.white.withValues(alpha: 0.05)
                                                            : Colors.grey[200]!,
                                                        width: 1,
                                                      ),
                                                borderRadius: BorderRadius.only(
                                                  topLeft: const Radius.circular(20),
                                                  topRight: const Radius.circular(20),
                                                  bottomLeft: Radius.circular(isMe ? 20 : 0),
                                                  bottomRight: Radius.circular(isMe ? 0 : 20),
                                                ),
                                                boxShadow: isMe
                                                    ? [
                                                        BoxShadow(
                                                          color: const Color(0xFFFD7C36).withValues(alpha: 0.3),
                                                          blurRadius: 8,
                                                          spreadRadius: 1,
                                                          offset: const Offset(0, 4),
                                                        )
                                                      ]
                                                    : [],
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (!isMe)
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 3),
                                                      child: Text(
                                                        senderName,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w900,
                                                          color: isDark ? Colors.white70 : const Color(0xFF041249),
                                                        ),
                                                      ),
                                                    ),
                                                  if (msg['image_url'] != null && (msg['image_url'] as String).isNotEmpty)
                                                    Padding(
                                                      padding: EdgeInsets.only(bottom: decryptedText.isNotEmpty ? 6 : 0),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Image.network(
                                                          msg['image_url'] as String,
                                                          width: 200,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                  if (decryptedText.isNotEmpty)
                                                    Text(
                                                      decryptedText,
                                                      style: TextStyle(
                                                        fontSize: 13.5,
                                                        color: isMe
                                                            ? Colors.white
                                                            : (isDark ? Colors.white : Colors.black87),
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        _formatMessageTime(timestampStr),
                                                        style: TextStyle(
                                                          fontSize: 9.5,
                                                          color: isMe ? Colors.white70 : Colors.grey[500],
                                                        ),
                                                      ),
                                                      if (msg['is_edited'] == true) ...[
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '(editado)',
                                                          style: TextStyle(
                                                            fontSize: 9.5,
                                                            color: isMe ? Colors.white70 : Colors.grey[500],
                                                            fontStyle: FontStyle.italic,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (msgReactions.isNotEmpty)
                                              Positioned(
                                                bottom: 0,
                                                right: isMe ? 10 : null,
                                                left: isMe ? null : 10,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.grey.shade300),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.05),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: () {
                                                      final map = <String, int>{};
                                                      for (var r in msgReactions) {
                                                        final emoji = r['reaction'] as String;
                                                        map[emoji] = (map[emoji] ?? 0) + 1;
                                                      }
                                                      return map.entries.map((e) => Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 2),
                                                        child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 10, color: Colors.black)),
                                                      )).toList();
                                                    }(),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(duration: 250.ms);
                          },
                          );
                        }),
            ),
          ),

          // Caja de entrada de texto premium
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161920) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF4F6F9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add_rounded, color: isDark ? Colors.white70 : const Color(0xFF041249), size: 24),
                      onPressed: _showAttachmentOptions,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF041249),
                        ),
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Escribe algo increíble para tu clan...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white30 : Colors.grey[500],
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFD7C36), Color(0xFFEA4E00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFD7C36).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
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

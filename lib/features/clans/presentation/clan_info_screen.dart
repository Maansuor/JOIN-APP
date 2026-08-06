import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/models/clan_model.dart';
import 'package:join_app/core/models/user_model.dart';
import 'package:join_app/core/theme/app_colors.dart';

/// Pantalla de información del clan — equivalente a "Info. del grupo".
///
/// Sólo expone acciones que la app realmente soporta: ver/añadir/quitar
/// miembros, ver la multimedia compartida en el chat y salir o eliminar
/// el clan. No hay llamadas, video ni código de invitación de clan.
class ClanInfoScreen extends StatefulWidget {
  final String clanId;
  final Clan clan;

  /// Cuando se abre desde el chat, la acción principal vuelve atrás en lugar
  /// de apilar una segunda pantalla de chat.
  final bool fromChat;

  const ClanInfoScreen({
    super.key,
    required this.clanId,
    required this.clan,
    this.fromChat = false,
  });

  @override
  State<ClanInfoScreen> createState() => _ClanInfoScreenState();
}

class _ClanInfoScreenState extends State<ClanInfoScreen> {
  late Future<List<ClanMember>> _membersFuture;
  late Future<List<String>> _mediaFuture;

  final _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  bool _showAddMemberSection = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _mediaFuture = _loadMedia();
  }

  void _loadMembers() {
    _membersFuture = context.read<AppState>().getClanMembers(widget.clanId);
  }

  /// Imágenes compartidas en el chat del clan, de la más reciente a la más antigua.
  Future<List<String>> _loadMedia() async {
    try {
      final rows = await Supabase.instance.client
          .from('clan_messages')
          .select('image_url')
          .eq('clan_id', widget.clanId)
          .eq('is_deleted', false)
          .not('image_url', 'is', null)
          .order('sent_at', ascending: false)
          .limit(30);

      return (rows as List)
          .map((r) => (r['image_url'] ?? '').toString())
          .where((url) => url.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error cargando multimedia del clan: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final results = await context.read<AppState>().searchProfiles(query);
    final members = await _membersFuture;
    final memberIds = members.map((m) => m.userId).toSet();
    final filtered = results.where((u) => !memberIds.contains(u.id)).toList();

    if (!mounted) return;
    setState(() {
      _searchResults = filtered;
      _isSearching = false;
    });
  }

  void _addMember(String userId, String name) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await appState.addMemberToClan(widget.clanId, userId);
    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('¡Se agregó a $name al Clan!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      setState(() {
        _searchController.clear();
        _searchResults = [];
        _showAddMemberSection = false;
        _loadMembers();
      });
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(appState.error ?? 'Error al agregar miembro'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeMember(String userId, String name) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await appState.removeMemberFromClan(widget.clanId, userId);
    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Se removió a $name del Clan.'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(_loadMembers);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(appState.error ?? 'Error al remover miembro'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteClan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Clan'),
        content: Text(
            '¿Estás seguro de que quieres eliminar permanentemente el clan "${widget.clan.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await appState.deleteClan(widget.clanId);
    if (!mounted) return;

    if (success) {
      // El clan ya no existe: volver hasta la lista de chats.
      context.go('/main');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Clan "${widget.clan.name}" eliminado.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _leaveClan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir del Clan'),
        content: Text('¿Estás seguro de que quieres salir del clan "${widget.clan.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await appState.leaveClan(widget.clanId);
    if (!mounted) return;

    if (success) {
      context.go('/main');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Has salido del clan "${widget.clan.name}".'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = context.read<AppState>().currentUser;
    final isCreator = widget.clan.creatorId == currentUser?.id;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF161920) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white : const Color(0xFF041249)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Info. del clan',
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF041249),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildHeader(isDark, isCreator),
          const SizedBox(height: 10),
          _buildQuickActions(isDark, isCreator),
          const SizedBox(height: 10),
          _buildMediaSection(isDark),
          const SizedBox(height: 10),
          _buildMembersSection(isDark, isCreator, currentUser),
          const SizedBox(height: 10),
          _buildDangerZone(isDark, isCreator),
          const SizedBox(height: 16),
          _buildFooter(isDark, isCreator),
        ],
      ),
    );
  }

  // ── Cabecera: avatar, nombre y número de miembros ──────────────────
  Widget _buildHeader(bool isDark, bool isCreator) {
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF161920) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
            backgroundImage: widget.clan.avatarUrl != null && widget.clan.avatarUrl!.isNotEmpty
                ? NetworkImage(widget.clan.avatarUrl!)
                : null,
            child: widget.clan.avatarUrl == null || widget.clan.avatarUrl!.isEmpty
                ? Text(
                    widget.clan.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOrange,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            widget.clan.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF041249),
            ),
          ),
          const SizedBox(height: 4),
          FutureBuilder<List<ClanMember>>(
            future: _membersFuture,
            builder: (context, snapshot) {
              final count = snapshot.data?.length;
              return Text(
                count == null ? 'Clan' : 'Clan · $count miembros',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Acciones rápidas disponibles ───────────────────────────────────
  Widget _buildQuickActions(bool isDark, bool isCreator) {
    return Container(
      color: isDark ? const Color(0xFF161920) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _quickAction(
            isDark: isDark,
            icon: Icons.forum_rounded,
            label: widget.fromChat ? 'Volver' : 'Mensaje',
            onTap: () {
              if (widget.fromChat) {
                context.pop();
              } else {
                context.push('/clan/${widget.clanId}/chat', extra: widget.clan);
              }
            },
          ),
          if (isCreator)
            _quickAction(
              isDark: isDark,
              icon: Icons.person_add_rounded,
              label: 'Añadir',
              onTap: () {
                setState(() => _showAddMemberSection = true);
              },
            ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: isDark ? 0.16 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primaryOrange, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF041249),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Multimedia compartida en el chat ───────────────────────────────
  Widget _buildMediaSection(bool isDark) {
    return FutureBuilder<List<String>>(
      future: _mediaFuture,
      builder: (context, snapshot) {
        final urls = snapshot.data ?? [];
        if (snapshot.connectionState != ConnectionState.done || urls.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          color: isDark ? const Color(0xFF161920) : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.perm_media_rounded,
                        size: 18, color: isDark ? Colors.white70 : const Color(0xFF041249)),
                    const SizedBox(width: 10),
                    Text(
                      'Multimedia',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF041249),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${urls.length}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: urls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final url = urls[index];
                    return GestureDetector(
                      onTap: () => _openImageViewer(url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          url,
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 92,
                            height: 92,
                            color: isDark ? const Color(0xFF1E222B) : Colors.grey[200],
                            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                          ),
                        ),
                      ),
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

  void _openImageViewer(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  // ── Miembros del clan ──────────────────────────────────────────────
  Widget _buildMembersSection(bool isDark, bool isCreator, UserModel? currentUser) {
    return Container(
      color: isDark ? const Color(0xFF161920) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.groups_rounded,
                    size: 18, color: isDark ? Colors.white70 : const Color(0xFF041249)),
                const SizedBox(width: 10),
                Text(
                  'Miembros',
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF041249),
                  ),
                ),
                const Spacer(),
                if (isCreator)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        setState(() => _showAddMemberSection = !_showAddMemberSection),
                    icon: Icon(
                      _showAddMemberSection ? Icons.close_rounded : Icons.person_add_rounded,
                      color: AppColors.primaryOrange,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          if (_showAddMemberSection) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF041249)),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, correo o código...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primaryOrange),
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
                  ),
                ),
              ),
            ),
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8F9FD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                  ),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final u = _searchResults[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            u.profileImageUrl.isNotEmpty ? NetworkImage(u.profileImageUrl) : null,
                        child: u.profileImageUrl.isEmpty
                            ? Text(u.name.substring(0, 1).toUpperCase())
                            : null,
                      ),
                      title: Text(
                        u.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF041249),
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () => _addMember(u.id, u.name),
                        child: const Text('Invitar',
                            style: TextStyle(color: AppColors.primaryOrange)),
                      ),
                    );
                  },
                ),
              ),
          ],
          const SizedBox(height: 8),
          FutureBuilder<List<ClanMember>>(
            future: _membersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text('Error al cargar miembros: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red)),
                );
              }

              final members = snapshot.data ?? [];
              if (members.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text('No hay miembros en este clan.'),
                );
              }

              return Column(
                children: members.map((m) {
                  final isMemberCreator = m.userId == widget.clan.creatorId;
                  final isSelf = m.userId == currentUser?.id;
                  final name = m.userProfile?.name ?? 'Usuario';
                  final image = m.userProfile?.profileImageUrl ?? '';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
                      child: image.isEmpty ? Text(name.substring(0, 1).toUpperCase()) : null,
                    ),
                    title: Text(
                      isSelf ? '$name (Tú)' : name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF041249),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: isSelf
                          ? null
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: _FriendshipEvolutionTag(memberId: m.userId),
                            ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMemberCreator)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Líder',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ),
                        if (isCreator && !isMemberCreator)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded,
                                color: Colors.redAccent, size: 22),
                            onPressed: () => _removeMember(m.userId, name),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Salir / eliminar ───────────────────────────────────────────────
  Widget _buildDangerZone(bool isDark, bool isCreator) {
    return Container(
      color: isDark ? const Color(0xFF161920) : Colors.white,
      child: ListTile(
        onTap: isCreator ? _deleteClan : _leaveClan,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Icon(
          isCreator ? Icons.delete_outline_rounded : Icons.exit_to_app_rounded,
          color: Colors.red,
        ),
        title: Text(
          isCreator ? 'Eliminar clan' : 'Salir del clan',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark, bool isCreator) {
    final fecha = DateFormat("d/MM/yy 'a las' h:mm a").format(widget.clan.createdAt.toLocal());
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          isCreator ? 'Creado por ti, $fecha' : 'Creado el $fecha',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.grey[500],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta que describe el vínculo con otro miembro a partir de las
/// categorías de actividades que ambos han compartido.
class _FriendshipEvolutionTag extends StatelessWidget {
  final String memberId;
  const _FriendshipEvolutionTag({required this.memberId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: context.read<AppState>().getSharedActivityCategories(memberId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          );
        }

        final categories = snapshot.data ?? [];
        if (categories.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Conociéndose',
              style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          );
        }

        final counts = <String, int>{};
        for (final c in categories) {
          counts[c] = (counts[c] ?? 0) + 1;
        }

        String dominantCategory = '';
        int maxCount = 0;
        counts.forEach((cat, count) {
          if (count > maxCount) {
            maxCount = count;
            dominantCategory = cat;
          }
        });

        String label = 'Amigo de Juntas';
        Color color = Colors.orange;

        final normalized = dominantCategory.toLowerCase();
        if (normalized.contains('comida') || normalized.contains('restaurante')) {
          label = 'Compañero de Comidas';
          color = Colors.amber;
        } else if (normalized.contains('deporte') ||
            normalized.contains('futbol') ||
            normalized.contains('pichanga')) {
          label = 'Socio de Pichangas';
          color = Colors.green;
        } else if (normalized.contains('naturaleza') ||
            normalized.contains('trekking') ||
            normalized.contains('viaje')) {
          label = 'Compañero de Aventuras';
          color = Colors.teal;
        } else if (normalized.contains('chill') || normalized.contains('salida')) {
          label = 'Compañero de Chill';
          color = Colors.blue;
        } else if (normalized.contains('arte') ||
            normalized.contains('música') ||
            normalized.contains('museo')) {
          label = 'Compañero de Cultura';
          color = Colors.purple;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}

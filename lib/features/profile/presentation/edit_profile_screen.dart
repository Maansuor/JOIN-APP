import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/models/user_model.dart';
import 'package:join_app/core/theme/app_colors.dart';

// Categorías de actividades con su color e ícono
const _interestMap = {
  'Deportes': (Icons.sports_baseball_rounded, Color(0xFFE53935)),
  'Comida': (Icons.restaurant_rounded, Color(0xFFFFA726)),
  'Naturaleza': (Icons.forest_rounded, Color(0xFF2E7D32)),
  'Chill': (Icons.local_cafe_rounded, Color(0xFF5E35B1)),
  'Juntas': (Icons.celebration_rounded, Color(0xFFD81B60)),
  'Música': (Icons.music_note_rounded, Color(0xFF0288D1)),
  'Viajes': (Icons.flight_rounded, Color(0xFF00ACC1)),
  'Fotografía': (Icons.camera_alt_rounded, Color(0xFF6D4C41)),
  'Arte': (Icons.palette_rounded, Color(0xFFAB47BC)),
  'Tecnología': (Icons.computer_rounded, Color(0xFF1565C0)),
  'Juegos': (Icons.games_rounded, Color(0xFF00897B)),
  'Lectura': (Icons.menu_book_rounded, Color(0xFF558B2F)),
  'Running': (Icons.directions_run_rounded, Color(0xFFF4511E)),
  'Trekking': (Icons.terrain_rounded, Color(0xFF4E342E)),
  'Ciclismo': (Icons.pedal_bike_rounded, Color(0xFF00695C)),
  'Yoga': (Icons.self_improvement_rounded, Color(0xFF7B1FA2)),
  'Cine': (Icons.movie_rounded, Color(0xFFC62828)),
  'Gastronomía': (Icons.restaurant_menu_rounded, Color(0xFFEF6C00)),
  'Baile': (Icons.nightlife_rounded, Color(0xFFAD1457)),
  'Aventura': (Icons.explore_rounded, Color(0xFF2E7D32)),
  'Social': (Icons.people_rounded, Color(0xFF1976D2)),
};

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _phoneCtrl;

  late UserGender _gender;
  late DateTime? _birthDate;
  late Set<String> _interests;
  bool _isSaving = false;
  bool _isLoading = true;
  File? _imageFile;
  final _picker = ImagePicker();
  late AnimationController _saveCtrl;

  @override
  void initState() {
    super.initState();
    _saveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _loadFromState();
  }

  void _loadFromState() {
    final user = context.read<AppState>().currentUser;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _bioCtrl = TextEditingController(text: user?.bio ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _gender = user?.gender ?? UserGender.preferNotToSay;
    _birthDate = user?.birthDate;
    // Normalizar intereses a Title Case para comparar con el mapa
    _interests = Set<String>.from(
      (user?.interests ?? []).map((i) => _normalizeInterest(i)),
    );
    setState(() => _isLoading = false);
  }

  /// Convierte 'deportes' → 'Deportes' buscando en el mapa de intereses
  String _normalizeInterest(String raw) {
    for (final key in _interestMap.keys) {
      if (key.toLowerCase() == raw.toLowerCase()) return key;
    }
    // Si no coincide, capitalizar primera letra
    return raw.isNotEmpty
        ? '${raw[0].toUpperCase()}${raw.substring(1)}'
        : raw;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _saveCtrl.dispose();
    super.dispose();
  }

  int? _calcAge(DateTime? date) {
    if (date == null) return null;
    final now = DateTime.now();
    int age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 13),
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryOrange,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 900,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    _saveCtrl.forward();

    try {
      String? imageBase64;
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        imageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      final appState = context.read<AppState>();
      await appState.updateProfile(
        name: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        birthDate: _birthDate,
        gender: _gender,
        // Guardar en lowercase para consistencia con el backend
        interests: _interests.map((i) => i.toLowerCase()).toList(),
        image: imageBase64,
      );

      if (appState.currentUser != null && !appState.currentUser!.setupCompleted) {
        appState.markSetupCompleted();
      }

      if (!mounted) return;
      _showSuccess('Perfil actualizado correctamente 🎉');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      _showError(appState.error ?? 'Error al guardar cambios');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        _saveCtrl.reset();
      }
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      backgroundColor: const Color(0xFF4CAF50),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ],
      ),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _buildAvatar() {
    final user = context.watch<AppState>().currentUser;
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryOrange, Color(0xFFFF8A50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withValues(alpha: 0.4),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.cover)
                  : (user?.isAssetImage ?? false)
                      ? Image.asset(user!.profileImageUrl, fit: BoxFit.cover)
                      : (user?.profileImageUrl.isNotEmpty ?? false)
                          ? Image.network(
                              user!.fullProfileImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildAvatarFallback(user.name),
                            )
                          : _buildAvatarFallback(user?.name ?? ''),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primaryOrange, size: 18),
              ),
            ),
          ),
        ],
      ),
    ).animate().scale(duration: 500.ms, curve: Curves.elasticOut);
  }

  Widget _buildAvatarFallback(String name) {
    final initials = name.isNotEmpty
        ? name
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : '?';
    return Container(
      color: AppColors.primaryOrange.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryOrange,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: GestureDetector(
        onTap: _isSaving ? null : _save,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: _isSaving
                ? const LinearGradient(
                    colors: [Color(0xFFBDBDBD), Color(0xFF9E9E9E)])
                : const LinearGradient(
                    colors: [AppColors.primaryOrange, Color(0xFFFF6B2B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: _isSaving
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
          ),
          child: Center(
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Guardar cambios',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar con hero ────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_rounded,
                    color: Color(0xFF041249), size: 16),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.blurBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF041249), Color(0xFF1A4A9C)],
                      ),
                    ),
                  ),
                  // Círculos decorativos
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            AppColors.primaryOrange.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  // Avatar centrado
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: _buildAvatar(),
                  ),
                ],
              ),
            ),
          ),

          // ── Formulario ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre de usuario centrado
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _nameCtrl.text.isNotEmpty
                                ? _nameCtrl.text
                                : 'Tu perfil',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF041249),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_interests.length} intereses · ${_calcAge(_birthDate) != null ? "${_calcAge(_birthDate)} años" : "Edad no definida"}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Datos personales ───────────────────────
                    _SectionCard(
                      title: 'Datos personales',
                      icon: Icons.person_outline_rounded,
                      color: const Color(0xFF041249),
                      children: [
                        _PremiumField(
                          controller: _nameCtrl,
                          label: 'Nombre completo',
                          icon: Icons.badge_outlined,
                          onChanged: (_) => setState(() {}),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'El nombre es requerido'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _PremiumField(
                          controller: _phoneCtrl,
                          label: 'Teléfono (opcional)',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        _PremiumField(
                          controller: _bioCtrl,
                          label: 'Sobre mí',
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                          maxLength: 180,
                          hint: 'Cuéntanos algo sobre ti...',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Fecha de nacimiento ────────────────────
                    _SectionCard(
                      title: 'Fecha de nacimiento',
                      icon: Icons.cake_outlined,
                      color: const Color(0xFF4A1942),
                      children: [
                        GestureDetector(
                          onTap: _pickBirthDate,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            decoration: BoxDecoration(
                              gradient: _birthDate != null
                                  ? LinearGradient(
                                      colors: [
                                        AppColors.primaryOrange
                                            .withValues(alpha: 0.06),
                                        AppColors.primaryOrange
                                            .withValues(alpha: 0.02),
                                      ],
                                    )
                                  : null,
                              color: _birthDate == null
                                  ? const Color(0xFFF8F9FC)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _birthDate != null
                                    ? AppColors.primaryOrange
                                    : const Color(0xFFE5E8F0),
                                width: _birthDate != null ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryOrange
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.calendar_month_rounded,
                                      color: AppColors.primaryOrange,
                                      size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Fecha de nacimiento',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: const Color(0xFF041249)
                                              .withValues(alpha: 0.45),
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _birthDate != null
                                            ? DateFormat(
                                                    'd \'de\' MMMM \'de\' yyyy',
                                                    'es')
                                                .format(_birthDate!)
                                            : 'Toca para seleccionar',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: _birthDate != null
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          color: _birthDate != null
                                              ? const Color(0xFF041249)
                                              : const Color(0xFF041249)
                                                  .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_birthDate != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryOrange,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_calcAge(_birthDate)} años',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: const Color(0xFF041249)
                                      .withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Género ────────────────────────────────
                    _SectionCard(
                      title: 'Género',
                      icon: Icons.wc_outlined,
                      color: const Color(0xFF1A3A2A),
                      children: [
                        _PremiumGenderSelector(
                          selected: _gender,
                          onChanged: (g) => setState(() => _gender = g),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Intereses ──────────────────────────────
                    _SectionCard(
                      title: 'Mis intereses',
                      icon: Icons.interests_outlined,
                      color: const Color(0xFF1A1A2E),
                      subtitle: 'Selecciona los que guían tus actividades',
                      children: [
                        _PremiumInterestGrid(
                          selected: _interests,
                          onToggle: (interest) {
                            setState(() {
                              if (_interests.contains(interest)) {
                                _interests.remove(interest);
                              } else {
                                _interests.add(interest);
                              }
                            });
                          },
                        ),
                        if (_interests.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.primaryOrange, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  '${_interests.length} interés${_interests.length == 1 ? '' : 'es'} seleccionado${_interests.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Botón guardar ─────────────────────────
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Widgets auxiliares premium
// ══════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de sección
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                bottom: BorderSide(
                    color: color.withValues(alpha: 0.08), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color.withValues(alpha: 0.7),
                          letterSpacing: 1,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF041249).withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final String? hint;
  final void Function(String)? onChanged;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF041249)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryOrange, size: 16),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: const Color(0xFF041249).withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: const Color(0xFF041249).withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppColors.primaryOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        labelStyle: TextStyle(
            color: const Color(0xFF041249).withValues(alpha: 0.5),
            fontSize: 13),
        hintStyle: TextStyle(
            color: const Color(0xFF041249).withValues(alpha: 0.3),
            fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        counterStyle: TextStyle(
            color: const Color(0xFF041249).withValues(alpha: 0.35),
            fontSize: 11),
      ),
    );
  }
}

class _PremiumGenderSelector extends StatelessWidget {
  final UserGender selected;
  final ValueChanged<UserGender> onChanged;

  const _PremiumGenderSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      (UserGender.male, Icons.male_rounded, 'Masculino',
          const Color(0xFF1565C0)),
      (UserGender.female, Icons.female_rounded, 'Femenino',
          const Color(0xFFAD1457)),
      (UserGender.nonBinary, Icons.transgender_rounded, 'No binario',
          const Color(0xFF7B1FA2)),
      (UserGender.preferNotToSay, Icons.remove_circle_outline_rounded,
          'Prefiero no decir', const Color(0xFF546E7A)),
    ];

    return Column(
      children: options.map((opt) {
        final (gender, icon, label, color) = opt;
        final isSel = selected == gender;
        return GestureDetector(
          onTap: () => onChanged(gender),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: isSel
                  ? LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.12),
                        color.withValues(alpha: 0.05),
                      ],
                    )
                  : null,
              color: isSel ? null : const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSel ? color : const Color(0xFFE5E8F0),
                width: isSel ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSel
                        ? color.withValues(alpha: 0.15)
                        : const Color(0xFF041249).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSel
                        ? color
                        : const Color(0xFF041249).withValues(alpha: 0.35),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSel ? FontWeight.w700 : FontWeight.w400,
                      color: isSel ? color : const Color(0xFF041249),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSel ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? color : const Color(0xFFCFD8DC),
                      width: 2,
                    ),
                  ),
                  child: isSel
                      ? const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PremiumInterestGrid extends StatelessWidget {
  final Set<String> selected;
  final void Function(String) onToggle;

  const _PremiumInterestGrid(
      {required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _interestMap.entries.map((entry) {
        final name = entry.key;
        final (icon, color) = entry.value;
        final isSel = selected.contains(name);

        return GestureDetector(
          onTap: () => onToggle(name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSel ? color : color.withValues(alpha: 0.3),
                width: isSel ? 0 : 1.5,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSel ? Colors.white : color,
                ),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSel ? Colors.white : color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

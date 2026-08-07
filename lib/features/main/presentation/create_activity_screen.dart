import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/features/main/presentation/map_picker_screen.dart';
import 'package:join_app/features/main/presentation/widgets/activity_form_sections.dart';
import 'package:join_app/features/main/presentation/widgets/activity_form_premium.dart';
import 'package:latlong2/latlong.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:join_app/core/models/interest_model.dart';
import 'package:join_app/features/main/presentation/widgets/cover_picker_sheet.dart';

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '10');
  final _scrollController = ScrollController();

  final Set<String> _selectedCategories = {'Deportes'};
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  String _selectedAgeRange = '18-35 años';
  String? _selectedPhotoPath;
  LatLng? _selectedLocation;
  final List<String> _contributions = [];
  final _contributionController = TextEditingController();

  // Punto de encuentro previo (opcional)
  bool _hasSeparateMeetingPoint = false;
  final _meetingLocationController = TextEditingController();
  LatLng? _selectedMeetingLocation;

  // Sugerencias del anfitrión
  final List<String> _suggestions = [];

  /// Categoría principal dominante (define color/ícono de la pantalla)
  String get _selectedCategory => _selectedCategories.firstWhere(
        CategoryConstants.groups.containsKey,
        orElse: () => _selectedCategories.isNotEmpty
            ? _selectedCategories.first
            : 'Deportes',
      );

  final List<String> _ageRanges = [
    'Libre',
    '18-25 años',
    '18-35 años',
    '25-40 años',
    '40+ años'
  ];

  bool _isLoading = false;
  late AnimationController _fabController;

  // Colores y datos por categoría
  static const Map<String, Color> _catColors = CategoryConstants.colors;
  static const Map<String, IconData> _catIcons = CategoryConstants.icons;

  Color get _selectedColor =>
      _catColors[_selectedCategory] ?? AppColors.primaryOrange;

  IconData get _selectedIcon =>
      _catIcons[_selectedCategory] ?? Icons.category_rounded;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scrollController.addListener(() {
      if (_scrollController.offset > 50) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    _contributionController.dispose();
    _meetingLocationController.dispose();
    _scrollController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    HapticFeedback.selectionClick();
    final picked = await showPremiumDatePicker(
      context,
      accent: _selectedColor,
      initial: _selectedDate,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    HapticFeedback.selectionClick();
    final picked = await showPremiumTimePicker(
      context,
      accent: _selectedColor,
      initial: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }
  Future<void> _selectLocation() async {
    HapticFeedback.selectionClick();
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLocation: _selectedLocation,
          accentColor: _selectedColor,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result.latLng;
        _locationController.text = result.address;
      });
    }
  }

  Future<void> _selectMeetingLocation() async {
    HapticFeedback.selectionClick();
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLocation: _selectedMeetingLocation ?? _selectedLocation,
          accentColor: _selectedColor,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedMeetingLocation = result.latLng;
        _meetingLocationController.text = result.address;
      });
    }
  }

  void _createActivity() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hasSeparateMeetingPoint && _meetingLocationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Elige el punto de encuentro en el mapa.'),
        backgroundColor: AppColors.primaryOrange,
      ));
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final appState = context.read<AppState>();
      final currentUser = appState.currentUser;
      
      final newActivity = Activity(
        id: '', // Lo genera el backend
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategories.join(', '),
        imageUrl: _selectedPhotoPath ?? '', // Imagen opcional o default por categoría
        maxParticipants: int.parse(_maxParticipantsController.text),
        organizerName: currentUser?.name ?? 'Usuario',
        organizerImageUrl: currentUser?.profileImageUrl ?? '',
        eventDateTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ),
        locationName: _locationController.text,
        latitude: _selectedLocation?.latitude ?? -12.0464,
        longitude: _selectedLocation?.longitude ?? -77.0428,
        ageRange: _selectedAgeRange,
        tags: _selectedCategories.map((c) => c.toLowerCase()).toList(),
        contributions: _contributions,
        suggestions: _suggestions,
        hasSeparateMeetingPoint: _hasSeparateMeetingPoint,
        meetingLocationName: _hasSeparateMeetingPoint
            ? _meetingLocationController.text
            : _locationController.text,
        meetingLatitude: _hasSeparateMeetingPoint
            ? _selectedMeetingLocation?.latitude
            : _selectedLocation?.latitude,
        meetingLongitude: _hasSeparateMeetingPoint
            ? _selectedMeetingLocation?.longitude
            : _selectedLocation?.longitude,
      );

      final created = await appState.createActivity(newActivity);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (created != null) {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appState.error ?? 'Error al crear la actividad')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    }
  }

  void _showSuccessDialog() {
    showActivitySuccessDialog(
      context,
      accent: _selectedColor,
      title: '¡Actividad creada! 🎉',
      message:
          '"${_titleController.text}" ya está lista para recibir participantes.',
      onPrimary: () {
        Navigator.of(context).pop();
        context.go('/main');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header con gradiente ──────────────────────────
              activityFormAppBar(
                accent: _selectedColor,
                icon: _selectedIcon,
                title: 'Nueva Actividad',
                subtitle: 'Organiza algo increíble · $_selectedCategory',
                onClose: () => context.pop(),
              ),

              // ── Formulario ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Sección: Básicos ──────────────────
                        FormSectionHeader(
                          icon: Icons.edit_note_rounded,
                          title: 'Información básica',
                          color: _selectedColor,
                        ),
                        const SizedBox(height: 12),

                        _PremiumField(
                          controller: _titleController,
                          label: 'Título de la actividad',
                          hint: 'Ej: Caminata al Cerro San Cristóbal',
                          icon: Icons.title_rounded,
                          accentColor: _selectedColor,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 12),

                        _PremiumField(
                          controller: _descriptionController,
                          label: 'Descripción',
                          hint: 'Describe qué harán, qué llevar, etc.',
                          icon: Icons.description_rounded,
                          accentColor: _selectedColor,
                          maxLines: 3,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 20),

                        // ── Sección: Categoría ────────────────
                        FormSectionHeader(
                          icon: Icons.category_rounded,
                          title: 'Categoría',
                          color: _selectedColor,
                        ),
                        const SizedBox(height: 12),

                        _buildCategorySelector(),
                        const SizedBox(height: 20),

                        // ── Sección: Foto ─────────────────────
                        FormSectionHeader(
                          icon: Icons.image_rounded,
                          title: 'Foto de referencia',
                          color: _selectedColor,
                        ),
                        const SizedBox(height: 12),

                        _buildPhotoSection(),
                        const SizedBox(height: 20),

                        // ── Sección: Ubicación ────────────────
                        FormSectionHeader(
                          icon: Icons.location_on_rounded,
                          title: 'Ubicación y fecha',
                          color: _selectedColor,
                        ),
                        const SizedBox(height: 12),

                        _PremiumField(
                          controller: _locationController,
                          label: 'Dirección o lugar',
                          hint: 'Presiona para buscar en el mapa...',
                          icon: Icons.place_rounded,
                          accentColor: _selectedColor,
                          readOnly: true,
                          onTap: _selectLocation,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Elegir ubicación del mapa' : null,
                        ),
                        const SizedBox(height: 14),

                        // Punto de encuentro previo (opcional)
                        MeetingPointSection(
                          accentColor: _selectedColor,
                          hasSeparate: _hasSeparateMeetingPoint,
                          onChanged: (val) => setState(() {
                            _hasSeparateMeetingPoint = val;
                            if (!val) {
                              _meetingLocationController.clear();
                              _selectedMeetingLocation = null;
                            }
                          }),
                          controller: _meetingLocationController,
                          onPickOnMap: _selectMeetingLocation,
                        ),
                        const SizedBox(height: 14),

                        // Fecha + Hora
                        Row(
                          children: [
                            Expanded(
                              child: _DateTimeTile(
                                isPrimary: true,
                                icon: Icons.calendar_month_rounded,
                                label: 'Fecha',
                                value: DateFormat('dd/MM/yyyy')
                                    .format(_selectedDate),
                                accentColor: _selectedColor,
                                onTap: () => _selectDate(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateTimeTile(
                                isPrimary: false,
                                icon: Icons.access_time_rounded,
                                label: 'Hora',
                                value: _selectedTime.format(context),
                                accentColor: _selectedColor,
                                onTap: () => _selectTime(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Sección: Participantes ────────────
                        FormSectionHeader(
                          icon: Icons.people_alt_rounded,
                          title: 'Participantes y edad',
                          color: _selectedColor,
                        ),
                        const SizedBox(height: 12),

                        _PremiumField(
                          controller: _maxParticipantsController,
                          label: 'Máximo de participantes',
                          hint: 'Entre 2 y 50',
                          icon: Icons.group_rounded,
                          accentColor: _selectedColor,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Campo requerido';
                            final n = int.tryParse(v);
                            if (n == null || n < 2 || n > 50) {
                              return 'Debe ser entre 2 y 50';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildAgeRangeSelector(),
                        const SizedBox(height: 20),

                        // ── Sección: Aportes ──────────────────
                        FormSectionHeader(
                          icon: Icons.card_giftcard_rounded,
                          title: 'Aportes necesarios',
                          color: _selectedColor,
                          subtitle: 'Opcional',
                        ),
                        const SizedBox(height: 12),

                        _buildContributionsSection(),
                        const SizedBox(height: 20),

                        // ── Sección: Sugerencias del anfitrión ─
                        FormSectionHeader(
                          icon: Icons.tips_and_updates_rounded,
                          title: 'Sugerencias',
                          color: _selectedColor,
                          subtitle: 'Para los que se unen',
                        ),
                        const SizedBox(height: 12),

                        HostSuggestionsSection(
                          accentColor: _selectedColor,
                          selectedCategories: _selectedCategories,
                          suggestions: _suggestions,
                          onAdd: (s) => setState(() => _suggestions.add(s)),
                          onRemove: (s) =>
                              setState(() => _suggestions.remove(s)),
                        ),
                        const SizedBox(height: 28),

                        // ── Botón principal ───────────────────
                        _buildCreateButton(),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Tips flotante (mascota) arriba a la derecha ───────
          Positioned(
            top: MediaQuery.of(context).padding.top + 78,
            right: 16,
            child: MascotTipsButton(
              accent: _selectedColor,
              category: _selectedCategory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return GroupedCategoryPicker(
      selected: _selectedCategories,
      onChanged: (next) => setState(() {
        _selectedCategories
          ..clear()
          ..addAll(next);
      }),
    );
  }

  Widget _buildPhotoSection() {
    return GestureDetector(
      onTap: () => _showPhotoSheet(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _selectedPhotoPath != null
                ? _selectedColor.withValues(alpha: 0.3)
                : Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: _selectedPhotoPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(_selectedPhotoPath!),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedPhotoPath = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.edit_rounded,
                                color: Colors.white, size: 13),
                            SizedBox(width: 5),
                            Text(
                              'Cambiar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 36,
                      color: _selectedColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Agrega una foto de portada',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toca para seleccionar',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showPhotoSheet() async {
    final elegida = await showCoverPickerSheet(
      context,
      category: _selectedCategory,
      accent: _selectedColor,
      selected: _selectedPhotoPath,
    );
    if (elegida != null && mounted) {
      setState(() => _selectedPhotoPath = elegida);
    }
  }

  Widget _buildImage(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Image.asset('assets/images/placeholder.png', fit: BoxFit.cover),
      );
    } else if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Image.asset('assets/images/placeholder.png', fit: BoxFit.cover),
      );
    } else {
      final file = File(path);
      if (!file.existsSync()) {
        return Image.asset('assets/images/placeholder.png', fit: BoxFit.cover);
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Image.asset('assets/images/placeholder.png', fit: BoxFit.cover),
      );
    }
  }

  Widget _buildAgeRangeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _ageRanges.map((age) {
        final isSelected = _selectedAgeRange == age;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedAgeRange = age);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? _selectedColor.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? _selectedColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              age,
              style: TextStyle(
                color: isSelected ? _selectedColor : Colors.grey[600],
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContributionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _contributionController,
                  style: const TextStyle(
                    color: AppColors.navyBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ej: Bebidas, snacks, pelota...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(
                      Icons.card_giftcard_rounded,
                      color: _selectedColor,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _addContribution(),
                ),
              ),
              GestureDetector(
                onTap: _addContribution,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
        if (_contributions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _contributions.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c,
                      style: TextStyle(
                        color: _selectedColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _contributions.remove(c)),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: _selectedColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _addContribution() {
    final text = _contributionController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        final emoji = _getEmojiForContribution(text);
        _contributions.add('$emoji $text');
        _contributionController.clear();
      });
    }
  }

  String _getEmojiForContribution(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('comida') || lower.contains('snack') || lower.contains('piqueo') || lower.contains('almuerzo') || lower.contains('cena') || lower.contains('desayuno') || lower.contains('pan') || lower.contains('fruta')) return '🍕';
    if (lower.contains('bebida') || lower.contains('gaseosa') || lower.contains('agua') || lower.contains('vino') || lower.contains('cerveza') || lower.contains('trago') || lower.contains('jugo')) return '🥤';
    if (lower.contains('musica') || lower.contains('parlante') || lower.contains('bocina') || lower.contains('audio')) return '🎵';
    if (lower.contains('pelota') || lower.contains('balon') || lower.contains('futbol') || lower.contains('voley') || lower.contains('basquet')) return '⚽';
    if (lower.contains('dinero') || lower.contains('cuota') || lower.contains('pago') || lower.contains('efectivo') || lower.contains('yape') || lower.contains('plin')) return '💰';
    if (lower.contains('transporte') || lower.contains('carro') || lower.contains('auto') || lower.contains('taxi') || lower.contains('gasolina')) return '🚗';
    if (lower.contains('hielo')) return '🧊';
    if (lower.contains('carbon') || lower.contains('parrilla') || lower.contains('leña')) return '🔥';
    if (lower.contains('vaso') || lower.contains('plato') || lower.contains('servilleta') || lower.contains('tenedor') || lower.contains('cuchillo')) return '🍽️';
    if (lower.contains('carne') || lower.contains('pollo') || lower.contains('embutido') || lower.contains('chorizo')) return '🥩';
    if (lower.contains('juego') || lower.contains('mesa') || lower.contains('carta') || lower.contains('uno') || lower.contains('casino')) return '🃏';
    if (lower.contains('bloqueador') || lower.contains('solar') || lower.contains('repelente')) return '🧴';
    
    // Fallback emoji based on the activity category
    switch (_selectedCategory) {
      case 'Deportes': return '⚽';
      case 'Comida': return '🍕';
      case 'Naturaleza': return '🌿';
      case 'Chill': return '🥤';
      case 'Juntas': return '🎉';
      default: return '✨';
    }
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _createActivity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 62,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isLoading
                ? [_selectedColor.withValues(alpha: 0.5), _selectedColor.withValues(alpha: 0.4)]
                : [_selectedColor, _selectedColor.withValues(alpha: 0.8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: _selectedColor.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: _isLoading
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                    SizedBox(width: 14),
                    Text(
                      'Creando actividad...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.rocket_launch_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'Crear Actividad',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Widgets auxiliares premium
// ══════════════════════════════════════════════════════════════

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(
        color: AppColors.navyBlue,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        labelStyle: TextStyle(
          color: AppColors.navyBlue.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 18),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}

class _DateTimeTile extends StatefulWidget {
  final bool isPrimary;
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final VoidCallback onTap;

  const _DateTimeTile({
    required this.isPrimary,
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_DateTimeTile> createState() => _DateTimeTileState();
}

class _DateTimeTileState extends State<_DateTimeTile> {
  bool _pressed = false;

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
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()..scaleByDouble(_pressed ? 0.97 : 1.0, _pressed ? 0.97 : 1.0, 1.0, 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed
                ? widget.accentColor
                : Colors.grey.shade200,
            width: _pressed ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 16, color: widget.accentColor),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.navyBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


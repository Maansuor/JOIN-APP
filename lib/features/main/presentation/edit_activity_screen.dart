import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/features/activity/presentation/widgets/activity_not_found.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:join_app/core/models/interest_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:join_app/features/main/presentation/map_picker_screen.dart';
import 'package:join_app/features/main/presentation/widgets/activity_form_sections.dart';
import 'package:join_app/features/main/presentation/widgets/cover_picker_sheet.dart';
import 'package:join_app/features/main/presentation/widgets/activity_form_premium.dart';

/// Pantalla para editar una actividad existente con una interfaz premium
class EditActivityScreen extends StatefulWidget {
  final String activityId;

  const EditActivityScreen({super.key, required this.activityId});

  @override
  State<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends State<EditActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _maxParticipantsController;
  
  final Set<String> _selectedCategories = {};
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedAgeRange;
  
  final List<String> _ageRanges = ['Libre', '18-25 años', '18-35 años', '25-40 años', '40+ años'];
  
  String? _selectedPhotoPath;
  bool _hasSeparateMeetingPoint = false;
  LatLng? _selectedMeetingLocation;
  late final TextEditingController _meetingLocationController;
  final List<String> _contributions = [];
  final _contributionController = TextEditingController();
  final List<String> _suggestions = [];
  bool _isLoading = false;
  Activity? _activity;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  void _loadActivity() {
    final appState = context.read<AppState>();
    _activity = appState.activities
        .where((a) => a.id == widget.activityId)
        .firstOrNull;

    if (_activity == null) {
      // La actividad ya no existe. Se inicializan los controladores vacíos
      // porque dispose() los libera siempre, y build() corta mostrando el
      // estado de "no disponible" antes de usarlos.
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _locationController = TextEditingController();
      _maxParticipantsController = TextEditingController();
      _meetingLocationController = TextEditingController();
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
      _selectedAgeRange = _ageRanges.first;
      return;
    }

    // Inicializar controladores con datos existentes
    _titleController = TextEditingController(text: _activity!.title);
    _descriptionController = TextEditingController(text: _activity!.description);
    _locationController = TextEditingController(text: _activity!.location);
    _maxParticipantsController = TextEditingController(text: _activity!.maxParticipants.toString());
    
    _hasSeparateMeetingPoint = _activity!.hasSeparateMeetingPoint;
    _selectedMeetingLocation = _activity!.meetingLatitude != null && _activity!.meetingLongitude != null
        ? LatLng(_activity!.meetingLatitude!, _activity!.meetingLongitude!)
        : null;
    _meetingLocationController = TextEditingController(text: _activity!.meetingLocationName);
    
    _contributions.clear();
    _contributions.addAll(_activity!.contributions);
    
    _suggestions.clear();
    _suggestions.addAll(_activity!.suggestions);
    
    // Los planes creados antes podían guardar varias principales; se deja una
    // sola, que es lo que decide portada, color e icono.
    _selectedCategories
      ..clear()
      ..addAll(CategoryConstants.normalizeSelection(_activity!.category.split(',')));

    // Coordenadas del lugar del plan (para el selector de mapa)
    _selectedLocation = _activity!.latitude != null && _activity!.longitude != null
        ? LatLng(_activity!.latitude!, _activity!.longitude!)
        : null;
    _selectedDate = _activity!.eventDateTime;
    _selectedTime = TimeOfDay.fromDateTime(_activity!.eventDateTime);
    _selectedAgeRange = _activity!.ageRange;
    _selectedPhotoPath = _activity!.imageUrl.isNotEmpty ? _activity!.imageUrl : null;
  }

  // Colores y datos por categoría
  static const Map<String, Color> _catColors = CategoryConstants.colors;
  static const Map<String, IconData> _catIcons = CategoryConstants.icons;

  LatLng? _selectedLocation;

  /// Categoría principal dominante (define color/ícono de la pantalla)
  String get _primaryCategory => _selectedCategories.firstWhere(
        CategoryConstants.groups.containsKey,
        orElse: () => _selectedCategories.isNotEmpty
            ? _selectedCategories.first
            : 'Deportes',
      );

  Color get _selectedColor => _catColors[_primaryCategory] ?? const Color(0xFFFD7C36);
  IconData get _selectedIcon => _catIcons[_primaryCategory] ?? Icons.category_rounded;

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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _meetingLocationController.dispose();
    _maxParticipantsController.dispose();
    _contributionController.dispose();
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
  Future<void> _updateActivity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedActivity = _activity!.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategories.join(', '),
        imageUrl: _selectedPhotoPath ?? '',
        locationName: _locationController.text,
        maxParticipants: int.parse(_maxParticipantsController.text),
        ageRange: _selectedAgeRange,
        eventDateTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ),
        tags: _selectedCategories.map((c) => c.toLowerCase()).toList(),
        contributions: _contributions,
        suggestions: _suggestions,
        meetingLocationName: _hasSeparateMeetingPoint ? _meetingLocationController.text : _locationController.text,
        latitude: _selectedLocation?.latitude ?? _activity!.latitude,
        longitude: _selectedLocation?.longitude ?? _activity!.longitude,
        meetingLatitude: _hasSeparateMeetingPoint ? _selectedMeetingLocation?.latitude : _selectedLocation?.latitude,
        meetingLongitude: _hasSeparateMeetingPoint ? _selectedMeetingLocation?.longitude : _selectedLocation?.longitude,
        hasSeparateMeetingPoint: _hasSeparateMeetingPoint,
      );

      await context.read<AppState>().updateActivity(updatedActivity);

      if (!mounted) return;
      setState(() => _isLoading = false);

      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  void _showSuccessDialog() {
    showActivitySuccessDialog(
      context,
      accent: _selectedColor,
      title: '¡Plan actualizado! 🎉',
      message: '"${_titleController.text}" guardó los cambios con éxito.',
      onPrimary: () {
        Navigator.of(context).pop();
        context.go('/main');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // _loadActivity() es síncrono, así que null aquí significa que la
    // actividad no existe, no que siga cargando.
    if (_activity == null) {
      return const ActivityNotFound(
        titulo: 'No se puede editar',
        mensaje: 'Esta actividad ya no existe, así que no hay nada que editar.',
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          activityFormAppBar(
            accent: _selectedColor,
            icon: _selectedIcon,
            title: 'Editar Actividad',
            subtitle: 'Ajusta los detalles · ${_selectedCategories.join(', ')}',
            onClose: () => context.pop(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormSectionHeader(icon: Icons.edit_note_rounded, title: 'Información básica', color: _selectedColor),
                    const SizedBox(height: 12),
                    _PremiumField(
                      controller: _titleController,
                      label: 'Título de la actividad',
                      hint: 'Ej: Caminata al Cerro San Cristóbal',
                      icon: Icons.title_rounded,
                      accentColor: _selectedColor,
                      validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    _PremiumField(
                      controller: _descriptionController,
                      label: 'Descripción',
                      hint: 'Describe qué harán, qué llevar, etc.',
                      icon: Icons.description_rounded,
                      accentColor: _selectedColor,
                      maxLines: 3,
                      validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 20),
                    FormSectionHeader(icon: Icons.category_rounded, title: 'Categoría', color: _selectedColor),
                    const SizedBox(height: 12),
                    _buildCategorySelector(),
                    const SizedBox(height: 20),
                    FormSectionHeader(icon: Icons.image_rounded, title: 'Foto de portada', color: _selectedColor),
                    const SizedBox(height: 12),
                    _buildPhotoSection(),
                    const SizedBox(height: 20),
                    FormSectionHeader(icon: Icons.location_on_rounded, title: 'Ubicación y fecha', color: _selectedColor),
                    const SizedBox(height: 12),
                    _PremiumField(
                      controller: _locationController,
                      label: 'Lugar del plan (Ubicación)',
                      hint: 'Presiona para buscar en el mapa...',
                      icon: Icons.place_rounded,
                      accentColor: _selectedColor,
                      readOnly: true,
                      onTap: _selectLocation,
                      validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
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
                    Row(
                      children: [
                        Expanded(
                          child: _DateTimeTile(
                            icon: Icons.calendar_month_rounded,
                            label: 'Fecha',
                            value: DateFormat('dd/MM/yyyy').format(_selectedDate),
                            accentColor: _selectedColor,
                            onTap: () => _selectDate(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateTimeTile(
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
                    FormSectionHeader(icon: Icons.people_alt_rounded, title: 'Participantes y edad', color: _selectedColor),
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
                        if (n == null || n < 2 || n > 50) return 'Debe ser entre 2 y 50';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildAgeRangeSelector(),
                    const SizedBox(height: 20),
                    FormSectionHeader(icon: Icons.card_giftcard_rounded, title: 'Aportes necesarios', color: _selectedColor, subtitle: 'Opcional'),
                    const SizedBox(height: 12),
                    _buildContributionsSection(),
                    const SizedBox(height: 20),
                    FormSectionHeader(icon: Icons.tips_and_updates_rounded, title: 'Sugerencias', color: _selectedColor, subtitle: 'Para los que se unen'),
                    const SizedBox(height: 12),
                    _buildSuggestionsSection(),
                    const SizedBox(height: 28),
                    _buildUpdateButton(),
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
              category: _primaryCategory,
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

  Widget _buildAgeRangeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _ageRanges.map((age) {
        final isSelected = _selectedAgeRange == age;
        return GestureDetector(
          onTap: () => setState(() => _selectedAgeRange = age),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? _selectedColor.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSelected ? _selectedColor : Colors.grey.shade200, width: isSelected ? 2 : 1),
            ),
            child: Text(
              age,
              style: TextStyle(color: isSelected ? _selectedColor : Colors.grey[600], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhotoSection() {
    return GestureDetector(
      onTap: () => _photoBottomSheet(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _selectedPhotoPath != null ? _selectedColor.withValues(alpha: 0.3) : Colors.grey.shade200, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: _selectedPhotoPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(_selectedPhotoPath!),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          children: [
                            Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                            SizedBox(width: 5),
                            Text('Cambiar', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
                  Icon(Icons.add_photo_alternate_rounded, size: 36, color: _selectedColor),
                  const SizedBox(height: 10),
                  const Text('Agrega una foto', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Future<void> _photoBottomSheet() async {
    final elegida = await showCoverPickerSheet(
      context,
      category: _primaryCategory,
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

  void _addContribution() {
    final text = _contributionController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        final emoji = _getEmojiForContribution(text);
        _contributions.add('$emoji $text');
        _contributionController.clear();
      });
    }
  }

  String _getEmojiForContribution(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('comida') || lower.contains('snack') || lower.contains('piqueo') || lower.contains('almuerzo')) return '🍕';
    if (lower.contains('bebida') || lower.contains('gaseosa') || lower.contains('agua') || lower.contains('vino') || lower.contains('cerveza')) return '🥤';
    if (lower.contains('musica') || lower.contains('parlante') || lower.contains('bocina')) return '🎵';
    if (lower.contains('pelota') || lower.contains('balon') || lower.contains('futbol') || lower.contains('voley')) return '⚽';
    if (lower.contains('dinero') || lower.contains('cuota') || lower.contains('pago') || lower.contains('efectivo')) return '💰';
    if (lower.contains('hielo')) return '🧊';
    
    // Fallback emoji basado en la categoría
    final primaryCategory = _selectedCategories.isNotEmpty ? _selectedCategories.first : 'Deportes';
    switch (primaryCategory) {
      case 'Deportes': return '⚽';
      case 'Comida': return '🍕';
      case 'Naturaleza': return '🌿';
      case 'Chill': return '🥤';
      case 'Juntas': return '🎉';
      default: return '✨';
    }
  }

  Widget _buildContributionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _PremiumField(
                controller: _contributionController,
                label: '¿Qué falta traer?',
                hint: 'Ej: Bebidas, snacks...',
                icon: Icons.card_giftcard_rounded,
                accentColor: _selectedColor,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addContribution,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: _selectedColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        if (_contributions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _contributions.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _selectedColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c, style: TextStyle(color: _selectedColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _contributions.remove(c)),
                      child: Icon(Icons.close, size: 14, color: _selectedColor),
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

  Widget _buildSuggestionsSection() {
    return HostSuggestionsSection(
      accentColor: _selectedColor,
      selectedCategories: _selectedCategories,
      suggestions: _suggestions,
      onAdd: (s) => setState(() => _suggestions.add(s)),
      onRemove: (s) => setState(() => _suggestions.remove(s)),
    );
  }

  Widget _buildUpdateButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _updateActivity,
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
              : [BoxShadow(color: _selectedColor.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Guardar Cambios', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
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

  const _PremiumField({required this.controller, required this.label, required this.hint, required this.icon, required this.accentColor, this.maxLines = 1, this.keyboardType, this.validator, this.readOnly = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: accentColor, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: accentColor, width: 2)),
        contentPadding: const EdgeInsets.all(16),
      ),
      validator: validator,
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final VoidCallback onTap;

  const _DateTimeTile({required this.icon, required this.label, required this.value, required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: accentColor),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E1E1E))),
          ],
        ),
      ),
    );
  }
}

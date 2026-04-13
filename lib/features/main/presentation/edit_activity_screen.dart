import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/data/mock_data.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:join_app/core/models/interest_model.dart';

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
  
  late String _selectedCategory;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedAgeRange;
  
  final List<String> _categories = CategoryConstants.all;
  final List<String> _ageRanges = ['Libre', '18-25 años', '18-35 años', '25-40 años', '40+ años'];
  
  String? _selectedPhotoPath;
  final List<String> _contributions = [];
  final _contributionController = TextEditingController();
  bool _isLoading = false;
  Activity? _activity;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  void _loadActivity() {
    final appState = context.read<AppState>();
    _activity = appState.activities.firstWhere(
      (a) => a.id == widget.activityId,
      orElse: () => mockActivities.firstWhere(
        (a) => a.id == widget.activityId,
        orElse: () => mockActivities[0],
      ),
    );

    // Inicializar controladores con datos existentes
    _titleController = TextEditingController(text: _activity!.title);
    _descriptionController = TextEditingController(text: _activity!.description);
    _locationController = TextEditingController(text: _activity!.location);
    _maxParticipantsController = TextEditingController(text: _activity!.maxParticipants.toString());
    
    _contributions.clear();
    _contributions.addAll(_activity!.contributions);
    
    _selectedCategory = _activity!.category;
    _selectedDate = _activity!.eventDateTime;
    _selectedTime = TimeOfDay.fromDateTime(_activity!.eventDateTime);
    _selectedAgeRange = _activity!.ageRange;
    _selectedPhotoPath = _activity!.imageUrl.isNotEmpty ? _activity!.imageUrl : null;
  }

  // Colores y datos por categoría
  static final Map<String, Color> _catColors = CategoryConstants.colors;
  static final Map<String, IconData> _catIcons = CategoryConstants.icons;

  Color get _selectedColor => _catColors[_selectedCategory] ?? const Color(0xFFFD7C36);
  IconData get _selectedIcon => _catIcons[_selectedCategory] ?? Icons.category_rounded;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    _contributionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _selectedColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _selectedColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _updateActivity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedActivity = _activity!.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
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
        tags: [_selectedCategory.toLowerCase()],
        contributions: _contributions,
      );

      await context.read<AppState>().updateActivity(updatedActivity);

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Actividad actualizada exitosamente'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activity == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: _selectedColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              TextButton.icon(
                onPressed: _isLoading ? null : _updateActivity,
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                label: Text(
                  _isLoading ? 'Guardando...' : 'Guardar',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_selectedColor, _selectedColor.withValues(alpha: 0.75)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 80, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                              child: Icon(_selectedIcon, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Editar Actividad',
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ajusta los detalles de tu evento',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(icon: Icons.edit_note_rounded, title: 'Información básica', color: _selectedColor),
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
                    _SectionHeader(icon: Icons.category_rounded, title: 'Categoría', color: _selectedColor),
                    const SizedBox(height: 12),
                    _buildCategorySelector(),
                    const SizedBox(height: 20),
                    _SectionHeader(icon: Icons.image_rounded, title: 'Foto de portada', color: _selectedColor),
                    const SizedBox(height: 12),
                    _buildPhotoSection(),
                    const SizedBox(height: 20),
                    _SectionHeader(icon: Icons.location_on_rounded, title: 'Ubicación y fecha', color: _selectedColor),
                    const SizedBox(height: 12),
                    _PremiumField(
                      controller: _locationController,
                      label: 'Dirección o lugar',
                      hint: 'Presiona para buscar en el mapa...',
                      icon: Icons.place_rounded,
                      accentColor: _selectedColor,
                      validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 12),
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
                    _SectionHeader(icon: Icons.people_alt_rounded, title: 'Participantes y edad', color: _selectedColor),
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
                    _SectionHeader(icon: Icons.card_giftcard_rounded, title: 'Aportes necesarios', color: _selectedColor, subtitle: 'Opcional'),
                    const SizedBox(height: 12),
                    _buildContributionsSection(),
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
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat;
        final color = _catColors[cat] ?? const Color(0xFFFD7C36);
        final icon = _catIcons[cat] ?? Icons.category;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: isSelected ? 0 : 1),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: isSelected ? Colors.white : color),
                const SizedBox(width: 8),
                Text(cat, style: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        );
      }).toList(),
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

  void _photoBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Seleccionar foto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: _selectedColor),
              title: const Text('Tomar foto'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.camera);
                if (image != null) setState(() => _selectedPhotoPath = image.path);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: _selectedColor),
              title: const Text('Elegir de galería'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) setState(() => _selectedPhotoPath = image.path);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('http')) return Image.network(path, fit: BoxFit.cover);
    if (path.startsWith('assets/')) return Image.asset(path, fit: BoxFit.cover);
    return Image.file(File(path), fit: BoxFit.cover);
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
    switch (_selectedCategory) {
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String? subtitle;

  const _SectionHeader({required this.icon, required this.title, required this.color, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.normal)),
        ],
      ],
    );
  }
}

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _PremiumField({required this.controller, required this.label, required this.hint, required this.icon, required this.accentColor, this.maxLines = 1, this.keyboardType, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
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

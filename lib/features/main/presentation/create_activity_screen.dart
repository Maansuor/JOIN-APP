import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/features/main/presentation/map_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:join_app/core/models/interest_model.dart';

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

  String _selectedCategory = 'Deportes';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  String _selectedAgeRange = '18-35 años';
  String? _selectedPhotoPath;
  LatLng? _selectedLocation;
  final List<String> _contributions = [];
  final _contributionController = TextEditingController();

  final List<String> _categories = CategoryConstants.all;
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
  static final Map<String, Color> _catColors = CategoryConstants.colors;
  static final Map<String, IconData> _catIcons = CategoryConstants.icons;

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
    _scrollController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    HapticFeedback.selectionClick();
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
              onSurface: AppColors.navyBlue,
            ),
            dialogTheme: const DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
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
    HapticFeedback.selectionClick();
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
              onSurface: AppColors.navyBlue,
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

  void _createActivity() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final appState = context.read<AppState>();
      final currentUser = appState.currentUser;
      
      final newActivity = Activity(
        id: '', // Lo genera el backend
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
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
        tags: [_selectedCategory.toLowerCase()],
        contributions: _contributions,
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
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, a1, a2) => const SizedBox(),
      transitionBuilder: (ctx, animation, _, __) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              contentPadding: EdgeInsets.zero,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_selectedColor, _selectedColor.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '¡Actividad Creada!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          '${_titleController.text} está lista para recibir participantes.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              context.go('/main');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '¡Genial!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
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
                  // Botón crear en appbar
                  TextButton.icon(
                    onPressed: _isLoading ? null : _createActivity,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18),
                    label: Text(
                      _isLoading ? 'Creando...' : 'Crear',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _selectedColor,
                          _selectedColor.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 8, 80, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_selectedIcon,
                                      color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Nueva Actividad',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Organiza algo increíble · $_selectedCategory',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
                        _SectionHeader(
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
                        _SectionHeader(
                          icon: Icons.category_rounded,
                          title: 'Categoría',
                          color: _selectedColor,
                        ),
                        const SizedBox(height: 12),

                        _buildCategorySelector(),
                        const SizedBox(height: 20),

                        // ── Sección: Foto ─────────────────────
                        _SectionHeader(
                          icon: Icons.image_rounded,
                          title: 'Foto de referencia',
                          color: _selectedColor,
                        ),
                        const SizedBox(height: 12),

                        _buildPhotoSection(),
                        const SizedBox(height: 20),

                        // ── Sección: Ubicación ────────────────
                        _SectionHeader(
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
                        const SizedBox(height: 12),

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
                        _SectionHeader(
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
                        _SectionHeader(
                          icon: Icons.card_giftcard_rounded,
                          title: 'Aportes necesarios',
                          color: _selectedColor,
                          subtitle: 'Opcional',
                        ),
                        const SizedBox(height: 12),

                        _buildContributionsSection(),
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

          // ── Tips flotante ─────────────────────────────────────
          _buildTipsFab(),
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
        final color = _catColors[cat] ?? AppColors.primaryOrange;
        final icon = _catIcons[cat] ?? Icons.category;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedCategory = cat);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade200,
                width: isSelected ? 0 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : color,
                ),
                const SizedBox(width: 8),
                Text(
                  cat,
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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

  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Seleccionar foto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navyBlue,
              ),
            ),
            const SizedBox(height: 20),
            _SheetOption(
              icon: Icons.camera_alt_rounded,
              label: 'Tomar foto',
              color: _selectedColor,
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                if (image != null) {
                  setState(() {
                    _selectedPhotoPath = image.path;
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            _SheetOption(
              icon: Icons.photo_library_rounded,
              label: 'Elegir de galería',
              color: _selectedColor,
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (image != null) {
                  setState(() {
                    _selectedPhotoPath = image.path;
                  });
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover);
    } else if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    } else {
      return Image.file(File(path), fit: BoxFit.cover);
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

  Widget _buildTipsFab() {
    final recs = _getRecommendationsForCategory(_selectedCategory);
    if (recs.isEmpty) return const SizedBox.shrink();

    return Positioned(
      right: 20,
      bottom: 20,
      child: GestureDetector(
        onTap: () => _showTipsModal(recs),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_selectedColor, _selectedColor.withValues(alpha: 0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _selectedColor.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tips',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTipsModal(List<String> recs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_selectedColor, _selectedColor.withValues(alpha: 0.75)],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_selectedIcon,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recomendaciones Pro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _selectedCategory.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ...recs.asMap().entries.map((e) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration:
                          Duration(milliseconds: 300 + e.key * 80),
                      curve: Curves.easeOut,
                      builder: (_, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(20 * (1 - value), 0),
                          child: child,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _selectedColor
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${e.key + 1}',
                                  style: TextStyle(
                                    color: _selectedColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: AppColors.navyBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedColor,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '¡Entendido, gracias!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getRecommendationsForCategory(String category) {
    switch (category) {
      case 'Deportes':
        return [
          'Lleva agua suficiente para todos los participantes',
          'No olvides protector solar y ropa cómoda',
          'Considera llevar un botiquín de primeros auxilios',
          'Confirma el nivel físico requerido en la descripción',
        ];
      case 'Comida':
        return [
          'Verifica restricciones alimentarias de los participantes',
          'Lleva servilletas y cubiertos de más',
          'Incluye opciones vegetarianas/veganas',
          'No olvides bolsas para la basura y mantener el lugar limpio',
        ];
      case 'Naturaleza':
        return [
          'Lleva repelente de insectos y protector solar',
          'Trae una manta o silla plegable para descansar',
          'No olvides bolsa para tu basura (deja el lugar mejor de cómo lo encontraste)',
          'Llevar una linterna si la actividad puede extenderse',
        ];
      case 'Chill':
        return [
          'Prepara una playlist colaborativa con los participantes',
          'Lleva juegos de mesa o cartas para romper el hielo',
          'Ten opciones de bebidas calientes y frías',
          'Considera la comodidad del espacio para todos',
        ];
      case 'Juntas':
        return [
          'Establece un punto de encuentro exacto y visible',
          'Considera transporte compartido o comparte rutas',
          'Ten un plan B en caso de cambios de clima o lugar',
          'Lleva un powerbank extra para mantener la comunicación',
        ];
      default:
        return [];
    }
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

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.navyBlue,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
        transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
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

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:join_app/core/models/interest_model.dart';

/// Hoja para elegir la portada de una actividad.
///
/// Ofrece primero las portadas sugeridas para su categoría —para que quien no
/// tenga una foto propia no se quede con una imagen genérica que no pega— y
/// debajo las opciones de cámara y galería.
///
/// Devuelve la ruta elegida (un asset o un archivo del dispositivo) o null si
/// se cerró sin elegir.
Future<String?> showCoverPickerSheet(
  BuildContext context, {
  required String category,
  required Color accent,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CoverPickerSheet(
      category: category,
      accent: accent,
      selected: selected,
    ),
  );
}

class _CoverPickerSheet extends StatelessWidget {
  final String category;
  final Color accent;
  final String? selected;

  const _CoverPickerSheet({
    required this.category,
    required this.accent,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fondo = isDark ? const Color(0xFF161920) : Colors.white;
    final textoPrincipal = isDark ? Colors.white : const Color(0xFF041249);

    final principal = CategoryConstants.mainCategoryOf(category);
    final portadas = CategoryConstants.coversFor(category);
    final propias = CategoryConstants.covers[principal]?.length ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Portada del plan',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textoPrincipal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            principal != null
                ? 'Sugeridas para $principal, o sube la tuya'
                : 'Elige una sugerida o sube la tuya',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 14),

          // ── Portadas sugeridas ────────────────────────────────
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: portadas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final ruta = portadas[index];
                // Una línea separa las de su categoría del resto.
                final esDeOtraCategoria = index >= propias;

                return _Miniatura(
                  ruta: ruta,
                  accent: accent,
                  atenuada: esDeOtraCategoria,
                  seleccionada: selected == ruta,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, ruta);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 18),
          Divider(color: isDark ? Colors.white12 : Colors.grey[200], height: 1),
          const SizedBox(height: 14),

          // ── Foto propia ───────────────────────────────────────
          _Opcion(
            icon: Icons.camera_alt_rounded,
            label: 'Tomar foto',
            accent: accent,
            isDark: isDark,
            onTap: () => _elegirFoto(context, ImageSource.camera),
          ),
          const SizedBox(height: 10),
          _Opcion(
            icon: Icons.photo_library_rounded,
            label: 'Subir imagen propia',
            accent: accent,
            isDark: isDark,
            onTap: () => _elegirFoto(context, ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  Future<void> _elegirFoto(BuildContext context, ImageSource source) async {
    // Se captura antes del await: al volver, este context ya no está montado.
    final navigator = Navigator.of(context);
    final imagen = await ImagePicker().pickImage(source: source, imageQuality: 70);
    navigator.pop(imagen?.path);
  }
}

class _Miniatura extends StatelessWidget {
  final String ruta;
  final Color accent;
  final bool seleccionada;
  final bool atenuada;
  final VoidCallback onTap;

  const _Miniatura({
    required this.ruta,
    required this.accent,
    required this.seleccionada,
    required this.atenuada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 124,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionada ? accent : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: atenuada ? 0.55 : 1,
                child: Image.asset(
                  ruta,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: accent.withValues(alpha: 0.15),
                    child: Icon(Icons.image_not_supported_rounded,
                        color: accent, size: 22),
                  ),
                ),
              ),
              if (seleccionada)
                Container(
                  color: accent.withValues(alpha: 0.25),
                  child: const Center(
                    child: Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _Opcion({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF6F8FC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 19),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF041249),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

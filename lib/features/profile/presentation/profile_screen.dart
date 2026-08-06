import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/models/user_model.dart';
import 'package:join_app/core/models/activity_model.dart';
import 'package:join_app/core/theme/app_colors.dart';
import 'package:join_app/core/models/interest_model.dart';
import 'package:join_app/core/models/clan_model.dart';
import 'edit_profile_screen.dart';

// ══════════════════════════════════════════════════════════════
//  ProfileScreen — Rediseño Premium y Totalmente Funcional
// ══════════════════════════════════════════════════════════════
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Diálogo de confirmación de cierre de sesión
  void _confirmLogout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161920) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark ? [] : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
            border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D1F21) : const Color(0xFFFFEEEB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFE53935),
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Cerrar sesión',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF041249),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '¿Seguro que quieres salir? Tendrás\nque iniciar sesión de nuevo.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : const Color(0xFF041249).withValues(alpha: 0.55),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF041249).withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF041249),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await context.read<AppState>().logout();
                        if (context.mounted) context.go('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Salir',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Modal de Privacidad Real conectado a Supabase ────────────────
  void _showPrivacySettings(BuildContext context, UserModel user) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        bool isAgeVisible = user.ageVisible;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161920) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryOrange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Privacidad del Perfil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF041249),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Controla cómo se muestra tu información a otros miembros en Chiclayo.',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
                          ),
                          child: Icon(Icons.cake_outlined, color: isDark ? Colors.white : const Color(0xFF041249), size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mostrar mi edad',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF041249),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Permite que otros usuarios vean tu edad calculada en tu perfil.',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[500], height: 1.25),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: isAgeVisible,
                          activeColor: AppColors.primaryOrange,
                          onChanged: (val) async {
                            HapticFeedback.lightImpact();
                            setModalState(() => isAgeVisible = val);
                            await context.read<AppState>().updateProfile(ageVisible: val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
                          ),
                          child: const Icon(Icons.verified_rounded, color: Color(0xFF1877F2), size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Perfil verificado',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF041249),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'La insignia se otorga al superar una puntuación de 4.5 estrellas en 5 actividades.',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[500], height: 1.25),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          user.isVerified ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                          color: user.isVerified ? const Color(0xFF4CAF50) : Colors.grey[400],
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Modal de Rango de Búsqueda Premium ──────────────────────────
  void _showSearchRangeSettings(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final appState = context.read<AppState>();
        double currentRadius = appState.searchRadius;
        
        return StatefulBuilder(
          builder: (context, setModalState) {
            String rangeLabelText = 'Solo mi distrito';
            if (currentRadius > 0 && currentRadius < 100) {
              rangeLabelText = 'Hasta ${currentRadius.toInt()} km a la redonda';
            } else if (currentRadius >= 100) {
              rangeLabelText = 'Rango ampliado (100+ km / Todo el departamento)';
            }
            
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161920) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.explore_rounded, color: AppColors.primaryOrange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Rango de Búsqueda',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF041249),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Expande el rango geográfico para descubrir increíbles actividades y personas en distritos o provincias cercanas.',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF718096), height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  
                  // Visual Range Value Display
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me_rounded, size: 16, color: AppColors.primaryOrange),
                          const SizedBox(width: 8),
                          Text(
                            rangeLabelText,
                            style: const TextStyle(
                              color: AppColors.primaryOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primaryOrange,
                      inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      trackHeight: 6.0,
                      thumbColor: AppColors.primaryOrange,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                      overlayColor: AppColors.primaryOrange.withValues(alpha: 0.1),
                      valueIndicatorColor: AppColors.primaryOrange,
                      valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    child: Slider(
                      value: currentRadius,
                      min: 0.0,
                      max: 100.0,
                      divisions: 5,
                      label: currentRadius == 0.0
                          ? 'Mi distrito'
                          : currentRadius == 100.0
                              ? 'Todo'
                              : '${currentRadius.toInt()} km',
                      onChanged: (double val) {
                        HapticFeedback.selectionClick();
                        setModalState(() {
                          currentRadius = val;
                        });
                      },
                    ),
                  ),
                  
                  // Labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mi distrito', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey)),
                        Text('50 km', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey)),
                        Text('Todo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                        await appState.updateSearchRadius(currentRadius);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      currentRadius == 0.0
                                          ? '¡Búsqueda configurada estrictamente en tu distrito!'
                                          : '¡Rango de búsqueda ampliado a ${currentRadius.toInt()} km!',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.primaryOrange.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('GUARDAR AJUSTES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Modal de Notificaciones Interactivo ────────────────────────
  void _showNotificationSettings(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        bool isPushEnabled = true;
        bool isNewPlansEnabled = true;
        bool isChatEnabled = true;
        bool isHennessyEnabled = true;
        
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161920) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notifications_active_outlined, color: AppColors.primaryOrange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Notificaciones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF041249),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Elige cómo y cuándo deseas recibir alertas sobre las actividades en Chiclayo.',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  _buildNotificationToggle(
                    title: 'Permitir notificaciones push',
                    subtitle: 'Activar o desactivar todas las alertas del sistema.',
                    icon: Icons.notifications_none_rounded,
                    value: isPushEnabled,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      setModalState(() {
                        isPushEnabled = val;
                        if (!val) {
                          isNewPlansEnabled = false;
                          isChatEnabled = false;
                          isHennessyEnabled = false;
                        } else {
                          isNewPlansEnabled = true;
                          isChatEnabled = true;
                          isHennessyEnabled = true;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildNotificationToggle(
                    title: 'Nuevas actividades sugeridas',
                    subtitle: 'Recibe alertas sobre planes afines a tus intereses.',
                    icon: Icons.explore_outlined,
                    value: isNewPlansEnabled,
                    enabled: isPushEnabled,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      setModalState(() => isNewPlansEnabled = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildNotificationToggle(
                    title: 'Mensajes de chats grupales',
                    subtitle: 'Alertas de nuevos mensajes en los chats de tus planes activos.',
                    icon: Icons.chat_bubble_outline_rounded,
                    value: isChatEnabled,
                    enabled: isPushEnabled,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      setModalState(() => isChatEnabled = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildNotificationToggle(
                    title: 'Sugerencias de Hennessy',
                    subtitle: 'Recomendaciones y cambios camaleónicos de tu guía de aventuras.',
                    icon: Icons.auto_awesome_rounded,
                    value: isHennessyEnabled,
                    enabled: isPushEnabled,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      setModalState(() => isHennessyEnabled = val);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8F9FD),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
                  ),
                  child: Icon(icon, color: isDark ? Colors.white : const Color(0xFF041249), size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF041249),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[500], height: 1.25),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: value,
                  activeColor: AppColors.primaryOrange,
                  onChanged: enabled ? onChanged : null,
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  // ── Modal de Soporte con Enrutamiento Directo a Hennessy ──────
  void _showHelpSupport(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161920) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.help_outline_rounded, color: AppColors.primaryOrange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Ayuda y Soporte',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF041249),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Encuentra respuestas rápidas o reporta problemas técnicos de la app.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              _buildSupportTile(
                context: context,
                title: 'Hablar con Hennessy Asistente',
                subtitle: 'Consulta sobre el funcionamiento de Join, limpieza de 5h, etc.',
                icon: Icons.smart_toy_rounded,
                iconColor: AppColors.primaryOrange,
                onTap: () {
                  Navigator.pop(context); // Cerrar bottom sheet
                  context.push('/main/hennessy'); // Redirigir a Hennessy
                },
              ),
              const SizedBox(height: 12),
              _buildSupportTile(
                context: context,
                title: 'Preguntas Frecuentes (FAQ)',
                subtitle: 'Preguntas y guías rápidas para organizadores y miembros.',
                icon: Icons.quiz_outlined,
                iconColor: const Color(0xFF5E35B1),
                onTap: () {
                  Navigator.pop(context);
                  _showFAQDialog(context);
                },
              ),
              const SizedBox(height: 12),
              _buildSupportTile(
                context: context,
                title: 'Reportar un problema técnico',
                subtitle: '¿Encontraste un error? Infórmanos para solucionarlo de inmediato.',
                icon: Icons.bug_report_outlined,
                iconColor: const Color(0xFFE53935),
                onTap: () {
                  Navigator.pop(context);
                  _showReportBugDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupportTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8F9FD),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF041249),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[500], height: 1.25),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showFAQDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161920) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1) : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preguntas Frecuentes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF041249)),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _buildFAQItem(
                        context,
                        '¿Es Join gratis?',
                        '¡Sí! Join es una plataforma 100% libre para proponer planes, chatear y conocer gente grandiosa en el mundo real.',
                      ),
                      _buildFAQItem(
                        context,
                        '¿Qué son los aportes?',
                        'Son recursos que los organizadores solicitan a los asistentes para que el plan funcione (ej: parlantes, piqueos, cuotas). ¡Todo se divide de forma justa!',
                      ),
                      _buildFAQItem(
                        context,
                        '¿Qué es la política de 5 horas?',
                        'Exactamente 5 horas después de terminar un plan, eliminamos toda la actividad y chats permanentemente para proteger tu privacidad y mantener fresco el feed.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.help_outline_rounded, size: 16, color: AppColors.primaryOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF041249)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[600], height: 1.4),
          ),
        ],
      ),
    );
  }

  void _showReportBugDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161920) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1) : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reportar un problema',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF041249)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Describe qué ocurrió para que podamos solucionarlo.',
                  style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white54 : Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Detalla el problema aquí...',
                    fillColor: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8F9FD),
                    filled: true,
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey[400], fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF041249).withValues(alpha: 0.15)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF041249), fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (controller.text.trim().isEmpty) return;
                          Navigator.pop(context);
                          HapticFeedback.mediumImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.white),
                                  SizedBox(width: 10),
                                  Text('¡Reporte enviado! Gracias por ayudarnos a mejorar.'),
                                ],
                              ),
                              backgroundColor: const Color(0xFF4CAF50),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Enviar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Modal de Acerca de Join (Créditos Accuracy Nexus) ───────────
  void _showAboutJoin(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161920) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: AppColors.primaryOrange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Acerca de Join',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF041249),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Image.asset('assets/images/join.png', height: 72, width: 72),
              const SizedBox(height: 12),
              Text(
                'Join App',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF041249), letterSpacing: -0.5),
              ),
              Text(
                'Versión 1.2.0 (Build 312)',
                style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Join es una red social diseñada para la vida real. Promovemos planes de valor en Chiclayo, reduciendo el tiempo de pantalla y reuniendo a personas en base a intereses compartidos de forma directa y limpia.\n\nDesarrollado y mantenido con orgullo por Accuracy Nexus.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white70 : Colors.grey[600], height: 1.5),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFF041249),
                    foregroundColor: isDark ? Colors.white : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF5F7FB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar Pinned con flexibleSpace estilizado ─────────
          SliverAppBar(
            expandedHeight: 265,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF5F7FB),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF041249).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: _ProfileHero(user: user),
            ),
          ),

          // ── Cuerpo de la pantalla ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cuadrícula de estadísticas estilizada
                  _StatsRow(user: user),
                  const SizedBox(height: 20),

                  // Información personal
                  _SectionCard(
                    title: 'Información personal',
                    icon: Icons.person_outline_rounded,
                    children: [
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Correo electrónico',
                        value: user.email ?? 'No registrado',
                      ),
                      if (user.phone != null && user.phone!.isNotEmpty)
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Teléfono',
                          value: user.phone!,
                        ),
                      if (user.birthDate != null) ...[
                        _InfoRow(
                          icon: Icons.cake_outlined,
                          label: 'Fecha de nacimiento',
                          value: DateFormat('d \'de\' MMMM \'de\' yyyy', 'es').format(user.birthDate!),
                        ),
                        if (user.ageVisible)
                          _InfoRow(
                            icon: Icons.today_outlined,
                            label: 'Edad',
                            value: '${user.age} años',
                            isLast: user.gender == UserGender.preferNotToSay,
                          ),
                      ],
                      _InfoRow(
                        icon: Icons.wc_outlined,
                        label: 'Género',
                        value: _genderLabel(user.gender),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bio
                  if (user.bio.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Sobre mí',
                      icon: Icons.notes_rounded,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Text(
                            user.bio,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF041249).withValues(alpha: 0.7),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Intereses en cápsulas pasteles
                  if (user.interests.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Intereses',
                      icon: Icons.interests_outlined,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: user.interests.map((interest) {
                              final normalized = interest.trim();
                              // Búsqueda insensible a mayúsculas en CategoryConstants para encontrar el nombre exacto de la categoría
                              final matchedKey = CategoryConstants.all.firstWhere(
                                (cat) => cat.toLowerCase() == normalized.toLowerCase(),
                                orElse: () => '',
                              );

                              final chipIcon = matchedKey.isNotEmpty
                                  ? (CategoryConstants.icons[matchedKey] ?? Icons.interests_rounded)
                                  : Icons.interests_rounded;

                              final chipColor = matchedKey.isNotEmpty
                                  ? (CategoryConstants.colors[matchedKey] ?? AppColors.primaryOrange)
                                  : AppColors.primaryOrange;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: chipColor.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: chipColor.withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      chipIcon,
                                      color: chipColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      interest.substring(0, 1).toUpperCase() + interest.substring(1),
                                      style: TextStyle(
                                        color: chipColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Mural de Recuerdos
                  _RecuerdosMuralSection(user: user),
                  const SizedBox(height: 16),

                  // Clanes de la Comunidad
                  _ClanesSection(user: user),
                  const SizedBox(height: 16),

                  // Configuración de menú interactivo
                  _SectionCard(
                    title: 'Configuración',
                    icon: Icons.settings_outlined,
                    children: [
                      _SettingsTile(
                        icon: Icons.lock_outline_rounded,
                        label: 'Privacidad',
                        onTap: () => _showPrivacySettings(context, user),
                      ),
                      Consumer<AppState>(
                        builder: (context, appState, _) {
                          final isDarkLocal = appState.isDarkMode;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.navyBlue.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isDarkLocal ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                                        color: isDark ? Colors.white : AppColors.navyBlue,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        'Modo Oscuro',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF041249),
                                        ),
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: isDarkLocal,
                                      activeColor: AppColors.primaryOrange,
                                      onChanged: (val) {
                                        HapticFeedback.lightImpact();
                                        appState.toggleTheme(val);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, indent: 66, color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFF041249).withValues(alpha: 0.04)),
                            ],
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        label: 'Notificaciones',
                        onTap: () => _showNotificationSettings(context),
                      ),
                      _SettingsTile(
                        icon: Icons.map_outlined,
                        label: 'Rango de búsqueda',
                        onTap: () => _showSearchRangeSettings(context),
                      ),
                      _SettingsTile(
                        icon: Icons.help_outline_rounded,
                        label: 'Ayuda y soporte',
                        onTap: () => _showHelpSupport(context),
                      ),
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        label: 'Acerca de Join',
                        onTap: () => _showAboutJoin(context),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Botón Cerrar Sesión Estilizado (Crimson Suave Premium)
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEB),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFCA5A5),
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _confirmLogout(context),
                        borderRadius: BorderRadius.circular(18),
                        highlightColor: const Color(0xFFFEE2E2),
                        splashColor: const Color(0xFFFECACA),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFE53935),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Cerrar sesión',
                              style: TextStyle(
                                color: Color(0xFFE53935),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _MadeWithNexusBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _genderLabel(UserGender gender) {
    switch (gender) {
      case UserGender.male:
        return 'Masculino';
      case UserGender.female:
        return 'Femenino';
      case UserGender.nonBinary:
        return 'No binario';
      case UserGender.preferNotToSay:
        return 'Prefiero no decir';
    }
  }
}

// ── Hero del perfil (header estilizado) ─────────────────────────
class _ProfileHero extends StatelessWidget {
  final UserModel user;
  const _ProfileHero({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      color: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF5F7FB),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Banner de Portada con degradado mesh premium y esquinas redondeadas
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFA000), // Naranja ámbar brillante
                    Color(0xFFFD7C36), // Naranja corporativo insignia
                    Color(0xFFFF3D00), // Naranja profundo / coral vibrante
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Stack(
                children: [
                  // Orbe de luz superior derecho
                  Positioned(
                    right: -40,
                    top: -40,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  // Orbe de luz izquierdo
                  Positioned(
                    left: -20,
                    top: 20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFD7C36).withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Información del perfil centrada flotando
          Positioned(
            top: 80, // Ajustado para que el avatar de 96px quede centrado a la mitad (140 - 48 = 92, usamos 80 para espacio balanceado)
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar con borde blanco grueso y sombra premium
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF041249).withValues(alpha: 0.12),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: user.isAssetImage
                            ? Image.asset(user.profileImageUrl, fit: BoxFit.cover)
                            : (user.profileImageUrl.isNotEmpty
                                ? Image.network(
                                    user.fullProfileImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _InitialsAvatar(name: user.name),
                                  )
                                : _InitialsAvatar(name: user.name)),
                      ),
                    ),
                    if (user.isVerified)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF1877F2),
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Nombre del Usuario
                Text(
                  user.name,
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.white : AppColors.navyBlue,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                // Correo del Usuario
                if (user.email != null)
                  Text(
                    user.email!,
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.45),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (user.searchCode.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: user.searchCode));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Código de búsqueda "${user.searchCode}" copiado al portapapeles.'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.primaryOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.primaryOrange.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_rounded,
                            size: 13,
                            color: isDark ? Colors.white70 : AppColors.primaryOrange,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            user.searchCode,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.primaryOrange,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 11,
                            color: isDark ? Colors.white30 : AppColors.primaryOrange.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Fila de Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: isDark ? const Color(0xFF161920) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text('Puntuación Join', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF041249))),
                              ],
                            ),
                            content: Text(
                              'Tu puntuación es calculada automáticamente en base al promedio de las reseñas recibidas de parte de otros usuarios después de que asisten a tus planes organizados.',
                              style: TextStyle(fontSize: 14, height: 1.45, color: isDark ? Colors.white70 : Colors.black87),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Entendido', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E222B) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: isDark ? [] : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _PillBadge(
                          icon: Icons.star_rounded,
                          label: user.rating.toStringAsFixed(1),
                          color: const Color(0xFFFFC107),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: isDark ? [] : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _PillBadge(
                        icon: Icons.calendar_today_outlined,
                        label: 'Desde ${DateFormat('MMM yyyy', 'es').format(user.joinedDate)}',
                        color: isDark ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fila de estadísticas (dashboard premium) ─────────────────────
class _StatsRow extends StatelessWidget {
  final UserModel user;
  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: const Color(0xFF041249).withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF041249).withValues(alpha: 0.01),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02), width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatItem(
              value: '${user.activitiesAttended}',
              label: 'Asistidas',
              icon: Icons.event_available_outlined,
              themeColor: const Color(0xFF10B981),
            ),
            VerticalDivider(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05), width: 1, indent: 6, endIndent: 6),
            _StatItem(
              value: '${user.activitiesCreated}',
              label: 'Organizadas',
              icon: Icons.rocket_launch_outlined,
              themeColor: AppColors.primaryOrange,
            ),
            VerticalDivider(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05), width: 1, indent: 6, endIndent: 6),
            _StatItem(
              value: user.rating.toStringAsFixed(1),
              label: 'Puntuación',
              icon: Icons.workspace_premium_outlined,
              themeColor: const Color(0xFFF59E0B),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color themeColor;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    this.themeColor = AppColors.primaryOrange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: themeColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF041249),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF041249).withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de sección ──────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: const Color(0xFF041249).withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF041249).withValues(alpha: 0.01),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.primaryOrange, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: isDark ? Colors.white : const Color(0xFF041249),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFF041249).withValues(alpha: 0.05)),
          ...children,
        ],
      ),
    );
  }
}

// ── Fila de info personal ────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF0F2F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: isDark ? Colors.white : const Color(0xFF53649F), size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : const Color(0xFF041249).withValues(alpha: 0.45),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF041249),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 66, color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFF041249).withValues(alpha: 0.04)),
      ],
    );
  }
}

// ── Tile de configuración ────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: isLast 
                ? const BorderRadius.vertical(bottom: Radius.circular(24))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.navyBlue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: isDark ? Colors.white : AppColors.navyBlue, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF041249),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white54 : const Color(0xFF041249).withValues(alpha: 0.35),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 66, color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFF041249).withValues(alpha: 0.04)),
      ],
    );
  }
}

// ── Avatar con iniciales ─────────────────────────────────────
class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';
    return Container(
      color: AppColors.primaryOrange,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ── Pill badge pequeño ───────────────────────────────────────
class _PillBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _PillBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Made with Nexus Banner (Footer Premium Animado) ───────────────────
class _MadeWithNexusBanner extends StatelessWidget {
  const _MadeWithNexusBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Hecho con ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : const Color(0xFF041249).withValues(alpha: 0.4),
              ),
            ),
            const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFE53935),
              size: 14,
            ).animate(onPlay: (c) => c.repeat())
             .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 1.seconds, curve: Curves.easeInOut)
             .then()
             .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1), duration: 1.seconds, curve: Curves.easeInOut),
            Text(
              ' por ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : const Color(0xFF041249).withValues(alpha: 0.4),
              ),
            ),
            Text(
              'Accuracy Nexus',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF041249),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Join App v1.2.0 · Todos los derechos reservados',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white38 : const Color(0xFF041249).withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}

class _RecuerdosMuralSection extends StatelessWidget {
  final UserModel user;
  const _RecuerdosMuralSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final activityRepo = context.read<AppState>().activityRepository;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _SectionCard(
      title: 'Mural de Recuerdos',
      icon: Icons.photo_library_outlined,
      children: [
        FutureBuilder<List<Activity>>(
          future: activityRepo.getCompletedActivitiesForUser(user.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryOrange),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error al cargar recuerdos: ${snapshot.error}',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              );
            }

            final completedList = snapshot.data ?? [];
            if (completedList.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.collections_rounded,
                        color: AppColors.primaryOrange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aún no hay recuerdos de aventuras',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF041249),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Las aventuras finalizadas en las que participes se convertirán en murales aquí.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF041249).withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 180,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: completedList.length,
                itemBuilder: (context, index) {
                  final activity = completedList[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/main/activity/${activity.id}/photos');
                      },
                      child: Container(
                        width: 140,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Imagen de la actividad
                              activity.imageUrl.isNotEmpty
                                  ? (activity.imageUrl.startsWith('assets/')
                                      ? Image.asset(activity.imageUrl, fit: BoxFit.cover)
                                      : Image.network(
                                          activity.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, _, __) => Container(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF7F5),
                                            child: const Icon(Icons.image, color: AppColors.primaryOrange, size: 28),
                                          ),
                                        ))
                                  : Container(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF7F5),
                                      child: const Icon(Icons.image, color: AppColors.primaryOrange, size: 28),
                                    ),
                              // Degradado oscuro para que el texto sea legible
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black54,
                                    ],
                                  ),
                                ),
                              ),
                              // Título y Fecha
                              Positioned(
                                bottom: 10,
                                left: 10,
                                right: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      activity.title,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('d MMM yyyy', 'es').format(activity.eventDateTime),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Badge de Cámara flotante
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: AppColors.primaryOrange,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1.0, 1.0),
                          duration: 300.ms,
                          delay: (index * 50).ms,
                          curve: Curves.easeOutBack,
                        ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ClanesSection extends StatelessWidget {
  final UserModel user;
  const _ClanesSection({required this.user});

  void _showCreateClan(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _CreateClanSheet(),
    );
  }

  void _showClanDetails(BuildContext context, Clan clan) {
    HapticFeedback.mediumImpact();
    context.push('/clan/${clan.id}/info', extra: clan);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final clans = context.watch<AppState>().userClans;

    return _SectionCard(
      title: 'Mis Clanes',
      icon: Icons.groups_outlined,
      children: [
        if (clans.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.group_add_rounded,
                    color: AppColors.primaryOrange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No tienes ningún Clan creado o unido',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF041249),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Crea un clan para inscribirte en grupo a tus planes preferidos con un solo clic.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showCreateClan(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Crear mi primer Clan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: clans.length + 1,
                    itemBuilder: (context, index) {
                      if (index == clans.length) {
                        return GestureDetector(
                          onTap: () => _showCreateClan(context),
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E222B) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFF041249).withValues(alpha: 0.06),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: AppColors.primaryOrange,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Nuevo Clan',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final clan = clans[index];
                      return GestureDetector(
                        onTap: () => _showClanDetails(context, clan),
                        child: Container(
                          width: 150,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF1E222B), const Color(0xFF161920)]
                                  : [const Color(0xFFFFECE7), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : AppColors.primaryOrange.withValues(alpha: 0.1),
                              width: 1,
                            ),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: AppColors.primaryOrange.withValues(alpha: 0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
                                    backgroundImage: clan.avatarUrl != null && clan.avatarUrl!.isNotEmpty
                                        ? NetworkImage(clan.avatarUrl!)
                                        : null,
                                    child: clan.avatarUrl == null || clan.avatarUrl!.isEmpty
                                        ? Text(
                                            clan.name.substring(0, 1).toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryOrange,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const Spacer(),
                                  if (clan.creatorId == user.id)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryOrange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Líder',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryOrange,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  clan.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF041249),
                                  ),
                                ),
                              ),
                              FutureBuilder<List<ClanMember>>(
                                future: context.read<AppState>().getClanMembers(clan.id),
                                builder: (context, snap) {
                                  final count = snap.data?.length ?? 1;
                                  return Text(
                                    '$count miembro${count == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ).animate().fade(duration: 200.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CreateClanSheet extends StatefulWidget {
  const _CreateClanSheet();

  @override
  State<_CreateClanSheet> createState() => _CreateClanSheetState();
}

class _CreateClanSheetState extends State<_CreateClanSheet> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final List<UserModel> _selectedUsers = [];
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
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
    final currentUserId = context.read<AppState>().currentUser?.id;
    final filtered = results.where((u) => u.id != currentUserId).toList();
    setState(() {
      _searchResults = filtered;
      _isSearching = false;
    });
  }

  void _createClan() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa el nombre del Clan')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final appState = context.read<AppState>();
    final success = await appState.createClan(
      name,
      memberUserIds: _selectedUsers.map((u) => u.id).toList(),
    );

    setState(() => _isSaving = false);
    if (success) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('¡El clan "$name" se ha creado con éxito!')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.error ?? 'Error al crear el clan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161920) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C3AED), AppColors.primaryOrange],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crear un nuevo Clan',
                      style: GoogleFonts.outfit(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF041249),
                      ),
                    ),
                    Text(
                      'Tu squad para unirse a planes con un clic',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Comparte tu código para que te encuentren ─────────
          Builder(builder: (context) {
            final myCode =
                context.read<AppState>().currentUser?.searchCode ?? '';
            if (myCode.isEmpty) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Clipboard.setData(ClipboardData(text: myCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Código $myCode copiado. ¡Compártelo!')),
                      ],
                    ),
                    backgroundColor: const Color(0xFF7C3AED),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded,
                        color: Color(0xFF7C3AED), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tu código: $myCode · tus amigos te encuentran con él',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ),
                    const Icon(Icons.copy_rounded,
                        color: Color(0xFF7C3AED), size: 15),
                  ],
                ),
              ),
            );
          }),

          TextField(
            controller: _nameController,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF041249)),
            decoration: InputDecoration(
              labelText: 'Nombre del Clan',
              hintText: 'Ej: Los del Barrio, Senderistas Pro...',
              prefixIcon: const Icon(Icons.edit_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_selectedUsers.isNotEmpty) ...[
            Text(
              'Miembros seleccionados (${_selectedUsers.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedUsers.length,
                itemBuilder: (context, index) {
                  final u = _selectedUsers[index];
                  return Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: u.profileImageUrl.isNotEmpty
                                  ? NetworkImage(u.profileImageUrl)
                                  : null,
                              child: u.profileImageUrl.isEmpty
                                  ? Text(u.name.substring(0, 1).toUpperCase())
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              u.name.split(' ')[0],
                              style: const TextStyle(fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        Positioned(
                          top: 0,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedUsers.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _searchController,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF041249)),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              labelText: 'Invitar amigos',
              hintText: 'Nombre, correo o código J-XXXXXX...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
              ),
            ),
          ),
          
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8F9FD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                ),
                itemBuilder: (context, index) {
                  final u = _searchResults[index];
                  final isAlreadySelected = _selectedUsers.any((selected) => selected.id == u.id);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: u.profileImageUrl.isNotEmpty
                          ? NetworkImage(u.profileImageUrl)
                          : null,
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
                    subtitle: Text(
                      u.email ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: isAlreadySelected
                        ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
                        : TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedUsers.add(u);
                                _searchController.clear();
                                _searchResults = [];
                              });
                            },
                            child: const Text('Agregar', style: TextStyle(fontSize: 12, color: AppColors.primaryOrange)),
                          ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 24),
          
          GestureDetector(
            onTap: _isSaving ? null : _createClan,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSaving
                      ? [Colors.grey.shade400, Colors.grey.shade500]
                      : [const Color(0xFF7C3AED), AppColors.primaryOrange],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: _isSaving
                    ? []
                    : [
                        BoxShadow(
                          color:
                              const Color(0xFF7C3AED).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ],
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Fundar mi Clan',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: Colors.white,
                            ),
                          ),
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




import 'package:flutter/material.dart';

class AuthService {
  static String? _currentUser;
  static String? _currentUserAvatar;

  // Simulación de usuarios administradores por actividad
  // Juan Pérez García es el creador de todas las actividades existentes
  static final Map<String, String> _activityAdmins = {
    '1': 'Juan Pérez García', // Caminada al Atardecer
    '2': 'Juan Pérez García', // Fútbol Amistoso
    '3': 'Juan Pérez García', // Parrillada Dominical
    '4': 'Juan Pérez García', // Yoga Matutino
    '5': 'Juan Pérez García', // Ciclada Nocturna
    '6': 'Juan Pérez García', // Picnic en el Parque
    '7': 'Juan Pérez García', // Escalada en Roca
    '8': 'Juan Pérez García', // Cena Italiana
  };

  static String? get currentUser => _currentUser;
  static String? get currentUserAvatar => _currentUserAvatar;

  static bool isLoggedIn() {
    return _currentUser != null;
  }

  static void login(String username) {
    _currentUser = username;
    _currentUserAvatar = 'assets/images/avatars/avatar_${(username.length % 5) + 1}.png';
    debugPrint('Usuario logueado: $username');
  }

  static void logout() {
    _currentUser = null;
    _currentUserAvatar = null;
    debugPrint('Usuario deslogueado');
  }

  static bool isActivityAdmin(String activityId) {
    if (_currentUser == null) return false;
    return _activityAdmins[activityId] == _currentUser;
  }

  /// Establece el administrador de una actividad (usado al crear nuevas actividades)
  static void setActivityAdmin(String activityId, String username) {
    _activityAdmins[activityId] = username;
    debugPrint('Admin establecido: $username para actividad $activityId');
  }

  static String getActivityAdmin(String activityId) {
    return _activityAdmins[activityId] ?? 'Administrador';
  }

  static List<String> getAllAdmins() {
    return _activityAdmins.values.toList();
  }
}

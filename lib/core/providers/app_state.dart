import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../models/activity_model.dart';
import '../models/join_request_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/api_activity_repository.dart';
import '../repositories/activity_repository.dart';
import '../services/api_client.dart';

// ══════════════════════════════════════════════════════════════
//  AppState  — Estado global conectado al backend real
//
//  ✅ autenticación vía backend PHP (login/registro/logout)
//  ✅ persistencia del token con SharedPreferences
//  ✅ actividades desde MySQL vía ActivityRepository
//  ✅ solicitudes de unión vía backend PHP
//  Compatible con la UI existente (misma interfaz pública)
// ══════════════════════════════════════════════════════════════
class AppState extends ChangeNotifier {
  // ─── Repositorios ─────────────────────────────────────────────────────────

  final AuthRepository _authRepo;
  final ActivityRepository _activityRepo;

  AppState({
    AuthRepository? authRepo,
    ActivityRepository? activityRepo,
  })  : _authRepo = authRepo ?? AuthRepository(),
        _activityRepo = activityRepo ?? ApiActivityRepository() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _restoreSession().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Initialization error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ─── Estado de autenticación ───────────────────────────────────────────────

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;
  String? _currentCity;
  String? get currentCity => _currentCity;

  bool get isInitialized => _isInitialized;

  void updatePosition(Position pos) async {
    _currentPosition = pos;
    notifyListeners();

    // Detectar ciudad automáticamente
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final city = placemarks.first.locality;
        if (city != null && city != _currentCity) {
          final oldCity = _currentCity;
          _currentCity = city;
          debugPrint('🌆 Nueva ciudad detectada: $city (antes: $oldCity)');
          _saveLastCity(city);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error en geocoding: $e');
    }
  }

  Future<void> _saveLastCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_known_city', city);
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get error => _error;

  // ─── Estado de actividades ─────────────────────────────────────────────────

  List<Activity> _activities = [];
  List<Activity> get activities => List.unmodifiable(_activities);
  bool _activitiesLoaded = false;

  List<Activity> get myActivities =>
      _activities.where((a) => a.organizerId == _currentUser?.id).toList();

  final Set<String> _acceptedActivityIds = {};
  Set<String> get acceptedActivityIds => Set.unmodifiable(_acceptedActivityIds);

  // ─── Estado de solicitudes ─────────────────────────────────────────────────

  List<JoinRequest> _joinRequests = [];
  List<JoinRequest> get joinRequests => List.unmodifiable(_joinRequests);

  List<JoinRequest> get pendingRequests => _joinRequests
      .where((r) =>
          r.status == JoinRequestStatus.pending &&
          myActivities.any((a) => a.id == r.activityId))
      .toList();

  // ─── Inicialización / restaurar sesión ─────────────────────────────────────

  /// Restaura sesión desde SharedPreferences (token guardado)
  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    try {
      final user = await _authRepo.restoreSession(token);
      if (user != null) {
        _currentUser = user;
        _currentCity = prefs.getString('last_known_city'); // Restaurar ciudad
        notifyListeners();
        await _loadActivities();
      } else {
        await prefs.remove('auth_token');
      }
    } catch (e) {
      debugPrint('Restore session error: $e');
      // Token expirado o red no disponible
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ─── Autenticación ─────────────────────────────────────────────────────────

  /// Login con usuario/contraseña
  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _error = null;

    try {
      final result = await _authRepo.login(username, password);
      _currentUser = result.user;
      await _saveToken(result.token);
      _setLoading(false);
      // Cargar actividades en background — sin bloquear el flujo de auth
      Future.microtask(_loadActivities).catchError((_) {});
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Error de conexión: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Registro nuevo usuario
  Future<bool> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final result = await _authRepo.register(
        fullName: fullName,
        username: username,
        email: email,
        password: password,
      );
      _currentUser = result.user;
      await _saveToken(result.token);
      _setLoading(false);
      // Cargar actividades en background — sin bloquear el flujo de auth
      Future.microtask(_loadActivities).catchError((_) {});
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Error de conexión: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Inicio de sesión con Google (abre popup de cuentas)
  /// Retorna true=ok, false=usuario canceló, lanza si hay error de red/API.
  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    _error = null;

    try {
      final result = await _authRepo.loginWithGoogle();
      if (result == null) {
        _setLoading(false);
        return false;
      }
      _currentUser = result.user;
      await _saveToken(result.token);
      _setLoading(false);
      // Cargar actividades en background — sin bloquear la navegación
      Future.microtask(_loadActivities).catchError((_) {});
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Error con Google Sign-In: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Solicita un código de acceso por email (Magic Code) 
  /// Retorna el debug_code si está disponible (solo en localhost)
  Future<String?> requestMagicCode(String email) async {
    _setLoading(true);
    _error = null;

    try {
      final debugCode = await _authRepo.requestMagicCode(email);
      _setLoading(false);
      return debugCode ?? ""; // Retornamos "" para indicar éxito sin debug_code
    } on ApiException catch (e) {
      _error = e.message;
      _setLoading(false);
      return null;
    } catch (e) {
      _error = 'Error enviando código: $e';
      _setLoading(false);
      return null;
    }
  }

  /// Verifica el código de acceso y entra en la sesión
  Future<bool> verifyMagicCode(String email, String code) async {
    _setLoading(true);
    _error = null;

    try {
      final result = await _authRepo.verifyMagicCode(email, code);
      _currentUser = result.user;
      await _saveToken(result.token);
      _setLoading(false);
      // Cargar actividades en background
      Future.microtask(_loadActivities).catchError((_) {});
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Error verificando código: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Cierra sesión del usuario actual
  Future<void> logout() async {
    try {
      await _authRepo.logout();
    } catch (_) {}
    _currentUser = null;
    _activities = [];
    _joinRequests = [];
    _acceptedActivityIds.clear();
    _activitiesLoaded = false;
    _error = null;
    await _clearToken();
    notifyListeners();
  }

  /// Marca el onboarding como completado en el estado local.
  /// El backend ya fue actualizado por onboarding.php.
  void markSetupCompleted() {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(setupCompleted: true);
    notifyListeners();
  }

  /// Actualiza el perfil del usuario solo en memoria (sin llamar al backend).
  /// Usado por el onboarding para reflejar los datos completados antes de navegar,
  /// garantizando que el router no redirija de vuelta al onboarding.
  Future<void> updateLocalProfile({
    DateTime? birthDate,
    UserGender? gender,
    List<String>? interests,
    String? name,
    String? bio,
    String? phone,
  }) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      birthDate: birthDate,
      gender: gender,
      interests: interests,
      name: name,
      bio: bio,
      phone: phone,
    );
    notifyListeners();
  }

  /// Actualiza el perfil del usuario en el backend y en memoria.
  Future<void> updateProfile({
    String? name,
    String? bio,
    String? phone,
    DateTime? birthDate,
    UserGender? gender,
    bool? ageVisible,
    List<String>? interests,
    String? image,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (bio != null) 'bio': bio,
        if (phone != null) 'phone': phone,
        if (birthDate != null)
          'birthDate': birthDate.toIso8601String().split('T').first,
        if (gender != null) 'gender': gender.toJson(),
        if (ageVisible != null) 'ageVisible': ageVisible,
        if (interests != null) 'interests': interests,
        if (image != null) 'image': image,
      };
      final data = await ApiClient.instance.post(
        '/profile.php',
        body,
        queryParams: {'action': 'update'},
      );
      final userJson = data is Map ? data['user'] : null;
      if (userJson is Map<String, dynamic>) {
        _currentUser = UserModel.fromJson(userJson);
      }
      _setLoading(false);
    } on ApiException catch (e) {
      _error = e.message;
      _setLoading(false);
      rethrow;
    } catch (e) {
      _error = 'Error actualizando perfil: $e';
      _setLoading(false);
      rethrow;
    }
  }

  // ─── Actividades ──────────────────────────────────────────────────────────

  /// Carga actividades desde el backend (evitar recarga si ya están cargadas)
  Future<void> loadActivities({String? category, bool force = false}) async {
    if (_activitiesLoaded && !force && category == null) return;
    await _loadActivities(category: category);
  }

  Future<void> _loadActivities({String? category}) async {
    try {
      final fetched = await _activityRepo.getActivities(category: category);
      if (category == null) {
        _activities = fetched;
        _activitiesLoaded = true;
      } else {
        // Merge: reemplaza las de esa categoría, mantiene las demás
        _activities = [
          ..._activities.where((a) => a.category != category),
          ...fetched,
        ];
      }
      
      // Also load my requests simultaneously to sync accepted state
      if (isLoggedIn) {
        await _loadMyRequests();
      }
      
      notifyListeners();
    } catch (e) {
      _error = 'Error cargando actividades: $e';
      notifyListeners();
    }
  }

  Future<void> _loadMyRequests() async {
    try {
      final myRequests = await _activityRepo.getMyAllRequests();
      // Only keep requests not belonging to my own organized activities, or just merge them
      _joinRequests = [
        ..._joinRequests.where((r) => r.userId != _currentUser?.id),
        ...myRequests
      ];
      
      // Populate accepted IDs for chatting
      for (final req in myRequests) {
        if (req.status == JoinRequestStatus.accepted) {
          _acceptedActivityIds.add(req.activityId);
        }
      }
    } catch (e) {
      debugPrint('Error loading my requests: $e');
    }
  }

  /// Comprueba si el usuario actual es administrador de una actividad
  bool isActivityOrganizer(String activityId) {
    if (_currentUser == null) return false;
    try {
      final activity = _activities.firstWhere((a) => a.id == activityId);
      return activity.organizerId == _currentUser!.id;
    } catch (_) {
      return false;
    }
  }

  /// Verifica si el usuario puede ver el chat de una actividad
  bool canAccessChat(String activityId) {
    if (_currentUser == null) return false;
    return isActivityOrganizer(activityId) ||
        _acceptedActivityIds.contains(activityId);
  }

  /// Crea una nueva actividad en el backend y la agrega a la lista local
  Future<Activity?> createActivity(Activity activity) async {
    _setLoading(true);
    _error = null;
    try {
      final created = await _activityRepo.createActivity(activity);
      _activities.insert(0, created);
      _setLoading(false);
      return created;
    } catch (e) {
      _error = 'Error creando actividad: $e';
      _setLoading(false);
      return null;
    }
  }

  /// Mantener compatibilidad con código que usa addActivity() directamente
  void addActivity(Activity activity) {
    _activities.insert(0, activity);
    notifyListeners();
  }

  /// Actualiza una actividad existente en el backend
  Future<void> updateActivity(Activity updated) async {
    final index = _activities.indexWhere((a) => a.id == updated.id);
    if (index == -1) return;

    _activities[index] = updated; // optimistic update
    notifyListeners();

    try {
      final serverUpdated = await _activityRepo.updateActivity(updated);
      _activities[index] = serverUpdated;
      notifyListeners();
    } catch (e) {
      _error = 'Error actualizando actividad: $e';
      notifyListeners();
    }
  }

  /// Cancela una actividad
  Future<void> cancelActivity(String activityId) async {
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index != -1) {
      _activities[index] = _activities[index].copyWith(isActive: false);
      notifyListeners();
    }
    try {
      await _activityRepo.cancelActivity(activityId);
    } catch (_) {}
  }

  // ─── Solicitudes ──────────────────────────────────────────────────────────

  /// Envía una solicitud de unión a una actividad
  Future<bool> submitJoinRequest(String activityId, String message) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _error = null;

    try {
      final request = await _activityRepo.submitJoinRequest(
        activityId: activityId,
        userId: _currentUser!.id,
        userName: _currentUser!.name,
        userImageUrl: _currentUser!.profileImageUrl,
        message: message,
      );
      _joinRequests.insert(0, request);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Error enviando solicitud: $e';
      _setLoading(false);
      return false;
    }
  }

  /// El organizador acepta o rechaza una solicitud
  Future<void> respondToRequest(
    String requestId, {
    required bool accepted,
    String? responseMessage,
  }) async {
    if (_currentUser == null) return;

    try {
      final updated = await _activityRepo.respondToRequest(
        requestId: requestId,
        accepted: accepted,
        responseMessage: responseMessage,
        respondedBy: _currentUser!.id,
      );

      final index = _joinRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _joinRequests[index] = updated;
      } else {
        _joinRequests.insert(0, updated);
      }

      if (accepted) {
        _acceptedActivityIds.add(updated.activityId);
        _incrementParticipants(updated.activityId);
      }
      notifyListeners();
    } catch (e) {
      _error = 'Error respondiendo solicitud: $e';
      notifyListeners();
    }
  }

  /// Carga las solicitudes de una actividad desde el backend
  Future<void> loadRequestsForActivity(String activityId) async {
    try {
      final fetched = await _activityRepo.getRequestsForActivity(activityId);
      // Merge: elimina las de esta actividad y re-inserta las actualizadas
      _joinRequests.removeWhere((r) => r.activityId == activityId);
      _joinRequests.insertAll(0, fetched);
      notifyListeners();
    } catch (e) {
      _error = 'Error cargando solicitudes: $e';
      notifyListeners();
    }
  }

  /// Obtiene el estado de la solicitud del usuario actual para una actividad
  JoinRequestStatus? getMyRequestStatus(String activityId) {
    if (_currentUser == null) return null;
    final request = _joinRequests.where(
      (r) => r.activityId == activityId && r.userId == _currentUser!.id,
    );
    return request.isEmpty ? null : request.first.status;
  }

  /// Solicitudes de una actividad específica
  List<JoinRequest> getRequestsForActivity(String activityId) {
    return _joinRequests.where((r) => r.activityId == activityId).toList();
  }

  // ─── Helpers privados ─────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _incrementParticipants(String activityId) {
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index != -1) {
      final activity = _activities[index];
      if (activity.currentParticipants < activity.maxParticipants) {
        _activities[index] = activity.copyWith(
          currentParticipants: activity.currentParticipants + 1,
        );
      }
    }
  }
}

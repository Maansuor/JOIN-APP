import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../models/activity_model.dart';
import '../models/join_request_model.dart';
import '../models/clan_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/supabase_activity_repository.dart';
import '../repositories/activity_repository.dart';
import '../repositories/clan_repository.dart';
import '../repositories/supabase_clan_repository.dart';
import '../location/peru_geography.dart';
import '../location/location_tracker.dart';
import '../services/notification_service.dart';

// ══════════════════════════════════════════════════════════════
//  AppState  — Estado global conectado a Supabase
//
//  ✅ autenticación vía Supabase
//  ✅ sesión persistida por Supabase, sin token duplicado en el cliente
//  ✅ actividades desde PostgreSQL vía SupabaseActivityRepository
//  ✅ solicitudes de unión vía Supabase
//  Compatible con la UI existente (misma interfaz pública)
// ══════════════════════════════════════════════════════════════
class AppState extends ChangeNotifier {
  // ─── Repositorios ─────────────────────────────────────────────────────────

  final AuthRepository _authRepo;
  final ActivityRepository _activityRepo;
  final ClanRepository _clanRepo;

  ActivityRepository get activityRepository => _activityRepo;
  ClanRepository get clanRepository => _clanRepo;

  AppState({
    AuthRepository? authRepo,
    ActivityRepository? activityRepo,
    ClanRepository? clanRepo,
    LocationTracker? locationTracker,
  })  : _authRepo = authRepo ?? AuthRepository(),
        _activityRepo = activityRepo ?? SupabaseActivityRepository(),
        _clanRepo = clanRepo ?? SupabaseClanRepository(),
        _location = locationTracker ?? LocationTracker() {
    // Los cambios de ubicación se propagan a las pantallas que escuchan AppState.
    _location.addListener(notifyListeners);
    _location.onMarkedCityChanged = _syncUserCityToBackend;
    _init();
  }

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  Future<void> _init() async {
    try {
      await _location.restore();

      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('is_dark_mode')) {
        _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      } else {
        final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        _isDarkMode = brightness == Brightness.dark;
      }

      await _restoreSession().timeout(const Duration(seconds: 10));
      if (_currentUser == null) {
        await _loadActivities();
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> toggleTheme(bool dark) async {
    _isDarkMode = dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', dark);
  }

  // ─── Estado de autenticación ───────────────────────────────────────────────

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // ─── Ubicación (delegada en LocationTracker) ──────────────────────────────
  //
  // El seguimiento de GPS y la geocodificación viven en LocationTracker; aquí
  // sólo se reexponen para que las pantallas sigan hablando con AppState.

  final LocationTracker _location;
  LocationTracker get location => _location;

  Position? get currentPosition => _location.currentPosition;
  String? get currentCity => _location.currentCity;
  Position? get actualPosition => _location.actualPosition;
  String? get actualCity => _location.actualCity;
  String? get discrepancyCity => _location.discrepancyCity;
  Position? get discrepancyPosition => _location.discrepancyPosition;
  bool get hasLocationDiscrepancy => _location.hasDiscrepancy;
  double get searchRadius => _location.searchRadius;

  bool get isInitialized => _isInitialized;

  @override
  void dispose() {
    _location.removeListener(notifyListeners);
    _location.dispose();
    super.dispose();
  }

  /// Arranca el seguimiento de ubicación en tiempo real.
  Future<void> checkLocationAndDetectDiscrepancy() => _location.start();

  /// Aplica una posición elegida fuera del stream (por ejemplo en el mapa).
  void updatePosition(Position pos) => _location.applyPosition(pos);

  /// Descarta la alerta de discrepancia sin cambiar de ciudad.
  void clearDiscrepancy() => _location.clearDiscrepancy();

  /// Fija la ciudad elegida por el usuario y recarga las actividades de la zona.
  Future<void> updateSelectedCity(String city, Position position) async {
    await _location.selectCity(city, position);

    _activitiesLoaded = false; // Forzar recarga
    _activities = []; // Evitar que parpadeen las de la ciudad anterior
    _isLoading = true; // Evitar el flash del estado vacío
    notifyListeners();

    Future.microtask(() => loadActivities(force: true)).catchError((e) {
      debugPrint('Error al recargar actividades tras cambio de ubicación: $e');
    });
  }

  /// Cambia el radio de búsqueda en kilómetros y recarga las actividades.
  Future<void> updateSearchRadius(double radius) async {
    await _location.setSearchRadius(radius);
    await loadActivities(force: true);
  }

  /// Guarda en el perfil la ciudad actual, para que el backend pueda usarla.
  Future<void> _syncUserCityToBackend(String city) async {
    final userId = _currentUser?.id;
    if (userId == null || userId.isEmpty || city.isEmpty) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'current_city': city})
          .eq('id', userId);
      debugPrint('📍 Ciudad sincronizada en Supabase: $city');
    } catch (e) {
      debugPrint('⚠️ Error al sincronizar ciudad en Supabase: $e');
    }
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

  /// Recupera la sesión que Supabase persiste por su cuenta.
  ///
  /// No se guarda ningún token: Supabase ya almacena y renueva la sesión, y
  /// duplicarla en SharedPreferences sólo servía para dejar un JWT en claro.
  Future<void> _restoreSession() async {
    try {
      final user = await _authRepo.restoreSession();
      if (user == null) return; // Sin sesión activa: se queda en login.

      _currentUser = user;
      notifyListeners();
      // La ciudad ya la restauró LocationTracker; aquí sólo se sincroniza
      // con el perfil, que necesita el usuario ya cargado.
      if (currentCity != null) _syncUserCityToBackend(currentCity!);
      await _loadActivities();
      await loadUserClans();
      NotificationService.subscribeToRealtime();
    } on AuthException catch (e) {
      debugPrint('Restore session auth error: ${e.message}');
    } catch (e) {
      debugPrint('Restore session error: $e');
    }
  }

  /// Borra el token que guardaban versiones anteriores de la app.
  Future<void> _clearLegacyToken() async {
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
      // Supabase persiste la sesión por su cuenta: no hay token que guardar.
      if (currentCity != null) _syncUserCityToBackend(currentCity!);
      _setLoading(false);
      // Cargar actividades y clanes en background
      Future.microtask(_loadActivities).catchError((_) {});
      Future.microtask(loadUserClans).catchError((_) {});
      NotificationService.subscribeToRealtime();
      return true;
    } on AuthException catch (e) {
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
      // Supabase persiste la sesión por su cuenta: no hay token que guardar.
      if (currentCity != null) _syncUserCityToBackend(currentCity!);
      _setLoading(false);
      // Cargar actividades y clanes en background
      Future.microtask(_loadActivities).catchError((_) {});
      Future.microtask(loadUserClans).catchError((_) {});
      NotificationService.subscribeToRealtime();
      return true;
    } on AuthException catch (e) {
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
      // Supabase persiste la sesión por su cuenta: no hay token que guardar.
      if (currentCity != null) _syncUserCityToBackend(currentCity!);
      _setLoading(false);
      // Cargar actividades y clanes en background
      Future.microtask(_loadActivities).catchError((_) {});
      Future.microtask(loadUserClans).catchError((_) {});
      NotificationService.subscribeToRealtime();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _setLoading(false);
      debugPrint('Google Sign-In API Error: ${e.message}');
      return false;
    } catch (e, stackTrace) {
      _error = 'Error con Google Sign-In: $e';
      _setLoading(false);
      debugPrint('Google Sign-In Error: $e');
      debugPrint('Stack trace: $stackTrace');
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
    } on AuthException catch (e) {
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
      // Supabase persiste la sesión por su cuenta: no hay token que guardar.
      if (currentCity != null) _syncUserCityToBackend(currentCity!);
      _setLoading(false);
      // Cargar actividades y clanes en background
      Future.microtask(_loadActivities).catchError((_) {});
      Future.microtask(loadUserClans).catchError((_) {});
      NotificationService.subscribeToRealtime();
      return true;
    } on AuthException catch (e) {
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
    _userClans = [];
    _activities = [];
    _joinRequests = [];
    _acceptedActivityIds.clear();
    _activitiesLoaded = false;
    _error = null;
    await NotificationService.unsubscribeFromRealtime();
    await _clearLegacyToken();
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
    String? userRole,
    bool? completedOnboarding,
    int? iguanaLevel,
    int? iguanaPoints,
    String? iguanaPersonality,
    String? iguanaType,
  }) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      birthDate: birthDate,
      gender: gender,
      interests: interests,
      name: name,
      bio: bio,
      phone: phone,
      userRole: userRole,
      completedOnboarding: completedOnboarding,
      iguanaLevel: iguanaLevel,
      iguanaPoints: iguanaPoints,
      iguanaPersonality: iguanaPersonality,
      iguanaType: iguanaType,
    );
    notifyListeners();
  }

  /// Actualiza el perfil del usuario en Supabase y en memoria.
  Future<void> updateProfile({
    String? name,
    String? bio,
    String? phone,
    DateTime? birthDate,
    UserGender? gender,
    bool? ageVisible,
    List<String>? interests,
    String? image,
    bool? setupCompleted,
    String? userRole,
    bool? completedOnboarding,
    int? iguanaLevel,
    int? iguanaPoints,
    String? iguanaPersonality,
    String? iguanaType,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('No hay usuario autenticado en Supabase.');

      String? imageUrl = image;
      // Subir foto de perfil a Storage Bucket avatars si es local
      if (imageUrl != null &&
          imageUrl.isNotEmpty &&
          !imageUrl.startsWith('http') &&
          !imageUrl.startsWith('assets')) {
        final file = File(imageUrl);
        final ext = imageUrl.split('.').last;
        final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        
        await Supabase.instance.client.storage.from('avatars').upload(fileName, file);
        imageUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
      }

      // 1. Actualizar tabla public.profiles
      final updates = <String, dynamic>{
        if (name != null) 'display_name': name,
        if (bio != null) 'bio': bio,
        if (phone != null) 'phone': phone,
        if (birthDate != null) 'birth_date': birthDate.toIso8601String().split('T').first,
        if (gender != null) 'gender': gender.toJson(),
        if (ageVisible != null) 'age_visible': ageVisible,
        if (imageUrl != null) 'profile_image_url': imageUrl,
        if (setupCompleted != null) 'setup_completed': setupCompleted,
        if (userRole != null) 'user_role': userRole,
        if (completedOnboarding != null) 'completed_onboarding': completedOnboarding,
        if (iguanaLevel != null) 'iguana_level': iguanaLevel,
        if (iguanaPoints != null) 'iguana_points': iguanaPoints,
        if (iguanaPersonality != null) 'iguana_personality': iguanaPersonality,
        if (iguanaType != null) 'iguana_type': iguanaType,
      };

      if (updates.isNotEmpty) {
        await Supabase.instance.client.from('profiles').update(updates).eq('id', userId);
      }

      // 2. Actualizar intereses
      if (interests != null) {
        // Borrar existentes e insertar nuevos
        await Supabase.instance.client.from('user_interests').delete().eq('user_id', userId);
        if (interests.isNotEmpty) {
          final interestsToInsert = interests.map((tag) => {
            'user_id': userId,
            'tag': tag,
          }).toList();
          await Supabase.instance.client.from('user_interests').insert(interestsToInsert);
        }
      }

      // 3. Recargar perfil en memoria
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('*, user_interests(tag)')
          .eq('id', userId)
          .single();

      _currentUser = UserModel.fromJson(profileData);
      _setLoading(false);
    } catch (e) {
      _error = 'Error actualizando perfil en Supabase: $e';
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
    _setLoading(true);
    try {
      final fetched = await _activityRepo.getActivities(
        category: category, 
        city: searchRadius > 0 ? null : currentCity,
      );
      
      List<Activity> processed = fetched;
      if (searchRadius > 0) {
        processed = fetched.where((a) {
          // Si es su propia actividad, siempre mostrarla
          if (a.organizerId == _currentUser?.id) return true;
          
          // Si tiene coordenadas y el usuario también, calcular distancia real
          if (a.latitude != null && a.longitude != null && currentPosition != null) {
            final distMeters = Geolocator.distanceBetween(
              currentPosition!.latitude,
              currentPosition!.longitude,
              a.latitude!,
              a.longitude!,
            );
            final distKm = distMeters / 1000.0;
            return distKm <= searchRadius;
          }
          
          // Si no hay posición del usuario, o no hay coordenadas de actividad, mostrarla sólo si pertenece a la misma región geográfica
          return PeruGeography.proximityScore(currentCity ?? '', a.city) < 100;
        }).toList();
      } else {
        // Filtrar de forma estricta para excluir actividades de ciudades/regiones distintas
        processed = fetched.where((a) {
          // Si es su propia actividad, siempre mostrarla
          if (a.organizerId == _currentUser?.id) return true;
          
          // Debe estar en el mismo grupo de proximidad geográfica (score < 100)
          return PeruGeography.proximityScore(currentCity ?? '', a.city) < 100;
        }).toList();
      }

      // Ordenar las actividades de forma inteligente según cercanía geográfica y lógica de distritos/provincias
      final myId = _currentUser?.id;
      final userCity = currentCity;
      final userPos = currentPosition;

      processed.sort((a, b) {
        // 1. Prioridad máxima: Propias actividades del organizador (siempre arriba)
        final aIsMine = a.organizerId == myId;
        final bIsMine = b.organizerId == myId;
        if (aIsMine && !bIsMine) return -1;
        if (!aIsMine && bIsMine) return 1;

        // 2. Si ambos tienen coordenadas de ubicación física y tenemos la del usuario, usar distancia métrica exacta
        if (userPos != null) {
          final aHasCoords = a.latitude != null && a.longitude != null;
          final bHasCoords = b.latitude != null && b.longitude != null;
          if (aHasCoords && bHasCoords) {
            final distA = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, a.latitude!, a.longitude!);
            final distB = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, b.latitude!, b.longitude!);
            if ((distA - distB).abs() > 10.0) {
              return distA.compareTo(distB);
            }
          }
        }

        // 3. Fallback de orden lógico basado en distritos, ciudades y provincias vecinas
        if (userCity != null && userCity.isNotEmpty) {
          final scoreA = PeruGeography.proximityScore(userCity, a.city);
          final scoreB = PeruGeography.proximityScore(userCity, b.city);
          if (scoreA != scoreB) {
            return scoreA.compareTo(scoreB);
          }
        }

        // 4. Si empatan en cercanía, mostrar las más recientes primero
        return a.eventDateTime.compareTo(b.eventDateTime);
      });

      if (category == null) {
        _activities = processed;
        _activitiesLoaded = true;
      } else {
        // Merge: reemplaza las de esa categoría, mantiene las demás
        _activities = [
          ..._activities.where((a) => a.category != category),
          ...processed,
        ];
      }
      
      // Also load my requests simultaneously to sync accepted state
      if (isLoggedIn) {
        await _loadMyRequests();
      }
      
      _setLoading(false);
    } catch (e) {
      _error = 'Error cargando actividades: $e';
      _setLoading(false);
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

  /// Elimina una actividad permanentemente
  Future<void> deleteActivity(String activityId) async {
    _activities.removeWhere((a) => a.id == activityId);
    notifyListeners();
    try {
      await _activityRepo.deleteActivity(activityId);
    } catch (e) {
      debugPrint('Error en deleteActivity en AppState: $e');
      // Recargar para restaurar estado local si falló en backend
      await _loadActivities();
    }
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

  // ─── Clanes y Asistencia Grupal ────────────────────────────────────────────

  List<Clan> _userClans = [];
  List<Clan> get userClans => List.unmodifiable(_userClans);

  /// Carga los clanes del usuario actual desde el repositorio
  Future<void> loadUserClans() async {
    if (_currentUser == null) return;
    try {
      final clans = await _clanRepo.getUserClans(_currentUser!.id);
      _userClans = clans;
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando clanes del usuario: $e');
    }
  }

  /// Crea un nuevo clan y lo agrega al estado local
  Future<bool> createClan(String name, {String? avatarUrl, List<String> memberUserIds = const []}) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _error = null;
    try {
      final clan = await _clanRepo.createClan(
        name: name,
        creatorId: _currentUser!.id,
        avatarUrl: avatarUrl,
        memberUserIds: memberUserIds,
      );
      _userClans.insert(0, clan);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al crear clan: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Elimina un clan si es el creador
  Future<bool> deleteClan(String clanId) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _error = null;
    try {
      await _clanRepo.deleteClan(clanId);
      _userClans.removeWhere((c) => c.id == clanId);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al eliminar clan: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Salir de un clan
  Future<bool> leaveClan(String clanId) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _error = null;
    try {
      await _clanRepo.removeClanMember(clanId, _currentUser!.id);
      _userClans.removeWhere((c) => c.id == clanId);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al salir del clan: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Agrega un miembro a un clan
  Future<bool> addMemberToClan(String clanId, String userId) async {
    try {
      await _clanRepo.addClanMember(clanId, userId);
      return true;
    } catch (e) {
      _error = 'Error al agregar miembro: $e';
      return false;
    }
  }

  /// Remueve un miembro de un clan
  Future<bool> removeMemberFromClan(String clanId, String userId) async {
    try {
      await _clanRepo.removeClanMember(clanId, userId);
      return true;
    } catch (e) {
      _error = 'Error al remover miembro: $e';
      return false;
    }
  }

  /// Obtiene los miembros de un clan
  Future<List<ClanMember>> getClanMembers(String clanId) async {
    return await _clanRepo.getClanMembers(clanId);
  }

  /// Busca perfiles de usuarios registrados
  Future<List<UserModel>> searchProfiles(String query) async {
    return await _clanRepo.searchProfiles(query);
  }

  /// Envía solicitudes de participación grupal en lote para todos los miembros del clan
  Future<bool> submitClanJoinRequest(String activityId, String clanId, String message) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _error = null;
    try {
      // 1. Obtener miembros del clan
      final members = await _clanRepo.getClanMembers(clanId);
      if (members.isEmpty) throw Exception('El clan no tiene miembros.');

      // 2. Para cada miembro enviar solicitud
      for (final m in members) {
        try {
          final request = await _activityRepo.submitJoinRequest(
            activityId: activityId,
            userId: m.userId,
            userName: m.userProfile?.name ?? '',
            userImageUrl: m.userProfile?.profileImageUrl ?? '',
            message: '$message (Clan: ${_userClans.firstWhere((c) => c.id == clanId).name})',
          );
          
          // Si es el usuario actual, actualizar estado local
          if (m.userId == _currentUser!.id) {
            _joinRequests.removeWhere((r) => r.activityId == activityId && r.userId == m.userId);
            _joinRequests.insert(0, request);
          }
        } catch (e) {
          // Omitir silenciosamente si ya existe solicitud/es participante
          debugPrint('Error al registrar miembro ${m.userId} del clan en la actividad: $e');
        }
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al enviar solicitudes grupales: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Obtiene las categorías de actividades compartidas entre el usuario actual y otro usuario
  Future<List<String>> getSharedActivityCategories(String otherUserId) async {
    if (_currentUser == null) return [];
    return await _clanRepo.getSharedActivityCategories(_currentUser!.id, otherUserId);
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

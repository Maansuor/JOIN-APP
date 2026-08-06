import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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

// ══════════════════════════════════════════════════════════════
//  AppState  — Estado global conectado a Supabase
//
//  ✅ autenticación vía Supabase
//  ✅ persistencia del token con Supabase Session persistente
//  ✅ actividades desde PostgreSQL vía SupabaseActivityRepository
//  ✅ solicitudes de unión vía Supabase
//  Compatible con la UI existente (misma interfaz pública)
// ══════════════════════════════════════════════════════════════
class AppState extends ChangeNotifier with WidgetsBindingObserver {
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
  })  : _authRepo = authRepo ?? AuthRepository(),
        _activityRepo = activityRepo ?? SupabaseActivityRepository(),
        _clanRepo = clanRepo ?? SupabaseClanRepository() {
    _init();
  }

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  Future<void> _init() async {
    try {
      WidgetsBinding.instance.addObserver(this);
      await GeocodingPlatform.instance?.setLocaleIdentifier("es_PE").catchError((e) {
        debugPrint('⚠️ No se pudo establecer el locale de geocoding: $e');
      });
      final prefs = await SharedPreferences.getInstance();
      _searchRadius = prefs.getDouble('search_radius') ?? 0.0;
      _currentCity = prefs.getString('last_known_city');
      
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

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;
  String? _currentCity;
  String? get currentCity => _currentCity;

  double _searchRadius = 0.0; // 0.0 significa filtro estricto por ciudad
  double get searchRadius => _searchRadius;

  // Nuevas variables para geolocalización en tiempo real y discrepancia
  Position? _actualPosition;
  Position? get actualPosition => _actualPosition;
  String? _actualCity;
  String? get actualCity => _actualCity;

  String? _discrepancyCity;
  String? get discrepancyCity => _discrepancyCity;
  Position? _discrepancyPosition;
  Position? get discrepancyPosition => _discrepancyPosition;
  bool get hasLocationDiscrepancy => _discrepancyCity != null;

  bool get isInitialized => _isInitialized;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _locationTimer;
  Position? _lastGeocodedPosition;

  /// El usuario ya concedió permisos y quiere seguimiento activo. Se usa para
  /// saber si hay que reanudar el rastreo al volver del segundo plano.
  bool _locationTrackingRequested = false;

  /// Metros que debe desplazarse el usuario para que el sistema operativo nos
  /// entregue una nueva posición. Con esto el GPS no se consulta mientras el
  /// usuario está quieto: es el SO quien nos despierta sólo si hay movimiento.
  static const int _positionDistanceFilterMeters = 100;

  /// Metros mínimos antes de volver a geocodificar. Un distrito no cambia en
  /// 100 m, y Nominatim admite ~1 petición por segundo: geocodificar en cada
  /// actualización de GPS sería desperdiciar red y arriesgar un bloqueo de IP.
  static const double _geocodeThresholdMeters = 500;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationUpdates();
    super.dispose();
  }

  /// Sin app en pantalla no hay nada que actualizar: se corta el rastreo al
  /// pasar a segundo plano y se reanuda al volver.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_locationTrackingRequested) return;

    if (state == AppLifecycleState.resumed) {
      if (_positionSubscription == null && _locationTimer == null) {
        _startPositionStream();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopLocationUpdates();
    }
  }

  void updatePosition(Position pos) async {
    _currentPosition = pos;
    _actualPosition = pos;
    notifyListeners();

    // Detectar ciudad automáticamente con timeout
    try {
      String? city = await _reverseGeocode(pos.latitude, pos.longitude);
      
      // Fallback a geocodificador nativo
      if (city == null || city.isEmpty) {
        List<Placemark> placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude)
                .timeout(const Duration(seconds: 4));
        if (placemarks.isNotEmpty) {
          city = placemarks.first.locality;
        }
      }

      if (city != null && city.isNotEmpty) {
        _actualCity = city;
        if (city != _currentCity) {
          final oldCity = _currentCity;
          _currentCity = city;
          debugPrint('🌆 Nueva ciudad detectada: $city (antes: $oldCity)');
          _saveLastCity(city);
          notifyListeners();
        }
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout en geocoding - usando ciudad anterior');
    } catch (e) {
      debugPrint('Error en geocoding: $e');
    }
  }

  /// Limpia el estado de discrepancia de ubicación (por ejemplo si el usuario descarta la alerta)
  void clearDiscrepancy() {
    _discrepancyCity = null;
    _discrepancyPosition = null;
    _lastGeocodedPosition = null; // Forzar re-evaluación inmediata física
    notifyListeners();
  }

  /// Método de geocodificación inversa resiliente usando OpenStreetMap Nominatim
  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&accept-language=es');
      final response = await http.get(url, headers: {
        'User-Agent': 'JoinApp-LocalDev',
      }).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        if (address != null) {
          final district = address['suburb'] ?? address['village'] ?? address['neighborhood'] ?? address['town'] ?? '';
          String cityOrRegion = address['city'] ?? address['county'] ?? '';
          if (cityOrRegion.isEmpty || cityOrRegion == district) {
            cityOrRegion = address['state'] ?? '';
          }
          String finalCity = '';
          if (district.isNotEmpty && cityOrRegion.isNotEmpty && district != cityOrRegion) {
            finalCity = '$district, $cityOrRegion';
          } else {
            finalCity = district.isNotEmpty ? district : cityOrRegion;
          }
          if (finalCity.isNotEmpty) return finalCity;
        }
      }
    } catch (e) {
      debugPrint('Resilient Geocoding Error in AppState: $e');
    }
    return null;
  }

  /// Procesa la posición recibida y realiza la geocodificación inversa y detección de discrepancia
  Future<void> _handleLivePositionUpdate(Position pos) async {
    try {
      _actualPosition = pos;

      // Calcular la distancia desde la última posición geocodificada para evitar inundar los servidores de geocodificación
      if (_lastGeocodedPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastGeocodedPosition!.latitude,
          _lastGeocodedPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );
        // Desplazamiento corto: no hace falta volver a preguntar la ciudad.
        if (distance < _geocodeThresholdMeters &&
            _actualCity != null &&
            _actualCity!.isNotEmpty) {
          // Aun así refrescamos la posición para que el orden por cercanía de
          // las actividades siga siendo exacto.
          if (_discrepancyCity == null) _currentPosition = pos;
          return;
        }
      }

      String? city;

      // 1. Intentar geocodificación resiliente usando OpenStreetMap Nominatim con idioma español
      city = await _reverseGeocode(pos.latitude, pos.longitude);

      // 2. Fallback a geocodificación nativa si Nominatim falló
      if (city == null || city.isEmpty) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude)
              .timeout(const Duration(seconds: 5));
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;

            String district = p.subLocality ?? '';
            if (district.isEmpty) {
              district = p.locality ?? '';
            }
            
            String cityOrRegion = p.subAdministrativeArea ?? '';
            if (cityOrRegion.isEmpty || cityOrRegion == district) {
              cityOrRegion = p.administrativeArea ?? '';
            }
            
            if (district.isNotEmpty && cityOrRegion.isNotEmpty && district != cityOrRegion) {
              city = '$district, $cityOrRegion';
            } else {
              city = district.isNotEmpty ? district : cityOrRegion;
            }
          }
        } catch (geocodingErr) {
          debugPrint('📍 _handleLivePositionUpdate: Geocodificación nativa falló: $geocodingErr');
        }
      }
      
      if (city != null && city.isNotEmpty) {
        _lastGeocodedPosition = pos;
        _actualCity = city;

        if (_currentCity == null || _currentCity!.isEmpty) {
          debugPrint('📍 Primera ciudad detectada: $city');
          _currentCity = city;
          _currentPosition = pos;
          await _saveLastCity(city);
          notifyListeners();
          return;
        }

        final cleanMarked = _currentCity!.toLowerCase().trim();
        final cleanActual = city.toLowerCase().trim();
        
        if (cleanMarked != cleanActual) {
          // Ignorar la ubicación por defecto del emulador "Mountain View" para no molestar en desarrollo local
          if (cleanActual == 'mountain view') {
            _discrepancyCity = null;
            _discrepancyPosition = null;
            notifyListeners();
            return;
          }

          _discrepancyCity = city;
          _discrepancyPosition = pos;
          debugPrint('⚠️ Discrepancia de ubicación detectada: Marcada=$_currentCity, Real=$city');
          notifyListeners();
        } else {
          _discrepancyCity = null;
          _discrepancyPosition = null;
          _currentPosition = pos; // Actualizar coordenadas para cálculos exactos
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('📍 Error en _handleLivePositionUpdate: $e');
    }
  }

  /// Arranca el seguimiento de ubicación en tiempo real.
  ///
  /// Usa el stream nativo de geolocator con `distanceFilter` en lugar de
  /// sondear el GPS en bucle: el sistema operativo sólo nos entrega una
  /// posición cuando el usuario se ha desplazado de verdad. Si está quieto no
  /// se gasta batería; si se mueve, la actualización llega de inmediato.
  Future<void> checkLocationAndDetectDiscrepancy() async {
    if (_positionSubscription != null || _locationTimer != null) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('📍 Servicio de ubicación desactivado.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('📍 Permiso de ubicación no concedido: $permission');
      return;
    }

    _locationTrackingRequested = true;
    _startPositionStream();
  }

  void _startPositionStream() {
    // Posición inicial inmediata: el stream sólo emite tras el primer
    // desplazamiento, así que sin esto la app no sabría dónde está al abrir.
    Geolocator.getLastKnownPosition().then(
      (pos) {
        if (pos != null) _handleLivePositionUpdate(pos);
      },
      onError: (e) => debugPrint('📍 Sin última posición conocida: $e'),
    );

    final LocationSettings settings = (!kIsWeb && Platform.isAndroid)
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: _positionDistanceFilterMeters,
            // Mantiene el LocationManager nativo en lugar de Play Services:
            // evita el DeadSystemException/JNI crash del GPS simulado en
            // ciertos emuladores, que fue el motivo del bucle manual previo.
            forceLocationManager: true,
            intervalDuration: const Duration(seconds: 30),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: _positionDistanceFilterMeters,
          );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      _handleLivePositionUpdate,
      onError: (e) {
        debugPrint('⚠️ Stream de ubicación falló ($e). Se pasa a sondeo lento.');
        _positionSubscription?.cancel();
        _positionSubscription = null;
        _startFallbackPolling();
      },
      cancelOnError: false,
    );
    debugPrint('📍 Seguimiento por stream activo (cada ${_positionDistanceFilterMeters}m).');
  }

  /// Plan B por si el stream nativo no funciona en un dispositivo concreto.
  /// Dos minutos basta para detectar un cambio de ciudad y no castiga la
  /// batería como el sondeo de 4 segundos que había antes.
  void _startFallbackPolling() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          forceAndroidLocationManager: true,
        ).timeout(const Duration(seconds: 15));
        await _handleLivePositionUpdate(pos);
      } catch (e) {
        debugPrint('📍 Sondeo de ubicación falló: $e');
      }
    });
  }

  void _stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  /// Actualiza la ciudad marcada por el usuario y sus coordenadas de referencia "en caliente"
  Future<void> updateSelectedCity(String city, Position position) async {
    _currentCity = city;
    _currentPosition = position;
    _actualCity = city;
    _actualPosition = position;
    _discrepancyCity = null;
    _discrepancyPosition = null;
    _lastGeocodedPosition = null; // Forzar re-evaluación inmediata física
    _activitiesLoaded = false; // Reset para forzar recarga visual
    _activities = []; // Limpiar para evitar parpadeo de datos viejos
    _isLoading = true; // Evitar parpadeo/flash del estado vacío de la lista
    
    await _saveLastCity(city);
    notifyListeners();
    
    // Forzar recarga de actividades para traer las correspondientes a la nueva ciudad
    Future.microtask(() => loadActivities(force: true)).catchError((e) {
      debugPrint('Error al recargar actividades tras cambio de ubicación: $e');
    });
  }

  /// Actualiza el rango de búsqueda en kilómetros y recarga actividades
  Future<void> updateSearchRadius(double radius) async {
    _searchRadius = radius;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('search_radius', radius);
    notifyListeners();
    await loadActivities(force: true);
  }

  Future<void> _syncUserCityToBackend() async {
    final userId = _currentUser?.id;
    final city = _currentCity;
    if (userId == null || userId.isEmpty || city == null || city.isEmpty) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'current_city': city})
          .eq('id', userId);
      debugPrint('📍 Ciudad sincronizada en Supabase para el usuario: $city');
    } catch (e) {
      debugPrint('⚠️ Error al sincronizar ciudad en Supabase: $e');
    }
  }

  Future<void> _saveLastCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_known_city', city);
    _syncUserCityToBackend(); // Sincronizar asíncronamente con Supabase
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
        _syncUserCityToBackend(); // Sincronizar ciudad recuperada
        await _loadActivities();
        await loadUserClans(); // Cargar clanes del usuario
      } else {
        // Token inválido (401), borrarlo
        await prefs.remove('auth_token');
      }
    } on AuthException catch (e) {
      debugPrint('Restore session auth error: ${e.message}');
      // Solo borrar el token si la sesión no es válida (401)
      if (e.statusCode == '401') {
        await prefs.remove('auth_token');
      }
      // Si es error de red, mantener el token para reintentar
    } catch (e) {
      debugPrint('Restore session error: $e');
      // Error de red u otro, mantener el token para reintentar
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
      _syncUserCityToBackend(); // Sincronizar ubicación tras login
      _setLoading(false);
      // Cargar actividades y clanes en background
      Future.microtask(_loadActivities).catchError((_) {});
      Future.microtask(loadUserClans).catchError((_) {});
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
      await _saveToken(result.token);
      _syncUserCityToBackend(); // Sincronizar ubicación tras registro
      _setLoading(false);
      // Cargar actividades y clanes en background
      Future.microtask(_loadActivities).catchError((_) {});
      Future.microtask(loadUserClans).catchError((_) {});
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
      await _saveToken(result.token);
      _syncUserCityToBackend(); // Sincronizar ubicación tras Google login
      _setLoading(false);
      // Cargar actividades y clanes en background
      Future.microtask(_loadActivities).catchError((_) {});
      Future.microtask(loadUserClans).catchError((_) {});
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
      await _saveToken(result.token);
      _syncUserCityToBackend(); // Sincronizar ubicación tras Magic Code login
      _setLoading(false);
      // Cargar actividades y clanes en background
      Future.microtask(_loadActivities).catchError((_) {});
      Future.microtask(loadUserClans).catchError((_) {});
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
        city: _searchRadius > 0 ? null : _currentCity,
      );
      
      List<Activity> processed = fetched;
      if (_searchRadius > 0) {
        processed = fetched.where((a) {
          // Si es su propia actividad, siempre mostrarla
          if (a.organizerId == _currentUser?.id) return true;
          
          // Si tiene coordenadas y el usuario también, calcular distancia real
          if (a.latitude != null && a.longitude != null && _currentPosition != null) {
            final distMeters = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              a.latitude!,
              a.longitude!,
            );
            final distKm = distMeters / 1000.0;
            return distKm <= _searchRadius;
          }
          
          // Si no hay posición del usuario, o no hay coordenadas de actividad, mostrarla sólo si pertenece a la misma región geográfica
          return _getGeographicProximityScore(_currentCity ?? '', a.city) < 100;
        }).toList();
      } else {
        // Filtrar de forma estricta para excluir actividades de ciudades/regiones distintas
        processed = fetched.where((a) {
          // Si es su propia actividad, siempre mostrarla
          if (a.organizerId == _currentUser?.id) return true;
          
          // Debe estar en el mismo grupo de proximidad geográfica (score < 100)
          return _getGeographicProximityScore(_currentCity ?? '', a.city) < 100;
        }).toList();
      }

      // Ordenar las actividades de forma inteligente según cercanía geográfica y lógica de distritos/provincias
      final myId = _currentUser?.id;
      final userCity = _currentCity;
      final userPos = _currentPosition;

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
          final scoreA = _getGeographicProximityScore(userCity, a.city);
          final scoreB = _getGeographicProximityScore(userCity, b.city);
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

  int _getGeographicProximityScore(String userLocation, String? activityLocation) {
    if (activityLocation == null || activityLocation.isEmpty) return 100;
    
    final cleanUser = userLocation.toLowerCase().trim();
    final cleanActivity = activityLocation.toLowerCase().trim();
    
    if (cleanUser == cleanActivity) {
      return 0; // Coincidencia exacta de distrito y ciudad
    }
    
    // Extraer partes del usuario (ej. "el tambo", "huancayo")
    final userParts = cleanUser.split(',').map((s) => s.trim()).toList();
    final userDistrict = userParts.isNotEmpty ? userParts[0] : '';
    final userParent = userParts.length > 1 ? userParts[1] : '';
    
    // Extraer partes de la actividad (ej. "huancayo", "junín")
    final activityParts = cleanActivity.split(',').map((s) => s.trim()).toList();
    final activityDistrict = activityParts.isNotEmpty ? activityParts[0] : '';
    final activityParent = activityParts.length > 1 ? activityParts[1] : '';
    
    // 1. Mismo distrito (ej. "el tambo")
    if (userDistrict.isNotEmpty && (activityDistrict == userDistrict || activityLocation.contains(userDistrict))) {
      return 1;
    }
    
    // 2. Misma provincia o ciudad principal (ej. "huancayo")
    if (userParent.isNotEmpty && (activityDistrict == userParent || activityParent == userParent || activityLocation.contains(userParent))) {
      return 2;
    }
    
    // 3. Detectar si pertenecen a la misma región general (ej: Junín, Lima, etc.) usando mapeo de palabras clave
    final String userRegion = _detectRegionGroup(cleanUser);
    final String activityRegion = _detectRegionGroup(cleanActivity);
    
    if (userRegion != 'other' && userRegion == activityRegion) {
      return 3; // Misma región
    }
    
    // Fallback simple: si comparten alguna palabra clave provincial/regional importante
    if (userParent.isNotEmpty && cleanActivity.contains(userParent)) {
      return 3;
    }
    if (activityParent.isNotEmpty && cleanUser.contains(activityParent)) {
      return 3;
    }
    
    return 100; // Distinto
  }

  String _detectRegionGroup(String location) {
    final clean = location.toLowerCase();
    
    // Grupo 1: Junín (incluye Huancayo y todos sus distritos principales)
    final juninKeywords = [
      'junin', 'junín', 'huancayo', 'tambo', 'chilca', 'jauja', 'tarma', 
      'chupaca', 'concepcion', 'concepción', 'satipo', 'chanchamayo', 
      'la merced', 'san ramon', 'san ramón', 'oroya', 'yauli', 'sicaya',
      'pilcomayo', 'sapallanga', 'cajas'
    ];
    if (juninKeywords.any((k) => clean.contains(k))) {
      return 'junin';
    }
    
    // Grupo 2: Lima & Callao
    final limaKeywords = [
      'lima', 'callao', 'miraflores', 'san isidro', 'lince', 'surco', 'san borja', 
      'molina', 'barranco', 'chorrillos', 'rimac', 'rímac', 'breña', 'san miguel', 
      'magdalena', 'pueblo libre', 'ate', 'victoria', 'surquillos', 'san martin', 
      'comas', 'carabayllo', 'olivos', 'puente piedra', 'lurigancho', 'chosica', 
      'vitarte', 'manchay', 'pachacamac', 'cieneguilla', 'lurin', 'lurín', 
      'villa el salvador', 'villa maria', 'sanjuan'
    ];
    if (limaKeywords.any((k) => clean.contains(k))) {
      return 'lima';
    }

    // Grupo 3: Arequipa
    final arequipaKeywords = [
      'arequipa', 'cayma', 'yanahuara', 'bustamante', 'selva alegre', 'socabaya', 
      'sachaca', 'miraflores arequipa'
    ];
    if (arequipaKeywords.any((k) => clean.contains(k))) {
      return 'arequipa';
    }

    // Grupo 4: Cusco
    final cuscoKeywords = [
      'cusco', 'cuzco', 'wanchaq', 'san sebastian', 'san sebastián', 'santiago', 'poroy'
    ];
    if (cuscoKeywords.any((k) => clean.contains(k))) {
      return 'cusco';
    }

    // Grupo 5: Lambayeque / Chiclayo
    final lambayequeKeywords = [
      'chiclayo', 'lambayeque', 'ferreñafe', 'pimentel', 'leonardo ortiz'
    ];
    if (lambayequeKeywords.any((k) => clean.contains(k))) {
      return 'lambayeque';
    }
    
    return 'other';
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

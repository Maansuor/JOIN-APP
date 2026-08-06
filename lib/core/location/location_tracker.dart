import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Sigue dónde está el usuario y decide cuándo eso importa.
///
/// Distingue dos cosas que la app trata por separado:
///  - la **ciudad marcada**, la que el usuario aceptó y con la que se filtran
///    las actividades ([currentCity]);
///  - la **ciudad real**, la que dice el GPS ahora mismo ([actualCity]).
///
/// Cuando dejan de coincidir se publica una [discrepancyCity] para que la
/// interfaz pregunte si quiere cambiarse; nunca se cambia por su cuenta.
///
/// Vive fuera de AppState para que la lógica de GPS y geocodificación sea
/// independiente del resto del estado global, pero AppState sigue exponiendo
/// los mismos getters, así que las pantallas no se enteran.
class LocationTracker extends ChangeNotifier with WidgetsBindingObserver {
  /// Metros que debe desplazarse el usuario para que el sistema operativo nos
  /// entregue una nueva posición. Con esto el GPS no se consulta mientras el
  /// usuario está quieto: es el SO quien nos despierta sólo si hay movimiento.
  static const int _positionDistanceFilterMeters = 100;

  /// Metros mínimos antes de volver a geocodificar. Un distrito no cambia en
  /// 100 m, y Nominatim admite ~1 petición por segundo: geocodificar en cada
  /// actualización de GPS sería desperdiciar red y arriesgar un bloqueo de IP.
  static const double _geocodeThresholdMeters = 500;

  /// Ubicación por defecto del emulador de Android. Se ignora para no
  /// molestar con una discrepancia falsa durante el desarrollo.
  static const String _emulatorDefaultCity = 'mountain view';

  /// Se avisa cuando la ciudad marcada cambia, para que quien nos use pueda
  /// sincronizarla con el backend y recargar lo que dependa de ella.
  Future<void> Function(String city)? onMarkedCityChanged;

  LocationTracker({this.onMarkedCityChanged});

  // ─── Estado publicado ─────────────────────────────────────────────────────

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  String? _currentCity;
  String? get currentCity => _currentCity;

  Position? _actualPosition;
  Position? get actualPosition => _actualPosition;

  String? _actualCity;
  String? get actualCity => _actualCity;

  String? _discrepancyCity;
  String? get discrepancyCity => _discrepancyCity;

  Position? _discrepancyPosition;
  Position? get discrepancyPosition => _discrepancyPosition;

  bool get hasDiscrepancy => _discrepancyCity != null;

  /// Radio de búsqueda en kilómetros. 0 significa filtro estricto por ciudad.
  double _searchRadius = 0.0;
  double get searchRadius => _searchRadius;

  // ─── Interno ──────────────────────────────────────────────────────────────

  StreamSubscription<Position>? _positionSubscription;
  Timer? _fallbackTimer;
  Position? _lastGeocodedPosition;

  /// El usuario ya concedió permisos y quiere seguimiento activo. Se usa para
  /// saber si hay que reanudar el rastreo al volver del segundo plano.
  bool _trackingRequested = false;

  /// Carga la ciudad y el radio guardados de la sesión anterior.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _searchRadius = prefs.getDouble('search_radius') ?? 0.0;
    _currentCity = prefs.getString('last_known_city');

    await GeocodingPlatform.instance?.setLocaleIdentifier('es_PE').catchError(
      (e) => debugPrint('⚠️ No se pudo establecer el locale de geocoding: $e'),
    );

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stop();
    super.dispose();
  }

  /// Sin app en pantalla no hay nada que actualizar: se corta el rastreo al
  /// pasar a segundo plano y se reanuda al volver.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_trackingRequested) return;

    if (state == AppLifecycleState.resumed) {
      if (_positionSubscription == null && _fallbackTimer == null) {
        _startPositionStream();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      stop();
    }
  }

  // ─── Arranque y parada del seguimiento ────────────────────────────────────

  /// Pide permiso si hace falta y arranca el seguimiento en tiempo real.
  ///
  /// Usa el stream nativo de geolocator con `distanceFilter` en lugar de
  /// sondear el GPS en bucle: el sistema operativo sólo nos entrega una
  /// posición cuando el usuario se ha desplazado de verdad. Si está quieto no
  /// se gasta batería; si se mueve, la actualización llega de inmediato.
  Future<void> start() async {
    if (_positionSubscription != null || _fallbackTimer != null) return;

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

    _trackingRequested = true;
    _startPositionStream();
  }

  void stop() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  void _startPositionStream() {
    // Posición inicial inmediata: el stream sólo emite tras el primer
    // desplazamiento, así que sin esto la app no sabría dónde está al abrir.
    Geolocator.getLastKnownPosition().then(
      (pos) {
        if (pos != null) _handlePositionUpdate(pos);
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

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      _handlePositionUpdate,
      onError: (e) {
        debugPrint('⚠️ Stream de ubicación falló ($e). Se pasa a sondeo lento.');
        _positionSubscription?.cancel();
        _positionSubscription = null;
        _startFallbackPolling();
      },
      cancelOnError: false,
    );
    debugPrint(
        '📍 Seguimiento por stream activo (cada ${_positionDistanceFilterMeters}m).');
  }

  /// Plan B por si el stream nativo no funciona en un dispositivo concreto.
  /// Dos minutos basta para detectar un cambio de ciudad y no castiga la
  /// batería como el sondeo de 4 segundos que había antes.
  void _startFallbackPolling() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          forceAndroidLocationManager: true,
        ).timeout(const Duration(seconds: 15));
        await _handlePositionUpdate(pos);
      } catch (e) {
        debugPrint('📍 Sondeo de ubicación falló: $e');
      }
    });
  }

  // ─── Procesado de cada posición ───────────────────────────────────────────

  /// Geocodifica la posición si el usuario se movió lo suficiente y compara la
  /// ciudad resultante con la marcada para detectar una discrepancia.
  Future<void> _handlePositionUpdate(Position pos) async {
    try {
      _actualPosition = pos;

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

      final city = await _resolveCity(pos);
      if (city == null || city.isEmpty) return;

      _lastGeocodedPosition = pos;
      _actualCity = city;

      // Primera vez: no hay nada con qué comparar, se adopta directamente.
      if (_currentCity == null || _currentCity!.isEmpty) {
        debugPrint('📍 Primera ciudad detectada: $city');
        _currentCity = city;
        _currentPosition = pos;
        await _saveMarkedCity(city);
        notifyListeners();
        return;
      }

      final marked = _currentCity!.toLowerCase().trim();
      final actual = city.toLowerCase().trim();

      if (marked == actual) {
        _discrepancyCity = null;
        _discrepancyPosition = null;
        _currentPosition = pos; // Coordenadas frescas para el orden por cercanía
        notifyListeners();
        return;
      }

      if (actual == _emulatorDefaultCity) {
        _discrepancyCity = null;
        _discrepancyPosition = null;
        notifyListeners();
        return;
      }

      _discrepancyCity = city;
      _discrepancyPosition = pos;
      debugPrint('⚠️ Discrepancia de ubicación: marcada=$_currentCity, real=$city');
      notifyListeners();
    } catch (e) {
      debugPrint('📍 Error procesando la posición: $e');
    }
  }

  /// Nombre de la ciudad para unas coordenadas, con dos proveedores.
  Future<String?> _resolveCity(Position pos) async {
    final fromNominatim = await _reverseGeocodeNominatim(pos.latitude, pos.longitude);
    if (fromNominatim != null && fromNominatim.isNotEmpty) return fromNominatim;
    return _reverseGeocodeNative(pos.latitude, pos.longitude);
  }

  /// Geocodificación inversa con OpenStreetMap Nominatim, que devuelve los
  /// nombres en español y distingue el distrito de la provincia.
  Future<String?> _reverseGeocodeNominatim(double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&accept-language=es');
      final response = await http.get(url, headers: {
        'User-Agent': 'JoinApp-LocalDev',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return null;

      final address = json.decode(response.body)['address'];
      if (address == null) return null;

      final district = address['suburb'] ??
          address['village'] ??
          address['neighborhood'] ??
          address['town'] ??
          '';
      String cityOrRegion = address['city'] ?? address['county'] ?? '';
      if (cityOrRegion.isEmpty || cityOrRegion == district) {
        cityOrRegion = address['state'] ?? '';
      }
      return _joinDistrictAndRegion(district, cityOrRegion);
    } catch (e) {
      debugPrint('📍 Nominatim falló: $e');
      return null;
    }
  }

  /// Geocodificador del sistema operativo, como respaldo.
  Future<String?> _reverseGeocodeNative(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon)
          .timeout(const Duration(seconds: 5));
      if (placemarks.isEmpty) return null;

      final p = placemarks.first;
      final district = (p.subLocality?.isNotEmpty ?? false) ? p.subLocality! : (p.locality ?? '');
      String cityOrRegion = p.subAdministrativeArea ?? '';
      if (cityOrRegion.isEmpty || cityOrRegion == district) {
        cityOrRegion = p.administrativeArea ?? '';
      }
      return _joinDistrictAndRegion(district, cityOrRegion);
    } catch (e) {
      debugPrint('📍 Geocodificación nativa falló: $e');
      return null;
    }
  }

  /// "El Tambo" + "Huancayo" -> "El Tambo, Huancayo", evitando repetir el
  /// mismo nombre cuando ambos coinciden.
  static String _joinDistrictAndRegion(String district, String cityOrRegion) {
    if (district.isNotEmpty && cityOrRegion.isNotEmpty && district != cityOrRegion) {
      return '$district, $cityOrRegion';
    }
    return district.isNotEmpty ? district : cityOrRegion;
  }

  // ─── Acciones del usuario ─────────────────────────────────────────────────

  /// Fija la ciudad que el usuario eligió y descarta la discrepancia.
  Future<void> selectCity(String city, Position position) async {
    _currentCity = city;
    _currentPosition = position;
    _actualCity = city;
    _actualPosition = position;
    _discrepancyCity = null;
    _discrepancyPosition = null;
    _lastGeocodedPosition = null; // Forzar re-evaluación inmediata
    await _saveMarkedCity(city);
    notifyListeners();
  }

  Future<void> setSearchRadius(double radius) async {
    _searchRadius = radius;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('search_radius', radius);
    notifyListeners();
  }

  /// Descarta la alerta de discrepancia sin cambiar de ciudad.
  void clearDiscrepancy() {
    _discrepancyCity = null;
    _discrepancyPosition = null;
    _lastGeocodedPosition = null; // Forzar re-evaluación inmediata
    notifyListeners();
  }

  /// Aplica una posición obtenida por fuera del stream (por ejemplo, la que
  /// elige el usuario en el mapa durante el onboarding).
  Future<void> applyPosition(Position pos) async {
    _currentPosition = pos;
    _actualPosition = pos;
    notifyListeners();

    final city = await _resolveCity(pos);
    if (city == null || city.isEmpty) return;

    _actualCity = city;
    if (city == _currentCity) return;

    debugPrint('🌆 Nueva ciudad detectada: $city (antes: $_currentCity)');
    _currentCity = city;
    await _saveMarkedCity(city);
    notifyListeners();
  }

  Future<void> _saveMarkedCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_known_city', city);
    // Sin await: sincronizar con el backend no debe frenar a la interfaz.
    onMarkedCityChanged?.call(city);
  }
}

import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:join_app/core/theme/app_colors.dart';


/// Resultado del selector de mapa
class MapPickerResult {
  final LatLng latLng;
  final String address;
  const MapPickerResult({required this.latLng, required this.address});
}

/// Pantalla para seleccionar un punto en el mapa
class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final Color accentColor;

  const MapPickerScreen({
    super.key,
    this.initialLocation,
    this.accentColor = AppColors.primaryOrange,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late MapController _mapController;
  LatLng _selectedPoint = const LatLng(-12.0464, -77.0428); // Lima por defecto
  String _address = 'Cargando dirección...';
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLocation != null) {
      _selectedPoint = widget.initialLocation!;
    }
    _reverseGeocode(_selectedPoint);
    _tryGetCurrentLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _tryGetCurrentLocation() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      setState(() => _isLoadingLocation = true);
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 8));
        final ll = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _selectedPoint = ll;
          _isLoadingLocation = false;
        });
        _mapController.move(ll, 15);
        await _reverseGeocode(ll);
      } catch (_) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isLoadingAddress = true);
    String? resolvedAddress;

    // 1. Intentar OpenStreetMap Nominatim con idioma español forzado
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&accept-language=es');
      final response = await http.get(url, headers: {
        'User-Agent': 'JoinApp/1.0 (com.join.app; contact@joinapp.com)',
        'Accept-Language': 'es',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        resolvedAddress = data['display_name'] ?? data['name'];
      }
    } catch (e) {
      debugPrint('Error en reverse geocoding Nominatim de MapPicker: $e');
    }

    // 2. Fallback a Geocoder nativo si Nominatim falló
    if (resolvedAddress == null || resolvedAddress.isEmpty) {
      try {
        final placemarks = await placemarkFromCoordinates(
          point.latitude,
          point.longitude,
        ).timeout(const Duration(seconds: 4));
        if (placemarks.isNotEmpty && mounted) {
          final p = placemarks.first;
          final parts = [
            p.street,
            p.subLocality,
            p.locality,
          ].where((s) => s != null && s.isNotEmpty).join(', ');
          resolvedAddress = parts.isNotEmpty ? parts : null;
        }
      } catch (e) {
        debugPrint('Error en Geocoder nativo de MapPicker: $e');
      }
    }

    if (mounted) {
      setState(() {
        _address = resolvedAddress ??
            'Lat: ${_selectedPoint.latitude.toStringAsFixed(5)}, Lng: ${_selectedPoint.longitude.toStringAsFixed(5)}';
      });
      setState(() => _isLoadingAddress = false);
    }
  }

  void _onTap(TapPosition tapPos, LatLng point) {
    setState(() => _selectedPoint = point);
    _reverseGeocode(point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Mapa principal ────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPoint,
              initialZoom: 14,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.join.app',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPoint,
                    width: 90,
                    height: 100,
                    child: _AnimatedMapMarker(color: widget.accentColor),
                  ),
                ],
              ),
            ],
          ),

          // ── AppBar flotante ───────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (TextEditingValue textEditingValue) async {
                        if (textEditingValue.text.length < 3) {
                          return const Iterable<Map<String, dynamic>>.empty();
                        }
                        try {
                          final query = Uri.encodeComponent(textEditingValue.text);
                          final url = Uri.parse(
                              'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&countrycodes=pe&accept-language=es');
                          final res = await http.get(
                            url,
                            headers: {
                              'User-Agent': 'JoinApp/1.0 (com.join.app; contact@joinapp.com)',
                              'Accept-Language': 'es',
                            },
                          ).timeout(const Duration(seconds: 5));
                          if (res.statusCode == 200) {
                            final List data = json.decode(res.body);
                            return data.cast<Map<String, dynamic>>();
                          }
                        } catch (_) {}
                        return const Iterable<Map<String, dynamic>>.empty();
                      },
                      displayStringForOption: (option) => option['display_name'] ?? '',
                      onSelected: (option) {
                        final lat = double.tryParse(option['lat'].toString());
                        final lon = double.tryParse(option['lon'].toString());
                        if (lat != null && lon != null) {
                          final newPoint = LatLng(lat, lon);
                          setState(() {
                            _selectedPoint = newPoint;
                            _address = option['display_name'] ?? '';
                          });
                          _mapController.move(newPoint, 16);
                        }
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ListenableBuilder(
                                listenable: textEditingController,
                                builder: (context, child) {
                                  final hasText = textEditingController.text.isNotEmpty;
                                  return TextField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                                    decoration: InputDecoration(
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                      prefixIcon: Icon(
                                        Icons.search_rounded,
                                        color: widget.accentColor,
                                        size: 22,
                                      ),
                                      hintText: 'Buscar un lugar...',
                                      hintStyle: const TextStyle(
                                        color: Colors.black38,
                                      ),
                                      suffixIcon: hasText
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                color: Colors.black45,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                textEditingController.clear();
                                                HapticFeedback.lightImpact();
                                              },
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            margin: const EdgeInsets.only(top: 8),
                            width: MediaQuery.of(context).size.width - 88,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Material(
                                  color: const Color(0xF2FFFFFF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Container(
                                    constraints: const BoxConstraints(maxHeight: 260),
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      separatorBuilder: (context, index) => Divider(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        height: 1,
                                        indent: 16,
                                        endIndent: 16,
                                      ),
                                      itemBuilder: (BuildContext context, int index) {
                                        final option = options.elementAt(index);
                                        return InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            onSelected(option);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: widget.accentColor.withValues(alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.place_rounded,
                                                    color: widget.accentColor,
                                                    size: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    option['display_name'] ?? '',
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      color: Colors.black87,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Panel flotante de controles del mapa (Zoom + Mi ubicación) ──
          Positioned(
            right: 16,
            bottom: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Zoom In
                      IconButton(
                        icon: Icon(Icons.add_rounded, color: widget.accentColor, size: 20),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(_selectedPoint, currentZoom + 1);
                        },
                      ),
                      Divider(
                        color: Colors.black.withValues(alpha: 0.06),
                        height: 1,
                        indent: 8,
                        endIndent: 8,
                      ),
                      // Zoom Out
                      IconButton(
                        icon: Icon(Icons.remove_rounded, color: widget.accentColor, size: 20),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(_selectedPoint, currentZoom - 1);
                        },
                      ),
                      Divider(
                        color: Colors.black.withValues(alpha: 0.06),
                        height: 1,
                        indent: 8,
                        endIndent: 8,
                      ),
                      // My Location
                      GestureDetector(
                        onTap: _isLoadingLocation
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                _tryGetCurrentLocation();
                              },
                        child: Container(
                          width: 44,
                          height: 44,
                          color: Colors.transparent,
                          child: Center(
                            child: _isLoadingLocation
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: widget.accentColor,
                                    ),
                                  )
                                : Icon(
                                    Icons.my_location_rounded,
                                    color: widget.accentColor,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Panel inferior con dirección y botón confirmar ────
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  decoration: BoxDecoration(
                    color: const Color(0xD9FFFFFF),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pill indicador
                      Center(
                        child: Container(
                          width: 44,
                          height: 4.5,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      // Dirección detectada
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.accentColor.withValues(alpha: 0.15),
                                  widget.accentColor.withValues(alpha: 0.03),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: widget.accentColor.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: widget.accentColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'UBICACIÓN SELECCIONADA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1.2,
                                        color: widget.accentColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_isLoadingAddress)
                                      SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: widget.accentColor,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (_isLoadingAddress)
                                  const _ShimmerText()
                                else
                                  Text(
                                    _address,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  'Coordenadas: ${_selectedPoint.latitude.toStringAsFixed(6)}, ${_selectedPoint.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Botón confirmar
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _isLoadingAddress
                              ? []
                              : [
                                  BoxShadow(
                                    color: widget.accentColor.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: _isLoadingAddress
                                        ? const LinearGradient(
                                            colors: [Colors.grey, Color(0xFF999999)],
                                          )
                                        : LinearGradient(
                                            colors: [
                                              widget.accentColor,
                                              Color.lerp(widget.accentColor, Colors.white, 0.12)!,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isLoadingAddress
                                        ? null
                                        : () {
                                            HapticFeedback.mediumImpact();
                                            Navigator.pop(
                                              context,
                                              MapPickerResult(
                                                latLng: _selectedPoint,
                                                address: _address,
                                              ),
                                            );
                                          },
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Confirmar ubicación',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Marcador animado con efecto de pulso concéntrico y balanceo bobbing
class _AnimatedMapMarker extends StatefulWidget {
  final Color color;
  const _AnimatedMapMarker({required this.color});

  @override
  State<_AnimatedMapMarker> createState() => _AnimatedMapMarkerState();
}

class _AnimatedMapMarkerState extends State<_AnimatedMapMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulseProgress = _controller.value;
        final bounceOffset = -6.0 * (1.0 - (pulseProgress - 0.5).abs() * 2.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Onda de pulso concéntrica 1
            Transform.scale(
              scale: 1.0 + pulseProgress * 1.5,
              child: Opacity(
                opacity: (1.0 - pulseProgress).clamp(0.0, 1.0),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.6),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Onda de pulso concéntrica 2 (Desplazada)
            Transform.scale(
              scale: 1.0 + ((pulseProgress + 0.5) % 1.0) * 1.5,
              child: Opacity(
                opacity: (1.0 - ((pulseProgress + 0.5) % 1.0)).clamp(0.0, 1.0),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            // El PIN
            Transform.translate(
              offset: Offset(0, bounceOffset - 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.color, Color.lerp(widget.color, Colors.white, 0.15)!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  CustomPaint(
                    size: const Size(12, 10),
                    painter: _TrianglePainter(widget.color),
                  ),
                ],
              ),
            ),
            // Sombra en el suelo del mapa
            Transform.translate(
              offset: const Offset(0, 14),
              child: Container(
                width: 12,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shimmer skeleton loader para la dirección mientras carga
class _ShimmerText extends StatefulWidget {
  const _ShimmerText();

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.35, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 160,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Triángulo de la punta del marcador
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

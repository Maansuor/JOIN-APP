import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
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
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      ).timeout(const Duration(seconds: 6));
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
        setState(() => _address = parts.isNotEmpty ? parts : 'Ubicación seleccionada');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _address =
            'Lat: ${_selectedPoint.latitude.toStringAsFixed(5)}, Lng: ${_selectedPoint.longitude.toStringAsFixed(5)}');
      }
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _onTap(TapPosition tapPos, LatLng point) {
    setState(() => _selectedPoint = point);
    _reverseGeocode(point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                urlTemplate:
                    'https://basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}{r}.png',
                userAgentPackageName: 'com.join.app',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPoint,
                    width: 60,
                    height: 70,
                    child: Column(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: widget.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    widget.accentColor.withValues(alpha: 0.5),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        CustomPaint(
                          size: const Size(12, 10),
                          painter: _TrianglePainter(widget.accentColor),
                        ),
                      ],
                    ),
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Colors.white),
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
                          final res = await http.get(Uri.parse(
                              'https://nominatim.openstreetmap.org/search?q=${textEditingValue.text}&format=json&limit=5&countrycodes=pe'));
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
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            style: const TextStyle(fontSize: 14, color: Colors.white),
                            decoration: InputDecoration(
                              icon: Icon(Icons.search_rounded, color: widget.accentColor, size: 20),
                              hintText: 'Buscar un lugar...',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                              border: InputBorder.none,
                            ),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 12,
                            color: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Colors.white12),
                            ),
                            child: Container(
                              width: MediaQuery.of(context).size.width - 80,
                              constraints: const BoxConstraints(maxHeight: 260),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    leading: Icon(Icons.place_rounded, color: widget.accentColor),
                                    title: Text(
                                      option['display_name'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: Colors.white),
                                    ),
                                    onTap: () => onSelected(option),
                                  );
                                },
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

          // ── FAB Mi ubicación ──────────────────────────────────
          Positioned(
            right: 16,
            bottom: 180,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              backgroundColor: const Color(0xFF1A1A1A),
              onPressed: _isLoadingLocation ? null : _tryGetCurrentLocation,
              child: _isLoadingLocation
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.accentColor,
                      ),
                    )
                  : Icon(Icons.my_location_rounded,
                      color: widget.accentColor, size: 20),
            ),
          ),

          // ── Panel inferior con dirección y botón confirmar ────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: BoxDecoration(
                color: const Color(0xFF141414), // Dark sleek theme
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: const Border(top: BorderSide(color: Colors.white10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
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
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Dirección detectada
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              widget.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.place_rounded,
                            color: widget.accentColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ubicación seleccionada',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _isLoadingAddress
                                ? SizedBox(
                                    height: 14,
                                    child: LinearProgressIndicator(
                                      color: widget.accentColor,
                                      backgroundColor: Colors.white10,
                                    ),
                                  )
                                : Text(
                                    _address,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            const SizedBox(height: 2),
                            Text(
                              '${_selectedPoint.latitude.toStringAsFixed(5)}, ${_selectedPoint.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Botón confirmar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingAddress
                          ? null
                          : () {
                              Navigator.pop(
                                context,
                                MapPickerResult(
                                  latLng: _selectedPoint,
                                  address: _address,
                                ),
                              );
                            },
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text(
                        'Confirmar ubicación',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

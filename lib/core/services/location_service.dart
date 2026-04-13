import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Servicio para manejar la geolocalización del usuario
class LocationService {
  static String? _currentLocation;
  static Position? _currentPosition;

  static String? get currentLocation => _currentLocation;
  static Position? get currentPosition => _currentPosition;

  /// Verifica y solicita permisos de ubicación
  static Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Verificar permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Obtiene la ubicación actual del usuario
  static Future<String?> getCurrentLocation() async {
    final hasPermission = await _handlePermission();
    if (!hasPermission) {
      return null;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Obtener nombre de la ubicación
      final placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Formato: "Distrito, Ciudad" o solo "Ciudad"
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          _currentLocation = '${place.subLocality}, ${place.locality}';
        } else if (place.locality != null && place.locality!.isNotEmpty) {
          _currentLocation = place.locality;
        } else {
          _currentLocation = place.administrativeArea ?? 'Ubicación desconocida';
        }
      }

      return _currentLocation;
    } catch (e) {
      debugPrint('Error al obtener ubicación: $e');
      return null;
    }
  }

  /// Para simulación/demo - establece ubicación manualmente
  static void setMockLocation(String location) {
    _currentLocation = location;
  }
}

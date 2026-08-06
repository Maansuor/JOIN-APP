import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Condición climática simplificada para los efectos visuales del banner.
enum WeatherKind { clear, clouds, rain, snow, wind }

/// ══════════════════════════════════════════════════════════════
///  WeatherService — clima actual vía Open-Meteo (gratis, sin key)
///
///  Se usa para ambientar el banner del home con efectos reales:
///  sol radiante, nubes, lluvia, nieve o viento.
/// ══════════════════════════════════════════════════════════════
class WeatherService {
  WeatherService._();

  static WeatherKind? _cached;
  static DateTime? _fetchedAt;

  /// Obtiene la condición actual para unas coordenadas (caché de 15 min).
  static Future<WeatherKind> fetch(double lat, double lon) async {
    final now = DateTime.now();
    if (_cached != null &&
        _fetchedAt != null &&
        now.difference(_fetchedAt!).inMinutes < 15) {
      return _cached!;
    }

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=weather_code,wind_speed_10m',
      );
      final response =
          await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>? ?? {};
        final code = (current['weather_code'] as num?)?.toInt() ?? 0;
        final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0;

        var kind = _mapWmoCode(code);
        // Viento fuerte domina sobre despejado/nublado
        if (wind >= 28 &&
            (kind == WeatherKind.clear || kind == WeatherKind.clouds)) {
          kind = WeatherKind.wind;
        }

        _cached = kind;
        _fetchedAt = now;
        debugPrint('🌦️ Clima actual: $kind (código WMO $code, viento $wind km/h)');
        return kind;
      }
    } catch (e) {
      debugPrint('WeatherService error: $e');
    }
    return _cached ?? WeatherKind.clear;
  }

  /// Mapea los códigos WMO de Open-Meteo a nuestras condiciones.
  static WeatherKind _mapWmoCode(int code) {
    if (code <= 1) return WeatherKind.clear;
    if (code <= 3 || code == 45 || code == 48) return WeatherKind.clouds;
    if ((code >= 51 && code <= 67) ||
        (code >= 80 && code <= 82) ||
        code >= 95) {
      return WeatherKind.rain;
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return WeatherKind.snow;
    }
    return WeatherKind.clouds;
  }
}

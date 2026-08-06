import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:join_app/core/services/weather_service.dart';

/// Momento del día para el paisaje del banner.
enum SkyTime { morning, afternoon, night }

/// Estación del año (hemisferio sur — Perú).
enum SkySeason { summer, autumn, winter, spring }

SkyTime skyTimeNow() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 12) return SkyTime.morning;
  if (h < 18) return SkyTime.afternoon;
  return SkyTime.night;
}

SkySeason skySeasonNow() {
  return switch (DateTime.now().month) {
    12 || 1 || 2 => SkySeason.summer,
    3 || 4 || 5 => SkySeason.autumn,
    6 || 7 || 8 => SkySeason.winter,
    _ => SkySeason.spring,
  };
}

/// ══════════════════════════════════════════════════════════════
///  DynamicSkyBanner — paisaje vivo para el banner del home
///
///  Pinta un cielo según la hora (amanecer / atardecer / noche),
///  teñido por la estación, con sol/luna/estrellas, montañas en
///  silueta y efectos de clima animados: lluvia, nieve, viento,
///  nubes a la deriva o brillo solar pulsante.
/// ══════════════════════════════════════════════════════════════
class DynamicSkyBanner extends StatefulWidget {
  final SkyTime time;
  final SkySeason season;
  final WeatherKind weather;
  final Widget child;

  const DynamicSkyBanner({
    super.key,
    required this.time,
    required this.season,
    required this.weather,
    required this.child,
  });

  @override
  State<DynamicSkyBanner> createState() => _DynamicSkyBannerState();
}

class _DynamicSkyBannerState extends State<DynamicSkyBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SceneryPainter(
                  time: widget.time,
                  season: widget.season,
                  weather: widget.weather,
                  t: t,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _WeatherParticlesPainter(
                  kind: widget.weather,
                  t: t,
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

// ── Pseudo-aleatorio determinista (mismo resultado por índice) ──
double _rnd(int i, int salt) {
  final v = math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
  return v - v.floorToDouble();
}

// ══════════════════════════════════════════════════════════════
//  Paisaje: cielo, astros, nubes y montañas
// ══════════════════════════════════════════════════════════════
class _SceneryPainter extends CustomPainter {
  final SkyTime time;
  final SkySeason season;
  final WeatherKind weather;
  final double t;

  _SceneryPainter({
    required this.time,
    required this.season,
    required this.weather,
    required this.t,
  });

  Color get _seasonTint => switch (season) {
        SkySeason.summer => const Color(0xFFFFB300),
        SkySeason.autumn => const Color(0xFFD2691E),
        SkySeason.winter => const Color(0xFF7FB8DF),
        SkySeason.spring => const Color(0xFFF472B6),
      };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // ── 1. Cielo según hora del día ─────────────────────────
    final List<Color> sky;
    final Offset sunPos;
    final double sunRadius;
    final Color sunColor;
    switch (time) {
      case SkyTime.morning:
        sky = const [Color(0xFF0B3556), Color(0xFF14638F), Color(0xFFE8964C)];
        sunPos = Offset(w * 0.80, h * 0.72);
        sunRadius = 26;
        sunColor = const Color(0xFFFFD980);
      case SkyTime.afternoon:
        sky = const [Color(0xFF241047), Color(0xFF73275B), Color(0xFFE2602F)];
        sunPos = Offset(w * 0.20, h * 0.76);
        sunRadius = 30;
        sunColor = const Color(0xFFFFB14E);
      case SkyTime.night:
        sky = const [Color(0xFF040A24), Color(0xFF0A1742), Color(0xFF1B2C66)];
        sunPos = Offset(w * 0.82, h * 0.26); // luna
        sunRadius = 18;
        sunColor = const Color(0xFFF6F1DD);
    }

    // Teñir el horizonte con el color de la estación
    final horizon = Color.lerp(sky.last, _seasonTint, 0.25)!;
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [sky[0], sky[1], horizon],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    // ── 2. Estrellas (solo de noche, titilando) ─────────────
    if (time == SkyTime.night) {
      for (var i = 0; i < 26; i++) {
        final x = _rnd(i, 1) * w;
        final y = _rnd(i, 2) * h * 0.55;
        final twinkle =
            0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * math.pi * 4 + i * 1.7));
        canvas.drawCircle(
          Offset(x, y),
          0.8 + _rnd(i, 3) * 1.1,
          Paint()..color = Colors.white.withValues(alpha: 0.55 * twinkle),
        );
      }
    }

    // ── 3. Sol / Luna con halo pulsante ─────────────────────
    final glowPulse = 1.0 + 0.06 * math.sin(t * math.pi * 2);
    final isSunnyDay = time != SkyTime.night && weather == WeatherKind.clear;
    final glowRadius = sunRadius * (isSunnyDay ? 4.2 : 3.0) * glowPulse;
    canvas.drawCircle(
      sunPos,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            sunColor.withValues(alpha: isSunnyDay ? 0.5 : 0.32),
            sunColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: sunPos, radius: glowRadius)),
    );
    canvas.drawCircle(sunPos, sunRadius, Paint()..color = sunColor);
    if (time == SkyTime.night) {
      // Cráter de la luna creciente
      canvas.drawCircle(
        sunPos.translate(-sunRadius * 0.38, -sunRadius * 0.22),
        sunRadius * 0.82,
        Paint()..color = sky[0].withValues(alpha: 0.85),
      );
    }

    // ── 4. Nubes a la deriva ────────────────────────────────
    final hasClouds = weather == WeatherKind.clouds ||
        weather == WeatherKind.rain ||
        weather == WeatherKind.snow;
    if (hasClouds) {
      final cloudAlpha = time == SkyTime.night ? 0.10 : 0.16;
      for (var i = 0; i < 3; i++) {
        final speed = 0.35 + _rnd(i, 4) * 0.4;
        final cx = (((_rnd(i, 5) + t * speed) % 1.3) - 0.15) * w;
        final cy = h * (0.14 + _rnd(i, 6) * 0.28);
        final scale = 0.8 + _rnd(i, 7) * 0.6;
        _drawCloud(canvas, Offset(cx, cy), scale,
            Colors.white.withValues(alpha: cloudAlpha));
      }
    }

    // ── 5. Velo oscuro si llueve ────────────────────────────
    if (weather == WeatherKind.rain) {
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF0A1430).withValues(alpha: 0.18),
      );
    }

    // ── 6. Montañas en silueta (dos capas) ──────────────────
    final mountainBack = Paint()
      ..color = Color.lerp(sky[0], Colors.black, 0.25)!.withValues(alpha: 0.55);
    final backPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.80)
      ..lineTo(w * 0.16, h * 0.62)
      ..lineTo(w * 0.34, h * 0.78)
      ..lineTo(w * 0.52, h * 0.58)
      ..lineTo(w * 0.72, h * 0.80)
      ..lineTo(w * 0.88, h * 0.66)
      ..lineTo(w, h * 0.78)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(backPath, mountainBack);

    final mountainFront = Paint()
      ..color = Color.lerp(sky[0], Colors.black, 0.5)!.withValues(alpha: 0.75);
    final frontPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.90)
      ..lineTo(w * 0.22, h * 0.74)
      ..lineTo(w * 0.46, h * 0.92)
      ..lineTo(w * 0.66, h * 0.76)
      ..lineTo(w * 0.86, h * 0.94)
      ..lineTo(w, h * 0.86)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(frontPath, mountainFront);

    // Nieve en las cumbres durante el invierno
    if (season == SkySeason.winter) {
      final snowCap = Paint()..color = Colors.white.withValues(alpha: 0.22);
      final capPath = Path()
        ..moveTo(w * 0.46, h * 0.645)
        ..lineTo(w * 0.52, h * 0.58)
        ..lineTo(w * 0.58, h * 0.645)
        ..lineTo(w * 0.55, h * 0.655)
        ..lineTo(w * 0.52, h * 0.635)
        ..lineTo(w * 0.49, h * 0.655)
        ..close();
      canvas.drawPath(capPath, snowCap);
    }

    // ── 7. Scrim sutil para legibilidad del texto ───────────
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(alpha: 0.30),
            Colors.black.withValues(alpha: 0.05),
          ],
        ).createShader(rect),
    );
  }

  void _drawCloud(Canvas canvas, Offset center, double scale, Color color) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
          center: center, width: 90 * scale, height: 26 * scale),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: center.translate(-22 * scale, -9 * scale),
          width: 50 * scale,
          height: 22 * scale),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: center.translate(18 * scale, -7 * scale),
          width: 44 * scale,
          height: 20 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SceneryPainter old) =>
      old.t != t ||
      old.time != time ||
      old.weather != weather ||
      old.season != season;
}

// ══════════════════════════════════════════════════════════════
//  Partículas de clima: lluvia, nieve y ráfagas de viento
// ══════════════════════════════════════════════════════════════
class _WeatherParticlesPainter extends CustomPainter {
  final WeatherKind kind;
  final double t;

  _WeatherParticlesPainter({required this.kind, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    switch (kind) {
      case WeatherKind.rain:
        final paint = Paint()
          ..color = Colors.white.withValues(alpha: 0.32)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 42; i++) {
          final speed = 1.4 + _rnd(i, 11) * 1.2;
          final x = _rnd(i, 12) * w;
          final y = ((_rnd(i, 13) + t * speed) % 1.08) * h;
          final len = 9.0 + _rnd(i, 14) * 8;
          canvas.drawLine(
            Offset(x, y),
            Offset(x - 2.5, y + len),
            paint,
          );
        }

      case WeatherKind.snow:
        for (var i = 0; i < 30; i++) {
          final speed = 0.35 + _rnd(i, 21) * 0.4;
          final drift =
              math.sin(t * math.pi * 2 * (1 + _rnd(i, 22)) + i) * 0.025;
          final x = ((_rnd(i, 23) + drift) % 1.0) * w;
          final y = ((_rnd(i, 24) + t * speed) % 1.06) * h;
          canvas.drawCircle(
            Offset(x, y),
            1.4 + _rnd(i, 25) * 1.8,
            Paint()
              ..color =
                  Colors.white.withValues(alpha: 0.35 + _rnd(i, 26) * 0.35),
          );
        }

      case WeatherKind.wind:
        for (var i = 0; i < 9; i++) {
          final speed = 0.55 + _rnd(i, 31) * 0.55;
          final y = (0.08 + _rnd(i, 32) * 0.8) * h +
              math.sin(t * math.pi * 2 + i) * 4;
          final x = (((_rnd(i, 33) + t * speed) % 1.35) - 0.2) * w;
          final len = 46.0 + _rnd(i, 34) * 70;
          canvas.drawLine(
            Offset(x, y),
            Offset(x + len, y - 3),
            Paint()
              ..color = Colors.white
                  .withValues(alpha: 0.08 + _rnd(i, 35) * 0.08)
              ..strokeWidth = 2.2
              ..strokeCap = StrokeCap.round,
          );
        }

      case WeatherKind.clear || WeatherKind.clouds:
        break; // El brillo solar y las nubes viven en el paisaje
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherParticlesPainter old) =>
      old.t != t || old.kind != kind;
}

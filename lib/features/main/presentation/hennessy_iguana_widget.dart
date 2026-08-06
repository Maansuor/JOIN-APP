import 'package:flutter/material.dart';

/// Un widget vectorial interactivo premium que dibuja una iguana aventurera
/// llamada Hennessy, la cual realiza transiciones de color sumamente fluidas
/// (mimetismo camaleónico) al cambiar sus parámetros.
class HennessyIguanaWidget extends StatelessWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final double size;
  final bool hasHat;

  const HennessyIguanaWidget({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
    this.size = 80.0,
    this.hasHat = true,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: primaryColor, end: primaryColor),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      builder: (context, animPrimary, _) {
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(begin: secondaryColor, end: secondaryColor),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
          builder: (context, animSecondary, _) {
            final color1 = animPrimary ?? primaryColor;
            final color2 = animSecondary ?? secondaryColor;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    color1.withValues(alpha: 0.12),
                    color2.withValues(alpha: 0.05)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CustomPaint(
                size: Size(size, size),
                painter: _IguanaPainter(
                  primaryColor: color1,
                  secondaryColor: color2,
                  hasHat: hasHat,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _IguanaPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final bool hasHat;

  _IguanaPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.hasHat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Pintura del cuerpo (Gradiente)
    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Pintura de las crestas/espinas
    final Paint crestPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Pintura de detalles / Sombrero
    final Paint hatPaint = Paint()
      ..color = const Color(0xFF8C6D58) // Color safari marrón claro
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Paint hatRibbonPaint = Paint()
      ..color = const Color(0xFF4A3425) // Cinta del sombrero marrón oscuro
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // ── 1. DIBUJAR CUERPO Y COLA EN ESPIRAL ─────────────────────────
    final Path bodyPath = Path();
    
    // Iniciar en el pecho / parte delantera
    bodyPath.moveTo(w * 0.35, h * 0.70);
    
    // Curva hacia el cuello
    bodyPath.quadraticBezierTo(w * 0.30, h * 0.50, w * 0.40, h * 0.35);
    
    // Curva de la cabeza/hocico
    bodyPath.cubicTo(w * 0.50, h * 0.22, w * 0.68, h * 0.25, w * 0.70, h * 0.38);
    
    // Mandíbula e inferior de la cabeza
    bodyPath.quadraticBezierTo(w * 0.72, h * 0.46, w * 0.60, h * 0.50);
    
    // Garganta y estómago
    bodyPath.quadraticBezierTo(w * 0.50, h * 0.55, w * 0.52, h * 0.72);
    
    // Cola en espiral premium hacia la izquierda/abajo
    bodyPath.cubicTo(w * 0.55, h * 0.90, w * 0.25, h * 0.92, w * 0.20, h * 0.78);
    bodyPath.cubicTo(w * 0.16, h * 0.66, w * 0.28, h * 0.60, w * 0.32, h * 0.68);
    bodyPath.quadraticBezierTo(w * 0.34, h * 0.74, w * 0.28, h * 0.76);
    bodyPath.quadraticBezierTo(w * 0.24, h * 0.74, w * 0.25, h * 0.70);
    bodyPath.quadraticBezierTo(w * 0.26, h * 0.66, w * 0.30, h * 0.68);
    
    // Espalda curvada de vuelta a la espiral
    bodyPath.lineTo(w * 0.30, h * 0.78);
    bodyPath.quadraticBezierTo(w * 0.38, h * 0.82, w * 0.45, h * 0.76);
    bodyPath.lineTo(w * 0.35, h * 0.70);
    bodyPath.close();

    canvas.drawPath(bodyPath, bodyPaint);

    // ── 1.5 DIBUJAR PATAS ADORABLES (Delantera y Trasera) ───────────
    final Path frontLegPath = Path();
    frontLegPath.moveTo(w * 0.46, h * 0.68); // Iniciar en el pecho
    frontLegPath.cubicTo(w * 0.48, h * 0.76, w * 0.50, h * 0.82, w * 0.53, h * 0.84); // Bajar hacia el pie
    // Dedo 1
    frontLegPath.quadraticBezierTo(w * 0.55, h * 0.84, w * 0.56, h * 0.82);
    frontLegPath.quadraticBezierTo(w * 0.53, h * 0.80, w * 0.51, h * 0.80);
    // Dedo 2
    frontLegPath.quadraticBezierTo(w * 0.54, h * 0.79, w * 0.55, h * 0.77);
    frontLegPath.quadraticBezierTo(w * 0.52, h * 0.76, w * 0.49, h * 0.77);
    // Subir de vuelta al estómago
    frontLegPath.quadraticBezierTo(w * 0.44, h * 0.74, w * 0.40, h * 0.71);
    frontLegPath.close();
    canvas.drawPath(frontLegPath, bodyPaint);

    final Path backLegPath = Path();
    backLegPath.moveTo(w * 0.32, h * 0.75); // Iniciar en el muslo/espalda
    backLegPath.cubicTo(w * 0.28, h * 0.80, w * 0.26, h * 0.84, w * 0.28, h * 0.87); // Bajar
    // Dedo 1
    backLegPath.quadraticBezierTo(w * 0.30, h * 0.87, w * 0.31, h * 0.85);
    backLegPath.quadraticBezierTo(w * 0.29, h * 0.83, w * 0.28, h * 0.83);
    // Dedo 2
    backLegPath.quadraticBezierTo(w * 0.31, h * 0.83, w * 0.32, h * 0.81);
    backLegPath.quadraticBezierTo(w * 0.29, h * 0.80, w * 0.30, h * 0.80);
    // Subir al cuerpo
    backLegPath.quadraticBezierTo(w * 0.33, h * 0.78, w * 0.34, h * 0.77);
    backLegPath.close();
    canvas.drawPath(backLegPath, bodyPaint);

    // ── 2. DIBUJAR CRESTAS / ESPINAS DE IGUANA ────────────────────
    // Cresta 1 (Gordita en la nuca)
    final Path crest1 = Path();
    crest1.moveTo(w * 0.40, h * 0.32);
    crest1.lineTo(w * 0.33, h * 0.25);
    crest1.lineTo(w * 0.44, h * 0.28);
    crest1.close();
    canvas.drawPath(crest1, crestPaint);

    // Cresta 2 (Espalda superior)
    final Path crest2 = Path();
    crest2.moveTo(w * 0.36, h * 0.42);
    crest2.lineTo(w * 0.28, h * 0.38);
    crest2.lineTo(w * 0.38, h * 0.48);
    crest2.close();
    canvas.drawPath(crest2, crestPaint);

    // Cresta 3 (Espalda media)
    final Path crest3 = Path();
    crest3.moveTo(w * 0.34, h * 0.54);
    crest3.lineTo(w * 0.26, h * 0.52);
    crest3.lineTo(w * 0.33, h * 0.60);
    crest3.close();
    canvas.drawPath(crest3, crestPaint);

    // ── 3. DIBUJAR OJO GRANDE Y AMIGABLE ───────────────────────────
    final double eyeCenterX = w * 0.56;
    final double eyeCenterY = h * 0.34;
    final double eyeRadius = w * 0.055;

    // Fondo del ojo (blanco)
    canvas.drawCircle(
      Offset(eyeCenterX, eyeCenterY),
      eyeRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Pupila (negra)
    canvas.drawCircle(
      Offset(eyeCenterX + (w * 0.01), eyeCenterY),
      eyeRadius * 0.6,
      Paint()
        ..color = const Color(0xFF1E1E1E)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Brillo de ojo (blanco)
    canvas.drawCircle(
      Offset(eyeCenterX + (w * 0.02), eyeCenterY - (h * 0.015)),
      eyeRadius * 0.2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // ── 3.5 DIBUJAR SONRISA ADORABLE ────────────────────────────────
    final Paint mouthPaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final Path mouthPath = Path();
    mouthPath.moveTo(w * 0.62, h * 0.42);
    mouthPath.quadraticBezierTo(w * 0.66, h * 0.45, w * 0.68, h * 0.40);
    canvas.drawPath(mouthPath, mouthPaint);

    // ── 3.8 DIBUJAR CÁMARA DE TURISTA COLGANDO DEL CUELLO ────────────
    final Paint strapPaint = Paint()
      ..color = const Color(0xFF4A3425)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..isAntiAlias = true;
    
    // Correa alrededor del cuello
    canvas.drawLine(
      Offset(w * 0.44, h * 0.50),
      Offset(w * 0.46, h * 0.62),
      strapPaint,
    );

    final Paint cameraBodyPaint = Paint()
      ..color = const Color(0xFF4A4A4A)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final RRect cameraRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.42, h * 0.60, w * 0.08, h * 0.06),
      Radius.circular(w * 0.015),
    );
    canvas.drawRRect(cameraRect, cameraBodyPaint);

    final Paint lensPaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(w * 0.46, h * 0.63), w * 0.02, lensPaint);

    final Paint lensShinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(w * 0.465, h * 0.625), w * 0.006, lensShinePaint);

    // ── 4. DIBUJAR SOMBRERO DE AVENTURERO / EXPLORADOR (OPCIONAL) ──
    if (hasHat) {
      // Copa del sombrero (Safari Domed Hat)
      final Path hatDome = Path();
      hatDome.moveTo(w * 0.42, h * 0.24);
      hatDome.cubicTo(w * 0.43, h * 0.12, w * 0.61, h * 0.11, w * 0.62, h * 0.22);
      hatDome.close();
      canvas.drawPath(hatDome, hatPaint);

      // Cinta del sombrero
      final Path hatRibbon = Path();
      hatRibbon.moveTo(w * 0.425, h * 0.24);
      hatRibbon.quadraticBezierTo(w * 0.52, h * 0.22, w * 0.615, h * 0.22);
      hatRibbon.lineTo(w * 0.61, h * 0.19);
      hatRibbon.quadraticBezierTo(w * 0.52, h * 0.19, w * 0.43, h * 0.21);
      hatRibbon.close();
      canvas.drawPath(hatRibbon, hatRibbonPaint);

      // Ala del sombrero (Safari brim)
      final Path hatBrim = Path();
      hatBrim.moveTo(w * 0.32, h * 0.26);
      hatBrim.quadraticBezierTo(w * 0.52, h * 0.23, w * 0.72, h * 0.23);
      hatBrim.quadraticBezierTo(w * 0.73, h * 0.26, w * 0.68, h * 0.26);
      hatBrim.quadraticBezierTo(w * 0.52, h * 0.26, w * 0.32, h * 0.26);
      hatBrim.close();
      canvas.drawPath(hatBrim, hatPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IguanaPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.hasHat != hasHat;
  }
}

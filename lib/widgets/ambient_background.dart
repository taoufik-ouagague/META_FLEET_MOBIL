import 'package:flutter/material.dart';

/// Arriere-plan ambiant partage : degrade bleute, filigrane de flotte, orbes
/// lumineux et motifs telematiques. Pose sous le contenu des pages pour que les
/// cartes en verre aient quelque chose a laisser transparaitre.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Dégradé de fond subtil et lumineux
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEBF3FA), // Bleu glacier très doux
                Color(0xFFF8FAFC), // Blanc ardoise épuré
                Color(0xFFF0F6FB), // Nuance brand subtile
                Color(0xFFE8F2FA), // Base bleutée douce
              ],
              stops: [0.0, 0.35, 0.70, 1.0],
            ),
          ),
        ),

        // 2. Filigrane de la flotte automobile / atelier (1.png) avec fondu progressif
        Positioned.fill(
          child: Opacity(
            opacity: 0.12,
            child: ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: [0.0, 0.45, 0.90],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: Image.asset('assets/img/1.png', fit: BoxFit.cover),
            ),
          ),
        ),

        // 3. Orbes lumineux ambiants
        Positioned(
          top: -60,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00C6FF).withValues(alpha: 0.20),
                  const Color(0xFF00C6FF).withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        Positioned(
          top: 60,
          left: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF1F3A5F).withValues(alpha: 0.12),
                  const Color(0xFF1F3A5F).withValues(alpha: 0.03),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),

        Positioned(
          top: size.height * 0.35,
          left: size.width * 0.20,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00C6FF).withValues(alpha: 0.14),
                  const Color(0xFF38BDF8).withValues(alpha: 0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 40,
          left: -50,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0284C7).withValues(alpha: 0.16),
                  const Color(0xFF38BDF8).withValues(alpha: 0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),

        // 4. Motifs télématiques
        Positioned.fill(child: CustomPaint(painter: _AmbientDecorPainter())),
      ],
    );
  }
}

/// Peintre d'arrière-plan pour les motifs télématiques de l'écran d'accueil
class _AmbientDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.85, size.height * 0.12);
    final ringPaint = Paint()
      ..color = const Color(0xFF00C6FF).withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 70, ringPaint);
    canvas.drawCircle(center, 120, ringPaint);
    canvas.drawCircle(center, 180, ringPaint);

    final dotPaint = Paint()
      ..color = const Color(0xFF1F3A5F).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    const spacing = 16.0;
    const startX = 24.0;
    final startY = size.height * 0.48;
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        canvas.drawCircle(
          Offset(startX + c * spacing, startY + r * spacing),
          1.5,
          dotPaint,
        );
      }
    }

    final brDotPaint = Paint()
      ..color = const Color(0xFF00C6FF).withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    final brStartX = size.width - 80;
    final brStartY = size.height * 0.78;
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        canvas.drawCircle(
          Offset(brStartX + c * spacing, brStartY + r * spacing),
          1.5,
          brDotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

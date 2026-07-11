import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? color;

  const AppLogo({
    super.key,
    this.size = 72,
    this.showText = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoBody = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.goldenBrown,
            AppColors.goldenBrown.withValues(alpha: 0.85),
            AppColors.mossGreen,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldenBrown.withValues(alpha: 0.25),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner decorative ring
          Container(
            width: size * 0.75,
            height: size * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),
          // Stylized flow graphics
          CustomPaint(
            size: Size(size * 0.45, size * 0.45),
            painter: _LogoPainter(),
          ),
        ],
      ),
    );

    if (showText) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          logoBody,
          const SizedBox(height: 12),
          Text(
            'EventFlow',
            style: GoogleFonts.playfairDisplay(
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 1.2,
            ),
          ),
        ],
      );
    }

    return logoBody;
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.13
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    // Draw an elegant loop flow line representing 'E' and 'F' curves
    path.moveTo(size.width * 0.2, size.height * 0.7);
    path.cubicTo(
      size.width * 0.1, size.height * 0.35,
      size.width * 0.45, size.height * 0.1,
      size.width * 0.75, size.height * 0.3,
    );
    path.cubicTo(
      size.width * 0.9, size.height * 0.55,
      size.width * 0.55, size.height * 0.9,
      size.width * 0.3, size.height * 0.6,
    );

    canvas.drawPath(path, paint);

    // Cross bar for F
    final crossPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round;
      
    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.44),
      Offset(size.width * 0.78, size.height * 0.44),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/color_utils.dart';
import '../utils/constants.dart';

/// Animated circular gauge that sweeps from 0 to [score] over [duration].
class TrustScoreGauge extends StatefulWidget {
  const TrustScoreGauge({
    super.key,
    required this.score,
    this.size = 220,
    this.duration = const Duration(milliseconds: 1400),
  });

  final double score;
  final double size;
  final Duration duration;

  @override
  State<TrustScoreGauge> createState() => _TrustScoreGaugeState();
}

class _TrustScoreGaugeState extends State<TrustScoreGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = colorForScore(widget.score);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final progress = _anim.value * widget.score / 100;
          final displayed = (_anim.value * widget.score).round();
          return CustomPaint(
            painter: _GaugePainter(progress: progress, color: color),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$displayed',
                    style: GoogleFonts.syne(
                      fontSize: widget.size * 0.32,
                      fontWeight: FontWeight.w600,
                      color: color,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Trust score',
                    style: GoogleFonts.inter(
                      fontSize: widget.size * 0.058,
                      fontWeight: FontWeight.w500,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = kHairline;
    canvas.drawCircle(center, radius, track);

    final sweep = 2 * math.pi * progress;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}

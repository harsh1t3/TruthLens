import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/constants.dart';

enum ScanStepState { pending, active, done }

/// Glass step indicator pill.
///   pending → light frosted glass, muted text
///   active  → frosted glass with subtle indigo glow
///   done    → dark glass with white check
class ScanStepPill extends StatelessWidget {
  const ScanStepPill({
    super.key,
    required this.label,
    required this.state,
    required this.index,
  });

  final String label;
  final ScanStepState state;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDone = state == ScanStepState.done;
    final isActive = state == ScanStepState.active;

    final fillColor = isDone
        ? const Color(0xFF1A1A1F).withOpacity(0.88)
        : isActive
            ? Colors.white.withOpacity(0.85)
            : Colors.white.withOpacity(0.55);
    final fg = isDone ? Colors.white : kTextPrimary;
    final borderColor = isDone
        ? Colors.white.withOpacity(0.08)
        : isActive
            ? kAccent.withOpacity(0.35)
            : Colors.white.withOpacity(0.5);

    Widget pill = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: fillColor,
            border: Border.all(color: borderColor, width: 0.6),
            borderRadius: BorderRadius.circular(999),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: kAccent.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Center(child: _leading(isDone: isDone, isActive: isActive)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isActive) {
      pill = pill.animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            duration: 900.ms,
            begin: const Offset(1, 1),
            end: const Offset(1.025, 1.025),
            curve: Curves.easeInOut,
          );
    } else if (isDone) {
      pill = pill.animate().scale(
            duration: 220.ms,
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            curve: Curves.easeOutBack,
          );
    }
    return pill;
  }

  Widget _leading({required bool isDone, required bool isActive}) {
    if (isDone) {
      return const Icon(Icons.check_rounded, color: Colors.white, size: 14);
    }
    if (isActive) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          valueColor: AlwaysStoppedAnimation(kAccent),
        ),
      );
    }
    return Text(
      '${index + 1}',
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: kTextMuted,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Soft neutral surface with diffused color blobs that glass surfaces blur
/// over. Without something behind the glass, the blur has nothing to work on
/// and the cards look like flat white rectangles.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFFF6F5F3))),
        Positioned(
          top: -140,
          right: -120,
          child: _Blob(color: const Color(0xFFFFB199), size: 380),
        ),
        Positioned(
          top: 220,
          left: -140,
          child: _Blob(color: const Color(0xFFB9C8FF), size: 420),
        ),
        Positioned(
          bottom: -160,
          right: -100,
          child: _Blob(color: const Color(0xFFB7E6D9), size: 380),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(0.55), color.withOpacity(0)],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

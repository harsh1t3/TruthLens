import 'dart:ui';

import 'package:flutter/material.dart';

/// Translucent frosted-glass surface.
///
/// Composes:
///   - [BackdropFilter] for the actual frost
///   - white at low opacity for the diffuse fill
///   - 1px hairline border at black-8% for the glass edge
///   - subtle shadow for depth
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
    this.opacity = 0.55,
    this.blur = 22,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final double blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A1A1F).withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Material(color: Colors.transparent, child: content),
        ),
      ),
    );
  }
}

/// Solid dark glass — same construction, darker tint. Use sparingly for
/// primary actions / accents.
class DarkGlassCard extends StatelessWidget {
  const DarkGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: content,
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1F).withOpacity(0.88),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.07),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A1A1F).withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Material(color: Colors.transparent, child: content),
        ),
      ),
    );
  }
}

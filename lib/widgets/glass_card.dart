import 'dart:ui';

import 'package:flutter/material.dart';

/// Glass-style surface — translucent white with a hairline border and a
/// subtle drop shadow. **No `BackdropFilter` by default.**
///
/// Stacking many `BackdropFilter` instances per frame tanks framerate on
/// mid-range phones because every blur instance re-rasterizes the backdrop.
/// We rely on the diffuse colored blobs of [AmbientBackground] showing
/// through the 55% white fill to get a "frosted" feel without paying the
/// blur cost on every small card.
///
/// Pass `frosted: true` for the rare hero surface that genuinely needs a
/// real blur. Use it sparingly — at most one or two per screen.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
    this.opacity = 0.65,
    this.frosted = false,
    this.blur = 18,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final bool frosted;
  final double blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(borderRadius: borderRadius, onTap: onTap, child: content);
    }

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A1F).withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(color: Colors.transparent, child: content),
    );

    if (!frosted) {
      return ClipRRect(borderRadius: borderRadius, child: decorated);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: decorated,
      ),
    );
  }
}

/// Solid dark surface — translucent dark fill, no blur. Used for primary
/// CTAs and the selected filter chip.
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
      content = InkWell(borderRadius: borderRadius, onTap: onTap, child: content);
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1F).withOpacity(0.92),
          borderRadius: borderRadius,
          border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1A1F).withOpacity(0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(color: Colors.transparent, child: content),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/constants.dart';
import 'glass_card.dart';

/// One row in the result breakdown — label, descriptive subtext, and a
/// score bar. `score` is 0.0–1.0 where higher means *more* anomalous.
class ResultBreakdownCard extends StatelessWidget {
  const ResultBreakdownCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final double score;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).clamp(0, 100).round();
    return GlassCard(
      padding: const EdgeInsets.all(16),
      radius: kRadiusMd,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.18), width: 0.6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: score.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: kHairline,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$pct%',
            style: GoogleFonts.syne(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

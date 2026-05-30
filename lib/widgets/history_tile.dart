import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/scan_result.dart';
import '../utils/color_utils.dart';
import '../utils/constants.dart';
import 'glass_card.dart';

class HistoryTile extends StatelessWidget {
  const HistoryTile({super.key, required this.scan, required this.onTap});

  final ScanResult scan;
  final VoidCallback onTap;

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd  $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final color = colorForScore(scan.trustScore);
    final imageFile = File(scan.imagePath);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      radius: kRadiusMd,
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageFile.existsSync()
                ? Image.file(imageFile, width: 52, height: 52, fit: BoxFit.cover)
                : Container(width: 52, height: 52, color: kHairline),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verdictLabel(scan.verdict),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(scan.scannedAt),
                  style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: color.withOpacity(0.25), width: 0.5),
            ),
            child: Text(
              '${scan.trustScore.round()}',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

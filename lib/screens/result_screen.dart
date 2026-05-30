import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scan_result.dart';
import '../utils/color_utils.dart';
import '../utils/constants.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/heatmap_overlay.dart';
import '../widgets/result_breakdown_card.dart';
import '../widgets/trust_score_gauge.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.scan});

  final ScanResult scan;

  Future<void> _share(BuildContext context) async {
    final imageFile = File(scan.imagePath);
    final lines = <String>[
      'TruthLens · Trust ${scan.trustScore.round()}/100 — ${verdictLabel(scan.verdict)}',
      if (scan.aiGenerator != null) 'Generator detected: ${scan.aiGenerator}',
      if (scan.c2paPresent) 'C2PA provenance manifest present',
      'AI signal ${(scan.aiSignalScore * 100).round()}% · '
          'Spectral ${(scan.spectralScore * 100).round()}% · '
          'Metadata ${(scan.metadataScore * 100).round()}% · '
          'Compression ${(scan.compressionScore * 100).round()}%',
    ];
    final text = lines.join('\n');
    if (await imageFile.exists()) {
      await Share.shareXFiles([XFile(imageFile.path)], text: text);
    } else {
      await Share.share(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verdictColor = colorForVerdict(scan.verdict);
    return Scaffold(
      backgroundColor: kSurfaceColor,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(kPadding, 8, kPadding, 24),
                  children: [
                    _buildVerdictHero(verdictColor),
                    if (scan.aiGenerator != null) ...[
                      const Gap(18),
                      _buildGeneratorBadge(),
                    ],
                    if (scan.c2paPresent) ...[
                      const Gap(10),
                      _buildC2PABadge(),
                    ],
                    const Gap(22),
                    _buildImageWithHeatmap(),
                    const Gap(22),
                    _buildBreakdownHeader(),
                    const Gap(12),
                    _buildBreakdown(),
                    const Gap(20),
                    if (scan.findings.isNotEmpty) _buildFindingsCard(),
                    const Gap(20),
                    _buildActions(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 8, kPadding, 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: GlassCard(
              padding: EdgeInsets.zero,
              radius: 20,
              onTap: () => Navigator.of(context).maybePop(),
              child: const Icon(Icons.arrow_back_rounded, color: kTextPrimary, size: 18),
            ),
          ),
          const Gap(12),
          Text(
            'Result',
            style: GoogleFonts.syne(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 40,
            height: 40,
            child: GlassCard(
              padding: EdgeInsets.zero,
              radius: 20,
              onTap: () => _share(context),
              child: const Icon(Icons.ios_share_rounded, color: kTextPrimary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerdictHero(Color verdictColor) {
    return Center(
      child: Column(
        children: [
          TrustScoreGauge(score: scan.trustScore),
          const Gap(10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: verdictColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: verdictColor.withOpacity(0.25), width: 0.5),
            ),
            child: Text(
              verdictLabel(scan.verdict),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: verdictColor,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildGeneratorBadge() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: kRadiusMd,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF6D5BFF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6D5BFF).withOpacity(0.25), width: 0.5),
            ),
            child: const Icon(Icons.auto_awesome_outlined, color: Color(0xFF6D5BFF), size: 18),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generator detected',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kTextSecondary,
                  ),
                ),
                const Gap(2),
                Text(
                  scan.aiGenerator!,
                  style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildC2PABadge() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: kRadiusMd,
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: kTextSecondary, size: 18),
          const Gap(10),
          Expanded(
            child: Text(
              'C2PA provenance manifest present',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWithHeatmap() {
    return GlassCard(
      padding: const EdgeInsets.all(8),
      radius: kRadiusLg,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusMd),
          child: Stack(
            fit: StackFit.expand,
            children: [
              HeatmapOverlay(imagePath: scan.imagePath, heatmapPath: scan.heatmapPath),
              if (scan.heatmapPath != null)
                const Positioned(
                  left: 10,
                  top: 10,
                  child: _GlassBadge(label: 'SPECTRAL HEATMAP'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownHeader() {
    return Text(
      'Analysis breakdown',
      style: GoogleFonts.syne(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: kTextPrimary,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildBreakdown() {
    return Column(
      children: [
        ResultBreakdownCard(
          title: 'Generator signature',
          subtitle: scan.aiGenerator != null
              ? 'Direct match: ${scan.aiGenerator}'
              : 'No known AI generator name found in metadata.',
          score: scan.aiSignalScore,
          icon: Icons.auto_awesome_outlined,
          color: const Color(0xFF6D5BFF),
        ),
        const Gap(10),
        ResultBreakdownCard(
          title: 'Spectral fingerprint',
          subtitle: 'High-frequency residual vs. local contrast.',
          score: scan.spectralScore,
          icon: Icons.waves_outlined,
          color: const Color(0xFF1E88E5),
        ),
        const Gap(10),
        ResultBreakdownCard(
          title: 'Metadata integrity',
          subtitle: scan.findings.isNotEmpty
              ? scan.findings.first
              : 'EXIF tags and editor signatures.',
          score: scan.metadataScore,
          icon: Icons.fact_check_outlined,
          color: const Color(0xFFD89412),
        ),
        const Gap(10),
        ResultBreakdownCard(
          title: 'Compression coherence',
          subtitle: 'JPEG 8-pixel block boundary anomalies.',
          score: scan.compressionScore,
          icon: Icons.grid_on_outlined,
          color: const Color(0xFF7C3AED),
        ),
      ],
    );
  }

  Widget _buildFindingsCard() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: kRadiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: kTextSecondary, size: 16),
              const Gap(8),
              Text(
                'Findings',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const Gap(8),
          for (final issue in scan.findings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: kTextSecondary)),
                  Expanded(
                    child: Text(
                      issue,
                      style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 14),
            radius: kRadiusMd,
            onTap: () => _share(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.ios_share_rounded, color: kTextPrimary, size: 17),
                const Gap(8),
                Text(
                  'Share',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(10),
        Expanded(
          child: DarkGlassCard(
            padding: const EdgeInsets.symmetric(vertical: 14),
            radius: kRadiusMd,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved to history')),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bookmark_outline_rounded, color: Colors.white, size: 17),
                const Gap(8),
                Text(
                  'Saved',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      radius: 999,
      opacity: 0.35,
      blur: 12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_outlined, size: 12, color: kTextPrimary),
          const Gap(6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

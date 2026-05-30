import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/scan_result.dart';
import '../services/ai_classifier_service.dart';
import '../utils/color_utils.dart';
import '../utils/constants.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_card.dart';
import 'analysis_screen.dart';
import 'history_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Re-render once the classifier warmup completes, so the diagnostic
    // banner reflects the latest status.
    AiClassifierService.instance.warmUp().whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked != null && mounted) await _launchAnalysis(File(picked.path));
  }

  Future<void> _pickFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission denied')),
      );
      return;
    }
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 100);
    if (picked != null && mounted) await _launchAnalysis(File(picked.path));
  }

  Future<void> _launchAnalysis(File file) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnalysisScreen(imageFile: file)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<ScanResult>('scans_v2');
    return Scaffold(
      backgroundColor: kSurfaceColor,
      body: AmbientBackground(
        child: SafeArea(
          child: ValueListenableBuilder<Box<ScanResult>>(
            valueListenable: box.listenable(),
            builder: (context, b, _) {
              final all = b.values.toList()
                ..sort((a, c) => c.scannedAt.compareTo(a.scannedAt));
              final recent = all.take(5).toList();
              final flaggedCount = all.where((s) => s.trustScore < 80).length;
              final flaggedPct = all.isEmpty ? 0 : ((flaggedCount / all.length) * 100).round();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildTopBar(context)),
                  SliverToBoxAdapter(child: _buildHeadline()),
                  SliverToBoxAdapter(child: _buildClassifierStatus()),
                  SliverToBoxAdapter(child: _buildActions()),
                  const SliverToBoxAdapter(child: Gap(28)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: kPadding),
                    sliver: SliverToBoxAdapter(
                      child: _buildStatsBar(all.length, flaggedPct),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Gap(28)),
                  SliverToBoxAdapter(child: _buildRecentHeader(context)),
                  if (recent.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: kPadding),
                      sliver: SliverList.separated(
                        itemCount: recent.length,
                        separatorBuilder: (_, _) => const Gap(10),
                        itemBuilder: (_, i) => _RecentScanCard(scan: recent[i]),
                      ),
                    ),
                  const SliverToBoxAdapter(child: Gap(28)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 8, kPadding, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.image_search_rounded, color: kTextPrimary, size: 20),
              const Gap(8),
              Text(
                'TruthLens',
                style: GoogleFonts.syne(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          _GlassIconButton(
            icon: Icons.history_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadline() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 36, kPadding, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Was this made\nby a person?',
            style: GoogleFonts.syne(
              fontSize: 40,
              height: 1.04,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.1,
              color: kTextPrimary,
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.06, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
          const Gap(12),
          Text(
            'Detect generator signatures, C2PA provenance, and spectral fingerprints. Fully on-device.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: kTextSecondary,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 120.ms),
        ],
      ),
    );
  }

  Widget _buildClassifierStatus() {
    final svc = AiClassifierService.instance;
    if (svc.status == ClassifierStatus.ready) {
      return const SizedBox.shrink();
    }
    final isWarming = svc.status == ClassifierStatus.warming;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 0, kPadding, 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusMd),
          onTap: isWarming ? null : () => _showClassifierDiagnostic(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isWarming
                  ? const Color(0xFFFFF7E6)
                  : const Color(0xFFFEE5E1),
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(
                color: isWarming
                    ? const Color(0xFFD89412).withOpacity(0.25)
                    : const Color(0xFFD33F2F).withOpacity(0.3),
                width: 0.6,
              ),
            ),
            child: Row(
              children: [
                if (isWarming)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      valueColor: AlwaysStoppedAnimation(Color(0xFFD89412)),
                    ),
                  )
                else
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFD33F2F),
                    size: 16,
                  ),
                const Gap(10),
                Expanded(
                  child: Text(
                    isWarming
                        ? 'Preparing on-device AI detector…'
                        : 'AI detector unavailable — using heuristics only. Tap for details.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isWarming
                          ? const Color(0xFF8B6914)
                          : const Color(0xFF8C2A20),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClassifierDiagnostic() {
    final svc = AiClassifierService.instance;
    final diag = StringBuffer()
      ..writeln('Status: ${svc.status.name}')
      ..writeln('Error:  ${svc.error ?? "(none)"}')
      ..writeln('Last output type: ${svc.lastOutputType ?? "(no inference yet)"}');
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLg)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bug_report_outlined,
                      color: Color(0xFFD33F2F), size: 18),
                  const Gap(8),
                  Text(
                    'AI detector diagnostic',
                    style: GoogleFonts.syne(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: kTextPrimary,
                    ),
                  ),
                ],
              ),
              const Gap(12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F5F3),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  border: Border.all(color: kHairline),
                ),
                child: SelectableText(
                  diag.toString().trimRight(),
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: kTextPrimary,
                    height: 1.5,
                  ),
                ),
              ),
              const Gap(10),
              Text(
                'When the detector is offline, only the metadata + spectral '
                'heuristics run. They miss most modern AI images. Copy this '
                'diagnostic so the cause can be debugged.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: kTextSecondary,
                  height: 1.5,
                ),
              ),
              const Gap(12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: diag.toString()));
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Diagnostic copied to clipboard')),
                      );
                    },
                    child: Text(
                      'Copy',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: kAccent,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Close',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: kTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPadding),
      child: Row(
        children: [
          Expanded(
            child: _GlassAction(
              icon: Icons.camera_alt_outlined,
              label: 'Capture',
              onTap: _pickFromCamera,
            ),
          ),
          const Gap(10),
          Expanded(
            child: _PrimaryAction(
              icon: Icons.add_photo_alternate_outlined,
              label: 'Upload',
              onTap: _pickFromGallery,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(int total, int flaggedPct) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: kRadiusLg,
      child: Row(
        children: [
          _StatChip(label: 'Total scans', value: '$total'),
          Container(width: 1, height: 30, color: kHairline),
          _StatChip(label: 'Flagged', value: '$flaggedPct%'),
        ],
      ),
    );
  }

  Widget _buildRecentHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 0, kPadding, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Recent',
            style: GoogleFonts.syne(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
              letterSpacing: -0.2,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'See all',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: kTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPadding),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
        child: Column(
          children: [
            const Icon(Icons.search_rounded, color: kTextMuted, size: 28),
            const Gap(10),
            Text(
              'No scans yet',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const Gap(4),
            Text(
              'Capture or upload an image to begin.',
              style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: GlassCard(
        padding: EdgeInsets.zero,
        radius: 20,
        onTap: onTap,
        child: Icon(icon, size: 18, color: kTextPrimary),
      ),
    );
  }
}

class _GlassAction extends StatelessWidget {
  const _GlassAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      radius: 16,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: kTextPrimary),
          const Gap(8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DarkGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      radius: 16,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const Gap(8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: kTextSecondary,
              ),
            ),
            const Gap(2),
            Text(
              value,
              style: GoogleFonts.syne(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentScanCard extends StatelessWidget {
  const _RecentScanCard({required this.scan});
  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    final color = colorForScore(scan.trustScore);
    final imageFile = File(scan.imagePath);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultScreen(scan: scan)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageFile.existsSync()
                ? Image.file(imageFile, width: 48, height: 48, fit: BoxFit.cover)
                : Container(width: 48, height: 48, color: kHairline),
          ),
          const Gap(12),
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
                const Gap(2),
                Text(
                  _shortDate(scan.scannedAt),
                  style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: color.withOpacity(0.25), width: 0.5),
            ),
            child: Text(
              '${scan.trustScore.round()}',
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

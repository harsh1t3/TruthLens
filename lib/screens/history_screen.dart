import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/scan_result.dart';
import '../services/analysis_orchestrator.dart';
import '../utils/constants.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/history_tile.dart';
import 'result_screen.dart';

enum _Filter { all, suspicious, authentic }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Filter _filter = _Filter.all;

  bool _matches(ScanResult s) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.suspicious:
        return s.trustScore < 80;
      case _Filter.authentic:
        return s.trustScore >= 80;
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<ScanResult>('scans_v2');
    final orchestrator = AnalysisOrchestrator(box);

    return Scaffold(
      backgroundColor: kSurfaceColor,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const Gap(8),
              _buildFilters(),
              const Gap(12),
              Expanded(
                child: ValueListenableBuilder<Box<ScanResult>>(
                  valueListenable: box.listenable(),
                  builder: (context, b, _) {
                    final all = b.values.toList()
                      ..sort((a, c) => c.scannedAt.compareTo(a.scannedAt));
                    final filtered = all.where(_matches).toList();
                    if (filtered.isEmpty) return _buildEmpty();
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(kPadding, 4, kPadding, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Gap(10),
                      itemBuilder: (_, i) {
                        final scan = filtered[i];
                        return Dismissible(
                          key: ValueKey(scan.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2553F).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(kRadiusMd),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          onDismissed: (_) => orchestrator.deleteScan(scan),
                          child: HistoryTile(
                            scan: scan,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ResultScreen(scan: scan)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
            'History',
            style: GoogleFonts.syne(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPadding),
      child: Row(
        children: [
          _chip('All', _Filter.all),
          const Gap(8),
          _chip('Suspicious', _Filter.suspicious),
          const Gap(8),
          _chip('Authentic', _Filter.authentic),
        ],
      ),
    );
  }

  Widget _chip(String label, _Filter f) {
    final selected = _filter == f;
    final text = Text(
      label,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: selected ? Colors.white : kTextPrimary,
      ),
    );
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
    return selected
        ? DarkGlassCard(
            padding: padding,
            radius: 999,
            onTap: () => setState(() => _filter = f),
            child: text,
          )
        : GlassCard(
            padding: padding,
            radius: 999,
            opacity: 0.45,
            blur: 18,
            onTap: () => setState(() => _filter = f),
            child: text,
          );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kPadding),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_rounded, size: 28, color: kTextMuted),
              const Gap(10),
              Text(
                'No matching scans',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

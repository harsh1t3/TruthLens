import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/scan_result.dart';
import '../services/analysis_orchestrator.dart';
import '../utils/constants.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/scan_step_pill.dart';
import 'result_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, required this.imageFile});

  final File imageFile;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  /// Per-pill state. The orchestrator runs as one isolate call, so we pace
  /// the visual step progression on a timer for UX, then snap-complete all
  /// remaining pills once compute() returns.
  final List<ScanStepState> _steps =
      List.generate(kAnalysisSteps.length, (_) => ScanStepState.pending);

  bool _failed = false;
  Timer? _stepTimer;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _startAnimation();
    _startAnalysis();
  }

  void _startAnimation() {
    _steps[0] = ScanStepState.active;
    setState(() {});
    _stepTimer = Timer.periodic(const Duration(milliseconds: 550), (t) {
      if (!mounted) return;
      if (_currentStep >= kAnalysisSteps.length) {
        t.cancel();
        return;
      }
      setState(() {
        _steps[_currentStep] = ScanStepState.done;
        _currentStep++;
        if (_currentStep < kAnalysisSteps.length) {
          _steps[_currentStep] = ScanStepState.active;
        }
      });
    });
  }

  Future<void> _startAnalysis() async {
    try {
      final box = Hive.box<ScanResult>('scans_v2');
      final orchestrator = AnalysisOrchestrator(box);
      final scan = await orchestrator.runAnalysis(widget.imageFile);

      _stepTimer?.cancel();
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _steps.length; i++) {
          _steps[i] = ScanStepState.done;
        }
      });

      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(scan: scan)),
      );
    } catch (e) {
      _stepTimer?.cancel();
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfaceColor,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kPadding),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 5,
                        child: GlassCard(
                          padding: const EdgeInsets.all(10),
                          radius: kRadiusXl,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(kRadiusLg),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(widget.imageFile, fit: BoxFit.cover),
                                if (!_failed) _ScanLineSweep(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Gap(20),
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (int i = 0; i < kAnalysisSteps.length; i++)
                                ScanStepPill(label: kAnalysisSteps[i], state: _steps[i], index: i),
                            ],
                          ),
                        ),
                      ),
                      if (_failed) _buildError(),
                      const Gap(12),
                    ],
                  ),
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
      padding: const EdgeInsets.fromLTRB(kPadding, 8, kPadding, 16),
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
            'Analyzing',
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

  Widget _buildError() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: kRadiusMd,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C)),
          const Gap(10),
          Expanded(
            child: Text(
              'Could not analyze this image. It may be corrupt or in an unsupported format.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFB91C1C)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

class _ScanLineSweep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (ctx, c) {
          return Stack(
            children: [
              Container(color: const Color(0xFF1A1A1F).withOpacity(0.08)),
              Positioned(
                left: 0,
                right: 0,
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .moveY(
                    begin: -90,
                    end: c.maxHeight,
                    duration: 2000.ms,
                    curve: Curves.easeInOut,
                  ),
            ],
          );
        },
      ),
    );
  }
}

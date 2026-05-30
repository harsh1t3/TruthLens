import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/constants.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_card.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfaceColor,
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    radius: 28,
                    child: const Center(
                      child: Icon(
                        Icons.image_search_rounded,
                        color: kTextPrimary,
                        size: 40,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1, 1),
                    )
                    .fadeIn(duration: 500.ms),
                const SizedBox(height: 22),
                Text(
                  'TruthLens',
                  style: GoogleFonts.syne(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                    letterSpacing: -0.6,
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 280.ms).slideY(
                      begin: 0.15,
                      end: 0,
                      duration: 600.ms,
                      delay: 280.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: 8),
                Text(
                  'Know what made your image',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: kTextSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

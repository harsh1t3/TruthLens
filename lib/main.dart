import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/scan_result.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ScanResultAdapter());
  await Hive.openBox<ScanResult>('scans_v2');
  runApp(const TruthLensApp());
}

class TruthLensApp extends StatelessWidget {
  const TruthLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8E44EC),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: kSurfaceColor,
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'TruthLens',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
          displayLarge: GoogleFonts.syne(textStyle: base.textTheme.displayLarge),
          displayMedium: GoogleFonts.syne(textStyle: base.textTheme.displayMedium),
          displaySmall: GoogleFonts.syne(textStyle: base.textTheme.displaySmall),
          headlineLarge: GoogleFonts.syne(textStyle: base.textTheme.headlineLarge),
          headlineMedium: GoogleFonts.syne(textStyle: base.textTheme.headlineMedium),
          headlineSmall: GoogleFonts.syne(textStyle: base.textTheme.headlineSmall),
          titleLarge: GoogleFonts.syne(
            textStyle: base.textTheme.titleLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

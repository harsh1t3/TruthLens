import 'package:flutter/material.dart';

void main() {
  runApp(const TruthLensApp());
}

class TruthLensApp extends StatelessWidget {
  const TruthLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'TruthLens',
      home: Scaffold(body: Center(child: Text('TruthLens'))),
    );
  }
}

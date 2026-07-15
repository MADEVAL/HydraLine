// /app/dashboard — a pure Flutter CanvasKit page (app mode).
// No Hydraline involvement: this route is noindex'd and crawlers never
// see it. It demonstrates that Hydraline coexists with any existing
// Flutter Web routes without modification.
import 'package:flutter/material.dart';

class AppDashboardPage extends StatelessWidget {
  const AppDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dashboard')),
    body: const Center(
      child: Text(
        'This page runs on CanvasKit. No Hydraline — just Flutter.',
        style: TextStyle(fontSize: 18),
      ),
    ),
  );
}

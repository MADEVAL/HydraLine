/// Build-time extraction sandbox: provides stub ancestors so `Seo.*` widgets
/// don't fail when `dart:ui`-dependent ancestors are absent.
/// (ARCHITECTURE.md §9; W-4, R2).
library;

import 'package:flutter/material.dart';
import 'package:hydraline/hydraline.dart' show SsgCollector;

import 'hydra_app.dart' show HydraScope;

/// Wraps the widget tree in stub [MediaQuery] and [Directionality] so
/// build-time SSG extraction never fails on missing ancestors.
class SsgSandbox extends StatelessWidget {
  const SsgSandbox({required this.collector, required this.child, super.key});

  final SsgCollector collector;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HydraScope(
      collector: collector,
      isSsgMode: true,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1024, 768)),
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      ),
    );
  }
}

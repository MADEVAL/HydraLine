/// Integration widget and scope: provides [SsgCollector] to the widget tree
/// via [HydraScope] InheritedWidget.
library;

import 'package:flutter/widgets.dart';
import 'package:hydraline/hydraline.dart' show SsgCollector;

/// Top-level wrapper; NOT a replacement for `MaterialApp`. Provides
/// [HydraScope] so `Seo.*` widgets can self-register during SSG extraction
/// or run normally at runtime.
class HydraApp extends StatelessWidget {
  const HydraApp({required this.child, this.collector, super.key});

  final Widget child;
  final SsgCollector? collector;

  @override
  Widget build(BuildContext context) {
    return HydraScope(
      collector: collector,
      isSsgMode: collector != null,
      child: child,
    );
  }
}

/// InheritedWidget carrying the current [SsgCollector] (if any) and a flag
/// indicating whether we are in build-time SSG mode (the only access
/// point from widgets).
class HydraScope extends InheritedWidget {
  const HydraScope({
    required this.collector,
    required this.isSsgMode,
    required super.child,
    super.key,
  });

  final SsgCollector? collector;
  final bool isSsgMode;

  /// Finds the nearest [HydraScope] ancestor.
  static HydraScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HydraScope>();
    assert(scope != null, 'HydraScope not found in the widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant HydraScope oldWidget) =>
      collector != oldWidget.collector || isSsgMode != oldWidget.isSsgMode;
}

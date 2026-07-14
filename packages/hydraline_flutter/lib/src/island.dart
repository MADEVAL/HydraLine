/// Island widget — a Flutter island that registers as an
/// `IslandPlaceholderNode` during extraction and renders a placeholder UI
/// at configuration time (ARCHITECTURE.md §11.1; W-2).
library;

import 'package:flutter/widgets.dart';
import 'package:hydraline/hydraline.dart'
    show
        HydrationDirective,
        IslandRenderMode,
        IslandSize,
        IslandStyleMode,
        IslandType,
        IslandSpec;

import 'hydra_app.dart' show HydraScope;

/// A declarative island zone. In SSG mode it self-registers an
/// `IslandPlaceholderNode`; at runtime the actual inter-activity is driven by
/// the Hydraline dispatcher JS.
class Island extends StatefulWidget {
  const Island({
    required this.id,
    required this.type,
    this.props = const {},
    this.directive = HydrationDirective.onIdle,
    this.renderMode = IslandRenderMode.ssr,
    this.styleMode = IslandStyleMode.shadow,
    this.width,
    this.height,
    this.placeholder,
    this.errorFallback,
    this.mediaQuery,
    super.key,
  });

  final String id;
  final IslandType type;
  final Map<String, Object?> props;
  final HydrationDirective directive;
  final IslandRenderMode renderMode;
  final IslandStyleMode styleMode;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorFallback;
  final String? mediaQuery;

  @override
  State<Island> createState() => _IslandState();
}

class _IslandState extends State<Island> {
  var _registered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_registered) {
      final collector = HydraScope.of(context).collector;
      if (collector != null) {
        final spec = _toSpec();
        collector.addIsland(spec);
        _registered = true;
      }
    }
  }

  IslandSpec _toSpec() {
    final w = widget.width;
    final h = widget.height;
    return IslandSpec(
      id: widget.id,
      type: widget.type,
      directive: widget.directive,
      renderMode: widget.renderMode,
      styleMode: widget.styleMode,
      size: (w != null && h != null)
          ? IslandSize(width: w.toInt(), height: h.toInt())
          : null,
      state: widget.props,
      mountSelector: widget.mediaQuery != null
          ? '@media(${widget.mediaQuery})'
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.placeholder ??
        SizedBox(width: widget.width, height: widget.height);
  }
}

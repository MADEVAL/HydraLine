/// `Seo.*` widgets (surface A): self-registering Flutter widgets with dual
/// nature - they render a visual and register semantic info into the nearest
/// [SsgCollector] via [HydraScope].
///
/// Registration happens unconditionally on each build; the collector handles
/// deduplication by key.
library;

import 'package:flutter/widgets.dart';
import 'package:hydraline/hydraline.dart'
    show SafeUrl, SectionRole, SeoMeta, SsgCollector;

import 'hydra_app.dart' show HydraScope;

/// Self-registering SEO widgets.
abstract final class Seo {
  static Widget text(String text, {int? headingLevel, Key? key}) => _SeoText(
    text: text,
    headingLevel: headingLevel,
    key: key ?? ValueKey('seo-text-$text'),
  );

  static Widget heading(String text, {required int level, Key? key}) =>
      _SeoHeading(
        text: text,
        level: level,
        key: key ?? ValueKey('seo-h$level-$text'),
      );

  static Widget image(
    String src, {
    required String alt,
    int? width,
    int? height,
    Key? key,
  }) => _SeoImage(
    src: src,
    alt: alt,
    width: width,
    height: height,
    key: key ?? ValueKey('seo-img-$src'),
  );

  /// A link with dual nature: registers an `<a href>` for extraction and is
  /// tappable at runtime. When [onTap] is omitted, internal hrefs (starting
  /// with `/`) navigate via `Navigator.pushNamed`; external hrefs need an
  /// explicit [onTap] (for example with `url_launcher`).
  static Widget link({
    required String href,
    required Widget child,
    VoidCallback? onTap,
    Key? key,
  }) => _SeoLink(
    href: href,
    onTap: onTap,
    child: child,
    key: key ?? ValueKey('seo-link-$href'),
  );

  static Widget section({
    required SectionRole role,
    required List<Widget> children,
    Key? key,
  }) => _SeoSection(
    role: role,
    children: children,
    key: key ?? ValueKey('seo-section-${role.name}'),
  );

  static Widget list({
    required bool ordered,
    required List<Widget> items,
    Key? key,
  }) => _SeoList(
    ordered: ordered,
    items: items,
    key: key ?? ValueKey('seo-list-${ordered ? "ol" : "ul"}'),
  );

  static Widget head(SeoMeta meta) =>
      _SeoHead(meta: meta, key: const ValueKey('seo-head'));
}

class _SeoText extends StatelessWidget {
  const _SeoText({required this.text, this.headingLevel, super.key});

  final String text;
  final int? headingLevel;

  @override
  Widget build(BuildContext context) {
    HydraScope.of(context).collector?.addText(
      text,
      headingLevel: headingLevel,
      key: key?.toString() ?? '',
    );
    return Text(text);
  }
}

class _SeoHeading extends StatelessWidget {
  const _SeoHeading({required this.text, required this.level, super.key});

  final String text;
  final int level;

  @override
  Widget build(BuildContext context) {
    HydraScope.of(context).collector?.addText(text, headingLevel: level);
    return Text(text);
  }
}

class _SeoImage extends StatelessWidget {
  const _SeoImage({
    required this.src,
    required this.alt,
    this.width,
    this.height,
    super.key,
  });

  final String src;
  final String alt;
  final int? width;
  final int? height;

  @override
  Widget build(BuildContext context) {
    final scope = HydraScope.of(context);
    final url = SafeUrl.tryParse(src);
    if (url != null) {
      scope.collector?.addImage(url, alt, width: width, height: height);
    }
    final w = width?.toDouble();
    final h = height?.toDouble();
    // During SSG extraction only the registration above matters; skip the
    // network fetch and render a sized placeholder instead.
    if (scope.isSsgMode) {
      return SizedBox(width: w, height: h);
    }
    return Image.network(
      src,
      width: w,
      height: h,
      semanticLabel: alt,
      errorBuilder: (_, _, _) => SizedBox(width: w, height: h),
    );
  }
}

class _SeoLink extends StatelessWidget {
  const _SeoLink({
    required this.href,
    required this.child,
    this.onTap,
    super.key,
  });

  final String href;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = SafeUrl.tryParse(href);
    if (url != null) {
      final label = switch (child) {
        final Text text => text.data ?? '',
        _ => '',
      };
      HydraScope.of(context).collector?.addLink(url, label);
    }
    return Semantics(
      link: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap ?? () => _navigate(context),
          child: child,
        ),
      ),
    );
  }

  void _navigate(BuildContext context) {
    if (!href.startsWith('/')) {
      return;
    }
    Navigator.maybeOf(context)?.pushNamed(href);
  }
}

class _SeoSection extends StatelessWidget {
  const _SeoSection({required this.role, required this.children, super.key});

  final SectionRole role;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Registration is flat: the section's children self-register into the
    // collector in build order. The [role] shapes the visual grouping only.
    return Column(children: children);
  }
}

class _SeoList extends StatelessWidget {
  const _SeoList({required this.ordered, required this.items, super.key});

  final bool ordered;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(children: items);
  }
}

class _SeoHead extends StatelessWidget {
  const _SeoHead({required this.meta, super.key});

  final SeoMeta meta;

  @override
  Widget build(BuildContext context) {
    HydraScope.of(context).collector?.addMeta(meta);
    return const SizedBox.shrink();
  }
}

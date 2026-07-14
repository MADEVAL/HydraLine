/// `robots.txt` generation (ARCHITECTURE.md §7.3; SEO-6, C-6).
library;

import 'escaping.dart' show SafeUrl;

/// A `User-agent` group with its allow/disallow paths.
class RobotsRule {
  const RobotsRule({
    required this.userAgent,
    this.allow = const [],
    this.disallow = const [],
  });

  final String userAgent;
  final List<String> allow;
  final List<String> disallow;
}

/// `robots.txt` generator.
abstract final class Robots {
  static String generate({
    required List<RobotsRule> rules,
    List<SafeUrl> sitemaps = const [],
  }) {
    final groups = <String>[];
    for (final rule in rules) {
      final lines = <String>['User-agent: ${rule.userAgent}'];
      for (final path in rule.disallow) {
        lines.add('Disallow: $path');
      }
      for (final path in rule.allow) {
        lines.add('Allow: $path');
      }
      groups.add(lines.join('\n'));
    }

    final buffer = StringBuffer(groups.join('\n\n'));
    if (sitemaps.isNotEmpty) {
      if (groups.isNotEmpty) {
        buffer.write('\n\n');
      }
      buffer.write(sitemaps.map((s) => 'Sitemap: ${s.value}').join('\n'));
    }
    buffer.write('\n');
    return buffer.toString();
  }
}

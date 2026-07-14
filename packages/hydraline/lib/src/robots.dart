/// `robots.txt` generation.
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
      _requireSingleLine(rule.userAgent, 'userAgent');
      final lines = <String>['User-agent: ${rule.userAgent}'];
      for (final path in rule.disallow) {
        _requireSingleLine(path, 'disallow');
        lines.add('Disallow: $path');
      }
      for (final path in rule.allow) {
        _requireSingleLine(path, 'allow');
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

  /// A value containing a line break would inject extra robots.txt
  /// directives; fail loudly instead of emitting a corrupted file.
  static void _requireSingleLine(String value, String name) {
    if (value.contains('\n') || value.contains('\r')) {
      throw ArgumentError.value(value, name, 'must not contain line breaks');
    }
  }
}

import 'package:hydraline_flutter/hydraline_flutter.dart';
import 'package:test/test.dart';

void main() {
  group('hosting recipes', () {
    const recipes = {
      'Firebase': hostingFirebase,
      'Netlify': hostingNetlify,
      'Cloudflare': hostingCloudflare,
      'GitHub Pages': hostingGitHubPages,
    };

    test('all four recipes are non-empty', () {
      for (final entry in recipes.entries) {
        expect(entry.value, isNotEmpty, reason: entry.key);
      }
    });

    test('every recipe uses the real SSG build command', () {
      for (final entry in recipes.entries) {
        expect(
          entry.value,
          contains('dart run hydraline_flutter:build'),
          reason: entry.key,
        );
      }
    });

    test('every recipe publishes the dist directory', () {
      for (final entry in recipes.entries) {
        expect(entry.value, contains('dist'), reason: entry.key);
      }
    });
  });
}

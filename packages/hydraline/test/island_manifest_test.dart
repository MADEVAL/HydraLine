import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  group('IslandStateCodec (DS1-DS4)', () {
    test('encode/decode round-trip', () {
      const state = {'price': 100, 'currency': 'RUB', 'inStock': true};
      final encoded = IslandStateCodec.encode(state);
      expect(IslandStateCodec.decode(encoded), state);
    });

    test('encode HTML-escapes the attribute value (DS1)', () {
      final encoded = IslandStateCodec.encode({'q': '"a"<b>&c'});
      expect(encoded, contains('&quot;'));
      expect(encoded, isNot(contains('"a"')));
    });

    test('rejects non-JSON-safe values like DateTime (DS3)', () {
      expect(
        () => IslandStateCodec.encode({'when': DateTime.utc(2026)}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('byteSize reports the JSON payload size (DS4)', () {
      expect(IslandStateCodec.byteSize({'a': 1}), '{"a":1}'.length);
    });
  });

  group('IslandManifest (C-7)', () {
    test('serialize/deserialize round-trip', () {
      final manifest = IslandManifest([
        const IslandSpec(
          id: 'calc',
          type: IslandType.flutter,
          directive: HydrationDirective.onVisible,
          size: IslandSize(width: 640, height: 480),
          state: {'price': 100},
        ),
        const IslandSpec(
          id: 'reviews',
          type: IslandType.htmx,
          endpoint: '/api/reviews',
        ),
      ]);
      final data = manifest.serialize();
      final restored = IslandManifest.deserialize(data);
      expect(restored.islands, hasLength(2));
      expect(restored.islands[0].id, 'calc');
      expect(restored.islands[0].type, IslandType.flutter);
      expect(restored.islands[0].directive, HydrationDirective.onVisible);
      expect(restored.islands[0].size!.width, 640);
      expect(restored.islands[0].state['price'], 100);
      expect(restored.islands[1].type, IslandType.htmx);
      expect(restored.islands[1].endpoint, '/api/reviews');
    });
  });
}

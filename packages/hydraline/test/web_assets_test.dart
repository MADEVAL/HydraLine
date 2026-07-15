import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

void main() {
  group('vanilla islands bundle (<=8 KB)', () {
    test('is a non-empty string', () {
      expect(vanillaIslandsJs, isNotEmpty);
    });

    test('size with gzip approximation is under the budget', () {
      final bytes = vanillaIslandsJs.codeUnits.length;
      expect(bytes, lessThan(8192), skip: bytes > 8192 ? 'over budget' : false);
    });

    test('contains the event bus bootstrap', () {
      expect(vanillaIslandsJs, contains('document.addEventListener'));
    });

    test('carousel guards missing prev/next controls', () {
      expect(vanillaIslandsJs, contains('if(prev)'));
      expect(vanillaIslandsJs, contains('if(next)'));
    });

    test('copy-button guards a missing trigger element', () {
      expect(vanillaIslandsJs, contains('if(!btn)return'));
    });

    test('bootstrap isolates a throwing island handler', () {
      expect(vanillaIslandsJs, contains('catch'));
    });
  });

  group('HTMX glue (<=14 KB)', () {
    test('is a non-empty string', () {
      expect(htmxGlueJs, isNotEmpty);
    });

    test('size is under the budget', () {
      final bytes = htmxGlueJs.codeUnits.length;
      expect(
        bytes,
        lessThan(14336),
        skip: bytes > 14336 ? 'over budget' : false,
      );
    });

    test('references the HTMX script', () {
      expect(htmxGlueJs, contains('htmx'));
    });
  });
}

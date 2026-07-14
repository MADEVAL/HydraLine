import 'package:hydraline_flutter/hydraline_flutter.dart';
import 'package:hydraline_flutter/island_main.dart' as island_entry;
import 'package:test/test.dart';

void main() {
  group('Custom Element JS', () {
    test('is a non-empty string', () {
      expect(jsCustomElement, isNotEmpty);
    });

    test('defines the hydraline-island custom element', () {
      expect(jsCustomElement, contains('customElements.define'));
      expect(jsCustomElement, contains('hydraline-island'));
    });

    test('uses Declarative Shadow DOM (no FOUC)', () {
      expect(jsCustomElement, contains('shadowRoot'));
      expect(jsCustomElement, contains('template'));
    });

    test('includes ResizeObserver for view constraints', () {
      expect(jsCustomElement, contains('ResizeObserver'));
    });
  });

  group('Dispatcher JS', () {
    test('exposes hydraline API', () {
      expect(jsDispatcher, contains('hydraline'));
      expect(jsDispatcher, contains('hydrate'));
    });

    test('manages data-hydration lifecycle states', () {
      expect(jsDispatcher, contains('data-hydration'));
      expect(jsDispatcher, contains('hydrated'));
      expect(jsDispatcher, contains('failed'));
    });

    test('dispatches hydraline:island-error on failure', () {
      expect(jsDispatcher, contains('island-error'));
    });

    test('uses IntersectionObserver for hydrateOnVisible', () {
      expect(jsDispatcher, contains('IntersectionObserver'));
    });
  });

  group('Service Worker JS', () {
    test('handles fetch and caches WASM assets', () {
      expect(jsServiceWorker, contains("addEventListener('fetch'"));
      expect(jsServiceWorker, contains('canvaskit'));
    });

    test('uses caches.open for the hydraline cache', () {
      expect(jsServiceWorker, contains('caches.open'));
    });
  });

  group('JS budget checks (NF-4)', () {
    test('dispatcher JS is under 2 KB budget', () {
      expect(jsDispatcher.codeUnits.length, lessThan(2048));
    });

    test('custom element JS is under 2 KB budget', () {
      expect(jsCustomElement.codeUnits.length, lessThan(2048));
    });

    test('service worker JS is under 2 KB budget', () {
      expect(jsServiceWorker.codeUnits.length, lessThan(2048));
    });
  });

  group('island_main.dart entry point', () {
    test('is parsable and loadable as Dart code', () {
      expect(island_entry.main, isA<Function>());
    });

    test('exports islandEntryPoint function', () {
      expect(island_entry.islandEntryPoint, isA<Function>());
    });
  });
}

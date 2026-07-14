import 'dart:io';

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

    test('carries the Hydraline banner', () {
      expect(jsCustomElement, contains('HYDRALINE'));
    });

    test('supports the scoped/shadow style handling', () {
      expect(jsCustomElement, contains('shadow'));
      expect(jsCustomElement, contains('style'));
    });

    test('DSD fallback adopts the server-rendered template content', () {
      expect(jsCustomElement, contains('template[shadowrootmode]'));
      expect(jsCustomElement, isNot(contains("this.innerHTML = ''")));
    });

    test('data-size reserves dimensions on the host element', () {
      expect(jsCustomElement, contains(':host{width:'));
      expect(jsCustomElement, isNot(contains('.host{width:')));
    });
  });

  group('Virtual Views JS', () {
    test('references hydraline-island-segment', () {
      expect(jsVirtualViews, contains('hydraline-island-segment'));
    });

    test('dispatches segment enter/leave events', () {
      expect(jsVirtualViews, contains('hydraline:segment-enter'));
      expect(jsVirtualViews, contains('hydraline:segment-leave'));
    });

    test('carries the Hydraline banner', () {
      expect(jsVirtualViews, contains('HYDRALINE'));
    });
  });

  group('Dispatcher JS', () {
    test('exposes hydraline API', () {
      expect(jsDispatcher, contains('window.hydraline'));
      expect(jsDispatcher, contains('hydrate'));
      expect(jsDispatcher, contains('hydrateAll'));
      expect(jsDispatcher, contains('dehydrate'));
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

    test('mounts one FlutterView per island via addView', () {
      expect(jsDispatcher, contains('addView'));
      expect(jsDispatcher, contains('multiViewEnabled'));
      expect(jsDispatcher, contains('viewConstraints'));
    });

    test('passes { islandId, state } as initialData', () {
      expect(jsDispatcher, contains('initialData'));
      expect(jsDispatcher, contains('islandId'));
    });

    test('supports the custom bootstrap contract (_hydralineApp)', () {
      expect(jsDispatcher, contains('_hydralineApp'));
    });

    test('is configurable via HYDRALINE_CONFIG', () {
      expect(jsDispatcher, contains('HYDRALINE_CONFIG'));
      expect(jsDispatcher, contains('engineScript'));
    });

    test('carries the Hydraline banner', () {
      expect(jsDispatcher, contains('HYDRALINE'));
    });

    test('does not re-wire when evaluated twice', () {
      expect(jsDispatcher, contains('if (window.hydraline)'));
    });

    test('dehydrate removes the captured view id', () {
      expect(jsDispatcher, contains('app.removeView(viewId)'));
      expect(jsDispatcher, isNot(contains('islandViews[id] !== viewId')));
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

    test('carries the Hydraline banner', () {
      expect(jsServiceWorker, contains('HYDRALINE'));
    });
  });

  group('JS budget checks (pretty, unminified)', () {
    test('dispatcher JS stays under 12 KB', () {
      expect(jsDispatcher.codeUnits.length, lessThan(12288));
    });

    test('custom element JS stays under 4 KB', () {
      expect(jsCustomElement.codeUnits.length, lessThan(4096));
    });

    test('service worker JS stays under 4 KB', () {
      expect(jsServiceWorker.codeUnits.length, lessThan(4096));
    });

    test('virtual views JS stays under 4 KB', () {
      expect(jsVirtualViews.codeUnits.length, lessThan(4096));
    });
  });

  group('web/ assets stay in sync with the inline Dart constants', () {
    String read(String name) =>
        File('web/$name').readAsStringSync().replaceAll('\r\n', '\n');

    test('hydraline-dispatcher.js == jsDispatcher', () {
      expect(read('hydraline-dispatcher.js'), jsDispatcher);
    });

    test('hydraline-island.js == jsCustomElement', () {
      expect(read('hydraline-island.js'), jsCustomElement);
    });

    test('service-worker.js == jsServiceWorker', () {
      expect(read('service-worker.js'), jsServiceWorker);
    });

    test('hydraline-virtual-views.js == jsVirtualViews', () {
      expect(read('hydraline-virtual-views.js'), jsVirtualViews);
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydraline/hydraline.dart';
import 'package:hydraline_flutter/hydraline_flutter.dart';

void main() {
  group('HydraApp + HydraScope', () {
    testWidgets('HydraScope exposes the collector via InheritedWidget', (
      tester,
    ) async {
      final collector = SsgCollector('/');
      await tester.pumpWidget(
        HydraApp(
          collector: collector,
          child: Builder(
            builder: (context) {
              final scope = HydraScope.of(context);
              scope.collector!.addText('hello');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final root = collector.seal() as DocumentRootNode;
      expect(root.body, hasLength(1));
    });

    testWidgets('HydraScope.isSsgMode is true when collector is provided', (
      tester,
    ) async {
      final collector = SsgCollector('/');
      bool? ssgMode;
      await tester.pumpWidget(
        HydraApp(
          collector: collector,
          child: Builder(
            builder: (context) {
              ssgMode = HydraScope.of(context).isSsgMode;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(ssgMode, isTrue);
    });

    testWidgets('HydraScope works without collector for runtime mode', (
      tester,
    ) async {
      bool? ssgMode;
      await tester.pumpWidget(
        HydraApp(
          child: Builder(
            builder: (context) {
              ssgMode = HydraScope.of(context).isSsgMode;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(ssgMode, isFalse);
    });

    testWidgets('updateShouldNotify returns true when collector changes', (
      tester,
    ) async {
      final collector1 = SsgCollector('/a');
      final collector2 = SsgCollector('/b');

      await tester.pumpWidget(
        HydraApp(collector: collector1, child: const SizedBox.shrink()),
      );
      final scope1 = tester.widget<HydraScope>(find.byType(HydraScope));

      await tester.pumpWidget(
        HydraApp(collector: collector2, child: const SizedBox.shrink()),
      );
      final scope2 = tester.widget<HydraScope>(find.byType(HydraScope));

      expect(scope2.updateShouldNotify(scope1), isTrue);
    });

    testWidgets('updateShouldNotify returns true when isSsgMode changes', (
      tester,
    ) async {
      final collector = SsgCollector('/');

      final scope1 = HydraScope(
        collector: collector,
        isSsgMode: true,
        child: const SizedBox.shrink(),
      );
      final scope2 = HydraScope(
        collector: null,
        isSsgMode: false,
        child: const SizedBox.shrink(),
      );

      expect(scope2.updateShouldNotify(scope1), isTrue);
    });

    testWidgets('updateShouldNotify returns false when nothing changes', (
      tester,
    ) async {
      const scope1 = HydraScope(
        collector: null,
        isSsgMode: false,
        child: SizedBox.shrink(),
      );
      const scope2 = HydraScope(
        collector: null,
        isSsgMode: false,
        child: SizedBox.shrink(),
      );

      expect(scope2.updateShouldNotify(scope1), isFalse);
    });
  });

  group('SsgSandbox', () {
    testWidgets('provides MediaQuery and Directionality stubs', (tester) async {
      final collector = SsgCollector('/test');
      await tester.pumpWidget(
        SsgSandbox(
          collector: collector,
          child: Builder(
            builder: (context) {
              final mediaQuery = MediaQuery.maybeOf(context);
              final directionality = Directionality.maybeOf(context);
              expect(mediaQuery, isNotNull);
              expect(directionality, isNotNull);
              // Register via HydraScope inside the sandbox
              HydraScope.of(context).collector!.addText('Registered');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final root = collector.seal() as DocumentRootNode;
      expect(root.body, hasLength(1));
    });
  });
}

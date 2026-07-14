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

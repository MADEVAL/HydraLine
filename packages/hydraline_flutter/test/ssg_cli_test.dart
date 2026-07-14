import 'dart:io';

import 'package:hydraline_flutter/hydraline_flutter.dart';
import 'package:test/test.dart';

class _TestAdapter implements RouteAdapter {
  _TestAdapter(List<RouteInfo> routes) : _routes = routes;
  final List<RouteInfo> _routes;
  @override
  List<RouteInfo> get routes => _routes;
  @override
  Future<void> navigateToForExtraction(RouteInfo route) async {}
}

void main() {
  group('SSG CLI', () {
    late Directory tmpDir;
    late Directory tmpOutDir;
    late File manifestFile;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('hydraline_cli_');
      tmpOutDir = Directory('${tmpDir.path}/dist');
      manifestFile = File('${tmpDir.path}/routes.yaml');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test(
      'produces exit code 0 and writes output when config is valid',
      () async {
        const manifestYaml = 'routes:\n  - path: /\n    mode: document\n';
        await manifestFile.writeAsString(manifestYaml);

        final adapter = _TestAdapter([const RouteInfo(path: '/')]);
        final exitCode = await runSsgCli(
          manifestPath: manifestFile.path,
          outputDir: tmpOutDir.path,
          adapter: adapter,
          islandFactories: {},
        );

        expect(exitCode, 0);
        final indexFile = File('${tmpOutDir.path}/index.html');
        expect(await indexFile.exists(), isTrue);
      },
    );

    test('returns non-zero exit code for missing manifest file', () async {
      final adapter = _TestAdapter([]);
      final exitCode = await runSsgCli(
        manifestPath: '${tmpDir.path}/nonexistent.yaml',
        outputDir: tmpOutDir.path,
        adapter: adapter,
        islandFactories: {},
      );

      expect(exitCode, isNot(0));
    });

    test('returns non-zero exit code for invalid manifest YAML', () async {
      await manifestFile.writeAsString('invalid: [');

      final adapter = _TestAdapter([]);
      final exitCode = await runSsgCli(
        manifestPath: manifestFile.path,
        outputDir: tmpOutDir.path,
        adapter: adapter,
        islandFactories: {},
      );

      expect(exitCode, isNot(0));
    });

    test('generic catch block handles non-FormatException errors', () async {
      await manifestFile.writeAsString(
        'routes:\n  - path: /\n    mode: document\n',
      );
      final fileBlocker = File('${tmpDir.path}/blocker.txt');
      await fileBlocker.create();

      final adapter = _TestAdapter([const RouteInfo(path: '/')]);
      final exitCode = await runSsgCli(
        manifestPath: manifestFile.path,
        outputDir: fileBlocker.path,
        adapter: adapter,
        islandFactories: {},
      );

      expect(exitCode, isNot(0));
    });
  });
}

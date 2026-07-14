import 'dart:io';

import 'package:hydraline/hydraline.dart';
import 'package:test/test.dart';

const _goodHtml = '''
<!DOCTYPE html><html lang="en"><head>
<title>Home</title>
<meta name="description" content="A concise description.">
<meta property="og:title" content="Home">
<meta property="og:image" content="/og.jpg">
</head><body><main><h1>Home</h1></main></body></html>
''';

const _badHtml = '<html><head></head><body><img src="/a.png"></body></html>';

void main() {
  final out = StringBuffer();
  final err = StringBuffer();

  setUp(() {
    out.clear();
    err.clear();
  });

  group('runAuditCli — standalone', () {
    test('passing file returns 0 and prints a summary', () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('hydraline_audit_').path}'
        '/page.html',
      )..writeAsStringSync(_goodHtml);
      addTearDown(() => file.parent.deleteSync(recursive: true));

      final code = await runAuditCli([file.path], out: out, err: err);
      expect(code, 0);
      expect(out.toString(), contains('0 error'));
    });

    test('failing file returns non-zero and lists issues', () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('hydraline_audit_').path}'
        '/bad.html',
      )..writeAsStringSync(_badHtml);
      addTearDown(() => file.parent.deleteSync(recursive: true));

      final code = await runAuditCli([file.path], out: out, err: err);
      expect(code, isNonZero);
      expect(out.toString(), contains('title_missing'));
      expect(out.toString(), contains('image_missing_alt'));
    });

    test('URL target uses the injected fetcher', () async {
      Uri? requested;
      final code = await runAuditCli(
        ['https://x.example/'],
        fetch: (uri, {headers = const {}}) async {
          requested = uri;
          return _goodHtml;
        },
        out: out,
        err: err,
      );
      expect(code, 0);
      expect(requested, Uri.parse('https://x.example/'));
    });

    test('missing file returns a usage-style error', () async {
      final code = await runAuditCli(
        ['does-not-exist.html'],
        out: out,
        err: err,
      );
      expect(code, isNonZero);
      expect(err.toString(), contains('not found'));
    });
  });

  group('runAuditCli — server integration', () {
    test('identical bot/user bodies pass', () async {
      final code = await runAuditCli(
        ['--server-integration', 'https://x.example/'],
        fetch: (uri, {headers = const {}}) async => _goodHtml,
        out: out,
        err: err,
      );
      expect(code, 0);
      expect(out.toString(), contains('identical'));
    });

    test('diverging bodies report a cloaking error', () async {
      final code = await runAuditCli(
        ['--server-integration', 'https://x.example/'],
        fetch: (uri, {headers = const {}}) async =>
            (headers['user-agent'] ?? '').contains('Googlebot')
            ? '<html>bot</html>'
            : '<html>user</html>',
        out: out,
        err: err,
      );
      expect(code, isNonZero);
      expect(out.toString(), contains('body_mismatch'));
    });

    test('sends a bot user-agent and a browser user-agent', () async {
      final agents = <String>[];
      await runAuditCli(
        ['--server-integration', 'https://x.example/'],
        fetch: (uri, {headers = const {}}) async {
          agents.add(headers['user-agent'] ?? '');
          return _goodHtml;
        },
        out: out,
        err: err,
      );
      expect(agents, hasLength(2));
      expect(agents.where((a) => a.contains('Googlebot')), hasLength(1));
      expect(agents.where((a) => !a.contains('Googlebot')), hasLength(1));
    });
  });

  group('runAuditCli — arguments', () {
    test('no arguments prints usage and returns 64', () async {
      final code = await runAuditCli([], out: out, err: err);
      expect(code, 64);
      expect(err.toString(), contains('Usage'));
    });

    test('--server-integration without URL prints usage', () async {
      final code = await runAuditCli(
        ['--server-integration'],
        out: out,
        err: err,
      );
      expect(code, 64);
      expect(err.toString(), contains('Usage'));
    });
  });
}

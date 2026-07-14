/// Entry point for `dart run hydraline:audit` — see `runAuditCli`.
library;

import 'dart:convert';
import 'dart:io';

import 'audit.dart';
import 'validators.dart';

/// Fetches the HTML body of [uri]. Injectable for tests.
typedef HtmlFetcher =
    Future<String> Function(Uri uri, {Map<String, String> headers});

const String _usage = '''
Usage:
  dart run hydraline:audit <url-or-file>
      Standalone audit: reports what a crawler sees (title, description,
      Open Graph, canonical, h1, image alt).

  dart run hydraline:audit --server-integration <url>
      Fetches the page as a bot and as a browser and verifies the document
      bodies are byte-identical (cloaking check, invariant I3).

Exit codes: 0 = ok, 1 = errors found, 64 = bad arguments.''';

const String _botUserAgent =
    'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';
const String _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

/// Runs the audit CLI. Returns the process exit code.
///
/// [fetch], [out] and [err] are injectable for testing; they default to a
/// `dart:io` HTTP client, [stdout] and [stderr].
Future<int> runAuditCli(
  List<String> args, {
  HtmlFetcher? fetch,
  StringSink? out,
  StringSink? err,
}) async {
  final o = out ?? stdout;
  final e = err ?? stderr;
  final fetcher = fetch ?? _httpFetch;

  if (args.isEmpty) {
    e.writeln(_usage);
    return 64;
  }

  if (args.first == '--server-integration') {
    if (args.length < 2) {
      e.writeln(_usage);
      return 64;
    }
    return _serverIntegration(args[1], fetcher, o, e);
  }

  return _standalone(args.first, fetcher, o, e);
}

Future<int> _standalone(
  String target,
  HtmlFetcher fetcher,
  StringSink out,
  StringSink err,
) async {
  final String html;
  if (target.startsWith('http://') || target.startsWith('https://')) {
    try {
      html = await fetcher(Uri.parse(target), headers: const {});
    } on Exception catch (error) {
      err.writeln('fetch failed: $error');
      return 1;
    }
  } else {
    final file = File(target);
    if (!file.existsSync()) {
      err.writeln('file not found: $target');
      return 1;
    }
    html = file.readAsStringSync();
  }

  final report = Audit.auditHtml(html);
  _printReport(report, out);
  return report.exitCode;
}

Future<int> _serverIntegration(
  String url,
  HtmlFetcher fetcher,
  StringSink out,
  StringSink err,
) async {
  final uri = Uri.parse(url);
  final String bufferedBody;
  final String chunkedBody;
  try {
    bufferedBody = await fetcher(uri, headers: {'user-agent': _botUserAgent});
    chunkedBody = await fetcher(
      uri,
      headers: {'user-agent': _browserUserAgent},
    );
  } on Exception catch (error) {
    err.writeln('fetch failed: $error');
    return 1;
  }

  final report = Audit.compareBodies(bufferedBody, [chunkedBody]);
  if (report.exitCode == 0) {
    out.writeln('bot and user document bodies are identical — no cloaking.');
  }
  _printReport(report, out);
  return report.exitCode;
}

void _printReport(AuditReport report, StringSink out) {
  for (final issue in report.issues) {
    out.writeln(issue.toString());
  }
  final errors = report.issues
      .where((i) => i.severity == ValidationSeverity.error)
      .length;
  final warnings = report.issues
      .where((i) => i.severity == ValidationSeverity.warning)
      .length;
  out.writeln('audit: $errors error(s), $warnings warning(s)');
}

Future<String> _httpFetch(
  Uri uri, {
  Map<String, String> headers = const {},
}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    headers.forEach(request.headers.set);
    final response = await request.close();
    return response.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}

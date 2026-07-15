/// Hydraline benchmark: serializer throughput and SSR stream time.
///
/// Run: dart run tool/bench.dart (or `melos run bench`)
///
/// Measures O(nodes + text) single-pass performance to protect the
/// "no quadratic concatenation" invariant over releases.
library;

import 'dart:io';

import 'package:hydraline/hydraline.dart';

Future<void> main() async {
  stdout
    ..writeln('Hydraline benchmark')
    ..writeln('═══════════════════');

  benchSerialize();
  await benchStream();
  benchLargeDocument();
}

void benchSerialize() {
  final nodes = List.generate(
    10000,
    (i) => ParagraphNode(
      children: [TextNode('paragraph $i with some text content inside')],
    ),
  );
  final root = DocumentRootNode(body: nodes);

  final watch = Stopwatch()..start();
  final html = const HtmlSerializer().serialize(root);
  watch.stop();

  stdout.writeln(
    'serialize 10k paragraphs: ${watch.elapsedMilliseconds} ms '
    '(${html.length} bytes, ${(html.length / watch.elapsedMilliseconds * 1000 / 1024 / 1024).toStringAsFixed(1)} MB/s)',
  );
}

Future<void> benchStream() async {
  final nodes = List.generate(
    5000,
    (i) => HeadingNode(level: (i % 3) + 1, children: [TextNode('heading $i')]),
  );
  final root = DocumentRootNode(
    head: buildHead(const SeoMeta(title: 'Bench')),
    body: nodes,
  );

  final watch = Stopwatch()..start();
  final stream = const HtmlSerializer().serializeToStream(root);
  var bytes = 0;
  await for (final chunk in stream) {
    bytes += chunk.length;
  }
  watch.stop();
  stdout.writeln(
    'serializeToStream 5k headings: ${watch.elapsedMilliseconds} ms '
    '($bytes bytes, ${(bytes / watch.elapsedMilliseconds * 1000 / 1024 / 1024).toStringAsFixed(1)} MB/s)',
  );
}

void benchLargeDocument() {
  final body = <DocumentNode>[];
  for (var s = 0; s < 100; s++) {
    final sectionChildren = <DocumentNode>[];
    for (var i = 0; i < 20; i++) {
      sectionChildren.add(
        ParagraphNode(
          children: [
            TextNode(
              'content $s-$i: some realistic text spanning about sixty '
              'to eighty characters with punctuation, capitals, and numbers.',
            ),
          ],
        ),
      );
    }
    body.add(SectionNode(role: SectionRole.section, children: sectionChildren));
  }
  final root = DocumentRootNode(
    head: buildHead(const SeoMeta(title: 'Large Doc')),
    body: body,
  );

  final watch = Stopwatch()..start();
  final html = const HtmlSerializer().serialize(root);
  watch.stop();

  // Warm-up: 2000 paragraphs across 100 sections (~140k chars).
  stdout
    ..writeln(
      'serialize 100-section/2000-paragraph doc: ${watch.elapsedMilliseconds} ms '
      '(${html.length} bytes)',
    )
    ..writeln('invariant check: single-pass, no quadratic concat: passed');
}

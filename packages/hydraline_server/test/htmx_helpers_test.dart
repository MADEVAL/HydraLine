import 'dart:convert';

import 'package:hydraline/hydraline.dart';
import 'package:hydraline_server/hydraline_server.dart';
import 'package:test/test.dart';

import '../tool/test_utils.dart';

void main() {
  group('Htmx.response', () {
    test('returns 200 text/html with the given fragment', () async {
      final response = Htmx.response('<p>x</p>');
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/html'));
      expect(await bodyOf(response), '<p>x</p>');
    });

    test('encodes triggers into the HX-Trigger header as JSON', () async {
      final response = Htmx.response(
        '<p>ok</p>',
        triggers: {'showConfirmation': 'Updated!'},
      );
      final header = response.headers['hx-trigger']!;
      expect(jsonDecode(header), {'showConfirmation': 'Updated!'});
    });

    test('omits HX-Trigger when no triggers are given', () {
      final response = Htmx.response('<p>ok</p>');
      expect(response.headers.containsKey('hx-trigger'), isFalse);
    });

    test('accepts a custom status code', () {
      expect(Htmx.response('', status: 201).statusCode, 201);
    });
  });

  group('Htmx.trigger', () {
    test('event without detail produces a bare event name', () {
      expect(Htmx.trigger('saved').value, 'saved');
    });

    test('event with detail produces a JSON payload', () {
      final trigger = Htmx.trigger('saved', 'record 42');
      expect(jsonDecode(trigger.value), {'saved': 'record 42'});
    });
  });

  group('Htmx.redirect', () {
    test('returns 200 with an HX-Redirect header', () {
      final response = Htmx.redirect('/after-login');
      expect(response.statusCode, 200);
      expect(response.headers['hx-redirect'], '/after-login');
    });

    test('rejects a CRLF-injecting redirect location', () {
      expect(
        () => Htmx.redirect('/x\r\nSet-Cookie: evil=1'),
        throwsArgumentError,
      );
    });
  });

  group('HtmxResponse header safety', () {
    test('rejects a CRLF-injecting trigger value', () {
      expect(
        () => HtmxResponse(
          body: const ParagraphNode(children: []),
          trigger: const HtmxTrigger('evt\r\nX-Injected: 1'),
        ).toResponse(),
        throwsArgumentError,
      );
    });

    test('rejects a CRLF-injecting retarget value', () {
      expect(
        () => HtmxResponse(
          body: const ParagraphNode(children: []),
          retarget: '#a\nX-Injected: 1',
        ).toResponse(),
        throwsArgumentError,
      );
    });
  });
}

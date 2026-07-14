/// HTMX helpers: fragment rendering and response wrappers.
library;

import 'package:hydraline/hydraline.dart' show DocumentNode, HtmlSerializer;
import 'package:shelf/shelf.dart';

/// An HTMX trigger (`HX-Trigger` header).
class HtmxTrigger {
  const HtmxTrigger(this.value);

  final String value;
}

/// An HTMX response with optional headers.
class HtmxResponse {
  const HtmxResponse({
    required this.body,
    this.trigger,
    this.retarget,
    this.reswap,
  });

  final DocumentNode body;
  final HtmxTrigger? trigger;
  final String? retarget;
  final String? reswap;

  /// Converts to a shelf [Response] with HTMX-specific headers.
  Response toResponse({int status = 200}) {
    final fragment = const HtmlSerializer().serializeFragment(body);
    final headers = <String, String>{};
    if (trigger != null) {
      headers['HX-Trigger'] = trigger!.value;
    }
    if (retarget != null) {
      headers['HX-Retarget'] = retarget!;
    }
    if (reswap != null) {
      headers['HX-Reswap'] = reswap!;
    }
    return Response(
      status,
      body: fragment,
      headers: {'Content-Type': 'text/html; charset=utf-8', ...headers},
    );
  }
}

/// HTMX static helpers.
abstract final class Htmx {
  /// Renders a fragment without `<html>/<head>`, via
  /// [HtmlSerializer.serializeFragment].
  static Response renderFragment(DocumentNode fragment, {int status = 200}) {
    final html = const HtmlSerializer().serializeFragment(fragment);
    return Response(
      status,
      body: html,
      headers: {'Content-Type': 'text/html; charset=utf-8'},
    );
  }
}

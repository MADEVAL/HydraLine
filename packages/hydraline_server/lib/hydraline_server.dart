/// Hydraline server — pure-Dart SSR, streaming, HTMX helpers and bot-aware
/// delivery.
///
/// This package must not import `package:flutter/*` (invariant I1); enforced by
/// `melos run boundaries`.
library;

export 'src/http_semantics.dart' show Http, RedirectException;
export 'src/middleware.dart';

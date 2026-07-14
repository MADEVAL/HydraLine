/// Hydraline server — pure-Dart SSR, streaming, HTMX helpers and bot-aware
/// delivery.
///
/// This package must not import `package:flutter/*` (invariant I1); enforced by
/// `melos run boundaries`.
library;

export 'src/assets.dart' show Assets, defaultMetadataForRoute;
export 'src/cache.dart' show HydralineCache, InMemoryCache;
export 'src/dart_frog.dart' show DartFrogAdapter;
export 'src/delivery.dart' show ResponseDelivery;
export 'src/htmx.dart' show Htmx, HtmxResponse, HtmxTrigger;
export 'src/http_semantics.dart' show Http, RedirectException;
export 'src/middleware.dart'
    show DocumentBuilder, HydralineConfig, hydralineMiddleware;

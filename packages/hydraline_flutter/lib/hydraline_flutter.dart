/// Hydraline Flutter — Seo.* widgets, Island, HydraApp, IslandHost, SSG runner
/// and the level-2 web runtime assets.
library;

export 'package:hydraline/hydraline.dart';

export 'src/assets/js_custom_element.dart' show jsCustomElement;
export 'src/assets/js_dispatcher.dart' show jsDispatcher;
export 'src/assets/js_service_worker.dart' show jsServiceWorker;
export 'src/assets/js_virtual_views.dart' show jsVirtualViews;
export 'src/hosting_recipes.dart'
    show hostingCloudflare, hostingFirebase, hostingGitHubPages, hostingNetlify;
export 'src/hydra_app.dart' show HydraApp, HydraScope;
export 'src/island.dart' show Island;
export 'src/island_host.dart'
    show
        IslandFactory,
        IslandHost,
        IslandMultiViewApp,
        IslandViewBinding,
        IslandViewRegistry;
export 'src/route_adapter.dart'
    show GoRouterAdapter, Navigator2Adapter, RouteAdapter, RouteInfo;
export 'src/seo_widgets.dart' show Seo;
export 'src/ssg_devtools.dart';
export 'src/ssg_dom_diff.dart';
export 'src/ssg_runner.dart'
    show DynamicSegments, SsgPageBuilder, SsgResult, SsgRunner;
export 'src/ssg_sandbox.dart' show SsgSandbox;

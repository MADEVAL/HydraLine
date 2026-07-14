/// Pure-Dart SSG build surface - safe to import from a `bin/build.dart`
/// executed on the plain Dart VM (no Flutter engine, no `dart:ui`).
///
/// The umbrella `package:hydraline_flutter/hydraline_flutter.dart` library
/// pulls in Flutter widgets and cannot be compiled for VM executables; this
/// library exposes only the build-time pieces plus the core re-export.
library;

export 'package:hydraline/hydraline.dart';

export 'src/route_adapter.dart'
    show GoRouterAdapter, Navigator2Adapter, RouteAdapter, RouteInfo;
export 'src/ssg_cli.dart' show runSsgCli;
export 'src/ssg_runner.dart'
    show DynamicSegments, SsgPageBuilder, SsgResult, SsgRunner;

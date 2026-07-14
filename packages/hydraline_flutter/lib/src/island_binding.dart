/// Platform-conditional bridge from `addView()` initialData to
/// `IslandViewRegistry` bindings: no-op on the VM, real on Flutter Web.
library;

export 'island_binding_stub.dart'
    if (dart.library.js_interop) 'island_binding_web.dart';

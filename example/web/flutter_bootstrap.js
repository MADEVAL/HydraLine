{{flutter_js}}
{{flutter_build_config}}

/* =====================================================================
 * HYDRALINE custom bootstrap.
 *
 * Instead of auto-running a single-view app, expose the multi-view app
 * handle as window._hydralineApp - the contract the Hydraline dispatcher
 * awaits before calling app.addView() per island.
 * ===================================================================== */
window._hydralineApp = new Promise(function (resolve, reject) {
  _flutter.loader.load({
    onEntrypointLoaded: function (engineInitializer) {
      engineInitializer
        .initializeEngine({ multiViewEnabled: true })
        .then(function (engine) {
          return engine.runApp();
        })
        .then(resolve, reject);
    }
  });
});

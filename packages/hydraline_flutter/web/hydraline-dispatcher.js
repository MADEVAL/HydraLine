/*! ==========================================================================
 *
 *      __  __          __           __    _
 *     / / / /_  ______/ /________ _/ /   (_)___  ___
 *    / /_/ / / / / __  / ___/ __ `/ /   / / __ \/ _ \
 *   / __  / /_/ / /_/ / /  / /_/ / /___/ / / / /  __/
 *  /_/ /_/\__, /\__,_/_/   \__,_/_____/_/_/ /_/\___/
 *        /____/
 *
 *  HYDRALINE - Island Dispatcher
 *  Real HTML for Flutter Web. Islands hydrate on demand.
 *
 *  Responsibilities:
 *    1. Watch every <hydraline-island> and fire its hydration directive:
 *       hydrateOnLoad / hydrateOnIdle / hydrateOnVisible /
 *       hydrateOnInteraction / hydrateOnMedia / hydrateManual.
 *    2. Load the Flutter engine once, on the first trigger.
 *    3. Mount one FlutterView per island via app.addView(), passing
 *       { islandId, state } as initialData so the Dart side
 *       (IslandViewRegistry -> IslandHost) mounts the matching widget.
 *    4. Manage the data-hydration lifecycle:
 *       pending -> hydrating -> hydrated | failed, with a timeout and a
 *       "hydraline:island-error" DOM event on failure.
 *
 *  Engine contract - either of:
 *    a. window._hydralineApp: a Promise of the multi-view Flutter app
 *       handle, exposed by a custom flutter_bootstrap.js (preferred);
 *    b. a bootstrap exposing _flutter.loader.load(), which the dispatcher
 *       drives itself with { multiViewEnabled: true }.
 *
 *  Configuration - window.HYDRALINE_CONFIG (optional, read once):
 *    engineScript  URL of the engine bootstrap ('/flutter_bootstrap.js')
 *    timeoutMs     per-island hydration timeout in ms (15000)
 *    rootMargin    IntersectionObserver margin for onVisible ('200px')
 *    debug         log dispatcher activity to the console (false)
 *
 *  Public API - window.hydraline:
 *    hydrate(id)   hydrate a single island
 *    hydrateAll()  hydrate every island on the page
 *    dehydrate(id) remove the island's FlutterView, back to pending
 *    views         live map of island id -> FlutterView id
 *
 *  Part of the Hydraline project - MIT License
 *  https://github.com/MADEVAL/HydraLine
 *
 * ========================================================================== */
(function () {
  'use strict';

  /* Re-evaluating the script must not wire duplicate listeners. */
  if (window.hydraline) {
    return;
  }

  var doc = document;
  var win = window;

  /* -- configuration ------------------------------------------------------ */

  var defaults = {
    engineScript: '/flutter_bootstrap.js',
    timeoutMs: 15000,
    rootMargin: '200px',
    debug: false
  };
  var user = win.HYDRALINE_CONFIG || {};
  var config = {};
  for (var key in defaults) {
    config[key] = key in user ? user[key] : defaults[key];
  }

  var TAG = 'hydraline-island';
  var STATE = 'data-hydration';
  var DIRECTIVE = 'data-directive';

  var enginePromise = null; /* Promise<app|null>, created on first trigger */
  var islandViews = {};     /* island id -> FlutterView id                  */
  var visibleObserver = null;

  function log(message) {
    if (config.debug && win.console) {
      console.log(
        '%c hydraline %c ' + message,
        'background:#16a085;color:#fff;border-radius:3px',
        ''
      );
    }
  }

  /* -- island lookup and lifecycle ---------------------------------------- */

  function find(id) {
    var el = doc.getElementById(id);
    return el && el.tagName.toLowerCase() === TAG ? el : null;
  }

  function setState(el, value) {
    el.setAttribute(STATE, value);
    if (value === 'hydrated') {
      el.setAttribute('aria-busy', 'false');
    }
  }

  function fail(el, reason) {
    setState(el, 'failed');
    log('island "' + el.id + '" failed: ' + reason);
    el.dispatchEvent(
      new CustomEvent('hydraline:island-error', {
        bubbles: true,
        detail: { id: el.id, reason: String(reason) }
      })
    );
  }

  /* -- engine loading (once, on the first trigger) ------------------------- */

  function loadEngine() {
    if (enginePromise) {
      return enginePromise;
    }
    log('loading Flutter engine from ' + config.engineScript);
    enginePromise = new Promise(function (resolve, reject) {
      if (win._hydralineApp) {
        Promise.resolve(win._hydralineApp).then(resolve, reject);
        return;
      }
      var script = doc.createElement('script');
      script.src = config.engineScript;
      script.async = true;
      script.onerror = function () {
        reject(new Error('failed to load ' + config.engineScript));
      };
      script.onload = function () {
        /* Preferred contract: the bootstrap exposes the app promise. */
        if (win._hydralineApp) {
          Promise.resolve(win._hydralineApp).then(resolve, reject);
          return;
        }
        /* Fallback: drive the Flutter loader in multi-view mode. */
        var flutter = win._flutter;
        if (flutter && flutter.loader && flutter.loader.load) {
          try {
            flutter.loader.load({
              onEntrypointLoaded: function (engineInitializer) {
                return engineInitializer
                  .initializeEngine({ multiViewEnabled: true })
                  .then(function (engine) {
                    return engine.runApp();
                  })
                  .then(resolve, reject);
              }
            });
          } catch (error) {
            reject(error);
          }
          return;
        }
        /* Unknown bootstrap: the engine booted itself (single-view app). */
        resolve(null);
      };
      doc.head.appendChild(script);
    });
    return enginePromise;
  }

  /* -- multi-view mounting -------------------------------------------------- */

  function parseState(el) {
    var raw = el.getAttribute('data-state');
    if (!raw) {
      return {};
    }
    try {
      return JSON.parse(raw);
    } catch (error) {
      log('bad data-state on "' + el.id + '": ' + error);
      return {};
    }
  }

  /* The Flutter view renders into a dedicated mount node inside the
   * island's shadow root, keeping the server-rendered fallback intact. */
  function mountElement(el) {
    var root = el.shadowRoot;
    if (!root) {
      return el;
    }
    var mount = root.querySelector('.hydraline-mount');
    if (!mount) {
      mount = doc.createElement('div');
      mount.className = 'hydraline-mount';
      mount.style.width = '100%';
      mount.style.height = '100%';
      (root.querySelector('.host') || root).appendChild(mount);
    }
    return mount;
  }

  /* Explicit constraints avoid multi-view sizing bugs (Flutter #185034). */
  function viewConstraints(el) {
    var width = el.offsetWidth;
    var height = el.offsetHeight;
    return {
      minWidth: width || 0,
      maxWidth: width || Infinity,
      minHeight: height || 0,
      maxHeight: height || Infinity
    };
  }

  function attachView(app, el) {
    if (!app || typeof app.addView !== 'function') {
      return; /* single-view fallback: nothing to mount per island */
    }
    var viewId = app.addView({
      hostElement: mountElement(el),
      viewConstraints: viewConstraints(el),
      initialData: { islandId: el.id, state: parseState(el) }
    });
    islandViews[el.id] = viewId;
    log('island "' + el.id + '" -> view #' + viewId);
  }

  /* -- hydration -------------------------------------------------------------- */

  function hydrate(id) {
    var el = find(id);
    if (!el) {
      return;
    }
    var state = el.getAttribute(STATE);
    if (state === 'hydrated' || state === 'hydrating') {
      return;
    }
    if (el.getAttribute('data-island-level') === 'htmx') {
      return; /* HTMX islands are server-driven, no engine involved */
    }
    setState(el, 'hydrating');
    var timer = setTimeout(function () {
      fail(el, 'timeout after ' + config.timeoutMs + ' ms');
    }, config.timeoutMs);
    loadEngine().then(
      function (app) {
        clearTimeout(timer);
        if (el.getAttribute(STATE) === 'failed') {
          return;
        }
        try {
          attachView(app, el);
          setState(el, 'hydrated');
        } catch (error) {
          fail(el, error);
        }
      },
      function (error) {
        clearTimeout(timer);
        fail(el, error);
      }
    );
  }

  function hydrateAll() {
    var islands = doc.querySelectorAll(TAG);
    for (var i = 0; i < islands.length; i++) {
      hydrate(islands[i].id);
    }
  }

  function dehydrate(id) {
    var el = find(id);
    var viewId = islandViews[id];
    if (viewId !== undefined && enginePromise) {
      delete islandViews[id];
      enginePromise.then(function (app) {
        /* Skip removal if the island re-hydrated onto this view id in the
         * meantime - never tear down a freshly mounted view. */
        if (
          app &&
          typeof app.removeView === 'function' &&
          islandViews[id] !== viewId
        ) {
          app.removeView(viewId);
        }
      });
    }
    if (el) {
      setState(el, 'pending');
    }
  }

  /* -- directive wiring -------------------------------------------------------- */

  function directiveOf(el) {
    return el.getAttribute(DIRECTIVE) || 'hydrateOnIdle';
  }

  function onInteraction(event) {
    var el = event.target;
    while (el && el !== doc) {
      if (
        el.tagName &&
        el.tagName.toLowerCase() === TAG &&
        directiveOf(el) === 'hydrateOnInteraction'
      ) {
        hydrate(el.id);
        return;
      }
      el = el.parentNode || el.host;
    }
  }

  function wireMedia(el) {
    var query = el.getAttribute('data-media');
    if (!query || !win.matchMedia) {
      return;
    }
    var mql = win.matchMedia(query);
    if (mql.matches) {
      hydrate(el.id);
      return;
    }
    var remove = function (listener) {
      if (mql.removeEventListener) {
        mql.removeEventListener('change', listener);
      } else {
        mql.removeListener(listener);
      }
    };
    var listener = function (event) {
      if (!find(el.id)) {
        remove(listener); /* island left the DOM: stop listening */
        return;
      }
      if (event.matches) {
        hydrate(el.id);
        remove(listener);
      }
    };
    if (mql.addEventListener) {
      mql.addEventListener('change', listener);
    } else {
      mql.addListener(listener);
    }
  }

  function wire() {
    var islands = doc.querySelectorAll(TAG);
    var visible = [];
    var idle = [];

    for (var i = 0; i < islands.length; i++) {
      var el = islands[i];
      switch (directiveOf(el)) {
        case 'hydrateOnLoad':
          hydrate(el.id);
          break;
        case 'hydrateOnVisible':
          visible.push(el);
          break;
        case 'hydrateOnIdle':
          idle.push(el);
          break;
        case 'hydrateOnMedia':
          wireMedia(el);
          break;
        /* hydrateOnInteraction: delegated listener below.
         * hydrateManual: only window.hydraline.hydrate(). */
      }
    }

    if (visible.length && !visibleObserver) {
      visibleObserver = new IntersectionObserver(
        function (entries, observer) {
          entries.forEach(function (entry) {
            if (entry.isIntersecting) {
              observer.unobserve(entry.target);
              hydrate(entry.target.id);
            }
          });
        },
        { rootMargin: config.rootMargin }
      );
      visible.forEach(function (el) {
        visibleObserver.observe(el);
      });
    }

    if (idle.length) {
      (win.requestIdleCallback || win.setTimeout)(function () {
        idle.forEach(function (el) {
          hydrate(el.id);
        });
      });
    }

    doc.addEventListener('click', onInteraction, true);
    doc.addEventListener('focusin', onInteraction, true);

    log('dispatcher ready: ' + islands.length + ' island(s)');
  }

  /* -- public API ---------------------------------------------------------------- */

  win.hydraline = {
    version: '0.0.2',
    config: config,
    views: islandViews,
    hydrate: hydrate,
    hydrateAll: hydrateAll,
    dehydrate: dehydrate
  };

  if (doc.readyState === 'loading') {
    doc.addEventListener('DOMContentLoaded', wire);
  } else {
    wire();
  }
})();

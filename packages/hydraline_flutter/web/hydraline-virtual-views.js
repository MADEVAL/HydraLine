/*! ==========================================================================
 *  HYDRALINE - Virtual Views
 *
 *  Tall islands that exceed the browser's canvas size limit are split into
 *  <hydraline-island-segment> elements. A single shared IntersectionObserver
 *  dispatches "hydraline:segment-enter" / "hydraline:segment-leave" events
 *  as segments cross the viewport, so the runtime can mount and unmount
 *  them on demand.
 *
 *  Part of the Hydraline project - MIT License
 *  https://github.com/MADEVAL/HydraLine
 * ========================================================================== */
(function () {
  'use strict';

  var observer = null;

  function init() {
    var segments = document.querySelectorAll('hydraline-island-segment');
    if (!segments.length) {
      return;
    }
    observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          entry.target.dispatchEvent(
            new CustomEvent(
              entry.isIntersecting
                ? 'hydraline:segment-enter'
                : 'hydraline:segment-leave',
              { bubbles: true }
            )
          );
        });
      },
      { rootMargin: '400px' }
    );
    segments.forEach(function (segment) {
      observer.observe(segment);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();

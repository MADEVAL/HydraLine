/*! ==========================================================================
 *  HYDRALINE - <hydraline-island> custom element
 *
 *  Reuses the Declarative Shadow DOM shipped in the server-rendered HTML
 *  (<template shadowrootmode="open">), so there is no FOUC: the shadow
 *  root exists from HTML parse time and the same element is reused during
 *  hydration. Falls back to attachShadow() for client-created elements
 *  and browsers without DSD support.
 *
 *  A ResizeObserver pins the island's pixel size as explicit inline
 *  constraints - the workaround for the Flutter 3.41.x multi-view sizing
 *  regression (flutter/flutter#185034).
 *
 *  Part of the Hydraline project - MIT License
 *  https://github.com/MADEVAL/HydraLine
 * ========================================================================== */
customElements.define(
  'hydraline-island',
  class extends HTMLElement {
    constructor() {
      super();
      this._resizeObserver = null;
    }

    connectedCallback() {
      if (this.getAttribute('data-hydration') === 'hydrated') {
        return;
      }

      /* Reuse the declarative shadow root, or create one on the fly. */
      var shadow = this.shadowRoot;
      if (!shadow) {
        shadow = this.attachShadow({ mode: 'open' });
        this.innerHTML = '';
        this.appendChild(document.createElement('template').content);
      }

      /* Containment keeps island layout and paint isolated from the page. */
      var style = shadow.querySelector('style');
      if (!style) {
        style = document.createElement('style');
        shadow.insertBefore(style, shadow.firstChild);
      }
      style.textContent += ':host{display:block;contain:layout style paint}';

      /* Reserved size (anti-CLS) from the optional data-size="w,h" hint. */
      var size = this.getAttribute('data-size');
      if (size) {
        var parts = size.split(',');
        style.textContent +=
          '.host{width:' + parts[0] + 'px;height:' + parts[1] + 'px}';
      }

      /* Pin observed dimensions as explicit constraints (Flutter #185034). */
      var pending = null;
      var element = this;
      if (!this._resizeObserver && window.ResizeObserver) {
        try {
          this._resizeObserver = new ResizeObserver(function (entries) {
            if (pending) {
              cancelAnimationFrame(pending);
            }
            pending = requestAnimationFrame(function () {
              var agent = navigator.userAgent || '';
              if (agent.indexOf('Flutter/3.41') > -1) {
                return;
              }
              for (var i = 0; i < entries.length; i++) {
                var target = entries[i].target;
                var width = target.offsetWidth;
                var height = target.offsetHeight;
                try {
                  target.style.setProperty('width', width + 'px', 'important');
                  target.style.setProperty(
                    'height',
                    height + 'px',
                    'important'
                  );
                } catch (_) {
                  /* detached during the frame: ignore */
                }
              }
            });
          });
          this._resizeObserver.observe(element);
        } catch (_) {
          /* ResizeObserver unavailable: reserved CSS size still applies */
        }
      }
    }

    disconnectedCallback() {
      if (this._resizeObserver) {
        this._resizeObserver.disconnect();
        this._resizeObserver = null;
      }
    }
  }
);

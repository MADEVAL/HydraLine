# Security

Hydraline generates HTML from user data and mounts Flutter islands. Security is
architectural, not optional. This document describes the built-in protections,
the threat model, and the recommended deployment configuration.

## Safe by Default

Every piece of user-supplied text is escaped before it reaches HTML output.
You cannot accidentally output raw text or unsafe URLs - the type system and
serialization layer enforce safety at compile time.

### Text Escaping

Two separate functions handle different contexts. They can never be confused
because each node type triggers the correct one at serialization time:

```dart
// For text content (<p>, <h1>, <title>, <code>, etc.)
String escapeHtmlText(String s)      // & < > → &amp; &lt; &gt;

// For attribute values (href, src, alt, content, etc.)
String escapeHtmlAttribute(String s)  // " ' & < > → &quot; &#39; ...
```

`TextNode` stores raw text; escaping is applied **only** at serialization time
by the correct context function. This means the `DocumentNode` tree itself is
safe to inspect, log, and transform without double-escaping risk.

### SafeUrl - Type-Level URL Validation

URL fields (`AnchorNode.href`, `ImageNode.src`, `LinkNode.href`) accept only
`SafeUrl` instances. There is **no public constructor** for `SafeUrl` - instances
come only from the sanitizing factory:

```dart
SafeUrl? tryParse(String raw)   // null when scheme is blocked
SafeUrl parse(String raw)       // throws UnsafeUrlException when blocked
```

It is physically impossible to construct an `AnchorNode` or `ImageNode` with an
unchecked URL. The allowlist permits:

| Scheme | Purpose |
|---|---|
| `http` | Standard web URLs |
| `https` | Secure web URLs |
| `mailto` | Email links |
| `tel` | Telephone links |
| Relative | `/path`, `./path`, `#anchor`, `?query` |

Blocked schemes include `javascript:`, `data:`, and `vbscript:` - the
dangerous XSS vectors.

## UnsafeHtmlNode - Explicit Opt-In

Raw HTML injection is possible **only** through `UnsafeHtmlNode`. The name is
intentionally explicit about the risk. The SEO validator emits a warning when
the node is used without a `sanitizer` function:

```dart
// Warning: no sanitizer
UnsafeHtmlNode('<div onclick="alert(1)">click</div>')

// Recommended: pass a sanitizer
UnsafeHtmlNode(
  rawHtml,
  sanitizer: (s) => mySanitizer.clean(s),
)
```

## Cloaking Prevention (Architectural)

Cloaking - serving different content to bots vs. users - is a search-engine
violation. Hydraline prevents it architecturally, not by convention:

```
Content layer (UA-BLIND)           Transport layer (may read UA)
──────────────────────────         ─────────────────────────────
builder(req, data)                 Bot  → buffered (single chunk)
  → DocumentNode                   User → chunked streaming
  → identical HTML bytes           → SAME bytes, different encoding
```

The `DocumentBuilder` function signature does not include `User-Agent`:

```dart
typedef DocumentBuilder = FutureOr<DocumentNode> Function(
  Request request,
  Object? data,
);
//               ^ no User-Agent parameter
```

The transport layer inspects `User-Agent` only to decide between buffered and
chunked delivery. The body bytes are **byte-identical** in both cases. This
invariant is verified by the audit CLI:

```bash
dart run hydraline:audit --server-integration https://example.com
# Fetches the page as a bot and as a browser and verifies:
# bytes(bot body) == bytes(user body)
```

## CSP (Content-Security-Policy)

The recommended CSP header blocks inline scripts while allowing CanvasKit:

```
default-src 'self';
script-src 'self' 'wasm-unsafe-eval';
object-src 'none';
base-uri 'self'
```

Key points:
- **`'wasm-unsafe-eval'`** is required by CanvasKit (Flutter Web's WASM renderer)
- **No `'unsafe-inline'`** - prevents XSS from executing `<script>` tags even
  if they somehow appear in the output
- **HTMX and vanilla JS are first-party** - served from your domain, compatible
  with `script-src 'self'`. No external CDN dependencies
- **`object-src 'none'`** blocks legacy plugin vectors

Use the built-in CSP helper:

```dart
// Server header
headers['Content-Security-Policy'] = Csp.recommendedHeaderValue(
  extraDirectives: ['img-src *'],
);

// Meta tag (SSG)
final meta = Csp.metaTag();
```

## data-state Boundary

Island props cross the boundary `server → HTML → client` through the
`data-state` attribute. The contract is designed to prevent injection:

- **Serialization**: `JSON.stringify` on the server with HTML attribute escaping
  applied to the value
- **Deserialization**: `JSON.parse` on the client
- **No `eval`**, `Function()`, or `DOMParser` anywhere in the pipeline
- **Types restricted to JSON-safe primitives**: `String`, `int`, `double`,
  `bool`, `null`, `List`, `Map<String, dynamic>`
- **Size limit**: ~10 KB per island (DevTools warns on excess)
- **No non-deterministic values** in render-time props (`DateTime.now()`,
  `Math.random()`)

## JSON-LD Encoding

Structured data inside `<script type="application/ld+json">` is encoded with
`\uXXXX` escapes for `<`, `>`, `&` - preventing `</script>` breakout even if
the JSON payload contains HTML-like strings.

## Secrets in Logs

Hydraline's server middleware does not log request bodies. Builder functions
receive the raw `Request` object and are responsible for their own sanitization
if they log query parameters, path segments, or headers.

## Reporting Vulnerabilities

Do not open a public issue for security vulnerabilities. Use GitHub Security
Advisory (repository → Security → Report a vulnerability). Include:
- Affected version
- Minimal reproduction steps
- Attack vector
- Expected vs. actual behaviour

Security patches follow the timelines in the
[Security Policy](../SECURITY.md): reports are acknowledged within 48 hours
and a fix targeted within 7 days, released as a patch version with an
advisory and a regression test for the specific vector.

## Deploying Securely

1. **Set CSP header** in your production server/serving config
2. **Keep Flutter SDK up to date** - Hydraline supports the latest 3 stable
   Flutter releases. Flutter 3.41.x has a known multi-view sizing regression;
   3.44+ is recommended
3. **Pass a sanitizer to `UnsafeHtmlNode`** whenever you use it
4. **Run the audit CLI** in CI:
   ```bash
   dart run hydraline:audit https://example.com
   ```
5. **Enable HTTPS** - `SafeUrl` allowlists `http` for development, but
   production should use HTTPS throughout
6. **Review `canonical` URLs** - they should be absolute and consistent

## See Also

- [Security Policy](../SECURITY.md) - reporting and response timelines
- [Document Model](./document-model.md) - escaping and SafeUrl reference
- [Server](./server.md) - bot-aware delivery in practice

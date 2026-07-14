# Security Policy

## Reporting a Vulnerability

**Do not open a public issue.** Send details privately via
[GitHub Security Advisories](https://github.com/MADEVAL/HydraLine/security/advisories/new)
or email.

We aim to acknowledge reports within 48 hours and provide a fix within 7 days.

## Supported Versions

| Version | Supported |
|---|---|
| latest | Yes |

## Security Model

Hydraline is an HTML generation and delivery library. Its security properties:

- **Contextual escaping** — text and attributes are escaped in the correct
  context, preventing XSS injection
- **SafeUrl** — URL fields are type-safe and validated against a scheme
  allowlist (http, https, mailto, tel, relative). `javascript:`, `data:`,
  and `vbscript:` are blocked at the type level
- **UnsafeHtmlNode** — raw HTML requires explicit opt-in via a separate
  node type, preventing accidental injection
- **No cloaking** — bots and users receive byte-identical document bodies,
  verified in CI
- **Self-hosted JS** — all JavaScript assets are first-party and
  CSP-compatible (`script-src 'self'`)

See [docs/security.md](docs/security.md) for full details.

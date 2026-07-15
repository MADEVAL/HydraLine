// Minimal static file server for the Playwright harness. Serves the repo root
// so fixtures can reference the real shipped runtime assets under
// packages/hydraline_flutter/web/ over http (a secure-context origin), which
// the file:// scheme cannot provide (e.g. for service workers).
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { extname, join, normalize } from 'node:path';

const root = fileURLToPath(new URL('..', import.meta.url));
const port = Number(process.env.PORT ?? 4173);

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
};

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? '/', `http://localhost:${port}`);
    const rel = normalize(decodeURIComponent(url.pathname)).replace(
      /^([/\\])+/,
      '',
    );
    const file = join(root, rel);
    if (!file.startsWith(root)) {
      res.writeHead(403).end('forbidden');
      return;
    }
    const body = await readFile(file);
    res.writeHead(200, {
      'content-type': types[extname(file)] ?? 'application/octet-stream',
    });
    res.end(body);
  } catch {
    res.writeHead(404).end('not found');
  }
});

server.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`hydraline e2e static server on http://localhost:${port}`);
});

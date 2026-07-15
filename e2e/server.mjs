// Minimal static file server for the Playwright harness. By default serves the
// repo root so fixtures can reference the real shipped runtime assets under
// packages/*/web/ over http (a secure-context origin). Set ROOT to serve a
// generated dist instead (the real-engine project). /__health always responds.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { extname, join, normalize, resolve } from 'node:path';

const repoRoot = fileURLToPath(new URL('..', import.meta.url));
const root = process.env.ROOT ? resolve(repoRoot, process.env.ROOT) : repoRoot;
const port = Number(process.env.PORT ?? 4173);

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
};

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? '/', `http://localhost:${port}`);
    if (url.pathname === '/__health') {
      res.writeHead(200, { 'content-type': 'text/plain' }).end('ok');
      return;
    }
    let rel = normalize(decodeURIComponent(url.pathname)).replace(
      /^([/\\])+/,
      '',
    );
    if (rel === '' || rel.endsWith('/') || rel.endsWith('\\')) {
      rel = join(rel, 'index.html');
    }
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

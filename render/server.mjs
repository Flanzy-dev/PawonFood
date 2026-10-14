// Static file server for the render page: "/" serves web/, "/assets/" serves the Flutter app's assets (read-only, no copies).
// Run directly (`npm run preview`) to open the real-time preview in a browser.

import http from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const MOUNTS = [
  ['/assets/', path.resolve(here, '../app/assets')],
  ['/', path.resolve(here, 'web')],
];
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.ttf': 'font/ttf',
};

async function resolveFile(pathname) {
  const [prefix, root] = MOUNTS.find(([p]) => pathname.startsWith(p));
  const file = path.resolve(root, decodeURIComponent(pathname.slice(prefix.length)) || 'index.html');
  if (!file.startsWith(root + path.sep)) return null; // blocks ../ traversal out of the mount
  const info = await stat(file).catch(() => null);
  return info?.isFile() ? file : null;
}

export function startServer(port = 0) {
  const server = http.createServer(async (req, res) => {
    let file = null;
    try {
      file = await resolveFile(new URL(req.url, 'http://localhost').pathname);
    } catch {
      // Malformed URI: falls through to 404.
    }
    if (!file || (req.method !== 'GET' && req.method !== 'HEAD')) {
      res.writeHead(404).end('Not found');
      return;
    }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file).toLowerCase()] ?? 'application/octet-stream', 'Cache-Control': 'no-store' });
    if (req.method === 'HEAD') res.end();
    else createReadStream(file).pipe(res);
  });
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', () => resolve({ server, url: `http://127.0.0.1:${server.address().port}` }));
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const { url } = await startServer(Number(process.env.PORT) || 4317);
  console.log(`Preview: ${url}/   (space: play/pause, arrows: step one frame, Ctrl+C: stop)`);
}

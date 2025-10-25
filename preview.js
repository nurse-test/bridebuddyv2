import { createServer } from 'http';
import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const publicDir = path.join(__dirname, 'public');

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.eot': 'application/vnd.ms-fontobject',
  '.otf': 'font/otf'
};

const resolveCandidatePaths = (requestPath) => {
  const attempts = [];
  const sanitized = requestPath.replace(/^\/+/, '');

  if (!sanitized) {
    attempts.push(path.join(publicDir, 'pages', 'index.html'));
    return attempts;
  }

  const hasExtension = Boolean(path.extname(sanitized));

  if (hasExtension) {
    attempts.push(path.join(publicDir, sanitized));
    attempts.push(path.join(publicDir, 'pages', sanitized));
  } else {
    attempts.push(path.join(publicDir, sanitized, 'index.html'));
    attempts.push(path.join(publicDir, `${sanitized}.html`));
    attempts.push(path.join(publicDir, 'pages', `${sanitized}.html`));
    attempts.push(path.join(publicDir, 'pages', sanitized, 'index.html'));
  }

  return attempts;
};

const getFileToServe = async (requestPath) => {
  const normalized = path.normalize(requestPath).replace(/^\.+/, '');
  const candidates = resolveCandidatePaths(normalized);

  for (const candidate of candidates) {
    const safeCandidate = path.normalize(candidate);
    if (!safeCandidate.startsWith(publicDir)) continue;

    try {
      const stat = await fs.stat(safeCandidate);
      if (stat.isDirectory()) {
        const indexFile = path.join(safeCandidate, 'index.html');
        const indexStat = await fs.stat(indexFile).catch(() => null);
        if (indexStat && indexStat.isFile()) {
          return indexFile;
        }
        continue;
      }

      if (stat.isFile()) {
        return safeCandidate;
      }
    } catch (error) {
      continue;
    }
  }

  return null;
};

const server = createServer(async (req, res) => {
  if (!req.url) {
    res.writeHead(400, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Bad Request');
    return;
  }

  const requestUrl = new URL(req.url, `http://${req.headers.host ?? 'localhost'}`);
  const requestPath = decodeURIComponent(requestUrl.pathname);

  try {
    const fileToServe = await getFileToServe(requestPath);

    if (!fileToServe) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('404 Not Found');
      return;
    }

    const ext = path.extname(fileToServe).toLowerCase();
    const mimeType = mimeTypes[ext] ?? 'application/octet-stream';
    const fileContents = await fs.readFile(fileToServe);

    res.writeHead(200, { 'Content-Type': mimeType });
    res.end(fileContents);
  } catch (error) {
    console.error('Error serving request:', error);
    res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Internal Server Error');
  }
});

const port = Number.parseInt(process.env.PORT ?? '4173', 10);
const host = process.env.HOST ?? '0.0.0.0';

server.listen(port, host, () => {
  console.log(`Bride Buddy preview server running at http://${host}:${port}`);
  console.log('Serving static assets from ./public');
});

const shutdown = () => {
  console.log('\nShutting down preview server...');
  server.close(() => process.exit(0));
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

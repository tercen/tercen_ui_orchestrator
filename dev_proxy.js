#!/usr/bin/env node
/**
 * Dev reverse proxy for the Tercen UI Orchestrator.
 *
 * Serves the Flutter web build on "/" and proxies /api/v1/* requests
 * to the Tercen backend (e.g. stage.tercen.com), so the browser sees
 * a single origin and CORS is not an issue.
 *
 * Also provides /api/local-chat — a streaming endpoint that spawns
 * the local `claude` CLI so the SDUI ChatBox can use Claude Code
 * without a separate Anthropic API key.
 *
 * Usage:
 *   node dev_proxy.js [--port 8888] [--backend https://stage.tercen.com]
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const url = require('url');
const { spawn } = require('child_process');

// --- Config ---
const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
}

const PORT = parseInt(arg('port', '8888'), 10);
const BACKEND = arg('backend', 'https://stage.tercen.com');
const STATIC_DIR = path.join(__dirname, 'build', 'web');
const CLAUDE_BIN = arg('claude', 'claude');

const backendUrl = new URL(BACKEND);

// --- MIME types ---
const MIME = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
};

// ---------------------------------------------------------------------------
// Local Claude Code chat endpoint
// ---------------------------------------------------------------------------
// POST /api/local-chat  { message, sessionId? }
// Returns SSE stream of chat events matching the ChatBackend format.
//
// Uses: claude -p --output-format stream-json --include-partial-messages
//       [--resume <sessionId>] "<message>"
// ---------------------------------------------------------------------------

function handleLocalChat(req, res) {
  let body = '';
  req.on('data', (chunk) => { body += chunk; });
  req.on('end', () => {
    let payload;
    try {
      payload = JSON.parse(body);
    } catch {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Invalid JSON' }));
      return;
    }

    const message = payload.message;
    if (!message) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Missing message' }));
      return;
    }

    const sessionId = payload.sessionId || null;

    // Build claude CLI args
    const cliArgs = [
      '-p',
      '--output-format', 'stream-json',
      '--verbose',
    ];
    if (sessionId) {
      cliArgs.push('--resume', sessionId);
    }
    cliArgs.push(message);

    console.log(`[local-chat] Spawning: ${CLAUDE_BIN} ${cliArgs.join(' ').substring(0, 100)}...`);

    const child = spawn(CLAUDE_BIN, cliArgs, {
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env },
    });

    // Buffer the full response, then return as JSON.
    // (Browser XHR can't stream SSE from a POST, so we collect everything.)
    let fullText = '';
    let resultSessionId = sessionId;
    const events = []; // chat events to deliver to the client
    let buffer = '';

    child.stdout.on('data', (data) => {
      buffer += data.toString();
      const lines = buffer.split('\n');
      buffer = lines.pop(); // keep incomplete last line

      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const evt = JSON.parse(line);
          processClaudeEvent(evt, events, fullText, (t) => { fullText = t; }, (sid) => { resultSessionId = sid; });
        } catch (e) {
          console.log(`[local-chat] non-JSON: ${line.substring(0, 80)}`);
        }
      }
    });

    child.stderr.on('data', (data) => {
      const text = data.toString().trim();
      if (text) console.log(`[local-chat] stderr: ${text.substring(0, 200)}`);
    });

    child.on('close', (code) => {
      console.log(`[local-chat] Process exited with code ${code}, text=${fullText.length} chars`);
      // Return buffered result as JSON
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        text: fullText,
        sessionId: resultSessionId,
        events: events,
      }));
    });

    child.on('error', (err) => {
      console.error(`[local-chat] Spawn error: ${err.message}`);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: `Failed to start claude: ${err.message}` }));
    });

    // If client disconnects before response is sent, kill the process
    res.on('close', () => {
      if (!child.killed && !res.writableEnded) {
        child.kill('SIGTERM');
        console.log(`[local-chat] Client disconnected, killed process`);
      }
    });
  });
}

function processClaudeEvent(evt, events, fullText, setFullText, setSessionId) {
  const type = evt.type;

  switch (type) {
    case 'assistant':
      if (evt.message && evt.message.content) {
        for (const block of evt.message.content) {
          if (block.type === 'text' && block.text) {
            setFullText(block.text);
          }
        }
      }
      break;

    case 'result':
      if (evt.session_id) setSessionId(evt.session_id);
      if (evt.result) setFullText(evt.result);
      break;

    case 'tool_use':
      events.push({
        type: 'tool_start',
        toolName: (evt.tool && evt.tool.name) || 'tool',
        toolId: (evt.tool && evt.tool.id) || 'tool',
      });
      break;

    case 'tool_result':
      events.push({
        type: 'tool_end',
        toolId: (evt.tool && evt.tool.id) || 'tool',
        isError: evt.is_error || false,
      });
      break;

    case 'error':
      events.push({ type: 'error', text: evt.error || 'Unknown error' });
      break;
  }
}

// ---------------------------------------------------------------------------
// Static file server
// ---------------------------------------------------------------------------

function serveStatic(req, res) {
  let filePath = path.join(STATIC_DIR, req.url.split('?')[0]);
  if (filePath.endsWith('/')) filePath += 'index.html';

  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(STATIC_DIR, 'index.html');
  }

  const ext = path.extname(filePath);
  const mime = MIME[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }
    res.writeHead(200, { 'Content-Type': mime });
    res.end(data);
  });
}

// ---------------------------------------------------------------------------
// Reverse proxy to Tercen backend
// ---------------------------------------------------------------------------

function proxyRequest(req, res) {
  const targetPath = req.url;

  const options = {
    hostname: backendUrl.hostname,
    port: backendUrl.port || (backendUrl.protocol === 'https:' ? 443 : 80),
    path: targetPath,
    method: req.method,
    headers: {
      ...req.headers,
      host: backendUrl.host,
      origin: backendUrl.origin,
      referer: backendUrl.origin + '/',
    },
  };

  delete options.headers['connection'];

  const transport = backendUrl.protocol === 'https:' ? https : http;

  const proxyReq = transport.request(options, (proxyRes) => {
    const headers = { ...proxyRes.headers };
    delete headers['access-control-allow-origin'];
    delete headers['access-control-allow-credentials'];

    res.writeHead(proxyRes.statusCode, headers);
    proxyRes.pipe(res, { end: true });
  });

  proxyReq.on('error', (e) => {
    console.error(`[proxy] Error proxying ${req.method} ${targetPath}: ${e.message}`);
    res.writeHead(502);
    res.end(`Proxy error: ${e.message}`);
  });

  req.pipe(proxyReq, { end: true });
}

// ---------------------------------------------------------------------------
// HTTP server
// ---------------------------------------------------------------------------

const server = http.createServer((req, res) => {
  const pathname = url.parse(req.url).pathname;

  // Local Claude Code chat — handled entirely by the proxy
  if (pathname === '/api/local-chat' && req.method === 'POST') {
    console.log(`[proxy] POST /api/local-chat`);
    handleLocalChat(req, res);
    return;
  }

  // Proxy API and service calls to Tercen backend
  if (pathname.startsWith('/api/')) {
    console.log(`[proxy] ${req.method} ${pathname}`);
  }
  if (pathname.startsWith('/api/') ||
      pathname.startsWith('/service/') ||
      pathname.startsWith('/_anthropic') ||
      pathname.startsWith('/_openai')) {
    proxyRequest(req, res);
  } else {
    serveStatic(req, res);
  }
});

// Handle WebSocket upgrades for event service
server.on('upgrade', (req, socket, head) => {
  const targetPath = req.url;
  console.log(`[proxy] WebSocket upgrade: ${targetPath}`);

  const options = {
    hostname: backendUrl.hostname,
    port: backendUrl.port || (backendUrl.protocol === 'https:' ? 443 : 80),
    path: targetPath,
    method: 'GET',
    headers: {
      ...req.headers,
      host: backendUrl.host,
    },
  };

  const transport = backendUrl.protocol === 'https:' ? https : http;

  const proxyReq = transport.request(options);
  proxyReq.on('upgrade', (proxyRes, proxySocket, proxyHead) => {
    let response = `HTTP/1.1 101 Switching Protocols\r\n`;
    for (const [key, value] of Object.entries(proxyRes.headers)) {
      response += `${key}: ${value}\r\n`;
    }
    response += '\r\n';
    socket.write(response);
    if (proxyHead.length > 0) socket.write(proxyHead);

    proxySocket.pipe(socket);
    socket.pipe(proxySocket);

    proxySocket.on('error', () => socket.destroy());
    socket.on('error', () => proxySocket.destroy());
  });

  proxyReq.on('error', (e) => {
    console.error(`[proxy] WebSocket upgrade error: ${e.message}`);
    socket.destroy();
  });

  proxyReq.end();
});

server.listen(PORT, () => {
  console.log(`[dev-proxy] Listening on http://localhost:${PORT}`);
  console.log(`[dev-proxy] Static files: ${STATIC_DIR}`);
  console.log(`[dev-proxy] API proxy → ${BACKEND}`);
  console.log(`[dev-proxy] Local chat → ${CLAUDE_BIN} CLI`);
  console.log(`[dev-proxy] Open: http://localhost:${PORT}/?token=YOUR_JWT`);
});

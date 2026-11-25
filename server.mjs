import { randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { WebSocket, WebSocketServer } from 'ws';
import { advancePlayer, applyInput, interactWithWorld, makePlayer } from './public/world.js';

const assets = new Map([
  ['/', ['index.html', 'text/html; charset=utf-8']],
  ['/index.html', ['index.html', 'text/html; charset=utf-8']],
  ['/style.css', ['style.css', 'text/css; charset=utf-8']],
  ['/game.js', ['game.js', 'text/javascript; charset=utf-8']],
  ['/assets.js', ['assets.js', 'text/javascript; charset=utf-8']],
  ['/world.js', ['world.js', 'text/javascript; charset=utf-8']],
  ['/atmosphere.js', ['atmosphere.js', 'text/javascript; charset=utf-8']],
  ['/terrain.js', ['terrain.js', 'text/javascript; charset=utf-8']],
  ['/assets/lu-khach-run.webp', ['assets/lu-khach-run.webp', 'image/webp']],
  ['/assets/lau.webp', ['assets/lau.webp', 'image/webp']],
  ['/assets/river-material.png', ['assets/river-material.png', 'image/png']],
  ['/sprite.js', ['sprite.js', 'text/javascript; charset=utf-8']],
  ['/assets/song-nguyet.webp', ['assets/song-nguyet.webp', 'image/webp']],
  ['/assets/lu-khach.webp', ['assets/lu-khach.webp', 'image/webp']],
]);
const server = createServer(async (request, response) => {
  const asset = assets.get(request.url?.split('?')[0]);
  if (!asset || !['GET', 'HEAD'].includes(request.method)) {
    response.writeHead(404).end();
    return;
  }

  try {
    const [file, type] = asset;
    const bytes = await readFile(new URL('./public/' + file, import.meta.url));
    response.writeHead(200, { 'Content-Type': type, 'Content-Length': bytes.length });
    response.end(request.method === 'HEAD' ? undefined : bytes);
  } catch {
    response.writeHead(500).end();
  }
});

const sockets = new WebSocketServer({ noServer: true, maxPayload: 1024 });
const players = new Map();
const maxPlayers = 24;
const tickMs = 50;

server.on('upgrade', (request, socket, head) => {
  if (request.url !== '/play' || players.size >= maxPlayers) {
    socket.end('HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n\r\n');
    return;
  }
  sockets.handleUpgrade(request, socket, head, (ws) => sockets.emit('connection', ws));
});

function send(ws, payload) {
  if (ws.readyState === WebSocket.OPEN && ws.bufferedAmount < 64 * 1024) {
    ws.send(JSON.stringify(payload));
  }
}

function notify(ws, message) {
  if (message) send(ws, { type: 'notice', text: message });
}

sockets.on('connection', (ws) => {
  const idx = [...Array(maxPlayers).keys()].find((n) =>
    ![...players.values()].some((player) => player.idx === n));
  const player = { ...makePlayer(idx, randomUUID()), idx, alive: true };
  players.set(ws, player);
  send(ws, { type: 'welcome', id: player.id });
  ws.on('error', () => ws.terminate());
  ws.on('close', () => players.delete(ws));
  ws.on('pong', () => { player.alive = true; });
  ws.on('message', (raw) => {
    let message;
    try { message = JSON.parse(raw); } catch { return; }
    if (!message || typeof message !== 'object') return;

    if (message.type === 'interact') notify(ws, interactWithWorld(player));
    else applyInput(player, message, Date.now());
  });
});

const simulation = setInterval(() => {
  const now = Date.now();
  for (const [ws, player] of players) {
    notify(ws, advancePlayer(player, tickMs / 1000, now));
  }

  const actors = [...players.values()].map(({ id, x, y, name, color, face, moving }) =>
    ({ id, x, y, name, color, face, moving }));
  for (const [ws, player] of players) {
    send(ws, { type: 'state', actors, stage: player.stage, collected: player.collected });
  }
}, tickMs);

const heartbeat = setInterval(() => {
  for (const [ws, player] of players) {
    if (!player.alive) {
      ws.terminate();
      continue;
    }
    player.alive = false;
    ws.ping();
  }
}, 15000);
server.on('close', () => {
  clearInterval(simulation);
  clearInterval(heartbeat);
});
const port = Number(process.env.PORT ?? 3000);
server.listen(port, '0.0.0.0', () => console.log('Tinh Vực đang chạy tại http://localhost:' + port));

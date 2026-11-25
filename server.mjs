import { randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { WebSocket, WebSocketServer } from 'ws';
import { altar, canWalk, distance, fragments, guide } from './public/world.js';

const assets = new Map([
  ['/', ['index.html', 'text/html; charset=utf-8']],
  ['/style.css', ['style.css', 'text/css; charset=utf-8']],
  ['/game.js', ['game.js', 'text/javascript; charset=utf-8']],
  ['/world.js', ['world.js', 'text/javascript; charset=utf-8']],
  ['/atmosphere.js', ['atmosphere.js', 'text/javascript; charset=utf-8']],
  ['/sprite.js', ['sprite.js', 'text/javascript; charset=utf-8']],
  ['/assets/ha-nguyet.webp', ['assets/ha-nguyet.webp', 'image/webp']],
  ['/assets/ha-nguyet-depth.webp', ['assets/ha-nguyet-depth.webp', 'image/webp']],
  ['/assets/ha-nguyet-water.webp', ['assets/ha-nguyet-water.webp', 'image/webp']],
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
const colors = ['teal', 'violet', 'rose', 'amber'];
const maxPlayers = 24;
const spawnColumns = [715, 820, 610, 925];
const speed = 200;
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

function interact(ws, player) {
  if (player.stage === 'start' && distance(player, guide) < 85) {
    player.stage = 'collect';
    send(ws, { type: 'notice', text: 'Người giữ đền nhờ bạn tìm ba mảnh nguyệt thạch trong làng.' });
  } else if (player.stage === 'return' && distance(player, altar) < 85) {
    player.stage = 'done';
    send(ws, { type: 'notice', text: 'Ấn Nguyệt đã sáng trở lại. Bạn nhận được 100 kinh nghiệm!' });
  }
}

sockets.on('connection', (ws) => {
  const idx = [...Array(maxPlayers).keys()].find((n) =>
    ![...players.values()].some((player) => player.idx === n));
  const player = {
    idx, id: randomUUID(), x: spawnColumns[idx % spawnColumns.length],
    y: 784 + Math.floor(idx / spawnColumns.length) * 28,
    name: 'Lữ khách ' + String(idx + 1).padStart(2, '0'),
    color: colors[idx % colors.length], stage: 'start', collected: [],
    dx: 0, dy: 0, face: 1, moving: false, target: null, alive: true, lastInputAt: 0,
  };
  players.set(ws, player);
  send(ws, { type: 'welcome', id: player.id });
  ws.on('error', () => ws.terminate());
  ws.on('close', () => players.delete(ws));
  ws.on('pong', () => { player.alive = true; });
  ws.on('message', (raw) => {
    let message;
    try { message = JSON.parse(raw); } catch { return; }
    if (!message || typeof message !== 'object') return;

    if (message.type === 'move' && Number.isFinite(message.dx) && Number.isFinite(message.dy)) {
      player.lastInputAt = Date.now();
      player.dx = Math.max(-1, Math.min(1, message.dx));
      player.dy = Math.max(-1, Math.min(1, message.dy));
      player.target = null;
    } else if (message.type === 'target' && Number.isFinite(message.x) &&
      Number.isFinite(message.y) && canWalk(message.x, message.y)) {
      player.target = { x: message.x, y: message.y };
    } else if (message.type === 'interact') {
      interact(ws, player);
    }
  });
});

const simulation = setInterval(() => {
  const now = Date.now();
  for (const [ws, player] of players) {
    let dx = 0;
    let dy = 0;
    if (player.target) {
      dx = player.target.x - player.x;
      dy = player.target.y - player.y;
    } else if (now - player.lastInputAt < 420) {
      dx = player.dx;
      dy = player.dy;
    }
    const step = speed * tickMs / 1000;
    const divisor = player.target ? Math.max(step, Math.hypot(dx, dy)) : Math.max(1, Math.hypot(dx, dy));
    const x = player.x + dx / divisor * step;
    const y = player.y + dy / divisor * step;
    const oldX = player.x;
    const oldY = player.y;
    if (canWalk(x, player.y)) player.x = x;
    if (canWalk(player.x, y)) player.y = y;
    player.moving = oldX !== player.x || oldY !== player.y;
    if (Math.abs(dx) > 0.01) player.face = Math.sign(dx);
    if (player.target && (!player.moving || distance(player, player.target) < 1)) player.target = null;

    if (player.stage === 'collect') {
      fragments.forEach((fragment, index) => {
        if (distance(player, fragment) < 37 && !player.collected.includes(index)) {
          player.collected.push(index);
          send(ws, { type: 'notice', text: 'Đã nhặt nguyệt thạch · ' + player.collected.length + '/' + fragments.length });
        }
      });
      if (player.collected.length === fragments.length) player.stage = 'return';
    }
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

import { altar, canWalk, distance, fragments, guide, height, width } from './world.js';

const canvas = document.querySelector('#world');
const ctx = canvas.getContext('2d');
const connection = document.querySelector('#connection');
const objective = document.querySelector('#objective');
const progress = document.querySelector('#progress');
const icons = document.querySelector('#shard-icons');
const count = document.querySelector('#count');
const notice = document.querySelector('#notice');
const interactButton = document.querySelector('#interact');
const interactLabel = interactButton.querySelector('span');
const experience = document.querySelector('#experience');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const compact = matchMedia('(max-width: 600px)');
const npcs = { x: guide.x, y: guide.y, name: 'Người giữ đền', color: 'amber', face: 1 };
const actors = new Map();
const keys = new Set();
const moveKeys = new Map([
  ['w', [0, -1]], ['a', [-1, 0]], ['s', [0, 1]], ['d', [1, 0]],
  ['arrowup', [0, -1]], ['arrowleft', [-1, 0]],
  ['arrowdown', [0, 1]], ['arrowright', [1, 0]],
]);
const questText = {
  start: 'Gặp Người giữ đền ở quảng trường.',
  collect: 'Tìm ba mảnh nguyệt thạch đang phát sáng.',
  return: 'Mang nguyệt thạch đến Ấn Nguyệt trên bậc đền.',
  done: 'Ánh sáng đã trở lại làng Hạ Nguyệt.',
};
const lanterns = [[694, 316], [847, 316], [600, 456], [941, 456], [1118, 505], [301, 461], [132, 500]];
const palette = {
  teal: ['#1d5265', '#4fa2a9', '#9be2e3'],
  violet: ['#482e68', '#8464bb', '#d5bfff'],
  rose: ['#582e4d', '#ad5d87', '#f8afc9'],
  amber: ['#69442d', '#ac7946', '#ffd99a'],
};
const sprite = [
  '      hhhh      ',
  '    hhkkkkh     ',
  '   hkkkllkkh    ',
  '   hkllkkkkhh   ',
  '   hkkffffkhh   ',
  '   hkkfefekkh   ',
  '    hkfffkh     ',
  '   ddttffddd    ',
  '  dttttatttqd   ',
  ' dttttaattttqd  ',
  ' dtttaaattttqd  ',
  ' dtqtaaastqqd   ',
  '  fqdaagaaaf    ',
  '   dqaaaatqdd   ',
  '  ddqaatttqqd   ',
  '  dqttttqqqqd   ',
  '  dqtdttqdd     ',
  '   ddddddd      ',
];
const points = Array.from({ length: 34 }, (_, i) => ({
  x: 115 + ((i * 137.31) % 1290),
  y: 206 + ((i * 73.17) % 676),
  phase: i * 2.4,
}));
let socket;
let self;
let stage = 'start';
let collected = [];
let noticeTimer;
let retryDelay = 600;
let clickMarker;

function send(payload) {
  if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(payload));
}

function updateQuest(nextStage, nextCollected) {
  if (stage === nextStage && collected.length === nextCollected.length) return;
  stage = nextStage;
  collected = nextCollected;
  objective.textContent = questText[stage];
  progress.hidden = stage === 'start' || stage === 'done';
  icons.textContent = fragments.map((_, index) => index < collected.length ? '◆' : '◇').join(' ');
  count.textContent = collected.length + '/' + fragments.length + ' mảnh';
  experience.textContent = stage === 'done' ? 'Cấp 2 · 100 KN' : 'Cấp 1 · 0 KN';
}

function connect() {
  socket = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/play');
  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    if (message.type === 'welcome') {
      self = message.id;
      retryDelay = 600;
    } else if (message.type === 'notice') {
      clearTimeout(noticeTimer);
      notice.textContent = message.text;
      notice.hidden = false;
      noticeTimer = setTimeout(() => { notice.hidden = true; }, 3200);
    } else if (message.type === 'state') {
      const visible = new Set(message.actors.map(({ id }) => id));
      for (const id of actors.keys()) {
        if (!visible.has(id)) actors.delete(id);
      }
      for (const data of message.actors) {
        const actor = actors.get(data.id);
        if (actor) Object.assign(actor, data);
        else actors.set(data.id, { ...data, renderX: data.x, renderY: data.y });
      }
      updateQuest(message.stage, message.collected);
      connection.dataset.state = 'online';
      const label = message.actors.length + ' trực tuyến';
      if (connection.textContent !== label) connection.textContent = label;
      const player = actors.get(self);
      const canTalk = player && stage === 'start' && distance(player, guide) < 85;
      const canFinish = player && stage === 'return' && distance(player, altar) < 85;
      interactButton.hidden = !canTalk && !canFinish;
      if (canTalk || canFinish) interactLabel.textContent = canTalk ? 'Nói chuyện' : 'Thắp Ấn Nguyệt';
    }
  });
  socket.addEventListener('close', () => {
    self = undefined;
    actors.clear();
    keys.clear();
    clickMarker = undefined;
    notice.hidden = true;
    interactButton.hidden = true;
    updateQuest('start', []);
    connection.dataset.state = 'connecting';
    connection.textContent = 'Đang kết nối lại';
    setTimeout(connect, retryDelay);
    retryDelay = Math.min(retryDelay * 2, 8000);
  });
}

function keyboardMove() {
  let dx = 0;
  let dy = 0;
  for (const key of keys) {
    const [x, y] = moveKeys.get(key);
    dx += x;
    dy += y;
  }
  send({ type: 'move', dx: Math.sign(dx), dy: Math.sign(dy) });
}

window.addEventListener('keydown', (event) => {
  if (event.altKey || event.ctrlKey || event.metaKey) return;
  const key = event.key.toLowerCase();
  if (moveKeys.has(key)) {
    event.preventDefault();
    keys.add(key);
    keyboardMove();
  } else if (key === 'e' && !event.repeat) send({ type: 'interact' });
});
window.addEventListener('keyup', (event) => {
  if (keys.delete(event.key.toLowerCase())) keyboardMove();
});
window.addEventListener('blur', () => {
  if (!keys.size) return;
  keys.clear();
  keyboardMove();
});
setInterval(() => { if (keys.size) keyboardMove(); }, 120);
interactButton.addEventListener('click', () => send({ type: 'interact' }));

canvas.addEventListener('pointerdown', (event) => {
  if (event.button !== 0 || !self) return;
  const bounds = canvas.getBoundingClientRect();
  const x = (event.clientX - bounds.left) * width / bounds.width;
  const y = (event.clientY - bounds.top) * height / bounds.height;
  if (!canWalk(x, y)) return;
  keys.clear();
  clickMarker = { x, y, until: performance.now() + 670 };
  send({ type: 'target', x, y });
});

function glow(x, y, radius, color) {
  const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
  gradient.addColorStop(0, color);
  gradient.addColorStop(1, 'transparent');
  ctx.fillStyle = gradient;
  ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
}

function diamond(x, y, radius, color, fill) {
  ctx.beginPath();
  ctx.moveTo(x, y - radius);
  ctx.lineTo(x + radius * 0.63, y);
  ctx.lineTo(x, y + radius);
  ctx.lineTo(x - radius * 0.63, y);
  ctx.closePath();
  if (fill) {
    ctx.fillStyle = color;
    ctx.fill();
  } else {
    ctx.lineWidth = 2;
    ctx.strokeStyle = color;
    ctx.stroke();
  }
}

function label(text, x, y, color) {
  ctx.textAlign = 'center';
  ctx.font = '600 ' + (compact.matches ? 22 : 17) + 'px system-ui';
  ctx.lineWidth = 4;
  ctx.strokeStyle = '#111527';
  ctx.strokeText(text, x, y);
  ctx.fillStyle = color;
  ctx.fillText(text, x, y);
}

function drawActor(actor, time) {
  const x = Math.round(actor.renderX ?? actor.x);
  const y = Math.round(actor.renderY ?? actor.y);
  const size = Math.max(3, Math.min(4, 3 + (y - 620) / 300));
  const stride = actor.moving ? Math.floor(time / 130) % 4 : 0;
  const bob = stride % 2;
  const [main, medium, light] = palette[actor.color];
  const ink = {
    h: '#111726', k: '#2a3045', l: '#515b71', f: '#e4ae8c', e: '#272237',
    d: '#12182c', t: main, a: medium, q: '#2e2945', s: light, g: '#e9cc8c',
  };

  ctx.beginPath();
  ctx.ellipse(x + 5, y + 1, 17, 6, -0.12, 0, Math.PI * 2);
  ctx.fillStyle = '#05081899';
  ctx.fill();
  ctx.save();
  ctx.translate(x, y - bob * size);
  ctx.scale(actor.face, 1);
  ctx.fillStyle = '#151724';
  ctx.fillRect(-size * 3, -size * 3 - (stride === 1 ? 2 : 0), size * 2, size * 3);
  ctx.fillRect(size, -size * 3 - (stride === 3 ? 2 : 0), size * 2, size * 3);
  ctx.fillStyle = '#4d4c67';
  ctx.fillRect(-size * 3, -size, size * 2, size);
  ctx.fillRect(size, -size, size * 2, size);
  sprite.forEach((row, iy) => {
    for (let ix = 0; ix < row.length; ix++) {
      if (row[ix] === ' ') continue;
      ctx.fillStyle = ink[row[ix]];
      ctx.fillRect((ix - 8) * size, (iy - sprite.length - 2) * size, size, size);
    }
  });
  ctx.restore();
  if (actor.id === self) {
    diamond(x, y - size * 24, 5, '#a3f4fa', true);
    label('Bạn', x, y + 19, '#cafffb');
  } else label(actor.name, x, y + 19, actor === npcs ? '#ffe2a4' : '#f1e9ff');
}

function render(now) {
  const time = reducedMotion.matches ? 0 : now;
  ctx.clearRect(0, 0, width, height);
  ctx.save();
  ctx.globalCompositeOperation = 'screen';
  lanterns.forEach(([x, y], i) => {
    ctx.globalAlpha = 0.48 + Math.sin(time / 440 + i * 1.6) * 0.13;
    glow(x, y, 43, '#ff9b3b7a');
  });
  ctx.restore();

  for (const p of points) {
    const x = p.x + Math.sin(time / 2600 + p.phase) * 19;
    const y = p.y + Math.cos(time / 2400 + p.phase) * 10;
    ctx.globalAlpha = 0.36 + Math.sin(time / 980 + p.phase) * 0.29;
    ctx.fillStyle = '#ffdcac';
    ctx.fillRect(x, y, 2, 2);
  }
  ctx.globalAlpha = 1;

  if (clickMarker && now < clickMarker.until) {
    const fade = (clickMarker.until - now) / 670;
    ctx.globalAlpha = fade * 0.85;
    ctx.strokeStyle = '#ddfbff';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.ellipse(clickMarker.x, clickMarker.y, 9 + 14 * (1 - fade), 4 + 5 * (1 - fade), 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;
  }

  if (stage === 'start') {
    diamond(guide.x, guide.y - 88, 8, '#ffdd9e', false);
  } else if (stage === 'collect') {
    fragments.forEach(({ x, y }, index) => {
      if (collected.includes(index)) return;
      const hover = Math.sin(time / 430 + index) * 5;
      glow(x, y - 14 + hover, 32, '#5df7e2a0');
      diamond(x, y - 14 + hover, 11, '#bdfffa', true);
      diamond(x + 1, y - 15 + hover, 7, '#449fc0', true);
    });
  } else {
    const lit = stage === 'done';
    glow(altar.x, altar.y - 76, lit ? 97 : 54, lit ? '#ffe1a88c' : '#a5faf980');
    diamond(altar.x, altar.y - 73, 13, lit ? '#ffebae' : '#c1fff5', lit);
  }

  for (const actor of actors.values()) {
    actor.renderX += (actor.x - actor.renderX) * 0.24;
    actor.renderY += (actor.y - actor.renderY) * 0.24;
  }
  const ordered = [npcs, ...actors.values()].sort((a, b) => (a.renderY ?? a.y) - (b.renderY ?? b.y));
  for (const actor of ordered) drawActor(actor, time);
  requestAnimationFrame(render);
}

connect();
requestAnimationFrame(render);

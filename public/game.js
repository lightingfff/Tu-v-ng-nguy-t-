import { createAtmosphere } from './atmosphere.js';
import { actorHeight, drawSprite } from './sprite.js';
import {
  advancePlayer, applyInput, areas, altar, cameraTop, fragments, groundAt, guide,
  interactWithWorld, interactionFor, makePlayer, viewportHeight, viewportWidth, width,
} from './world.js';

const canvas = document.querySelector('#world');
const ctx = canvas.getContext('2d');
const atmosphere = createAtmosphere();
const layout = document.querySelector('.layout');
const viewButton = document.querySelector('#view-scene');
const hudButton = document.querySelector('#hide-hud');
const connection = document.querySelector('#connection');
const objective = document.querySelector('#objective');
const progress = document.querySelector('#progress');
const icons = document.querySelector('#shard-icons');
const count = document.querySelector('#count');
const notice = document.querySelector('#notice');
const interactButton = document.querySelector('#interact');
const interactLabel = interactButton.querySelector('span');
const experience = document.querySelector('#experience');
const place = document.querySelector('#place-name');
const trailMeter = document.querySelector('#trail-meter');
const offlineOnly = document.body.hasAttribute('data-offline-only') || location.protocol === 'file:' || location.hostname.endsWith('.github.io');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const compact = matchMedia('(max-width: 700px)');
const guideActor = { ...guide, name: 'Người trông quán', color: 'amber', face: 1 };
const localPlayer = makePlayer(0, 'local');
const actors = new Map();
const keys = new Set();
const touches = new Map();
const moveKeys = new Map([['a', -1], ['d', 1], ['arrowleft', -1], ['arrowright', 1]]);
const questText = {
  start: 'Tìm người trông quán ở bến sông.',
  collect: 'Tìm ba mảnh nguyệt thạch trên đường tới đền.',
  return: 'Mang nguyệt thạch tới Ấn Nguyệt ở đền Trăng Nổi.',
  done: 'Ấn Nguyệt đã sáng trở lại bên bờ sông.',
};
let socket;
let self;
let serverState = 'start';
let serverShards = [];
let sceneMode = new URLSearchParams(location.search).get('view') === 'scene' || offlineOnly;
let camera = 0;
let noticeTimer;
let retryTimer;
let retryDelay = 600;
let clickMarker;
let lastFrame = performance.now();

function showNotice(message) {
  if (!message) return;
  clearTimeout(noticeTimer);
  notice.textContent = message;
  notice.hidden = false;
  noticeTimer = setTimeout(() => { notice.hidden = true; }, 3400);
}

function player() {
  return sceneMode ? localPlayer : actors.get(self);
}

function setMode(offline) {
  sceneMode = offline;
  viewButton.textContent = offline ? 'Chơi cùng' : 'Chơi một mình';
  if (offline) {
    clearTimeout(retryTimer);
    if (socket) {
      const lastSocket = socket;
      socket = undefined;
      if (lastSocket.readyState < WebSocket.CLOSING) lastSocket.close();
    }
    actors.clear();
    self = undefined;
    connection.textContent = 'Một người chơi';
    connection.dataset.state = 'offline';
  } else if (!socket) {
    connection.textContent = 'Đang kết nối';
    connection.dataset.state = 'connecting';
    connect();
  }
  keys.clear();
  touches.clear();
  move();
}

function updateQuest(currentStage, collected) {
  if (objective.textContent !== questText[currentStage]) objective.textContent = questText[currentStage];
  progress.hidden = currentStage === 'start' || currentStage === 'done';
  const total = collected.length + '/' + fragments.length + ' mảnh';
  if (count.textContent !== total) {
    count.textContent = total;
    icons.textContent = fragments.map((_, index) => index < collected.length ? '◆' : '◇').join(' ');
  }
  const level = currentStage === 'done' ? 'Cấp 2 · 100 KN' : 'Cấp 1 · 0 KN';
  if (experience.textContent !== level) experience.textContent = level;
}

function connect() {
  const endpoint = new URL('./play', location.href);
  endpoint.protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
  const connectionSocket = new WebSocket(endpoint);
  let entered = false;
  socket = connectionSocket;
  socket.addEventListener('message', (event) => {
    if (socket !== connectionSocket) return;
    const message = JSON.parse(event.data);
    if (message.type === 'welcome') {
      self = message.id;
      entered = true;
      retryDelay = 600;
    } else if (message.type === 'notice') {
      showNotice(message.text);
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
      serverState = message.stage;
      serverShards = message.collected;
      connection.dataset.state = 'online';
      const label = message.actors.length + ' trực tuyến';
      if (connection.textContent !== label) connection.textContent = label;
    }
  });
  socket.addEventListener('close', () => {
    if (socket !== connectionSocket) return;
    socket = undefined;
    actors.clear();
    self = undefined;
    keys.clear();
    touches.clear();
    if (!entered) {
      setMode(true);
      showNotice('Đang chơi một mình. Máy chủ chơi cùng hiện chưa kết nối được.');
      return;
    }
    connection.dataset.state = 'connecting';
    connection.textContent = 'Đang kết nối lại';
    retryTimer = setTimeout(connect, retryDelay);
    retryDelay = Math.min(retryDelay * 2, 8000);
  });
}

function command(payload) {
  if (sceneMode) {
    if (payload.type === 'interact') showNotice(interactWithWorld(localPlayer));
    else applyInput(localPlayer, payload, performance.now());
  } else if (socket?.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify(payload));
  }
}

function move() {
  let dx = 0;
  for (const key of keys) dx += moveKeys.get(key);
  for (const value of touches.values()) dx += value;
  command({ type: 'move', dx: Math.sign(dx) });
}

function act() {
  command({ type: 'interact' });
}

window.addEventListener('keydown', (event) => {
  if (event.altKey || event.ctrlKey || event.metaKey) return;
  const key = event.key.toLowerCase();
  if (moveKeys.has(key)) {
    event.preventDefault();
    keys.add(key);
    move();
  } else if (key === 'e' && !event.repeat) act();
});
window.addEventListener('keyup', (event) => {
  if (keys.delete(event.key.toLowerCase())) move();
});
window.addEventListener('blur', () => {
  if (!keys.size && !touches.size) return;
  keys.clear();
  touches.clear();
  move();
});
setInterval(() => { if (keys.size || touches.size) move(); }, 120);

for (const control of document.querySelectorAll('[data-move]')) {
  const direction = Number(control.dataset.move);
  control.addEventListener('pointerdown', (event) => {
    if (event.button !== 0) return;
    event.preventDefault();
    control.setPointerCapture(event.pointerId);
    touches.set(event.pointerId, direction);
    move();
  });
  for (const type of ['pointerup', 'pointercancel', 'lostpointercapture']) {
    control.addEventListener(type, (event) => {
      if (touches.delete(event.pointerId)) move();
    });
  }
  control.addEventListener('click', (event) => {
    if (event.detail !== 0) return;
    const active = player();
    if (active) command({ type: 'target', x: active.x + direction * 124 });
  });
}

canvas.addEventListener('pointerdown', (event) => {
  if (event.button !== 0 || !player()) return;
  const bounds = canvas.getBoundingClientRect();
  const x = camera + (event.clientX - bounds.left) * viewportWidth / bounds.width;
  keys.clear();
  touches.clear();
  clickMarker = { x, y: groundAt(x), until: performance.now() + 670 };
  command({ type: 'target', x });
});
interactButton.addEventListener('click', act);
viewButton.hidden = offlineOnly;
viewButton.addEventListener('click', () => setMode(!sceneMode));
hudButton.addEventListener('click', () => {
  const hidden = layout.classList.toggle('clean-view');
  hudButton.textContent = hidden ? 'Hiện giao diện' : 'Ẩn giao diện';
  hudButton.setAttribute('aria-pressed', String(hidden));
});
setMode(sceneMode);

function glow(x, y, radius, color) {
  const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
  gradient.addColorStop(0, color);
  gradient.addColorStop(1, 'transparent');
  ctx.fillStyle = gradient;
  ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
}

function diamond(x, y, radius, color) {
  ctx.beginPath();
  ctx.moveTo(x, y - radius);
  ctx.lineTo(x + radius * 0.57, y);
  ctx.lineTo(x, y + radius);
  ctx.lineTo(x - radius * 0.57, y);
  ctx.closePath();
  ctx.fillStyle = color;
  ctx.fill();
}

function drawActor(actor, time) {
  const x = Math.round(actor.renderX ?? actor.x);
  const y = Math.round(actor.renderY ?? actor.y);
  if (x + 100 < camera || x - 100 > camera + viewportWidth) return;
  drawSprite(ctx, actor, x, y, time);
  if (layout.classList.contains('clean-view') || actor.id === 'local') return;
  if (actor.id === self) diamond(x + 4, y - actorHeight(actor) - 15, 5, '#e4fff7');
  ctx.textAlign = 'center';
  ctx.font = '600 ' + (compact.matches ? 22 : 17) + 'px system-ui';
  ctx.lineWidth = 4;
  ctx.strokeStyle = '#1b2437';
  ctx.strokeText(actor.name, x, y + 23);
  ctx.fillStyle = actor === guideActor ? '#ffeac9' : '#fcfff0';
  ctx.fillText(actor.name, x, y + 23);
}

function drawWorld(stage, collected, time, now) {
  if (clickMarker && now < clickMarker.until) {
    const fade = (clickMarker.until - now) / 670;
    ctx.globalAlpha = fade * .85;
    ctx.strokeStyle = '#fff8d3';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.ellipse(clickMarker.x, clickMarker.y, 10 + 13 * (1 - fade), 5 + 5 * (1 - fade), 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;
  }
  if (stage === 'start') {
    const y = guide.y - actorHeight(guideActor) - 14 + Math.sin(time * 3.4) * 4;
    glow(guide.x, y, 19, '#ffdc7566');
    diamond(guide.x, y, 7, '#f9d569');
  } else if (stage === 'collect') {
    fragments.forEach(({ x, y }, index) => {
      if (collected.includes(index) || x < camera - 32 || x > camera + viewportWidth + 32) return;
      const hover = Math.sin(time * 2.8 + index) * 5;
      glow(x, y - 30 + hover, 37, '#b8ffe6c0');
      diamond(x, y - 30 + hover, 13, '#edffeb');
      diamond(x + 2, y - 32 + hover, 8, '#79dacf');
    });
  } else {
    const lit = stage === 'done';
    const y = altar.y - 217;
    glow(altar.x, y, lit ? 103 : 49, lit ? '#ffe19ac0' : '#dcffd390');
    if (!lit) diamond(altar.x, y, 10, '#effeca');
  }
}

function render(now) {
  const dt = Math.min((now - lastFrame) / 1000, 0.05);
  const animate = !reducedMotion.matches;
  const time = animate ? now / 1000 : 0;
  lastFrame = now;
  if (sceneMode) showNotice(advancePlayer(localPlayer, dt, now));

  for (const actor of actors.values()) {
    const smoothing = 1 - Math.exp(-dt * 15);
    actor.renderX += (actor.x - actor.renderX) * smoothing;
    actor.renderY += (actor.y - actor.renderY) * smoothing;
  }
  const current = player();
  const stage = sceneMode ? localPlayer.stage : serverState;
  const collected = sceneMode ? localPlayer.collected : serverShards;
  if (current) {
    const position = current.renderX ?? current.x;
    const follow = Math.max(0, Math.min(width - viewportWidth, position - viewportWidth * 0.47));
    camera += (follow - camera) * (animate ? 1 - Math.exp(-dt * 7) : 1);
    const region = areas.findLast(({ start }) => position >= start);
    if (region && place.textContent !== region.name) place.textContent = region.name;
    trailMeter.value = position / width;
  }
  updateQuest(stage, collected);
  const action = current && interactionFor({ ...current, stage });
  interactButton.hidden = !action;
  if (action && interactLabel.textContent !== action) interactLabel.textContent = action;

  ctx.clearRect(0, 0, viewportWidth, viewportHeight);
  const origin = Math.round(camera);
  atmosphere.background(ctx, origin, time, animate);
  ctx.save();
  ctx.translate(-origin, -cameraTop);
  if (!layout.classList.contains('clean-view')) drawWorld(stage, collected, time, now);
  const visible = sceneMode ? [guideActor, localPlayer] : [guideActor, ...actors.values()];
  visible.sort((a, b) => (a.renderY ?? a.y) - (b.renderY ?? b.y));
  for (const actor of visible) drawActor(actor, time);
  ctx.restore();
  atmosphere.foreground(ctx, origin, time);
  requestAnimationFrame(render);
}

requestAnimationFrame(render);

export const width = 2560;
export const height = 853;
export const viewportWidth = 1360;
export const viewportHeight = 765;
export const cameraTop = 25;

const trail = [
  [63, 621], [472, 619], [765, 618], [950, 615],
  [1015, 571], [1100, 540], [1195, 512], [1306, 489],
  [1427, 493], [1515, 514], [1590, 536], [1690, 604],
  [1830, 618], [2240, 618], [2485, 620],
];
const first = trail[0][0];
const last = trail.at(-1)[0];
const speed = 225;

export function groundAt(x) {
  for (let index = 1; index < trail.length; index++) {
    const [right, end] = trail[index];
    if (x > right) continue;
    const [left, start] = trail[index - 1];
    return start + (end - start) * Math.max(0, (x - left) / (right - left));
  }
  return trail.at(-1)[1];
}

const point = (x) => ({ x, y: groundAt(x) });
export const guide = point(395);
export const altar = point(2215);
export const fragments = [778, 1318, 1870].map(point);
export const areas = [
  { start: 0, name: 'Xóm Bến Sương' },
  { start: 935, name: 'Cầu Gió' },
  { start: 1690, name: 'Vườn Đèn Nước' },
  { start: 1980, name: 'Đền Trăng Nổi' },
];
const colors = ['teal', 'violet', 'rose', 'amber'];

export function makePlayer(index, id) {
  const x = 210 + (index % 6) * 21 + Math.floor(index / 6) * 19;
  return {
    ...point(x), id, name: 'Lữ khách ' + String(index + 1).padStart(2, '0'),
    color: colors[index % colors.length], face: 1, moving: false, direction: 0, inputAt: 0,
    target: null, stage: 'start', collected: [],
  };
}

export function applyInput(player, message, now) {
  if (message.type === 'move' && Number.isFinite(message.dx)) {
    player.direction = Math.sign(message.dx);
    player.inputAt = now;
    player.target = null;
  } else if (message.type === 'target' && Number.isFinite(message.x)) {
    player.direction = 0;
    player.target = Math.max(first, Math.min(last, message.x));
  }
}

export function advancePlayer(player, seconds, now) {
  const old = player.x;
  const step = speed * seconds;
  if (player.target !== null) {
    const remaining = player.target - player.x;
    const offset = Math.abs(remaining) <= step ? remaining : Math.sign(remaining) * step;
    player.x += offset;
    if (player.x === player.target) player.target = null;
  } else if (now - player.inputAt < 420) {
    player.x = Math.max(first, Math.min(last, player.x + player.direction * step));
  }

  player.y = groundAt(player.x);
  player.moving = old !== player.x;
  if (player.moving) player.face = Math.sign(player.x - old);

  if (player.stage !== 'collect') return;
  const shard = fragments.findIndex(({ x }, index) =>
    Math.abs(x - player.x) < 35 && !player.collected.includes(index));
  if (shard === -1) return;
  player.collected.push(shard);
  if (player.collected.length === fragments.length) player.stage = 'return';
  return 'Đã tìm thấy mảnh nguyệt thạch · ' + player.collected.length + '/' + fragments.length;
}

export function interactionFor(player) {
  if (player.stage === 'start' && Math.abs(player.x - guide.x) < 79) return 'Nói chuyện';
  if (player.stage === 'return' && Math.abs(player.x - altar.x) < 82) return 'Thắp Ấn Nguyệt';
}

export function interactWithWorld(player) {
  if (!interactionFor(player)) return;
  if (player.stage === 'start') {
    player.stage = 'collect';
    return 'Tìm ba mảnh nguyệt thạch dọc bờ sông rồi mang đến đền Trăng Nổi.';
  }
  player.stage = 'done';
  return 'Ấn Nguyệt đã sáng trở lại. Bạn nhận được 100 kinh nghiệm!';
}

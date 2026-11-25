import { travelerUrl, runUrl } from './assets.js';

const filters = {
  teal: 'none',
  violet: 'hue-rotate(26deg) saturate(.9)',
  rose: 'hue-rotate(301deg) saturate(.83)',
  amber: 'sepia(.6) saturate(.72)',
};

function loadPoses(url, frames) {
  const poses = new Map();
  const art = new Image();
  art.src = url;
  art.decode().then(() => {
    for (const [name, filter] of Object.entries({ ...filters, shadow: 'brightness(0)' })) {
      const sheet = document.createElement('canvas');
      sheet.width = art.width;
      sheet.height = art.height;
      const context = sheet.getContext('2d');
      context.filter = filter;
      context.drawImage(art, 0, 0);
      poses.set(name, sheet);
    }
  }).catch(() => {});
  return { poses, frames };
}

const idle = loadPoses(travelerUrl, 1);
const run = loadPoses(runUrl, 6);

export function actorHeight(actor) {
  return actor.color === 'amber' ? 120 : 138;
}

export function drawSprite(ctx, actor, x, y, time) {
  const animation = actor.moving && run.poses.size ? run : idle;
  const tex = animation.poses.get(actor.color) ?? animation.poses.get('teal');
  if (!tex) return;
  const h = actorHeight(actor);
  const cell = tex.width / animation.frames;
  const w = cell * h / tex.height;
  const frame = Math.floor(time * 12) % animation.frames;
  const inhale = actor.moving ? 0 : Math.sin(time * 2.1) * 0.8;
  const drawPose = bitmap => ctx.drawImage(bitmap, frame * cell, 0, cell, tex.height,
    -w / 2, -h - inhale, w, h + inhale);

  ctx.save();
  ctx.translate(x, y);
  ctx.fillStyle = '#1b263854';
  ctx.beginPath();
  ctx.ellipse(4, 2, w * .29, 5, .05, 0, Math.PI * 2);
  ctx.fill();
  ctx.save();
  ctx.transform(actor.face * .89, 0, -.47, -.105, 1, 0);
  ctx.globalAlpha = .24;
  drawPose(animation.poses.get('shadow'));
  ctx.restore();
  ctx.scale(actor.face, 1);
  drawPose(tex);
  ctx.restore();
}

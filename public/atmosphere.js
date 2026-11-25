import { createTerrain } from "./terrain.js";
import { panoramaUrl, reedsUrl, materialUrl } from './assets.js';
import { cameraTop, height, viewportHeight, viewportWidth, width } from './world.js';

const banks = new Path2D([
  'M 290 782 L 550 748 L 790 755 L 979 724 L 1118 709 L 1182 652',
  'Q 1194 582 1261 551 Q 1300 536 1349 552 Q 1406 560 1436 628',
  'L 1457 710 L 1538 743 L 1772 751 L 2006 725 L 2160 741 L 2315 724',
  'L 2300 786 L 2220 803 L 1980 818 L 1730 824 L 1133 835 L 554 840 Z',
].join(' '));
const reedZones = [
  { x: 753, y: 422, w: 203, h: 172, phase: 0 },
  { x: 1705, y: 406, w: 214, h: 184, phase: 2 },
  { x: 4, y: 667, w: 475, h: 186, phase: 3 },
  { x: 2067, y: 670, w: 475, h: 183, phase: 1 },
];
const petals = Array.from({ length: 35 }, (_, i) => ({
  x: i < 17 ? (i * 61) % 625 : 2050 + (i * 83) % 500,
  phase: i * 2.399,
  duration: 9 + i % 9,
  tone: i < 17 ? ['#ffda8b', '#fff1b2', '#eab472'][i % 3] : ['#f77b46', '#f6ae6e', '#ffd87d'][i % 3],
  size: 2.1 + ((i * 17) % 7) * 0.36,
}));

function createBuffer(w, h) {
  const layer = document.createElement('canvas');
  layer.width = w;
  layer.height = h;
  return layer.getContext('2d');
}

function createReeds(image, zone) {
  const feather = createBuffer(zone.w, zone.h);
  feather.drawImage(image, zone.x, zone.y, zone.w, zone.h, 0, 0, zone.w, zone.h);
  const pixels = feather.getImageData(0, 0, zone.w, zone.h);
  for (let y = 0; y < zone.h; y++) {
    for (let x = 0; x < zone.w; x++) {
      const index = (y * zone.w + x) * 4;
      const red = pixels.data[index];
      const green = pixels.data[index + 1];
      const blue = pixels.data[index + 2];
      const plant = Math.min((red + green) * 0.5 - blue, green - blue + 18);
      const featherEdge = Math.min(1, x / 22, (zone.w - 1 - x) / 22, y / 17, (zone.h - 1 - y) / 17);
      pixels.data[index + 3] = Math.round(240 * featherEdge * Math.max(0, Math.min(1, (plant - 17) / 30)));
    }
  }
  feather.putImageData(pixels, 0, 0);
  return { ...zone, mask: feather.canvas, buffer: createBuffer(zone.w, zone.h) };
}

function focusBackground(image) {
  const out = createBuffer(width, height);
  out.drawImage(image, 0, 0);
  const defocus = createBuffer(width, height);
  defocus.filter = 'blur(2.8px)';
  defocus.drawImage(image, 0, 0);
  defocus.filter = 'none';

  const mask = createBuffer(width, height);
  ellipseGlow(mask, 1450, 192, 1250, 251, '#ffffffb0');
  ellipseGlow(mask, 183, 840, 486, 176, '#ffffff70');
  ellipseGlow(mask, 2405, 852, 490, 178, '#ffffff70');
  defocus.globalCompositeOperation = 'destination-in';
  defocus.drawImage(mask.canvas, 0, 0);
  out.drawImage(defocus.canvas, 0, 0);
  return out.canvas;
}

function ellipseGlow(ctx, x, y, radiusX, radiusY, color) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(1, radiusY / radiusX);
  const gradient = ctx.createRadialGradient(0, 0, 0, 0, 0, radiusX);
  gradient.addColorStop(0, color);
  gradient.addColorStop(1, 'transparent');
  ctx.fillStyle = gradient;
  ctx.fillRect(-radiusX, -radiusX, radiusX * 2, radiusX * 2);
  ctx.restore();
}

export function createAtmosphere() {
  let frame;
  let terrain;
  const nearReeds = new Image();
  const material = new Image();
  nearReeds.src = reedsUrl;
  material.src = materialUrl;
  let reeds = [];
  let reedTick = -1;
  const art = new Image();
  art.src = panoramaUrl;
  art.decode().then(() => {
    reeds = reedZones.map((zone) => createReeds(art, zone));
    frame = focusBackground(art);
    material.decode().then(() => { terrain = createTerrain(frame, material); }).catch(() => {});
  }).catch(() => { /* Keep the CSS fallback when artwork cannot be loaded. */ });

  function drawWater(ctx, camera, time) {
    ctx.save();
    ctx.clip(banks);
    const left = Math.max(3, camera - 3);
    const right = Math.min(width - 3, camera + viewportWidth + 3);
    const band = 6;
    const shine = 0.6 + Math.sin(time * 0.9) * 0.14;
    for (let y = 541; y < cameraTop + viewportHeight; y += band) {
      const ripple = Math.sin(y * 0.12 + time * 2.80) + Math.sin(y * 0.047 - time * 2.07) * 0.61;
      ctx.drawImage(art, left, y, right - left, band, left + ripple * 1.7, y, right - left, band);
    }
    ctx.globalCompositeOperation = 'screen';
    for (let i = 0; i < 72; i++) {
      const x = 258 + (i * 197) % 1990;
      if (x + 42 < camera || x > camera + viewportWidth) continue;
      const y = 573 + (i * 21) % 245;
      const phase = time * (0.51 + i % 4 * 0.11) + i * 2.399;
      ctx.globalAlpha = Math.max(0, Math.sin(phase)) * 0.36 * shine;
      ctx.fillStyle = x > 1220 && x < 1415 ? '#ffd087' : '#82ced4';
      ctx.fillRect(Math.round(x + Math.sin(phase) * 9), y, 5 + (i % 6) * 3, 1.1);
    }
    ctx.restore();
  }

  function drawReeds(ctx, camera, time) {
    const tick = Math.floor(time * 24);
    for (const reed of reeds) {
      const { x, y, w, h, phase, buffer, mask } = reed;
      if (tick !== reedTick) {
        buffer.clearRect(0, 0, w, h);
        const gust = Math.sin(time * 1.9 + phase) + Math.sin(time * 3.1 + phase * 1.7) * 0.36;
        for (let row = 0; row < h; row += 7) {
          const bend = (1 - row / h) ** 1.7;
          const height = Math.min(7, h - row);
          const offset = bend * gust * 5.5;
          buffer.drawImage(art, x, y + row, w, height, offset, row, w, height);
        }
        buffer.globalCompositeOperation = 'destination-in';
        buffer.drawImage(mask, 0, 0);
        buffer.globalCompositeOperation = 'source-over';
      }
      if (x + w >= camera && x <= camera + viewportWidth) ctx.drawImage(buffer.canvas, x, y);
    }
    reedTick = tick;
  }

  function drawLight(ctx, time) {
    ctx.save();
    ctx.globalCompositeOperation = 'screen';
    ctx.globalAlpha = 0.78 + Math.sin(time * 0.72) * 0.11;
    ellipseGlow(ctx, 255, 91, 356, 152, '#ffe4a838');
    ellipseGlow(ctx, 445, 617, 317, 45, '#ffe0a636');
    ellipseGlow(ctx, 2197, 375, 134, 99, '#ffd2775a');
    ellipseGlow(ctx, 2198, 618, 171, 27, '#ffd47e3c');
    ctx.restore();
  }

  return {
    background(ctx, camera, time, animate) {
      if (!frame) return;
      const rendered = terrain?.(ctx, camera, time);
      if (!rendered) ctx.drawImage(frame, camera, cameraTop, viewportWidth, viewportHeight,
        0, 0, viewportWidth, viewportHeight);
      ctx.save();
      ctx.translate(-camera, -cameraTop);
      if (animate) {
        if (!rendered) drawWater(ctx, camera, time);
        drawReeds(ctx, camera, time);
      }
      drawLight(ctx, time);
      ctx.restore();
    },

    foreground(ctx, camera, time) {
      ctx.save();
      ctx.translate(-camera, -cameraTop);
      if (nearReeds.complete && nearReeds.naturalWidth) {
        const pan = camera + viewportWidth / 2 - width / 2;
        for (const [i, [anchor, y, scale]] of [[130, 881, .74], [1100, 880, .56], [2365, 886, .81]].entries()) {
          ctx.save();
          ctx.translate(anchor - pan * .23, y);
          ctx.scale(scale, scale);
          ctx.transform(1, 0, Math.sin(time * 1.22 + i * 1.74) * .043, 1, 0, 0);
          ctx.drawImage(nearReeds, -240, -240, 480, 240);
          ctx.restore();
        }
      }
      for (const p of petals) {
        const age = (time + p.phase) % p.duration;
        const x = p.x + age * 19 + Math.sin(age * 1.36 + p.phase) * 27;
        if (x < camera || x > camera + viewportWidth) continue;
        const y = 45 + age * 41 + Math.sin(age * 0.92 + p.phase) * 18;
        ctx.save();
        ctx.globalAlpha = Math.min(1, age * 0.81, (p.duration - age) * 0.61) * 0.78;
        ctx.translate(x, y);
        ctx.rotate(age * (0.45 + Math.sin(p.phase) * 0.25));
        ctx.scale(1, 0.40 + Math.abs(Math.sin(age * 1.41 + p.phase)) * 0.60);
        ctx.fillStyle = p.tone;
        ctx.fillRect(-p.size, -p.size * 0.46, p.size * 2, p.size * 0.92);
        ctx.restore();
      }
      ctx.restore();
    },
  };
}

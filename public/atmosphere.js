import { width, height } from './world.js';

const water = { x: 1090, y: 292, w: 362, h: 276 };
const shore = new Path2D('M 1100 357 L 1124 321 L 1394 302 L 1439 316 L 1368 407 L 1352 470 L 1319 552 L 1155 504 L 1098 463 Z');
const foliage = [
  { x: 0, y: 0, w: 328, h: 240, pivot: 207, sway: 5, phase: 1, petals: true },
  { x: 290, y: 271, w: 193, h: 203, pivot: 149, sway: 5, phase: 2 },
  { x: 1220, y: 680, w: 316, h: 344, pivot: 319, sway: 5, phase: 0 },
];
const lanterns = [
  { x: 693, y: 328, ground: 472, radius: 84 },
  { x: 845, y: 328, ground: 474, radius: 84 },
  { x: 604, y: 455, ground: 514, radius: 54 },
  { x: 940, y: 455, ground: 514, radius: 54 },
  { x: 301, y: 462, ground: 623, radius: 105 },
  { x: 136, y: 498, ground: 643, radius: 104 },
  { x: 1393, y: 491, ground: 647, radius: 98 },
  { x: 1118, y: 505, ground: 649, radius: 112 },
];
const bursts = Array.from({ length: 31 }, (_, i) => ({
  x: 20 + ((i * 83) % 300),
  phase: i * 2.39996,
  duration: 12 + (i % 8),
  speed: 15 + ((i * 13) % 22),
  size: 2 + ((i * 11) % 7) * 0.60,
  tone: ['#f6b0d3', '#f1d1dc', '#ae79a2', '#fbb5bc'][i % 4],
}));
const fireflies = Array.from({ length: 22 }, (_, i) => ({
  x: i % 2 ? 160 + ((i * 53) % 370) : 998 + ((i * 89) % 375),
  y: 565 + ((i * 61) % 258),
  phase: i * 2.4,
}));

function buffer(w, h) {
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  return canvas.getContext('2d');
}

function image(src) {
  const asset = new Image();
  asset.src = src;
  return asset.decode().then(() => asset);
}

function smooth(a, b, value) {
  const t = Math.min(1, Math.max(0, (value - a) / (b - a)));
  return t * t * (3 - 2 * t);
}

function depthComposite(base, depth) {
  const out = buffer(width, height);
  out.drawImage(base, 0, 0, width, height);
  if (!depth) return out.canvas;

  const source = buffer(depth.width, depth.height);
  source.drawImage(depth, 0, 0);
  const pixels = source.getImageData(0, 0, depth.width, depth.height);
  const mask = buffer(depth.width, depth.height);
  const blurred = buffer(width, height);
  for (const [distanceBlur, opacity] of [
    [3.2, (value) => smooth(165, 235, value) * 0.84],
    [4.6, (value) => (1 - smooth(26, 82, value)) * 0.65],
  ]) {
    for (let i = 0; i < pixels.data.length; i += 4) {
      pixels.data[i + 3] = Math.round(255 * opacity(pixels.data[i]));
    }
    mask.putImageData(pixels, 0, 0);
    blurred.clearRect(0, 0, width, height);
    blurred.save();
    blurred.filter = 'blur(' + distanceBlur + 'px)';
    blurred.drawImage(base, 0, 0, width, height);
    blurred.filter = 'none';
    blurred.globalCompositeOperation = 'destination-in';
    blurred.drawImage(mask.canvas, 0, 0, width, height);
    blurred.restore();
    out.drawImage(blurred.canvas, 0, 0);
  }
  return out.canvas;
}

function reflectionMask(depth) {
  if (!depth) return null;
  const source = buffer(water.w, water.h);
  source.drawImage(depth, water.x * depth.width / width, water.y * depth.height / height,
    water.w * depth.width / width, water.h * depth.height / height, 0, 0, water.w, water.h);
  const pixels = source.getImageData(0, 0, water.w, water.h);
  for (let i = 0; i < pixels.data.length; i += 4) pixels.data[i + 3] = pixels.data[i];
  source.putImageData(pixels, 0, 0);
  return source.canvas;
}

function foliagePatch(entry, base) {
  const colors = buffer(entry.w, entry.h);
  colors.drawImage(base, entry.x, entry.y, entry.w, entry.h, 0, 0, entry.w, entry.h);
  const sample = colors.getImageData(0, 0, entry.w, entry.h).data;
  const mask = buffer(entry.w, entry.h);
  mask.save();
  mask.translate(entry.w * 0.47, entry.h * 0.48);
  mask.scale(entry.w * 0.61, entry.h * 0.60);
  const fade = mask.createRadialGradient(0, 0, 0, 0, 0, 1);
  fade.addColorStop(0, '#fff');
  fade.addColorStop(0.63, '#fff');
  fade.addColorStop(1, 'transparent');
  mask.fillStyle = fade;
  mask.fillRect(-1, -1, 2, 2);
  mask.restore();

  // Limit motion to the painted flowers or leaves so hard roof edges stay still.
  const alpha = mask.getImageData(0, 0, entry.w, entry.h);
  for (let i = 0; i < sample.length; i += 4) {
    const red = sample[i];
    const green = sample[i + 1];
    const blue = sample[i + 2];
    const tint = entry.petals
      ? Math.min(red - green, blue - green)
      : Math.min(green - red * 0.92, green * 1.14 - blue);
    alpha.data[i + 3] = Math.round(alpha.data[i + 3] * smooth(0, 12, tint));
  }
  mask.putImageData(alpha, 0, 0);
  return { ...entry, patch: buffer(entry.w, entry.h), mask: mask.canvas };
}

function pool(color, middle = 'transparent') {
  const canvas = buffer(128, 128);
  const gradient = canvas.createRadialGradient(64, 64, 0, 64, 64, 64);
  gradient.addColorStop(0, color);
  gradient.addColorStop(0.45, middle);
  gradient.addColorStop(1, 'transparent');
  canvas.fillStyle = gradient;
  canvas.fillRect(0, 0, 128, 128);
  return canvas.canvas;
}

function shaft() {
  const ctx = buffer(132, 168);
  const falloff = ctx.createLinearGradient(0, 0, 0, 168);
  falloff.addColorStop(0, '#fcb66660');
  falloff.addColorStop(0.48, '#f4a6532b');
  falloff.addColorStop(1, '#e4944700');
  ctx.fillStyle = falloff;
  ctx.filter = 'blur(9px)';
  ctx.beginPath();
  ctx.moveTo(61, 5);
  ctx.lineTo(71, 5);
  ctx.lineTo(123, 162);
  ctx.lineTo(9, 162);
  ctx.fill();
  return ctx.canvas;
}

const flame = pool('#ffbd6466', '#ff9c2124');
const lamplight = pool('#ffc47a4d', '#e58c4c28');
const mist = pool('#aac1e644', '#667fb827');
const coolLight = pool('#bbcef537', '#8594e52a');
const lightCone = shaft();

export function createAtmosphere() {
  let frame;
  let mask;
  const ripples = buffer(water.w, water.h);
  let patches = [];
  let surfaceFrame = -1;
  Promise.allSettled([
    image('/assets/ha-nguyet.webp'),
    image('/assets/ha-nguyet-depth.webp'),
    image('/assets/ha-nguyet-water.webp'),
  ]).then(([base, depth, waterDepth]) => {
    if (base.status !== 'fulfilled') return;
    frame = depthComposite(base.value, depth.value);
    mask = reflectionMask(waterDepth.value);
    patches = foliage.map((entry) => foliagePatch(entry, base.value));
  });

  function updateWater(time) {
    const layer = ripples;
    layer.clearRect(0, 0, water.w, water.h);
    const band = 4;
    for (let y = 0; y < water.h; y += band) {
      const phase = y * 0.075 + time * 1.52;
      const offset = Math.sin(phase) * 2.6 + Math.sin(y * 0.037 - time * 1.11) * 1.5;
      layer.drawImage(frame, water.x - 6, water.y + y, water.w + 12, band,
        offset - 6, y, water.w + 12, band);
    }

    // The narrow warm streak follows the house lights, while the open water catches cooler ripples.
    layer.save();
    layer.globalCompositeOperation = 'screen';
    for (let i = 0; i < 60; i++) {
      const y = 8 + ((i * 43) % 254);
      const x = 9 + ((i * 127) % 341);
      const phase = i * 2.4 + time * (0.8 + i % 4 * 0.08);
      const shimmer = 0.10 + 0.10 * Math.sin(phase) ** 2;
      const warm = Math.abs(x - 125) < 33 || Math.abs(x - 260) < 31;
      layer.globalAlpha = shimmer;
      layer.fillStyle = warm ? '#edb885' : '#6ac7df';
      layer.fillRect(x + Math.sin(phase) * 4, y, 4 + (i % 6) * 3, y > 190 ? 1.2 : 0.7);
    }
    layer.restore();
    if (mask) {
      layer.globalCompositeOperation = 'destination-in';
      layer.drawImage(mask, 0, 0);
      layer.globalCompositeOperation = 'source-over';
    }
  }

  function drawSurface(ctx, time) {
    const tick = Math.floor(time * 30);
    if (tick !== surfaceFrame) {
      surfaceFrame = tick;
      updateWater(time);
      updateFoliage(time);
    }

    ctx.save();
    if (!mask) ctx.clip(shore);
    ctx.drawImage(ripples.canvas, water.x, water.y);
    ctx.restore();
    for (const { x, y, patch } of patches) ctx.drawImage(patch.canvas, x, y);
  }

  function updateFoliage(time) {
    for (const { x, y, w, h, pivot, sway, phase, patch, mask: fade } of patches) {
      patch.clearRect(0, 0, w, h);
      const gust = Math.sin(time * 1.66 + phase) * 0.63 + Math.sin(time * 2.83 + phase * 2) * 0.37;
      for (let band = 0; band < h; band += 8) {
        const bend = Math.max(0, (pivot - band) / pivot);
        const offset = sway * (gust + Math.sin(band / 41 + time * 1.9) * 0.36) * bend ** 1.7;
        const bandHeight = Math.min(8, h - band);
        patch.drawImage(frame, x, y + band, w, bandHeight, offset, band, w, bandHeight);
      }
      patch.globalCompositeOperation = 'destination-in';
      patch.drawImage(fade, 0, 0);
      patch.globalCompositeOperation = 'source-over';
    }
  }

  function drawLights(ctx, time) {
    ctx.save();
    ctx.globalCompositeOperation = 'screen';
    ctx.globalAlpha = 0.40;
    ctx.drawImage(coolLight, 855, 4, 699, 256);
    ctx.globalAlpha = 0.50;
    ctx.drawImage(mist, 933 + Math.sin(time * 0.13) * 39, 328, 494, 154);
    ctx.globalAlpha = 0.57;
    ctx.drawImage(mist, 368 + Math.sin(time * 0.17) * 42, 104, 572, 144);
    lanterns.forEach(({ x, y, ground, radius }, i) => {
      const flicker = 0.83 + Math.sin(time * 3.7 + i * 1.8) * 0.085 + Math.sin(time * 10.2 + i * 4) * 0.05;
      ctx.globalAlpha = flicker * 0.64;
      ctx.drawImage(lightCone, x - radius * 0.55, y - 6, radius * 1.1, ground - y + 16);
      ctx.globalAlpha = flicker;
      ctx.drawImage(flame, x - radius * 0.58, y - radius * 0.56, radius * 1.16, radius * 1.12);
      const offset = x > 1000 ? radius * 0.27 : 0;
      ctx.drawImage(lamplight, x - radius - offset, ground - radius * 0.34, radius * 2, radius * 0.64);
    });
    ctx.restore();
  }

  function drawBirds(ctx, time) {
    ctx.save();
    ctx.strokeStyle = '#8a99c9';
    ctx.lineCap = 'round';
    for (let i = 0; i < 5; i++) {
      const t = (time * 79 + 390 - i * 31 + width * 2) % (width + 130) - 65;
      const y = 123 + i * 8 + Math.sin(time * 0.62 + i * 0.48) * 15;
      const wing = Math.sin(time * 9.1 - i * 1.4) * 4;
      ctx.globalAlpha = 0.56 + i * 0.035;
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      ctx.moveTo(t - 6, y - wing);
      ctx.quadraticCurveTo(t - 3, y - 2, t, y + 1);
      ctx.quadraticCurveTo(t + 3, y - 2, t + 7, y - wing);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawButterflies(ctx, time) {
    ctx.save();
    for (let i = 0; i < 4; i++) {
      const side = i < 2 ? 407 : 1024;
      const x = side + Math.sin(time * (0.68 + i * 0.16) + i * 1.7) * (27 + i * 3);
      const y = 503 + i * 13 + Math.cos(time * 1.26 + i * 1.8) * (15 + i);
      const wing = 1.2 + Math.abs(Math.sin(time * 16 + i * 3)) * 3.3;
      ctx.globalAlpha = 0.83;
      ctx.fillStyle = i % 2 ? '#f7c5a0' : '#f5c9e5';
      ctx.fillRect(Math.round(x - wing), Math.round(y - 2), wing, 2);
      ctx.fillRect(Math.round(x + 1), Math.round(y - 2), wing, 2);
      ctx.fillStyle = '#ab73a6';
      ctx.fillRect(Math.round(x - wing * 0.5), Math.round(y), wing * 0.5, 2);
      ctx.fillRect(Math.round(x + 1), Math.round(y), wing * 0.5, 2);
      ctx.fillStyle = '#502e56';
      ctx.fillRect(Math.round(x), Math.round(y - 1), 1, 3);
    }
    ctx.restore();
  }

  return {
    background(ctx, time, animate) {
      if (frame) {
        ctx.drawImage(frame, 0, 0);
        if (animate) drawSurface(ctx, time);
      }
      drawBirds(ctx, time);
      drawLights(ctx, time);
      drawButterflies(ctx, time);
      ctx.save();
      for (const p of fireflies) {
        const x = p.x + Math.sin(time * 0.84 + p.phase) * 21;
        const y = p.y + Math.cos(time * 0.91 + p.phase) * 12;
        ctx.globalAlpha = Math.max(0.05, Math.sin(time * 1.5 + p.phase)) * 0.72;
        ctx.fillStyle = '#ffdcac';
        ctx.fillRect(Math.round(x), Math.round(y), 2, 2);
      }
      ctx.restore();
    },

    foreground(ctx, time, large) {
      ctx.save();
      for (const p of bursts) {
        const age = (time + p.phase) % p.duration;
        const x = p.x + age * p.speed + Math.sin(age * 1.7 + p.phase) * 26;
        const y = 58 + age * (38 + 3 * Math.cos(p.phase)) + 17 * Math.sin(age * 1.28 + p.phase);
        ctx.globalAlpha = smooth(0, 1.5, age) * (1 - smooth(p.duration - 2, p.duration, age)) * 0.78;
        ctx.fillStyle = p.tone;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(time * 0.67 + p.phase);
        ctx.scale(1, 0.32 + Math.abs(Math.cos(age * 1.1 + p.phase)) * 0.68);
        ctx.fillRect(-p.size * 0.82, -p.size * 0.35, p.size * 1.64, p.size * 0.70);
        ctx.fillRect(-p.size * 0.44, -p.size * 0.59, p.size * 0.88, p.size * 1.18);
        ctx.restore();
      }
      if (large) {
        ctx.globalAlpha = 0.14;
        ctx.drawImage(mist, 82 + Math.sin(time * 0.13) * 33, 868, 596, 156);
      }
      ctx.restore();
    },
  };
}

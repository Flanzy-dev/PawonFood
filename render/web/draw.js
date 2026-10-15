// Shared painters for scenes. All coordinates are design units on the stage: 1920×1080 in landscape, 1080×1920 in
// portrait (engine.js picks it from the output size and passes it to scenes as env.stage).

import { color, alpha, display, ui } from './tokens.js';
import { clamp, enter, rng } from './ease.js';

/** Fills the whole canvas, letterbox included, whatever the current stage transform. */
export function fillStage(ctx, fill) {
  ctx.save();
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.fillStyle = fill;
  ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
  ctx.restore();
}

export function rrect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

/** Lines of `str` that fit `maxWidth` in the current ctx.font. "\n" always breaks. */
function wrap(ctx, str, maxWidth) {
  const lines = [];
  for (const para of str.split('\n')) {
    let line = '';
    for (const word of para.split(' ')) {
      const next = line ? `${line} ${word}` : word;
      if (line && ctx.measureText(next).width > maxWidth) {
        lines.push(line);
        line = word;
      } else {
        line = next;
      }
    }
    lines.push(line);
  }
  return lines;
}

/** Wrapped text with its first baseline at `y`. Returns the y one line below the last baseline. */
export function text(ctx, str, x, y, { font, fill = color.ink, align = 'left', maxWidth = Infinity, lineHeight, spacing = 0 } = {}) {
  ctx.save();
  ctx.font = font;
  ctx.fillStyle = fill;
  ctx.textAlign = align;
  ctx.textBaseline = 'alphabetic';
  ctx.letterSpacing = `${spacing}px`;
  const lh = lineHeight ?? parseFloat(font.split(' ')[1]) * 1.25;
  const lines = wrap(ctx, str, maxWidth);
  lines.forEach((line, i) => ctx.fillText(line, x, y + i * lh));
  ctx.restore();
  return y + lines.length * lh;
}

/** Draws `img` to fill the box, cropping the overflow (CSS object-fit: cover). `fx`/`fy` pick the crop focus. */
export function cover(ctx, img, x, y, w, h, fx = 0.5, fy = 0.5) {
  const s = Math.max(w / img.naturalWidth, h / img.naturalHeight);
  const sw = w / s;
  const sh = h / s;
  ctx.drawImage(img, (img.naturalWidth - sw) * fx, (img.naturalHeight - sh) * fy, sw, sh, x, y, w, h);
}

/** Check mark centred on (cx, cy), `size` wide, stroked up to `progress` (0–1) of its length. */
export function checkMark(ctx, cx, cy, size, progress, stroke, lineWidth) {
  if (progress <= 0) return;
  const [a, b, c] = [[-0.42, 0.02], [-0.12, 0.3], [0.44, -0.3]].map(([px, py]) => [cx + px * size, cy + py * size]);
  const l1 = Math.hypot(b[0] - a[0], b[1] - a[1]);
  const l2 = Math.hypot(c[0] - b[0], c[1] - b[1]);
  const d = (l1 + l2) * clamp(progress);
  ctx.save();
  ctx.strokeStyle = stroke;
  ctx.lineWidth = lineWidth;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(...a);
  if (d <= l1) {
    ctx.lineTo(a[0] + (b[0] - a[0]) * (d / l1), a[1] + (b[1] - a[1]) * (d / l1));
  } else {
    const k = (d - l1) / l2;
    ctx.lineTo(...b);
    ctx.lineTo(b[0] + (c[0] - b[0]) * k, b[1] + (c[1] - b[1]) * k);
  }
  ctx.stroke();
  ctx.restore();
}

/** Rounded pill, optionally led by a check. `x` is the left edge unless align is 'center' or 'right'. Returns its width. */
export function pill(ctx, label, x, y, { h = 36, size = 16, weight = 600, fill, ink, stroke, padX = 14, check = false, align = 'left', font = ui } = {}) {
  ctx.save();
  ctx.font = font(size, weight);
  const iconW = check ? size * 1.1 + 6 : 0;
  const w = ctx.measureText(label).width + padX * 2 + iconW;
  const left = align === 'center' ? x - w / 2 : align === 'right' ? x - w : x;
  rrect(ctx, left, y, w, h, h / 2);
  if (fill) {
    ctx.fillStyle = fill;
    ctx.fill();
  }
  if (stroke) {
    ctx.strokeStyle = stroke;
    ctx.lineWidth = 2;
    ctx.stroke();
  }
  if (check) checkMark(ctx, left + padX + size * 0.55, y + h / 2, size * 1.1, 1, ink, size * 0.16);
  ctx.fillStyle = ink;
  ctx.textBaseline = 'middle';
  ctx.fillText(label, left + padX + iconW, y + h / 2 + size * 0.06);
  ctx.restore();
  return w;
}

/** Feed-card "AI ✓" badge. */
export const aiBadge = (ctx, x, y) => pill(ctx, 'AI', x, y, { h: 30, size: 14, weight: 700, fill: color.successTint, ink: color.primary, padX: 10, check: true });

export const PHONE = { w: 430, h: 900, inset: 12, radius: 64 };

/** Phone mockup with its top-left at (x, y). `paintScreen(sx, sy, sw, sh)` paints inside the clipped screen. */
export function phone(ctx, x, y, paintScreen, { statusInk = color.ink } = {}) {
  const { w, h, inset, radius } = PHONE;
  ctx.save();
  ctx.shadowColor = alpha(color.ink, 0.22);
  ctx.shadowBlur = 80;
  ctx.shadowOffsetY = 30;
  rrect(ctx, x, y, w, h, radius);
  ctx.fillStyle = color.ink;
  ctx.fill();
  ctx.restore();

  const sx = x + inset;
  const sy = y + inset;
  const sw = w - inset * 2;
  const sh = h - inset * 2;
  ctx.save();
  rrect(ctx, sx, sy, sw, sh, radius - inset);
  ctx.clip();
  paintScreen(sx, sy, sw, sh);
  text(ctx, '18.45', sx + 36, sy + 40, { font: ui(17, 600), fill: statusInk });
  ctx.strokeStyle = statusInk;
  ctx.fillStyle = statusInk;
  ctx.lineWidth = 1.5;
  rrect(ctx, sx + sw - 66, sy + 27, 30, 15, 4);
  ctx.stroke();
  rrect(ctx, sx + sw - 63, sy + 30, 19, 9, 2);
  ctx.fill();
  ctx.restore();

  rrect(ctx, x + w / 2 - 58, y + inset + 12, 116, 34, 17);
  ctx.fillStyle = color.ink;
  ctx.fill();
}

/** A phone at `scale` that rises 60 units into place while fading in, at the start of its scene. */
export function risingPhone(ctx, t, { x, y, scale = 1 }, paintScreen, options) {
  const e = enter(t, 0);
  ctx.save();
  ctx.globalAlpha = e;
  ctx.translate(0, (1 - e) * 60);
  ctx.translate(x, y);
  ctx.scale(scale, scale);
  phone(ctx, 0, 0, paintScreen, options);
  ctx.restore();
}

/** Price-label map pin whose pointer tip sits on (x, y). */
export function pricePin(ctx, label, x, y, { fill, ink, stroke, scale = 1, opacity = 1 }) {
  if (opacity <= 0) return;
  ctx.save();
  ctx.globalAlpha *= opacity;
  ctx.translate(x, y);
  ctx.scale(scale, scale);
  ctx.font = ui(16, 700);
  const w = ctx.measureText(label).width + 28;
  const h = 36;
  ctx.shadowColor = alpha(color.ink, 0.18);
  ctx.shadowBlur = 12;
  ctx.shadowOffsetY = 4;
  ctx.beginPath();
  ctx.moveTo(-9, -h / 2 - 12);
  ctx.lineTo(0, 0);
  ctx.lineTo(9, -h / 2 - 12);
  ctx.fillStyle = stroke ?? fill;
  ctx.fill();
  ctx.restore();
  ctx.save();
  ctx.globalAlpha *= opacity;
  ctx.translate(x, y);
  ctx.scale(scale, scale);
  pill(ctx, label, 0, -h - 10, { h, size: 16, weight: 700, fill, ink, stroke, padX: 14, align: 'center' });
  ctx.restore();
}

/**
 * The app's map pin: a food photo in a circle `size` wide, with a white rim and a coloured `ring` (green free, terracotta
 * paid), centred on (x, y). No price: the card shows it.
 */
export function photoPin(ctx, image, x, y, { size = 44, ring = color.primary, scale = 1, opacity = 1 }) {
  if (opacity <= 0) return;
  const r = size / 2;
  ctx.save();
  ctx.globalAlpha *= opacity;
  ctx.translate(x, y);
  ctx.scale(scale, scale);
  ctx.save();
  ctx.shadowColor = alpha(color.ink, 0.18);
  ctx.shadowBlur = 6;
  ctx.shadowOffsetY = 2;
  ctx.beginPath();
  ctx.arc(0, 0, r, 0, Math.PI * 2);
  ctx.fillStyle = ring;
  ctx.fill();
  ctx.restore();
  ctx.beginPath();
  ctx.arc(0, 0, r - 2, 0, Math.PI * 2);
  ctx.fillStyle = color.surface;
  ctx.fill();
  ctx.beginPath();
  ctx.arc(0, 0, r - 5, 0, Math.PI * 2);
  ctx.clip();
  cover(ctx, image, -(r - 5), -(r - 5), 2 * (r - 5), 2 * (r - 5));
  ctx.restore();
}

/** The receiver's own location: a green dot with a white ring. */
export function userPin(ctx, x, y, r = 12) {
  ctx.save();
  ctx.shadowColor = alpha(color.ink, 0.25);
  ctx.shadowBlur = 10;
  ctx.beginPath();
  ctx.arc(x, y, r + 5, 0, Math.PI * 2);
  ctx.fillStyle = color.surface;
  ctx.fill();
  ctx.restore();
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fillStyle = color.primary;
  ctx.fill();
}

/** A QR-style code: real finder patterns, seeded data modules (it is a picture, not a scannable code). */
export function qrCode(ctx, x, y, size, seed = 7) {
  const n = 25;
  const m = size / n;
  const next = rng(seed);
  const finder = (i, j) => (i < 8 && j < 8) || (i >= n - 8 && j < 8) || (i < 8 && j >= n - 8);
  ctx.fillStyle = color.ink;
  for (let j = 0; j < n; j++) {
    for (let i = 0; i < n; i++) {
      const on = next() < 0.5;
      if (on && !finder(i, j)) ctx.fillRect(x + i * m, y + j * m, m + 0.5, m + 0.5);
    }
  }
  for (const [fi, fj] of [[0, 0], [n - 7, 0], [0, n - 7]]) {
    const fx = x + fi * m;
    const fy = y + fj * m;
    ctx.fillStyle = color.ink;
    ctx.fillRect(fx, fy, 7 * m, 7 * m);
    ctx.fillStyle = color.surface;
    ctx.fillRect(fx + m, fy + m, 5 * m, 5 * m);
    ctx.fillStyle = color.ink;
    ctx.fillRect(fx + 2 * m, fy + 2 * m, 3 * m, 3 * m);
  }
}

/** The Tungku logo (a Path2D from logo_tungku.svg) centred on (cx, cy), `size` wide, in any token colour. */
export function logoMark(ctx, path, cx, cy, size, fill) {
  // The drawing spans x 96–416, y 104–400 inside the 512 viewBox.
  const s = size / 320;
  ctx.save();
  ctx.translate(cx, cy);
  ctx.scale(s, s);
  ctx.translate(-256, -252);
  ctx.fillStyle = fill;
  ctx.fill(path, 'evenodd');
  ctx.restore();
}

/** Round camera-screen icon button (cameraControl fill). `glyph` paints the icon centred on (0, 0). */
export function roundButton(ctx, cx, cy, r, glyph) {
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.fillStyle = color.cameraControl;
  ctx.fill();
  ctx.save();
  ctx.translate(cx, cy);
  ctx.strokeStyle = color.background;
  ctx.fillStyle = color.background;
  ctx.lineWidth = 2.5;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  glyph(ctx);
  ctx.restore();
}

export function closeGlyph(ctx) {
  ctx.beginPath();
  ctx.moveTo(-8, -8);
  ctx.lineTo(8, 8);
  ctx.moveTo(8, -8);
  ctx.lineTo(-8, 8);
  ctx.stroke();
}

export function flashGlyph(ctx) {
  ctx.beginPath();
  ctx.moveTo(2, -11);
  ctx.lineTo(-7, 2);
  ctx.lineTo(0, 2);
  ctx.lineTo(-2, 11);
  ctx.lineTo(7, -2);
  ctx.lineTo(0, -2);
  ctx.closePath();
  ctx.stroke();
}

/** The feed/map listing card for the shared Sayur Lodeh (app copy and layout, no tier tag). */
export function listingCard(ctx, img, x, y, w, h) {
  ctx.save();
  ctx.shadowColor = alpha(color.ink, 0.16);
  ctx.shadowBlur = 24;
  ctx.shadowOffsetY = 8;
  rrect(ctx, x, y, w, h, 24);
  ctx.fillStyle = color.surface;
  ctx.fill();
  ctx.restore();

  const ix = x + 12;
  const iy = y + 12;
  const iw = 128;
  const ih = h - 24;
  ctx.save();
  rrect(ctx, ix, iy, iw, ih, 16);
  ctx.clip();
  cover(ctx, img.lodeh, ix, iy, iw, ih);
  ctx.restore();
  pill(ctx, 'Sisa 3 porsi', ix + 8, iy + 8, { h: 26, size: 12, weight: 700, fill: color.accent, ink: color.surface, padX: 10 });
  aiBadge(ctx, ix + 8, iy + ih - 38);

  const tx = ix + iw + 16;
  text(ctx, 'Sayur Lodeh', tx, y + 50, { font: display(24, 700), fill: color.ink, spacing: -0.7 });
  text(ctx, 'Bu Kos Wulan', tx, y + 76, { font: ui(15, 500), fill: color.inkMuted });
  text(ctx, 'GRATIS', tx, y + 136, { font: display(30, 800), fill: color.primary, spacing: -0.5 });
  text(ctx, '300 m · ± 4 mnt jalan kaki', tx, y + 164, { font: ui(13, 500), fill: color.inkMuted });
}

/**
 * Draws an illustration to cover the box, framed as close to centre on the image point (fx, fy) as the crop allows, and
 * pushed in by `zoom` around that point so it stays put on screen (a camera push-in). Returns a function mapping image
 * coordinates (0–1) to screen coordinates.
 */
export function photo(ctx, img, x, y, w, h, { zoom = 1, fx = 0.5, fy = 0.5, radius = 0 } = {}) {
  const iw = img.naturalWidth;
  const ih = img.naturalHeight;
  const base = Math.max(w / iw, h / ih);
  const s = base * zoom;
  // Frame the focal point at zoom 1 without uncovering the box; it then lies inside the box, so zooming around it
  // keeps the box covered.
  const fit = (start, size, imgSize, f) => Math.min(start, Math.max(start + size - imgSize * base, start + size / 2 - f * imgSize * base));
  const px = fit(x, w, iw, fx) + fx * iw * base;
  const py = fit(y, h, ih, fy) + fy * ih * base;
  const ox = px - fx * iw * s;
  const oy = py - fy * ih * s;
  ctx.save();
  rrect(ctx, x, y, w, h, radius);
  ctx.clip();
  ctx.drawImage(img, ox, oy, iw * s, ih * s);
  ctx.restore();
  return (u, v) => [ox + u * iw * s, oy + v * ih * s];
}

/** Three soft steam wisps rising from (x, y), `size` tall, in `tint`. Looping on `t`, faded by `opacity`. */
export function steam(ctx, x, y, t, { size = 220, opacity = 1, tint = color.surface } = {}) {
  if (opacity <= 0) return;
  ctx.save();
  ctx.filter = 'blur(5px)';
  ctx.lineCap = 'round';
  for (let i = 0; i < 3; i++) {
    const phase = (t * 0.45 + i / 3) % 1;
    const fade = Math.sin(phase * Math.PI);
    const ox = (i - 1) * size * 0.22;
    ctx.beginPath();
    for (let k = 0; k <= 12; k++) {
      const v = k / 12;
      const yy = y - (phase * 0.35 + v * 0.65) * size;
      const xx = x + ox + Math.sin(v * 5 + t * 1.6 + i * 2) * size * 0.07 * (0.4 + v);
      if (k === 0) ctx.moveTo(xx, yy);
      else ctx.lineTo(xx, yy);
    }
    ctx.strokeStyle = alpha(tint, 0.5 * fade * opacity);
    ctx.lineWidth = size * 0.07;
    ctx.stroke();
  }
  ctx.restore();
}

/**
 * In-phone page push: the outgoing screen drifts 30 % left, the incoming one slides in from the right. `p` comes from a
 * spring, which only approaches 1, so the push counts as done once the incoming screen is within half a pixel.
 */
export function pushScreens(ctx, p, sw, paintFrom, paintTo) {
  if (sw * (1 - p) < 0.5) p = 1;
  if (p < 1) {
    ctx.save();
    ctx.translate(-sw * 0.3 * p, 0);
    paintFrom();
    ctx.restore();
  }
  if (p > 0) {
    ctx.save();
    ctx.translate(sw * (1 - p), 0);
    paintTo();
    ctx.restore();
  }
}

/** Runs `paint` faded in by `p` (0–1) and risen `dy` units from below. Skips the work while invisible. */
export function rise(ctx, p, paint, dy = 24) {
  if (p <= 0) return;
  ctx.save();
  ctx.globalAlpha *= p;
  ctx.translate(0, (1 - p) * dy);
  paint();
  ctx.restore();
}

/**
 * Where a feature scene puts its caption and phone. Landscape: side by side, the phone on `phoneSide`. Portrait: the
 * caption centred on top, the phone centred below it and a little larger.
 */
export function featureLayout(stage, phoneSide) {
  if (stage.portrait) {
    const scale = 1.15;
    return {
      caption: { x: stage.w / 2, y: 170, width: 900, align: 'center' },
      phone: { x: (stage.w - PHONE.w * scale) / 2, y: 700, scale },
    };
  }
  return phoneSide === 'right'
    ? { caption: { x: 200, y: 330, width: 760, align: 'left' }, phone: { x: 1230, y: 90 } }
    : { caption: { x: 880, y: 330, width: 760, align: 'left' }, phone: { x: 300, y: 90 } };
}

/** Feature caption: step pill, big title, body. Each part rises in a beat after the previous one. `x` is the left edge, or the centre when align is 'center'. */
export function caption(ctx, t, { x, y, width, align }, { step, title, body }) {
  const part = (start, paint) => rise(ctx, enter(t, start), paint, 28);
  const titleFont = display(96, 800);
  ctx.save();
  ctx.font = titleFont;
  ctx.letterSpacing = '-2.9px';
  const titleLines = wrap(ctx, title, width).length;
  ctx.restore();
  const titleTop = y + 48 + 44;
  const bodyTop = titleTop + 76 + (titleLines - 1) * 100 + 80;

  part(0.08, () => pill(ctx, step, x, y, { h: 48, size: 22, weight: 600, fill: color.successTint, ink: color.primary, padX: 20, align }));
  part(0.14, () => text(ctx, title, x, titleTop + 76, { font: titleFont, fill: color.ink, maxWidth: width, lineHeight: 100, spacing: -2.9, align }));
  part(0.22, () => text(ctx, body, x, bodyTop, { font: ui(32, 400), fill: color.inkMuted, maxWidth: width - 60, lineHeight: 46, align }));
}

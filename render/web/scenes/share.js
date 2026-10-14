// Scene 2: Bagikan. The camera's AI scan finds the food, draws its box and clears it for the photo.

import { color, alpha, ui, springs } from '../tokens.js';
import { enter, pop } from '../ease.js';
import { caption, checkMark, closeGlyph, cover, featureLayout, fillStage, flashGlyph, pill, rise, risingPhone, roundButton, rrect, text } from '../draw.js';

export default {
  duration: 1.6,
  paint(ctx, t, { img, stage }) {
    const layout = featureLayout(stage, 'right');
    fillStage(ctx, color.background);
    caption(ctx, t, layout.caption, { step: '01  Bagikan', title: 'Bagikan makanan\nberlebih', body: 'Foto asli, dicek AI' });

    risingPhone(ctx, t, layout.phone, (sx, sy, sw, sh) => cameraScreen(ctx, t, img, sx, sy, sw, sh), { statusInk: color.background });
  },
};

/** Camera-screen time at which the AI detection box starts closing on the meal (the ad puts it on a beat). */
export const DETECT_AT = 0.56;

/** The Bagikan camera screen (step 1 of 3) at scene time `t`: AI sweep, detection box, status row. */
export function cameraScreen(ctx, t, img, sx, sy, sw, sh) {
  ctx.fillStyle = color.cameraBg;
  ctx.fillRect(sx, sy, sw, sh);

  roundButton(ctx, sx + 42, sy + 92, 22, closeGlyph);
  roundButton(ctx, sx + sw - 42, sy + 92, 22, flashGlyph);
  text(ctx, 'Langkah 1 dari 3', sx + sw / 2, sy + 98, { font: ui(17, 700), fill: color.background, align: 'center' });

  // Camera preview
  const px = sx + 16;
  const py = sy + 134;
  const pw = sw - 32;
  const ph = 470;
  ctx.save();
  rrect(ctx, px, py, pw, ph, 28);
  ctx.clip();
  cover(ctx, img.lodeh, px, py, pw, ph, 0.5, 0.5);

  // One AI sweep (the app loops it; the video shows a single pass).
  const scanning = t < 0.62;
  const sweep = enter(t, 0.1);
  if (scanning && t > 0.1) {
    const y = py + ph * 0.18 + ph * 0.5 * sweep;
    ctx.save();
    ctx.shadowColor = color.detectBox;
    ctx.shadowBlur = 14;
    rrect(ctx, px + 28, y, pw - 56, 4, 2);
    ctx.fillStyle = color.detectBox;
    ctx.fill();
    ctx.restore();
  }
  const scanPill = 1 - enter(t, DETECT_AT, springs.snap);
  if (scanPill > 0) {
    ctx.save();
    ctx.globalAlpha *= scanPill;
    pill(ctx, 'AI sedang memindai...', px + 16, py + 16, { h: 34, size: 15, weight: 500, fill: color.primaryDark, ink: color.background });
    ctx.restore();
  }

  // Detection box and its label
  const bx = px + pw * 0.1;
  const by = py + ph * 0.24;
  const bw = pw * 0.8;
  const bh = ph * 0.6;
  const draw = enter(t, DETECT_AT);
  if (draw > 0) {
    const perimeter = 2 * (bw + bh);
    ctx.save();
    ctx.setLineDash([perimeter * draw, perimeter]);
    ctx.strokeStyle = color.detectBox;
    ctx.lineWidth = 4;
    rrect(ctx, bx, by, bw, bh, 18);
    ctx.stroke();
    ctx.restore();
  }
  const label = pop(t, 0.72);
  if (label.alpha > 0) {
    ctx.save();
    ctx.globalAlpha *= label.alpha;
    ctx.translate(bx, by - 42);
    ctx.scale(label.scale, label.scale);
    pill(ctx, 'Lauk matang', 0, 0, { h: 34, size: 16, weight: 700, fill: color.detectBox, ink: color.primaryDark });
    ctx.restore();
  }
  pill(ctx, 'Pratinjau kamera', px + 16, py + ph - 50, { h: 34, size: 14, weight: 500, fill: alpha(color.cameraBg, 0.78), ink: color.surfaceSand });
  ctx.restore();

  // Status row under the preview
  const y = py + ph + 30;
  rise(ctx, enter(t, 0.82), () => {
    ctx.beginPath();
    ctx.arc(sx + 42, y + 22, 22, 0, Math.PI * 2);
    ctx.fillStyle = color.successTint;
    ctx.fill();
    checkMark(ctx, sx + 42, y + 22, 22, enter(t, 0.9, springs.snap), color.primary, 3.5);
    text(ctx, 'Makanan terdeteksi, siap difoto', sx + 76, y + 18, { font: ui(18, 700), fill: color.background });
    text(ctx, 'Foto hanya bisa diambil langsung dari kamera, bukan dari galeri.', sx + 76, y + 44, {
      font: ui(14, 400),
      fill: color.cameraText,
      maxWidth: sw - 100,
      lineHeight: 20,
    });
  }, 16);

  // Shutter
  const cx = sx + sw / 2;
  const cy = sy + sh - 96;
  ctx.beginPath();
  ctx.arc(cx, cy, 40, 0, Math.PI * 2);
  ctx.strokeStyle = color.background;
  ctx.lineWidth = 5;
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(cx, cy, 31, 0, Math.PI * 2);
  ctx.fillStyle = color.background;
  ctx.fill();
}

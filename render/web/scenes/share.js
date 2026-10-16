// Scene 2: Bagikan. A plain camera: frame the meal, press the shutter. The AI check runs after the photo, in the background.

import { color, alpha, display, ui, springs } from '../tokens.js';
import { enter } from '../ease.js';
import { caption, closeGlyph, cover, featureLayout, fillStage, flashGlyph, pill, rise, risingPhone, roundButton, rrect, text } from '../draw.js';

export default {
  duration: 1.6,
  paint(ctx, t, { img, stage }) {
    const layout = featureLayout(stage, 'right');
    fillStage(ctx, color.background);
    caption(ctx, t, layout.caption, { step: '01  Bagikan', title: 'Bagikan makanan\nberlebih', body: 'Foto asli, dicek AI' });

    risingPhone(ctx, t, layout.phone, (sx, sy, sw, sh) => cameraScreen(ctx, t, img, sx, sy, sw, sh), { statusInk: color.background });
  },
};

/** Camera-screen time at which the framing settles on the meal (the ad puts it on a beat, just before the shutter). */
export const DETECT_AT = 0.56;

/** The Bagikan camera screen (step 1 of 3) at scene time `t`: a plain viewfinder with a hint and the shutter. */
export function cameraScreen(ctx, t, img, sx, sy, sw, sh) {
  ctx.fillStyle = color.cameraBg;
  ctx.fillRect(sx, sy, sw, sh);

  roundButton(ctx, sx + 42, sy + 92, 22, closeGlyph);
  roundButton(ctx, sx + sw - 42, sy + 92, 22, flashGlyph);
  text(ctx, 'Langkah 1 dari 3', sx + sw / 2, sy + 98, { font: ui(17, 700), fill: color.background, align: 'center' });

  // Camera preview: the framing eases in on the meal and settles on the beat.
  const px = sx + 16;
  const py = sy + 134;
  const pw = sw - 32;
  const ph = 470;
  const zoom = 1 + 0.06 * (1 - enter(t, DETECT_AT, springs.snap));
  ctx.save();
  rrect(ctx, px, py, pw, ph, 28);
  ctx.clip();
  ctx.translate(px + pw / 2, py + ph / 2);
  ctx.scale(zoom, zoom);
  ctx.translate(-(px + pw / 2), -(py + ph / 2));
  cover(ctx, img.lodeh, px, py, pw, ph, 0.5, 0.5);
  ctx.restore();

  ctx.save();
  rrect(ctx, px, py, pw, ph, 28);
  ctx.clip();
  pill(ctx, 'Pratinjau kamera', px + 16, py + ph - 50, { h: 34, size: 14, weight: 500, fill: alpha(color.cameraBg, 0.78), ink: color.surfaceSand });
  ctx.restore();

  // Hint under the preview
  const y = py + ph + 30;
  rise(ctx, enter(t, 0.3), () => {
    text(ctx, 'Arahkan kamera ke makanan', sx + 24, y + 22, { font: display(22, 700), fill: color.background });
    text(ctx, 'Pastikan makanan terlihat jelas dan cahaya cukup.', sx + 24, y + 52, { font: ui(14, 400), fill: color.cameraText, maxWidth: sw - 48 });
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

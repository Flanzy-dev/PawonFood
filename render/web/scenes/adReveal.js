// Ad scene 5 (16–20 s): cream floods out from the success mark into the end card. The logo pops, the wordmark rises,
// the slogan builds line by line on the beat and a terracotta stroke underlines "jangan buang.". A slow push-in keeps the
// card alive, calmly, while the pitch begins, and a little steam rises from the Tungku logo.

import { color, alpha, display, ui, springs } from '../tokens.js';
import { enter, fade, pop } from '../ease.js';
import { drift, struck } from '../spring.js';
import { fillStage, logoMark, rise, steam, text } from '../draw.js';
import { CUES, SCENES } from '../adCues.js';
import rescue, { SUCCESS_AT } from './adRescue.js';

const LENGTH = SCENES.end - SCENES.reveal;
const local = (cue) => cue - SCENES.reveal;
const LOGO = local(CUES.logo);
const TAGLINE = local(CUES.tagline2);
const SLOGAN = local(CUES.slogan);
const ANSWER = local(CUES.answer);
const UNDERLINE = local(CUES.underline);
const SLOGAN_FONT = display(92, 800);

/** The terracotta brush stroke under "jangan buang.", drawn up to `p` (0–1). */
function underline(ctx, cx, baseline, p) {
  if (p <= 0) return;
  ctx.save();
  ctx.font = SLOGAN_FONT;
  ctx.letterSpacing = '-2.8px';
  const full = ctx.measureText('Bagikan, jangan buang.').width;
  const lead = ctx.measureText('Bagikan, ').width;
  const word = ctx.measureText('jangan buang.').width;
  ctx.restore();
  const x0 = cx - full / 2 + lead;
  const x1 = x0 + word * p;
  const y = baseline + 26;
  ctx.save();
  ctx.strokeStyle = color.accent;
  ctx.lineWidth = 9;
  ctx.lineCap = 'round';
  ctx.beginPath();
  for (let i = 0; i <= 24; i++) {
    const x = x0 + (x1 - x0) * (i / 24);
    const u = (x - x0) / word;
    const yy = y + Math.sin(u * Math.PI) * 7 - u * 4;
    if (i === 0) ctx.moveTo(x, yy);
    else ctx.lineTo(x, yy);
  }
  ctx.stroke();
  ctx.restore();
}

export default {
  duration: LENGTH,
  paint(ctx, t, env) {
    const { img, logo, stage } = env;
    const cx = stage.w / 2;

    // The flood takes two beats, so the logo pops while it is still spreading. It aims a little past the farthest
    // corner, so it covers the frame before its spring settles.
    const [fx, fy] = SUCCESS_AT;
    const reach = Math.hypot(Math.max(fx, stage.w - fx), Math.max(fy, stage.h - fy));
    const radius = 62 + (reach + 40 - 62) * struck(t, 0, springs.glide, 0.3);
    if (radius < reach) {
      rescue.paint(ctx, rescue.duration + t, env);
      ctx.beginPath();
      ctx.arc(fx, fy, radius, 0, Math.PI * 2);
      ctx.fillStyle = color.background;
      ctx.fill();
    } else {
      fillStage(ctx, color.background);
    }

    // A slow push-in across the whole end card on the heavy dolly, still drifting when the pitch takes over. The lines
    // below land on two-beat springs, so each is still settling as the next arrives.
    const settle = 1 + drift(t, 0, springs.dolly, 0.05, LENGTH);
    ctx.save();
    ctx.translate(cx, stage.h / 2);
    ctx.scale(settle, settle);
    ctx.translate(-cx, -stage.h / 2);

    const mark = pop(t, LOGO);
    if (mark.alpha > 0) {
      ctx.save();
      ctx.globalAlpha *= mark.alpha;
      logoMark(ctx, logo, cx, 600, 220 * mark.scale, color.primary);
      ctx.restore();
      // The Tungku is a stove: once it has landed, a little steam keeps rising from it while the card holds.
      steam(ctx, cx, 486, SCENES.reveal + t, { size: 170, opacity: 0.45 * fade(t, LOGO + 0.5, springs.glide), tint: color.primary });
    }
    const ww = 860;
    const wh = (ww * img.wordmark.naturalHeight) / img.wordmark.naturalWidth;
    rise(ctx, enter(t, LOGO + 0.25, springs.glide), () => ctx.drawImage(img.wordmark, cx - ww / 2, 700, ww, wh), 28);

    rise(ctx, enter(t, TAGLINE, springs.glide), () => text(ctx, 'Dari dapur ke komunitas.', cx, 1090, { font: display(66, 700), fill: color.ink, align: 'center', spacing: -2 }));
    rise(ctx, enter(t, SLOGAN, springs.glide), () => text(ctx, 'Masak kebanyakan?', cx, 1232, { font: SLOGAN_FONT, fill: color.ink, align: 'center', spacing: -2.8 }));
    rise(ctx, enter(t, ANSWER, springs.glide), () => text(ctx, 'Bagikan, jangan buang.', cx, 1340, { font: SLOGAN_FONT, fill: color.primary, align: 'center', spacing: -2.8 }));
    underline(ctx, cx, 1340, struck(t, UNDERLINE, springs.ui));

    rise(ctx, enter(t, UNDERLINE, springs.glide), () => {
      text(ctx, 'Ilustrasi produk · prototipe', cx, 1532, { font: ui(20, 500), fill: color.inkMuted, align: 'center' });
      text(ctx, 'Foto sayur lodeh: Midori, CC BY 3.0, via Wikimedia Commons', cx, 1566, { font: ui(17, 400), fill: alpha(color.inkMuted, 0.8), align: 'center' });
    }, 12);
    ctx.restore();
  },
};

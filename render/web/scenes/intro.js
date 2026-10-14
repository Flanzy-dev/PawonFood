// Scene 1: brand reveal. Logo pops, wordmark rises, then the slogan and the official tagline.

import { color, display, ui } from '../tokens.js';
import { enter, pop } from '../ease.js';
import { fillStage, logoMark, rise, text } from '../draw.js';

export default {
  duration: 1.6,
  paint(ctx, t, { img, logo, stage }) {
    fillStage(ctx, color.background);
    // The stack is laid out for a 1080-tall stage and centred vertically on taller (portrait) ones.
    const cx = stage.w / 2;
    const dy = (stage.h - 1080) / 2;

    const mark = pop(t, 0.04);
    ctx.save();
    ctx.globalAlpha = mark.alpha;
    logoMark(ctx, logo, cx, 290 + dy, 200 * mark.scale, color.primary);
    ctx.restore();

    const ww = 900;
    const wh = (ww * img.wordmark.naturalHeight) / img.wordmark.naturalWidth;
    rise(ctx, enter(t, 0.24), () => ctx.drawImage(img.wordmark, cx - ww / 2, 380 + dy, ww, wh), 28);
    rise(ctx, enter(t, 0.46), () => text(ctx, 'Dari dapur ke komunitas.', cx, 790 + dy, { font: display(68, 700), fill: color.ink, align: 'center', spacing: -2 }));
    rise(ctx, enter(t, 0.64), () =>
      text(ctx, 'HYPERLOCAL COMMUNITY FOOD RESCUE PLATFORM', cx, stage.h - 90, { font: ui(20, 600), fill: color.inkMuted, align: 'center', spacing: 4 }),
    );
  },
};

// Scene 5: end card on primaryDark. Logo, slogan, the share CTA and the photo credit.

import { color, alpha, display, ui } from '../tokens.js';
import { enter, pop } from '../ease.js';
import { fillStage, logoMark, pill, rise, text } from '../draw.js';

// The slogan is two lines in landscape; portrait is too narrow at this size, so each half breaks again.
const SLOGAN = {
  landscape: [['Masak kebanyakan?'], ['Bagikan, jangan buang.']],
  portrait: [['Masak', 'kebanyakan?'], ['Bagikan,', 'jangan buang.']],
};
const LINE = 114;

export default {
  duration: 1.6,
  paint(ctx, t, { logo, stage }) {
    fillStage(ctx, color.primaryDark);
    const cx = stage.w / 2;
    const [question, answer] = SLOGAN[stage.portrait ? 'portrait' : 'landscape'];
    const logoY = stage.portrait ? 640 : 320;
    const first = logoY + 220;
    const answerTop = first + question.length * LINE;
    const ctaTop = answerTop + (answer.length - 1) * LINE + 76;

    const mark = pop(t, 0.04);
    ctx.save();
    ctx.globalAlpha = mark.alpha;
    logoMark(ctx, logo, cx, logoY, 150 * mark.scale, color.background);
    ctx.restore();

    const slogan = (lines, top, fill) => text(ctx, lines.join('\n'), cx, top, { font: display(104, 800), fill, align: 'center', spacing: -3.1, lineHeight: LINE });
    rise(ctx, enter(t, 0.12), () => slogan(question, first, color.background));
    rise(ctx, enter(t, 0.2), () => slogan(answer, answerTop, color.detectBox));
    rise(ctx, enter(t, 0.32), () =>
      pill(ctx, 'Bagikan sekarang', cx, ctaTop, { h: 80, size: 30, weight: 700, fill: color.background, ink: color.primaryDark, align: 'center', padX: 44 }),
    );
    rise(ctx, enter(t, 0.44), () => {
      text(ctx, 'Foto sayur lodeh: Midori, CC BY 3.0, via Wikimedia Commons', 80, stage.h - 50, { font: ui(16, 400), fill: alpha(color.background, 0.55) });
      text(ctx, 'Pogung, Sleman', stage.w - 80, stage.h - 50, { font: ui(18, 600), fill: color.onGreenMuted, align: 'right' });
    });
  },
};

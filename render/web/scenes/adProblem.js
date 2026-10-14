// Ad scene 1 (0–4 s): a freshly cooked, edible surplus meal waits on a kos kitchen counter while the afternoon light
// turns to dusk and its steam thins out: nobody has come for it yet.

import { color, alpha, display, springs } from '../tokens.js';
import { enter } from '../ease.js';
import { drift, springAt, struck } from '../spring.js';
import { fillStage, photo, rise, rrect, steam, text } from '../draw.js';
import { CUES, SCENES } from '../adCues.js';

const LENGTH = SCENES.opportunity - SCENES.problem;
// The food container in kitchen.png, normalised: its centre and the top of its lid.
const CONTAINER = { x: 0.62, y: 0.83, lid: 0.76 };

/**
 * The kitchen shot at ad time `at`, drawn into a box: the push-in, the dusk and the steam. The next scene keeps calling
 * it with its own time, so the camera's momentum and the fading light carry on through the match cut. Returns the
 * image-to-screen mapping.
 */
export function kitchenShot(ctx, img, x, y, w, h, at, { radius = 0 } = {}) {
  // A heavy dolly: 12 % closer by the cut, and still creeping in after it.
  const zoom = 1 + drift(at, SCENES.problem, springs.camera, 0.12, LENGTH);
  const map = photo(ctx, img.kitchen, x, y, w, h, { zoom, fx: CONTAINER.x, fy: CONTAINER.y, radius });

  // The light sinks slowly from the dusk cue on; it is about halfway at the cut and keeps going.
  const dusk = springAt(at, CUES.dusk, springs.camera);
  ctx.save();
  rrect(ctx, x, y, w, h, radius);
  ctx.clip();
  ctx.globalCompositeOperation = 'multiply';
  ctx.fillStyle = alpha(color.ink, 0.32 * dusk);
  ctx.fillRect(x, y, w, h);
  ctx.globalCompositeOperation = 'source-over';
  const vignette = ctx.createRadialGradient(x + w / 2, y + h * 0.6, h * 0.25, x + w / 2, y + h * 0.6, h * 0.75);
  vignette.addColorStop(0, alpha(color.ink, 0));
  vignette.addColorStop(1, alpha(color.ink, 0.12 + 0.2 * dusk));
  ctx.fillStyle = vignette;
  ctx.fillRect(x, y, w, h);
  ctx.restore();

  const [lx, ly] = map(CONTAINER.x, CONTAINER.lid);
  steam(ctx, lx, ly, at, { size: 0.26 * w, opacity: 1 - 0.9 * dusk });
  return map;
}

/** The cream fade over the top of the frame that keeps the line readable over the wall, at `strength` (0–1). */
export function creamWash(ctx, stage, strength) {
  if (strength <= 0) return;
  const wash = ctx.createLinearGradient(0, 0, 0, 760);
  wash.addColorStop(0, alpha(color.background, 0.85 * strength));
  wash.addColorStop(1, alpha(color.background, 0));
  ctx.fillStyle = wash;
  ctx.fillRect(0, 0, stage.w, 760);
}

export default {
  duration: LENGTH,
  paint(ctx, t, { img, stage }) {
    fillStage(ctx, color.background);
    kitchenShot(ctx, img, 0, 0, stage.w, stage.h, t);
    creamWash(ctx, stage, 1);

    // "Masak kebanyakan?" lands, holds, then lifts away within the last beat before the cut.
    const out = struck(t, CUES.problemOut - SCENES.problem, springs.ui);
    ctx.save();
    ctx.globalAlpha *= 1 - out;
    ctx.translate(0, -40 * out);
    const font = display(132, 800);
    const at = CUES.problemText - SCENES.problem;
    rise(ctx, enter(t, at), () => text(ctx, 'Masak', stage.w / 2, 430, { font, fill: color.ink, align: 'center', spacing: -4 }), 36);
    rise(ctx, enter(t, at + 0.12), () => text(ctx, 'kebanyakan?', stage.w / 2, 568, { font, fill: color.ink, align: 'center', spacing: -4 }), 36);
    ctx.restore();
  },
};

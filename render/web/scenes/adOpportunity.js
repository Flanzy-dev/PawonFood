// Ad scene 2 (4–7 s): match cut from the kitchen to a split frame. The surplus meal sits in the top panel, a student in a
// nearby kos room in the bottom one, and a walking route draws itself from the food to the student.

import { color, alpha, display, springs } from '../tokens.js';
import { enter, fade, lerp, pop } from '../ease.js';
import { drift, springAt, struck } from '../spring.js';
import { fillStage, photo, pill, rise, rrect, text } from '../draw.js';
import { CUES, SCENES } from '../adCues.js';
import { creamWash, kitchenShot } from './adProblem.js';

const LENGTH = SCENES.connect - SCENES.opportunity;
const ROOM = 0.25; // the room panel follows the cut by an eighth
const TEXT = 0.5;
const ROUTE = CUES.route - SCENES.opportunity;
const TAG = CUES.routeTag - SCENES.opportunity;
const ARRIVE = CUES.arrive - SCENES.opportunity;
const TOP = { x: 60, y: 110, w: 960, h: 660, r: 44 };
const BOTTOM = { x: 60, y: 1140, w: 960, h: 700, r: 44 };
// The student's phone in room.png, normalised: where the route ends.
const STUDENT_PHONE = { x: 0.38, y: 0.61 };
// What the room panel frames on: between her face and her phone, so her head keeps some room above it.
const STUDENT_FRAME = { x: 0.5, y: 0.56 };

function panelShadow(ctx, { x, y, w, h, r }) {
  ctx.save();
  ctx.shadowColor = alpha(color.ink, 0.2);
  ctx.shadowBlur = 50;
  ctx.shadowOffsetY = 18;
  rrect(ctx, x, y, w, h, r);
  ctx.fillStyle = color.background;
  ctx.fill();
  ctx.restore();
}

/** Points along a cubic Bézier, with the running length at each point. */
function bezier(a, c1, c2, b, n = 120) {
  const pts = [];
  let len = 0;
  for (let i = 0; i <= n; i++) {
    const u = i / n;
    const v = 1 - u;
    const x = v ** 3 * a[0] + 3 * v * v * u * c1[0] + 3 * v * u * u * c2[0] + u ** 3 * b[0];
    const y = v ** 3 * a[1] + 3 * v * v * u * c1[1] + 3 * v * u * u * c2[1] + u ** 3 * b[1];
    if (i) len += Math.hypot(x - pts[i - 1].x, y - pts[i - 1].y);
    pts.push({ x, y, len });
  }
  return pts;
}

/** The dotted walking route, revealed up to `p` (0–1), with a small light travelling at its head. */
function route(ctx, pts, p) {
  if (p <= 0) return;
  const total = pts[pts.length - 1].len;
  const head = total * p;
  let next = 0;
  for (const pt of pts) {
    if (pt.len > head) break;
    if (pt.len < next) continue;
    next = pt.len + 22;
    ctx.beginPath();
    ctx.arc(pt.x, pt.y, 7, 0, Math.PI * 2);
    ctx.fillStyle = color.surface;
    ctx.fill();
    ctx.beginPath();
    ctx.arc(pt.x, pt.y, 4.5, 0, Math.PI * 2);
    ctx.fillStyle = color.primary;
    ctx.fill();
  }
  if (p < 1) {
    const at = pts.find((pt) => pt.len >= head) ?? pts[pts.length - 1];
    ctx.save();
    ctx.shadowColor = color.detectBox;
    ctx.shadowBlur = 28;
    ctx.beginPath();
    ctx.arc(at.x, at.y, 13, 0, Math.PI * 2);
    ctx.fillStyle = color.surface;
    ctx.fill();
    ctx.restore();
  }
}

/** One ring spreading out from the student's phone when the route reaches it. */
function arrivalPulse(ctx, x, y, t) {
  const p = struck(t, ARRIVE, springs.glide);
  if (p <= 0 || p >= 0.995) return;
  ctx.beginPath();
  ctx.arc(x, y, 22 + p * 90, 0, Math.PI * 2);
  ctx.strokeStyle = alpha(color.surface, 0.85 * (1 - p));
  ctx.lineWidth = 5;
  ctx.stroke();
}

function endpoint(ctx, x, y, ring, p) {
  if (p <= 0) return;
  ctx.save();
  ctx.globalAlpha *= p;
  ctx.beginPath();
  ctx.arc(x, y, 18, 0, Math.PI * 2);
  ctx.fillStyle = color.surface;
  ctx.fill();
  ctx.lineWidth = 6;
  ctx.strokeStyle = ring;
  ctx.stroke();
  ctx.restore();
}

export default {
  duration: LENGTH,
  paint(ctx, t, { img, stage }) {
    const clock = SCENES.opportunity + t;
    fillStage(ctx, color.background);

    // The full-frame kitchen settles into the top panel, the container still its anchor; the camera keeps its momentum.
    const s = springAt(t, 0, springs.glide);
    const box = { x: lerp(0, TOP.x, s), y: lerp(0, TOP.y, s), w: lerp(stage.w, TOP.w, s), h: lerp(stage.h, TOP.h, s), r: TOP.r * s };
    if (s > 0) panelShadow(ctx, box);
    const kitchen = kitchenShot(ctx, img, box.x, box.y, box.w, box.h, clock, { radius: box.r });
    // Scene 1's cream wash over the top of the frame dissolves instead of vanishing on the cut.
    creamWash(ctx, stage, 1 - fade(t, 0));

    // The student's room rises in as the bottom panel and lands with a little give.
    const up = springAt(t, ROOM, springs.land);
    let student = null;
    if (up > 0) {
      ctx.save();
      ctx.globalAlpha *= fade(t, ROOM);
      ctx.translate(0, (1 - up) * 420);
      panelShadow(ctx, BOTTOM);
      const zoom = 1 + drift(t, ROOM, springs.camera, 0.06, LENGTH - ROOM);
      student = photo(ctx, img.room, BOTTOM.x, BOTTOM.y, BOTTOM.w, BOTTOM.h, { zoom, fx: STUDENT_FRAME.x, fy: STUDENT_FRAME.y, radius: BOTTOM.r });
      ctx.restore();
    }

    const cx = stage.w / 2;
    const font = display(100, 800);
    rise(ctx, enter(t, TEXT), () => text(ctx, 'Jangan biarkan', cx, 905, { font, fill: color.ink, align: 'center', spacing: -3 }), 30);
    rise(ctx, enter(t, TEXT + 0.12), () => text(ctx, 'jadi sia-sia.', cx, 1005, { font, fill: color.ink, align: 'center', spacing: -3 }), 30);

    // The walking route from the food to the student: down the right margin, well clear of the text, then in to her
    // phone from the right at hand height, across her sleeve rather than her face.
    if (student) {
      const a = kitchen(0.62, 0.8);
      const b = student(STUDENT_PHONE.x, STUDENT_PHONE.y);
      const pts = bezier(a, [1010, a[1] + 120], [1010, b[1] + 190], b);
      const origin = pop(t, ROUTE);
      if (origin.alpha > 0) {
        ctx.save();
        ctx.translate(a[0], a[1]);
        ctx.scale(origin.scale, origin.scale);
        endpoint(ctx, 0, 0, color.accent, origin.alpha);
        ctx.restore();
      }
      // The light runs to the student in two beats, slowing as it arrives.
      const head = struck(t, ROUTE, springs.glide);
      route(ctx, pts, head < 0.995 ? head : 1);
      arrivalPulse(ctx, b[0], b[1], t);
      const arrive = pop(t, ARRIVE);
      if (arrive.alpha > 0) {
        ctx.save();
        ctx.translate(b[0], b[1]);
        ctx.scale(arrive.scale, arrive.scale);
        endpoint(ctx, 0, 0, color.primary, arrive.alpha);
        ctx.restore();
      }
      const tag = pop(t, TAG);
      if (tag.alpha > 0) {
        ctx.save();
        ctx.globalAlpha *= tag.alpha;
        ctx.translate(cx, 1076);
        ctx.scale(tag.scale, tag.scale);
        pill(ctx, '300 m · ± 4 mnt jalan kaki', 0, -26, { h: 52, size: 24, weight: 600, fill: color.surface, ink: color.primary, stroke: color.border, align: 'center', padX: 22 });
        ctx.restore();
      }
    }
  },
};

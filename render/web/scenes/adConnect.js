// Ad scene 3 (7–11 s): "Kenalkan, PawonFood." The split frame swells away as a phone is thrown up and lands. The
// provider photographs the meal (framing settles, shutter), the map shows it nearby, and its listing card lifts out of the
// phone.

import { color, alpha, display, ui, springs } from '../tokens.js';
import { clamp, enter, fade, lerp } from '../ease.js';
import { chain, drift, kick, springAt, struck } from '../spring.js';
import { PHONE, fillStage, listingCard, phone, pushScreens, rise, rrect, text } from '../draw.js';
import { CUES, SCENES } from '../adCues.js';
import opportunity from './adOpportunity.js';
import { DETECT_AT, cameraScreen } from './share.js';
import { mapCardRect, mapScreen } from './nearby.js';

const LENGTH = SCENES.rescue - SCENES.connect;
const HEADLINE = CUES.headline - SCENES.connect;
// The camera screen's clock, set so its framing settles on the detect beat.
const CAMERA = CUES.detect - SCENES.connect - DETECT_AT;
const SHUTTER = CUES.shutter - SCENES.connect;
const TO_MAP = CUES.toMap - SCENES.connect;
const TAGLINE = CUES.tagline - SCENES.connect;
const LIFT = CUES.cardOut - SCENES.connect;

/** Where the phone rests on the portrait stage. */
export const PHONE_AT = { cx: 540, cy: 1125, scale: 1.15 };
/** The phone's screen, in phone coordinates. */
export const SCREEN = { x: PHONE.inset, y: PHONE.inset, w: PHONE.w - 2 * PHONE.inset, h: PHONE.h - 2 * PHONE.inset };
/** Map-screen time at the end of this scene (the next scene continues from it). */
export const MAP_END = LENGTH - TO_MAP;

/** Runs `paint` in phone coordinates (top-left 0,0), with the phone offset, rotated or scaled by `pose`. */
export function inPhone(ctx, { dy = 0, rot = 0, scale = 1 } = {}, paint) {
  ctx.save();
  ctx.translate(PHONE_AT.cx, PHONE_AT.cy + dy);
  ctx.rotate(rot);
  ctx.scale(PHONE_AT.scale * scale, PHONE_AT.scale * scale);
  ctx.translate(-PHONE.w / 2, -PHONE.h / 2);
  paint();
  ctx.restore();
}

/** A phone-coordinate point on the stage, for the phone at rest scaled by `k` around its centre. */
export const phoneToStage = (x, y, k = 1) => [PHONE_AT.cx + (x - PHONE.w / 2) * PHONE_AT.scale * k, PHONE_AT.cy + (y - PHONE.h / 2) * PHONE_AT.scale * k];

/** A slow camera push on the phone from its arrival through the rescue (scale at ad time `at`), so it never sits dead still. */
export const dolly = (at) => 1 + drift(at, SCENES.connect, springs.dolly, 0.06, SCENES.reveal - SCENES.connect);

/**
 * How far the listing card is lifted out of the phone at ad time `at`. It floats up on the cardOut beat, overshooting
 * and bobbing like a light card on a spring, and drops back on toChat, keeping its velocity through the retarget.
 */
export const cardLift = (at) =>
  chain(at, springs.float, 0, [
    [CUES.cardOut, 1, springs.float, kick(springs.float, 0.3)],
    [CUES.toChat, 0, springs.ui, -kick(springs.ui)],
  ]).x;

/**
 * The map's listing card, lifted out of the phone by `lift` (0–1), pressed by `press`, outlined by `ring`, with a tap
 * ripple spreading out at `ripple` (0–1). Phone coordinates.
 */
export function floatingCard(ctx, img, lift, { press = 0, ring = 0, ripple = 0, opacity = 1 } = {}) {
  if (opacity <= 0) return;
  const [x, y, w, h] = mapCardRect(SCREEN.x, SCREEN.y, SCREEN.w, SCREEN.h);
  const k = (1 + 0.22 * lift) * (1 - 0.04 * press);
  ctx.save();
  ctx.globalAlpha *= opacity;
  ctx.translate(x + w / 2, y + h / 2 - 210 * lift);
  ctx.scale(k, k);
  ctx.translate(-(x + w / 2), -(y + h / 2));
  if (lift > 0) {
    ctx.save();
    ctx.shadowColor = alpha(color.ink, 0.24 * clamp(lift));
    ctx.shadowBlur = 60;
    ctx.shadowOffsetY = 30;
    rrect(ctx, x, y, w, h, 24);
    ctx.fillStyle = color.surface;
    ctx.fill();
    ctx.restore();
  }
  listingCard(ctx, img, x, y, w, h);
  if (ring > 0) {
    rrect(ctx, x - 7, y - 7, w + 14, h + 14, 31);
    ctx.strokeStyle = alpha(color.primary, ring);
    ctx.lineWidth = 5;
    ctx.stroke();
  }
  if (ripple > 0 && ripple < 0.995) {
    const g = 7 + ripple * 70;
    rrect(ctx, x - g, y - g, w + 2 * g, h + 2 * g, 24 + g);
    ctx.strokeStyle = alpha(color.primary, 0.5 * (1 - ripple));
    ctx.lineWidth = 4;
    ctx.stroke();
  }
  ctx.restore();
}

/** "Kenalkan, PawonFood." and its follow-up line, as they stand at scene time `t`. */
export function headline(ctx, t, stage) {
  const cx = stage.w / 2;
  const font = display(112, 800);
  rise(ctx, enter(t, HEADLINE), () => text(ctx, 'Kenalkan,', cx, 352, { font, fill: color.ink, align: 'center', spacing: -3.4 }), 30);
  rise(ctx, enter(t, HEADLINE + 0.12), () => text(ctx, 'PawonFood.', cx, 468, { font, fill: color.primary, align: 'center', spacing: -3.4 }), 30);
  rise(ctx, enter(t, TAGLINE), () => text(ctx, 'Temukan makanan di sekitarmu.', cx, 546, { font: ui(36, 500), fill: color.inkMuted, align: 'center' }), 20);
}

/** Soft warm light behind the phone and its contact shadow, for depth. */
export function phoneStage(ctx, stage, presence) {
  const glow = ctx.createRadialGradient(PHONE_AT.cx, PHONE_AT.cy, 80, PHONE_AT.cx, PHONE_AT.cy, 760);
  glow.addColorStop(0, alpha(color.surfaceSand, 0.9 * presence));
  glow.addColorStop(1, alpha(color.surfaceSand, 0));
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, stage.w, stage.h);
  ctx.save();
  ctx.filter = 'blur(18px)';
  ctx.beginPath();
  ctx.ellipse(PHONE_AT.cx, PHONE_AT.cy + (PHONE.h / 2) * PHONE_AT.scale + 18, 230, 26, 0, 0, Math.PI * 2);
  ctx.fillStyle = alpha(color.ink, 0.22 * presence);
  ctx.fill();
  ctx.restore();
}

function screen(ctx, t, img, push, sx, sy, sw, sh) {
  pushScreens(
    ctx,
    push,
    sw,
    () => {
      cameraScreen(ctx, t - CAMERA, img, sx, sy, sw, sh);
      const flash = t >= SHUTTER ? 1 - fade(t, SHUTTER) : 0;
      if (flash > 0) {
        ctx.fillStyle = alpha(color.surface, 0.75 * flash);
        ctx.fillRect(sx, sy, sw, sh);
      }
    },
    () => mapScreen(ctx, t - TO_MAP, img, sx, sy, sw, sh, { card: t < LIFT, pins: 'photo' }),
  );
}

export default {
  duration: LENGTH,
  paint(ctx, t, env) {
    const { img, stage } = env;
    fillStage(ctx, color.background);

    // The split frame from the previous scene (still drifting) swells and fades away as the phone arrives.
    const leave = fade(t, 0);
    if (leave < 0.999) {
      ctx.save();
      ctx.globalAlpha *= 1 - leave;
      ctx.translate(stage.w / 2, stage.h / 2);
      ctx.scale(1 + 0.06 * leave, 1 + 0.06 * leave);
      ctx.translate(-stage.w / 2, -stage.h / 2);
      opportunity.paint(ctx, opportunity.duration + t, env);
      ctx.restore();
    }

    // The phone is thrown up on the cut and lands like a heavy object: a slight overshoot and a settling tilt.
    const arrive = springAt(t, 0, springs.land);
    if (arrive <= 0) return;
    phoneStage(ctx, stage, clamp(arrive));
    ctx.save();
    ctx.globalAlpha *= fade(t, 0);
    inPhone(ctx, { dy: (1 - arrive) * 700, rot: -0.07 * (1 - arrive), scale: lerp(0.92, 1, arrive) * dolly(SCENES.connect + t) }, () => {
      const push = struck(t, TO_MAP, springs.ui);
      phone(ctx, 0, 0, (sx, sy, sw, sh) => screen(ctx, t, img, push, sx, sy, sw, sh), { statusInk: push < 0.5 ? color.background : color.ink });
      if (t >= LIFT) floatingCard(ctx, img, cardLift(SCENES.connect + t));
    });
    ctx.restore();

    headline(ctx, t, stage);
  },
};

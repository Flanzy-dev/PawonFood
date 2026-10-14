// Ad scene 4 (11–16 s): "Temukan. Pesan. Ambil." The floating listing card is picked (Temukan), the chat confirms the
// free claim (Pesan), the listing photo match-cuts into the real container being handed over (Ambil), and a small,
// illustrative QR check closes it with a success mark.

import { color, alpha, display, ui, springs } from '../tokens.js';
import { enter, fade, lerp, pop } from '../ease.js';
import { chain, drift, struck } from '../spring.js';
import { checkMark, cover, fillStage, phone, photo, pill, pushScreens, qrCode, rise, rrect, text } from '../draw.js';
import { CUES, SCENES } from '../adCues.js';
import { MAP_END, PHONE_AT, SCREEN, cardLift, dolly, floatingCard, headline, inPhone, phoneStage, phoneToStage } from './adConnect.js';
import { mapScreen } from './nearby.js';

const LENGTH = SCENES.reveal - SCENES.rescue;
const local = (cue) => cue - SCENES.rescue;
const SELECT = local(CUES.select);
const TO_CHAT = local(CUES.toChat);
const RESERVED = local(CUES.reserved);
const CUT = local(CUES.cut);
const HANDOVER = local(CUES.handover);
const QR_SWEEP = local(CUES.qrSweep);
const QR = local(CUES.qr);
const SUCCESS = local(CUES.success);

// The container in handover.png, normalised: the push-in centres on it.
const CONTAINER = { x: 0.535, y: 0.69 };
// The pinned listing thumbnail on the chat screen, in phone coordinates: the match cut opens from it.
const THUMB = { x: SCREEN.x + 28, y: SCREEN.y + 160, size: 68 };
// The match-cut window aims this far past the stage edges, so it covers the frame before its spring settles.
const OVERSHOOT = 80;
const QR_CARD = { x: 440, y: 470, size: 200 };
/** Stage point of the success mark; the end card floods out from here. */
export const SUCCESS_AT = [QR_CARD.x + QR_CARD.size / 2, QR_CARD.y + QR_CARD.size / 2];

const WORDS = ['Temukan.', 'Pesan.', 'Ambil.'];
const LIT = [SELECT, RESERVED, HANDOVER];

/** "Temukan. Pesan. Ambil." in one row: every word waits dimmed, and lights up with a small kick when its action happens. */
function wordRow(ctx, t, stage) {
  const show = enter(t, 0.25);
  if (show <= 0) return;
  ctx.save();
  ctx.font = display(88, 800);
  ctx.letterSpacing = '-2.6px';
  const widths = WORDS.map((w) => ctx.measureText(w).width);
  ctx.restore();
  const gap = 26;
  let x = (stage.w - widths.reduce((a, b) => a + b, 0) - gap * (WORDS.length - 1)) / 2;
  WORDS.forEach((word, i) => {
    const on = enter(t, LIT[i]);
    const font = display(88, 800);
    ctx.save();
    ctx.globalAlpha *= show;
    if (on < 1) text(ctx, word, x, 350, { font, fill: alpha(color.ink, 0.2 * (1 - on)), spacing: -2.6 });
    if (on > 0) {
      const k = lerp(0.9, 1, struck(t, LIT[i], springs.pop, 0.5));
      ctx.translate(x + widths[i] / 2, 350);
      ctx.scale(k, k);
      text(ctx, word, -widths[i] / 2, 0, { font, fill: alpha(color.primary, on), spacing: -2.6 });
    }
    ctx.restore();
    x += widths[i] + gap;
  });
}

function backGlyph(ctx, x, y) {
  ctx.save();
  ctx.strokeStyle = color.ink;
  ctx.lineWidth = 2.5;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(x + 9, y);
  ctx.lineTo(x - 9, y);
  ctx.moveTo(x - 2, y - 7);
  ctx.lineTo(x - 9, y);
  ctx.lineTo(x - 2, y + 7);
  ctx.stroke();
  ctx.restore();
}

function button(ctx, label, x, y, w, primary) {
  rrect(ctx, x, y, w, 50, 16);
  if (primary) {
    ctx.fillStyle = color.primary;
    ctx.fill();
  } else {
    ctx.strokeStyle = color.primary;
    ctx.lineWidth = 1.5;
    ctx.stroke();
  }
  text(ctx, label, x + w / 2, y + 31, { font: ui(16, 700), fill: primary ? color.background : color.primary, align: 'center' });
}

/** The receiver's chat after "Ambil · Gratis" at chat time `tc` (app copy and layout; the header's tier tag is left out). */
function chatScreen(ctx, tc, img, sx, sy, sw, sh) {
  ctx.fillStyle = color.background;
  ctx.fillRect(sx, sy, sw, sh);
  ctx.fillStyle = color.surface;
  ctx.fillRect(sx, sy, sw, 128);
  ctx.fillStyle = color.border;
  ctx.fillRect(sx, sy + 128, sw, 1);
  backGlyph(ctx, sx + 34, sy + 92);
  ctx.beginPath();
  ctx.arc(sx + 84, sy + 92, 24, 0, Math.PI * 2);
  ctx.fillStyle = color.avatarOlive;
  ctx.fill();
  text(ctx, 'BW', sx + 84, sy + 98, { font: ui(17, 700), fill: color.background, align: 'center' });
  text(ctx, 'Bu Kos Wulan', sx + 120, sy + 99, { font: display(18, 700), fill: color.ink });

  // Pinned listing summary
  const cx = sx + 16;
  const cy = sy + 148;
  const cw = sw - 32;
  rrect(ctx, cx, cy, cw, 92, 20);
  ctx.fillStyle = color.surface;
  ctx.fill();
  ctx.strokeStyle = color.border;
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.save();
  rrect(ctx, cx + 12, cy + 12, THUMB.size, THUMB.size, 14);
  ctx.clip();
  cover(ctx, img.lodeh, cx + 12, cy + 12, THUMB.size, THUMB.size);
  ctx.restore();
  text(ctx, 'Sayur Lodeh', cx + 94, cy + 40, { font: display(17, 700), fill: color.ink });
  text(ctx, 'Gratis · sisa 3 porsi · ambil s/d 20.30', cx + 94, cy + 64, { font: ui(12, 400), fill: color.inkMuted });
  text(ctx, 'Hari ini', sx + sw / 2, sy + 274, { font: ui(13, 500), fill: color.inkMuted, align: 'center' });

  // "Saya ambil ya." (own bubble) an eighth before the beat, then the reservation card on it.
  rise(ctx, enter(tc, RESERVED - 0.25 - TO_CHAT), () => {
    ctx.save();
    ctx.font = ui(15, 400);
    const bw = ctx.measureText('Saya ambil ya.').width + 36;
    ctx.restore();
    const bx = sx + sw - 16 - bw;
    rrect(ctx, bx, sy + 296, bw, 46, 20);
    ctx.fillStyle = color.primary;
    ctx.fill();
    text(ctx, 'Saya ambil ya.', bx + 18, sy + 325, { font: ui(15, 400), fill: color.background });
    text(ctx, '18.45', sx + sw - 16, sy + 360, { font: ui(12, 400), fill: color.inkMuted, align: 'right' });
  }, 16);

  rise(ctx, enter(tc, RESERVED - TO_CHAT), () => {
    const x = sx + 16;
    const y = sy + 378;
    const w = sw - 32;
    rrect(ctx, x, y, w, 300, 22);
    ctx.fillStyle = color.successTint;
    ctx.fill();
    ctx.beginPath();
    ctx.arc(x + 34, y + 34, 16, 0, Math.PI * 2);
    ctx.fillStyle = color.primary;
    ctx.fill();
    checkMark(ctx, x + 34, y + 34, 18, 1, color.background, 2.6);
    text(ctx, 'Ambil gratis disetujui', x + 62, y + 41, { font: display(18, 700), fill: color.ink });
    const after = text(ctx, 'Gratis. Pindai QR di HP Bu Kos Wulan saat tiba, sebelum 20.30.', x + 18, y + 82, { font: ui(15, 400), fill: color.ink, maxWidth: w - 36, lineHeight: 22 });
    text(ctx, 'Titik ambil: Kos Wulan, Pogung Lor', x + 18, after + 6, { font: ui(13, 400), fill: color.inkMuted });
    button(ctx, 'Pindai QR', x + 18, y + 176, w - 36, true);
    button(ctx, 'Lihat rute', x + 18, y + 236, w - 36, false);
  }, 16);
}

/** The handover photo with the camera pushing in on the container, and the cream fade that keeps the word row legible. */
function handoverShot(ctx, img, stage, zoom) {
  photo(ctx, img.handover, 0, 0, stage.w, stage.h, { zoom, fx: CONTAINER.x, fy: CONTAINER.y });
  const wash = ctx.createLinearGradient(0, 0, 0, 520);
  wash.addColorStop(0, alpha(color.background, 0.8));
  wash.addColorStop(1, alpha(color.background, 0));
  ctx.fillStyle = wash;
  ctx.fillRect(0, 0, stage.w, 520);
}

/** The small illustrative QR check over the handover: scan sweep, "QR terbaca", then the success mark. */
function qrCheck(ctx, t) {
  const card = pop(t, QR_SWEEP);
  if (card.alpha <= 0) return;
  const { x, y, size } = QR_CARD;
  const [cx, cy] = SUCCESS_AT;
  const done = fade(t, SUCCESS);
  ctx.save();
  ctx.globalAlpha *= card.alpha;
  ctx.translate(cx, cy);
  ctx.scale(card.scale, card.scale);
  ctx.translate(-cx, -cy);
  ctx.save();
  ctx.shadowColor = alpha(color.ink, 0.22);
  ctx.shadowBlur = 40;
  ctx.shadowOffsetY = 14;
  rrect(ctx, x, y, size, size, 28);
  ctx.fillStyle = color.surface;
  ctx.fill();
  ctx.restore();

  if (done < 1) {
    ctx.save();
    ctx.globalAlpha *= 1 - done;
    qrCode(ctx, x + 34, y + 34, size - 68, 11);
    if (t < QR) {
      const sweep = enter(t, QR_SWEEP);
      ctx.shadowColor = color.detectBox;
      ctx.shadowBlur = 12;
      rrect(ctx, x + 22, y + 26 + (size - 52) * sweep, size - 44, 4, 2);
      ctx.fillStyle = color.primary;
      ctx.fill();
    }
    ctx.restore();
  }
  if (done > 0) {
    const mark = pop(t, SUCCESS);
    ctx.save();
    ctx.globalAlpha *= mark.alpha;
    ctx.translate(cx, cy);
    ctx.scale(mark.scale, mark.scale);
    ctx.beginPath();
    ctx.arc(0, 0, 62, 0, Math.PI * 2);
    ctx.fillStyle = color.successTint;
    ctx.fill();
    checkMark(ctx, 0, 0, 62, enter(t, SUCCESS), color.primary, 8);
    ctx.restore();
  }
  ctx.restore();

  const ring = struck(t, SUCCESS, springs.glide);
  if (ring > 0 && ring < 0.995) {
    ctx.beginPath();
    ctx.arc(cx, cy, size * 0.55 + ring * 110, 0, Math.PI * 2);
    ctx.strokeStyle = alpha(color.surface, 0.7 * (1 - ring));
    ctx.lineWidth = 4;
    ctx.stroke();
  }
  const tag = pop(t, QR);
  if (tag.alpha > 0) {
    ctx.save();
    ctx.globalAlpha *= tag.alpha;
    ctx.translate(cx, y + size + 36);
    ctx.scale(tag.scale, tag.scale);
    pill(ctx, 'QR terbaca', 0, -21, { h: 42, size: 18, weight: 600, fill: color.detectBox, ink: color.primaryDark, align: 'center', check: true, padX: 18 });
    ctx.restore();
  }
}

export default {
  duration: LENGTH,
  paint(ctx, t, env) {
    const { img, stage } = env;
    fillStage(ctx, color.background);

    // The camera starts pushing in on the container the moment the window opens, and is still moving at the cut.
    const handZoom = 1 + drift(t, CUT, springs.camera, 0.07, LENGTH - CUT);
    // The match-cut window opens from the listing thumbnail; the handover photo fades up inside it.
    const open = struck(t, CUT, springs.ui, 0.3);
    const shown = fade(t, CUT);
    const push = dolly(SCENES.rescue + t);
    const [px, py] = phoneToStage(THUMB.x + THUMB.size / 2, THUMB.y + THUMB.size / 2, push);
    const k = lerp(1, 2.4, open);
    const r0 = THUMB.size * PHONE_AT.scale * push * k;
    const win = {
      x: lerp(px - r0 / 2, -OVERSHOOT, open),
      y: lerp(py - r0 / 2, -OVERSHOOT, open),
      w: lerp(r0, stage.w + 2 * OVERSHOOT, open),
      h: lerp(r0, stage.h + 2 * OVERSHOOT, open),
    };
    const covered = win.x <= 0 && win.y <= 0 && win.x + win.w >= stage.w && win.y + win.h >= stage.h && shown >= 0.995;

    if (!covered) {
      // The phone at rest: map with the floating card (picked, then dropped back), pushing to the chat.
      ctx.save();
      ctx.translate(px, py);
      ctx.scale(k, k);
      ctx.translate(-px, -py);
      phoneStage(ctx, stage, 1);
      // A press: the card dips on the beat and springs back an eighth later, its velocity carried through.
      const press = chain(t, springs.snap, 0, [[SELECT, 1], [SELECT + 0.125, 0]]).x;
      const ring = enter(t, SELECT) * (1 - fade(t, TO_CHAT));
      inPhone(ctx, { scale: push }, () => {
        phone(ctx, 0, 0, (sx, sy, sw, sh) =>
          pushScreens(
            ctx,
            struck(t, TO_CHAT, springs.ui),
            sw,
            () => mapScreen(ctx, MAP_END + t, img, sx, sy, sw, sh, { card: false }),
            () => chatScreen(ctx, t - TO_CHAT, img, sx, sy, sw, sh),
          ),
        );
        const ripple = struck(t, SELECT, springs.glide);
        floatingCard(ctx, img, cardLift(SCENES.rescue + t), { press, ring, ripple, opacity: 1 - fade(t, TO_CHAT) });
      });
      ctx.restore();

      // Scene 3's headline gives way to the word row.
      const out = struck(t, 0, springs.ui);
      if (out < 0.995) {
        ctx.save();
        ctx.globalAlpha *= 1 - out;
        ctx.translate(0, -30 * out);
        headline(ctx, SCENES.rescue - SCENES.connect + t, stage);
        ctx.restore();
      }

      if (open > 0) {
        ctx.save();
        rrect(ctx, win.x, win.y, win.w, win.h, lerp(14 * PHONE_AT.scale * push * k, 0, open));
        ctx.clip();
        cover(ctx, img.lodeh, win.x, win.y, win.w, win.h);
        ctx.globalAlpha *= shown;
        handoverShot(ctx, img, stage, handZoom);
        ctx.restore();
      }
    } else {
      handoverShot(ctx, img, stage, handZoom);
      qrCheck(ctx, t);
    }

    wordRow(ctx, t, stage);
  },
};

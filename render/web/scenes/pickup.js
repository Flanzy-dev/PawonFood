// Scene 4: Pindai QR. The receiver scans the provider's QR, the check pops and green floods the screen.

import { color, display, ui, springs } from '../tokens.js';
import { enter, pop } from '../ease.js';
import { struck } from '../spring.js';
import { caption, checkMark, closeGlyph, featureLayout, fillStage, pill, qrCode, rise, risingPhone, roundButton, rrect, text } from '../draw.js';

const FOUND = 0.64;

export default {
  duration: 1.6,
  paint(ctx, t, { stage }) {
    const layout = featureLayout(stage, 'right');
    fillStage(ctx, color.background);
    caption(ctx, t, layout.caption, {
      step: '03  Pindai QR',
      title: 'Ambil, pindai,\ndapat poin',
      body: 'Pindai QR saat mengambil. Setiap porsi yang terselamatkan menambah poinmu.',
    });
    risingPhone(ctx, t, layout.phone, (sx, sy, sw, sh) => scanScreen(ctx, t, sx, sy, sw, sh), { statusInk: color.background });
  },
};

function scanScreen(ctx, t, sx, sy, sw, sh) {
  ctx.fillStyle = color.cameraBg;
  ctx.fillRect(sx, sy, sw, sh);
  roundButton(ctx, sx + 42, sy + 92, 22, closeGlyph);
  text(ctx, 'Pindai QR', sx + sw / 2, sy + 100, { font: display(22, 700), fill: color.background, align: 'center' });

  // Viewfinder with the provider's QR
  const vx = sx + 24;
  const vy = sy + 150;
  const vs = sw - 48;
  rrect(ctx, vx, vy, vs, vs, 28);
  ctx.fillStyle = color.cameraControl;
  ctx.fill();
  const qs = 226;
  const qx = vx + (vs - qs) / 2;
  const qy = vy + (vs - qs) / 2;
  rrect(ctx, qx, qy, qs, qs, 18);
  ctx.fillStyle = color.surface;
  ctx.fill();
  qrCode(ctx, qx + 20, qy + 20, qs - 40);
  brackets(ctx, vx + 18, vy + 18, vs - 36);

  const sweep = enter(t, 0.12);
  if (t > 0.12 && t < FOUND) {
    const y = vy + 34 + (vs - 68) * sweep;
    ctx.save();
    ctx.shadowColor = color.detectBox;
    ctx.shadowBlur = 14;
    rrect(ctx, vx + 30, y, vs - 60, 4, 2);
    ctx.fillStyle = color.detectBox;
    ctx.fill();
    ctx.restore();
  }

  const found = t >= FOUND;
  pill(ctx, found ? 'QR terbaca' : 'Arahkan ke QR Bu Kos Wulan', sx + sw / 2, vy + vs + 28, {
    h: 38,
    size: 16,
    weight: 600,
    fill: found ? color.detectBox : color.cameraControl,
    ink: found ? color.primaryDark : color.background,
    align: 'center',
    check: found,
  });
  text(ctx, 'QR hanya berlaku untuk reservasimu dan sampai batas waktu ambil.', sx + sw / 2, vy + vs + 112, {
    font: ui(14, 400),
    fill: color.cameraText,
    align: 'center',
    maxWidth: sw - 80,
    lineHeight: 20,
  });

  // Success: the check pops on the QR, then primary floods out from it on a spring that settles in about 0.5 s (the
  // app's flood takes 520 ms). It aims past the farthest corner so the screen is covered before the spring settles.
  const ccx = vx + vs / 2;
  const ccy = vy + vs / 2;
  const flood = struck(t, FOUND + 0.16, springs.ui);
  if (flood > 0) {
    const reach = Math.hypot(Math.max(ccx - sx, sx + sw - ccx), Math.max(ccy - sy, sy + sh - ccy));
    ctx.beginPath();
    ctx.arc(ccx, ccy, 46 + (reach + 20 - 46) * flood, 0, Math.PI * 2);
    ctx.fillStyle = color.primary;
    ctx.fill();
  }
  const mark = pop(t, FOUND);
  if (mark.alpha > 0) {
    ctx.save();
    ctx.globalAlpha *= mark.alpha;
    ctx.translate(ccx, ccy);
    ctx.scale(mark.scale, mark.scale);
    ctx.beginPath();
    ctx.arc(0, 0, 46, 0, Math.PI * 2);
    ctx.fillStyle = flood > 0.6 ? color.successTint : color.primary;
    ctx.fill();
    checkMark(ctx, 0, 0, 46, enter(t, FOUND + 0.04), flood > 0.6 ? color.primary : color.surface, 6);
    ctx.restore();
  }

  rise(ctx, enter(t, FOUND + 0.42), () => {
    text(ctx, 'QR terbaca', sx + sw / 2, ccy + 112, { font: display(34, 800), fill: color.background, align: 'center', spacing: -1 });
    pill(ctx, '+10 poin', sx + sw / 2, ccy + 140, { h: 44, size: 20, weight: 700, fill: color.primaryDark, ink: color.detectBox, align: 'center', padX: 20 });
  }, 20);
}

function brackets(ctx, x, y, s) {
  const arm = 38;
  ctx.save();
  ctx.strokeStyle = color.detectBox;
  ctx.lineWidth = 5;
  ctx.lineCap = 'round';
  ctx.beginPath();
  for (const [cx, cy, dx, dy] of [[x, y, 1, 1], [x + s, y, -1, 1], [x, y + s, 1, -1], [x + s, y + s, -1, -1]]) {
    ctx.moveTo(cx + dx * arm, cy);
    ctx.lineTo(cx, cy);
    ctx.lineTo(cx, cy + dy * arm);
  }
  ctx.stroke();
  ctx.restore();
}

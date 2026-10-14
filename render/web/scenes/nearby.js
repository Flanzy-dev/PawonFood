// Scene 3: Peta. The 1 km radius around the receiver fills with pins, and the shared lodeh card slides up.

import { color, alpha, display, ui, motion, springs } from '../tokens.js';
import { enter, lerp, pop, rng } from '../ease.js';
import { struck } from '../spring.js';
import { caption, featureLayout, fillStage, listingCard, pricePin, risingPhone, rrect, text, userPin } from '../draw.js';

// Offsets from the user pin. The first one is the lodeh listing on the card.
const PINS = [
  { dx: -96, dy: -96, label: 'Gratis', free: true },
  { dx: 112, dy: -58, label: 'Rp5.000', free: false },
  { dx: -52, dy: 118, label: 'Gratis', free: true },
  { dx: 126, dy: 96, label: 'Gratis', free: true },
];

export default {
  duration: 1.6,
  paint(ctx, t, { img, stage }) {
    const layout = featureLayout(stage, 'left');
    fillStage(ctx, color.background);
    caption(ctx, t, layout.caption, { step: '02  Peta', title: 'Temukan makanan\ndi dekatmu', body: 'Lapar? Masih ada yang hangat di dekatmu.' });

    risingPhone(ctx, t, layout.phone, (sx, sy, sw, sh) => mapScreen(ctx, t, img, sx, sy, sw, sh));
  },
};

/** Where the listing card sits on the map screen. The ad lifts the card out of the phone from exactly here. */
export const mapCardRect = (sx, sy, sw, sh) => [sx + 14, sy + sh - 212, sw - 28, 190];

/** The Peta screen at scene time `t`. `card: false` leaves the listing card out (the ad draws it floating instead). */
export function mapScreen(ctx, t, img, sx, sy, sw, sh, { card = true } = {}) {
  ctx.fillStyle = color.background;
  ctx.fillRect(sx, sy, sw, sh);
  text(ctx, 'Peta', sx + 24, sy + 104, { font: display(30, 800), fill: color.ink, spacing: -0.9 });
  text(ctx, 'Radius 1 km dari Pogung, Sleman', sx + 24, sy + 134, { font: ui(16, 500), fill: color.inkMuted });

  const my = sy + 158;
  const mh = sh - 158;
  ctx.save();
  ctx.beginPath();
  ctx.rect(sx, my, sw, mh);
  ctx.clip();
  paintMap(ctx, sx, my, sw, mh);

  const cx = sx + sw / 2;
  const cy = my + 270;

  const ring = enter(t, 0.04);
  ctx.save();
  ctx.globalAlpha *= ring;
  ctx.beginPath();
  ctx.arc(cx, cy, lerp(120, 172, ring), 0, Math.PI * 2);
  ctx.fillStyle = alpha(color.primary, 0.07);
  ctx.fill();
  ctx.setLineDash([10, 8]);
  ctx.strokeStyle = color.primary;
  ctx.lineWidth = 2.5;
  ctx.stroke();
  ctx.restore();

  // One pulse from the user pin, then still.
  const pulse = struck(t, 0.18, springs.glide);
  if (pulse > 0 && pulse < 0.995) {
    ctx.beginPath();
    ctx.arc(cx, cy, 18 + pulse * 70, 0, Math.PI * 2);
    ctx.strokeStyle = alpha(color.primary, 0.4 * (1 - pulse));
    ctx.lineWidth = 3;
    ctx.stroke();
  }
  userPin(ctx, cx, cy);

  PINS.forEach((p, i) => {
    const pp = pop(t, 0.26 + i * motion.stagger * 2);
    const selected = i === 0 ? enter(t, 0.66) : 0;
    pricePin(ctx, p.label, cx + p.dx, cy + p.dy, {
      fill: p.free ? color.primary : color.surface,
      ink: p.free ? color.surface : color.ink,
      stroke: p.free ? undefined : color.accent,
      scale: pp.scale * lerp(1, 1.14, selected),
      opacity: pp.alpha,
    });
  });
  ctx.restore();

  if (card) foodCard(ctx, t, img, ...mapCardRect(sx, sy, sw, sh));
}

function paintMap(ctx, x, y, w, h) {
  ctx.fillStyle = color.mapSand;
  ctx.fillRect(x, y, w, h);
  const next = rng(3);
  const cell = 84;
  for (let gy = -1; gy < h / cell + 1; gy++) {
    for (let gx = -1; gx < w / cell + 1; gx++) {
      if (next() < 0.12) continue;
      const bw = cell - 22 - next() * 18;
      const bh = cell - 22 - next() * 18;
      rrect(ctx, x + gx * cell + 11 + (gy % 2) * 30, y + gy * cell + 11, bw, bh, 8);
      ctx.fillStyle = next() < 0.12 ? color.mapPark : color.mapBlock;
      ctx.fill();
    }
  }
  ctx.strokeStyle = color.mapRoad;
  ctx.lineCap = 'round';
  ctx.lineWidth = 16;
  ctx.beginPath();
  ctx.moveTo(x + w * 0.66, y - 20);
  ctx.lineTo(x + w * 0.58, y + h + 20);
  ctx.moveTo(x - 20, y + h * 0.58);
  ctx.lineTo(x + w + 20, y + h * 0.5);
  ctx.stroke();
}

function foodCard(ctx, t, img, x, y, w, h) {
  const p = enter(t, 0.54);
  if (p <= 0) return;
  ctx.save();
  ctx.globalAlpha *= p;
  ctx.translate(0, (1 - p) * 120);
  listingCard(ctx, img, x, y, w, h);
  ctx.restore();
}

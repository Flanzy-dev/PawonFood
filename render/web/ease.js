// Timing helpers. Motion comes from closed-form springs (spring.js, presets in tokens.js); duration-and-curve easing is
// not used anywhere in the engine. Everything here is a pure function of time, so any frame can be painted in any order.

import { springs } from './tokens.js';
import { kick, springAt } from './spring.js';

export const clamp = (v, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, v));
export const lerp = (a, b, t) => a + (b - a) * t;

/**
 * An arriving element's 0–1 progress: a spring struck at `start` (critically damped `ui` unless told otherwise), so it
 * moves from the first frame after its beat and settles without overshoot.
 */
export const enter = (t, start, preset = springs.ui) => springAt(t, start, preset, { velocity: kick(preset) });

/** Opacity 0–1 from `start`: an overdamped spring, struck so it shows on the first frame and never overshoots. */
export const fade = (t, start, preset = springs.fade) => clamp(springAt(t, start, preset, { velocity: kick(preset) }));

/** Small things that pop in: scale springs up from 55 % (never from zero) with a real overshoot, opacity fades in. */
export function pop(t, start, preset = springs.pop) {
  return { scale: lerp(0.55, 1, springAt(t, start, preset, { velocity: kick(preset, 0.5) })), alpha: fade(t, start) };
}

/** Seeded PRNG (mulberry32). Scenes use this, never Math.random, so frames are reproducible. */
export function rng(seed) {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let r = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

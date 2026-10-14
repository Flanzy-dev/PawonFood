// Closed-form damped springs. Every animated value in the render engine is the exact solution of a damped harmonic
// oscillator,
//
//   m·x″ + c·x′ + k·(x − to) = 0,
//
// evaluated analytically at time t. Nothing is integrated and nothing is stored between frames, so any frame can be
// painted alone or in any order and still come out identical. The presets live in tokens.js (`springs`).

// Damping ratios this close to 1 use the critical solution (rounded preset values land within it).
const EPS = 1e-4;

/** Natural frequency ω₀ (rad/s) and damping ratio ζ of a { mass, stiffness, damping } preset. */
export function character({ mass = 1, stiffness, damping }) {
  return { w0: Math.sqrt(stiffness / mass), zeta: damping / (2 * Math.sqrt(stiffness * mass)) };
}

/**
 * A spring released at t = 0 from `from` with `velocity` (units/s), pulled toward `to`. Returns a function of the time
 * since release that gives { x, v }. Before release it rests at `from`.
 */
export function spring(preset, { from = 0, to = 1, velocity = 0 } = {}) {
  const { w0, zeta } = character(preset);
  const y0 = from - to;
  const v0 = velocity;
  let solve;
  if (zeta < 1 - EPS) {
    // Underdamped: a decaying oscillation at the damped frequency ω_d.
    const a = zeta * w0;
    const wd = w0 * Math.sqrt(1 - zeta * zeta);
    const b = (v0 + a * y0) / wd;
    solve = (t) => {
      const e = Math.exp(-a * t);
      const c = Math.cos(wd * t);
      const s = Math.sin(wd * t);
      return [e * (y0 * c + b * s), e * ((b * wd - a * y0) * c - (y0 * wd + a * b) * s)];
    };
  } else if (zeta <= 1 + EPS) {
    // Critically damped: the fastest return without overshoot.
    const b = v0 + w0 * y0;
    solve = (t) => {
      const e = Math.exp(-w0 * t);
      return [(y0 + b * t) * e, (v0 - w0 * b * t) * e];
    };
  } else {
    // Overdamped: the sum of a slow and a fast decaying mode.
    const root = w0 * Math.sqrt(zeta * zeta - 1);
    const r1 = -zeta * w0 + root;
    const r2 = -zeta * w0 - root;
    const c2 = (v0 - r1 * y0) / (r2 - r1);
    const c1 = y0 - c2;
    solve = (t) => {
      const e1 = c1 * Math.exp(r1 * t);
      const e2 = c2 * Math.exp(r2 * t);
      return [e1 + e2, r1 * e1 + r2 * e2];
    };
  }
  return (t) => {
    if (t < 0) return { x: from, v: 0 };
    const [y, v] = solve(t);
    return { x: to + y, v };
  };
}

/**
 * Release velocity for a spring struck on a beat: `strength` × ω₀ × `distance`. A struck spring already moves on the
 * first frame after the beat, where one released from rest takes a few frames to get going. Struck at strength 1, a
 * critically damped spring approaches as a pure exponential, without overshoot.
 */
export const kick = (preset, strength = 1, distance = 1) => strength * character(preset).w0 * distance;

/** The value at time `t` of a spring released at `start`, resting at `from` until then. */
export function springAt(t, start, preset, { from = 0, to = 1, velocity = 0 } = {}) {
  return t < start ? from : spring(preset, { from, to, velocity })(t - start).x;
}

/** A 0–1 spring struck on the beat at `start` (see kick). */
export const struck = (t, start, preset, strength = 1) => springAt(t, start, preset, { velocity: kick(preset, strength) });

/**
 * A value moved by a sequence of retargets. `keys` are [start, to, preset?, impulse?], sorted by start. At each key the
 * spring is released toward the new target from its current position *and velocity* (plus an optional impulse), so
 * the motion stays continuous in both (CSS keyframes restart every segment from rest). Returns { x, v } at time `t`.
 */
export function chain(t, preset, from, keys) {
  let state = { x: from, v: 0 };
  let live = null;
  for (const [start, to, own = preset, impulse = 0] of keys) {
    if (t < start) break;
    if (live) state = live.motion(start - live.start);
    live = { start, motion: spring(own, { from: state.x, to, velocity: state.v + impulse }) };
  }
  return live ? live.motion(t - live.start) : state;
}

/**
 * A slow move that has covered `amount` by `reach` seconds after `start` and is still moving then: the spring aims past
 * the mark. For camera push-ins, which must not stop dead before a cut.
 */
export function drift(t, start, preset, amount, reach) {
  return springAt(t, start, preset, { to: amount / spring(preset)(reach).x });
}

/** Seconds until a spring released from rest stays within `eps` (a fraction of the distance) of its target. */
export function settleTime(preset, eps = 0.005) {
  const motion = spring(preset);
  const off = (t) => Math.abs(1 - motion(t).x);
  // Past `hi` the decay envelope (ζω₀ sets its rate) keeps the motion inside eps; walk back to the last excursion.
  const { w0, zeta } = character(preset);
  const rate = zeta < 1 ? zeta * w0 : w0 * (zeta - Math.sqrt(Math.max(0, zeta * zeta - 1)));
  const hi = (Math.log(1 / eps) + 8) / rate;
  const steps = 20000;
  for (let i = steps; i >= 0; i--) {
    const t = (hi * i) / steps;
    if (off(t) > eps) return t + hi / steps;
  }
  return 0;
}

/** A preset with damping ratio `zeta` (unit mass) that settles within 0.5 % in `settle` seconds. */
export function tuned(zeta, settle) {
  // settleTime scales as 1/ω₀, so measure it at ω₀ = 1 and rescale.
  const unit = settleTime({ mass: 1, stiffness: 1, damping: 2 * zeta });
  const w0 = unit / settle;
  return { mass: 1, stiffness: w0 * w0, damping: 2 * zeta * w0 };
}

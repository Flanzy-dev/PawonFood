// Checks that the engine's springs are real damped harmonic oscillators: the closed form satisfies the equation of
// motion, starts where it is released, stays continuous through retargets, and the presets settle when they claim to.
//
//   npm test

import test from 'node:test';
import assert from 'node:assert/strict';
import { chain, character, settleTime, spring, tuned } from '../web/spring.js';
import { springs } from '../web/tokens.js';

const H = 1e-4;

/** Residual of m·x″ + c·x′ + k·(x − to) by central differences, relative to the spring's initial force scale. */
function residual(preset, motion, to, t) {
  const { mass = 1, stiffness, damping } = preset;
  const a = (motion(t + H).x - 2 * motion(t).x + motion(t - H).x) / (H * H);
  const v = (motion(t + H).x - motion(t - H).x) / (2 * H);
  return mass * a + damping * v + stiffness * (motion(t).x - to);
}

for (const zeta of [0.3, 0.6, 1, 1.5]) {
  test(`closed form satisfies m·x″ + c·x′ + k·(x − to) = 0 at ζ = ${zeta}`, () => {
    const preset = tuned(zeta, 0.5);
    assert.ok(Math.abs(character(preset).zeta - zeta) < 1e-9);
    const opts = { from: -40, to: 120, velocity: 300 };
    const motion = spring(preset, opts);
    const scale = preset.stiffness * Math.abs(opts.to - opts.from);
    for (let t = 0.01; t < 1; t += 0.037) {
      assert.ok(Math.abs(residual(preset, motion, opts.to, t)) / scale < 1e-4, `residual too large at t = ${t.toFixed(3)}`);
    }
  });

  test(`analytic velocity matches the derivative of position at ζ = ${zeta}`, () => {
    const motion = spring(tuned(zeta, 0.5), { from: 3, to: -2, velocity: -7 });
    for (let t = 0.01; t < 1; t += 0.05) {
      const numeric = (motion(t + H).x - motion(t - H).x) / (2 * H);
      assert.ok(Math.abs(numeric - motion(t).v) < 1e-4 * (1 + Math.abs(numeric)));
    }
  });

  test(`starts at its release state at ζ = ${zeta}`, () => {
    const motion = spring(tuned(zeta, 0.5), { from: 5, to: 9, velocity: -2 });
    assert.equal(motion(0).x, 5);
    assert.ok(Math.abs(motion(0).v + 2) < 1e-12);
    assert.deepEqual(motion(-1), { x: 5, v: 0 });
  });
}

test('chain hands off position and velocity at every retarget', () => {
  const keys = [[0.2, 1], [0.45, -0.5, springs.snap], [0.9, 0.3]];
  const at = (t) => chain(t, springs.float, 0, keys);
  for (const [start] of keys) {
    const before = at(start - 1e-7);
    const after = at(start);
    assert.ok(Math.abs(before.x - after.x) < 1e-5, `position jumps at ${start}`);
    assert.ok(Math.abs(before.v - after.v) < 1e-3, `velocity jumps at ${start}`);
  }
});

test('every preset settles within 0.5 % by its settle time and not much before', () => {
  for (const [name, preset] of Object.entries(springs)) {
    const settle = settleTime(preset);
    const motion = spring(preset);
    for (let t = settle; t < settle + 3; t += 0.01) assert.ok(Math.abs(1 - motion(t).x) <= 0.005 + 1e-9, `${name} leaves the band at ${t}`);
    assert.ok(Math.abs(1 - motion(settle * 0.9).x) > 0.004 || character(preset).zeta < 1, `${name} settles much earlier than reported`);
  }
});

test('the documented settle times hold', () => {
  const expected = { ui: 0.5, snap: 0.25, pop: 0.5, glide: 1, land: 1, float: 1.25, fade: 0.5 };
  for (const [name, seconds] of Object.entries(expected)) {
    assert.ok(Math.abs(settleTime(springs[name]) - seconds) < 0.01, `${name}: ${settleTime(springs[name])} s`);
  }
});

test('the camera dolly is still moving after a 4 s scene', () => {
  assert.ok(spring(springs.camera)(4).v > 0.05);
});

// Synthesizes the 20 s ad's soundtrack in code, with no samples: kitchen ambience and a ticking clock while the food
// waits, a warm pad and marimba plucks that build toward the handover and resolve on the logo, and sound effects on the
// same 120 BPM cues the scenes animate on (web/adCues.js). The voices are physical models (struck bars, a membrane), and
// every transition whoosh is driven by the velocity of the spring that moves the picture at that cut (web/spring.js),
// so the sound swells and dies exactly as the motion does. Seeded, so every run writes the same 48 kHz stereo 16-bit
// WAV of exactly 20 s, plus an onset list the review checks against the beat grid.
// It is a placeholder score: AD.md explains how to swap in licensed music and record the voice-over.
//
//   node audio/ad-audio.mjs [out.wav]      (default out/ad-audio.wav, relative to render/)

import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { BEAT, BPM, CUES, SCENES } from '../web/adCues.js';
import { rng } from '../web/ease.js';
import { kick, settleTime, spring } from '../web/spring.js';
import { springs } from '../web/tokens.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(here, '..', process.argv[2] ?? 'out/ad-audio.wav');
const EVENTS = OUT.replace(/\.wav$/, '-events.json');
const SR = 48000;
const N = Math.round(SCENES.end * SR);
const TAU = Math.PI * 2;
/** Overall level, tuned so the mix lands near −17 LUFS with headroom for a voice-over. */
const MASTER = 1.6;

const dry = [new Float32Array(N), new Float32Array(N)];
const send = [new Float32Array(N), new Float32Array(N)];
const random = rng(20261013);
const white = () => random() * 2 - 1;
const hz = (midi) => 440 * 2 ** ((midi - 69) / 12);

/** Equal-power pan gains, −1 (left) to 1 (right). */
const panGains = (pan) => [Math.cos(((pan + 1) * Math.PI) / 4), Math.sin(((pan + 1) * Math.PI) / 4)];

/** Every onset, for the beat-grid check. A grace note trails an on-grid onset on purpose (a chime's second note). */
const events = [];
const onset = (t, kind, grace = false) => events.push({ t: Math.round(t * 1e4) / 1e4, kind, ...(grace && { grace }) });

function mix(i, v, [l, r], reverb) {
  if (i < 0 || i >= N) return;
  dry[0][i] += v * l;
  dry[1][i] += v * r;
  if (reverb) {
    send[0][i] += v * l * reverb;
    send[1][i] += v * r * reverb;
  }
}

// ---- Voices ---------------------------------------------------------------------------------------------------------

// Modal models of struck bars, as [frequency ratio, gain, decay time in s] per vibration mode. A free–free bar (a
// glockenspiel or chime) vibrates at 1 : 2.756 : 5.404; a marimba bar is undercut so its modes sit at 1 : 4 : 10.
// Higher modes lose energy faster, as in a real bar.
const BELL = [[1, 1, 0.9], [2.756, 0.35, 0.25], [5.404, 0.12, 0.08]];
const MALLET = [[1, 1, 0.38], [4, 0.22, 0.05], [10, 0.05, 0.012]];

/** A struck bar: its modes ring and decay independently. */
function strike(at, midi, gain, { partials = MALLET, pan = 0, reverb = 0.35, grace = false } = {}) {
  onset(at, partials === BELL ? 'bell' : 'mallet', grace);
  const f = hz(midi);
  const g = panGains(pan);
  const start = Math.round(at * SR);
  const len = Math.min(Math.round(Math.max(...partials.map((p) => p[2])) * 5 * SR), N - start);
  for (let k = 0; k < len; k++) {
    const t = k / SR;
    let v = 0;
    for (const [ratio, amp, decay] of partials) v += amp * Math.sin(TAU * f * ratio * t) * Math.exp(-t / decay);
    mix(start + k, v * gain * Math.min(1, t / 0.002), g, reverb);
  }
}

/** A soft pad note: two detuned sines plus quiet upper partials, smooth attack and release. */
function padNote(from, to, midi, gain, { attack = 0.7, release = 1.0, pan = 0 } = {}) {
  const f = hz(midi);
  const g = panGains(pan);
  const s0 = Math.round(from * SR);
  const s1 = Math.min(N, Math.round((to + release) * SR));
  for (let i = s0; i < s1; i++) {
    const tt = i / SR;
    const rise = Math.min(1, (tt - from) / attack);
    const fall = tt > to ? Math.max(0, 1 - (tt - to) / release) : 1;
    const env = (rise * rise * (3 - 2 * rise)) * (fall * fall * (3 - 2 * fall));
    const v = Math.sin(TAU * f * 0.9977 * tt) + Math.sin(TAU * f * 1.0023 * tt + 0.7) + 0.28 * Math.sin(TAU * 2 * f * tt) + 0.07 * Math.sin(TAU * 3 * f * tt + 1);
    mix(i, v * env * gain * 0.5, g, 0.3);
  }
}

/**
 * The air of a moving object: band-passed noise whose loudness and brightness follow the speed of the spring that moves
 * the picture at `at` (the same preset, released on the same beat). It swells while the motion is fastest and dies as
 * the motion settles; a bobbing spring makes it pulse.
 */
function motionWhoosh(at, preset, { strike = 0, gain = 0.2, low = 300, high = 3000, panFrom = -0.6, panTo = 0.6 } = {}) {
  onset(at, 'whoosh');
  // The same spring as the picture: released from rest, or struck on the beat with `strike` × ω₀.
  const motion = spring(preset, { velocity: kick(preset, strike) });
  const len = Math.round(Math.min(settleTime(preset), 1.5) * SR);
  let peak = 0;
  for (let k = 0; k < len; k += 64) peak = Math.max(peak, Math.abs(motion(k / SR).v));
  const start = Math.round(at * SR);
  let lp = 0;
  let bp = 0;
  for (let k = 0; k < len; k++) {
    const speed = Math.abs(motion(k / SR).v) / peak;
    const fc = low * (high / low) ** speed;
    const F = 2 * Math.sin((Math.PI * fc) / SR);
    const hp = white() - lp - 0.7 * bp;
    bp += F * hp;
    lp += F * bp;
    const attack = Math.min(1, k / (0.005 * SR));
    mix(start + k, bp * speed * speed * gain * attack, panGains(panFrom + (panTo - panFrom) * (k / len)), 0.2);
  }
}

/** A short UI tap: a high blip with a tiny click. */
function tap(at, gain = 0.16) {
  onset(at, 'tap');
  const start = Math.round(at * SR);
  for (let k = 0; k < SR * 0.05; k++) {
    const t = k / SR;
    const v = Math.sin(TAU * 1400 * t) * Math.exp(-t / 0.007) + 0.3 * white() * Math.exp(-t / 0.0015);
    mix(start + k, v * gain, panGains(0), 0.1);
  }
}

/** Camera shutter: two quick clicks over a soft low thump. */
function shutter(at) {
  onset(at, 'shutter');
  for (const [offset, gain] of [[0, 0.22], [0.055, 0.16]]) {
    const start = Math.round((at + offset) * SR);
    let hp = 0;
    let last = 0;
    for (let k = 0; k < SR * 0.04; k++) {
      const t = k / SR;
      const n = white();
      hp = 0.85 * (hp + n - last);
      last = n;
      const v = hp * Math.exp(-t / 0.004) + 0.6 * Math.sin(TAU * 170 * t) * Math.exp(-t / 0.02);
      mix(start + k, v * gain, panGains(0), 0.15);
    }
  }
}

/** A gentle confirmation beep (the illustrative QR read). */
function beep(at, gain = 0.1) {
  onset(at, 'beep');
  const start = Math.round(at * SR);
  const len = Math.round(0.09 * SR);
  for (let k = 0; k < len; k++) {
    const t = k / SR;
    const env = Math.min(1, t / 0.005) * Math.min(1, (0.09 - t) / 0.025);
    mix(start + k, Math.sin(TAU * 1760 * t) * env * gain, panGains(0), 0.25);
  }
}

/** A soft wooden clock tick. */
function tick(at, gain = 0.07) {
  onset(at, 'tick');
  const start = Math.round(at * SR);
  for (let k = 0; k < SR * 0.03; k++) {
    const t = k / SR;
    const v = Math.sin(TAU * 2300 * t) * Math.exp(-t / 0.004) + 0.4 * white() * Math.exp(-t / 0.002);
    mix(start + k, v * gain, panGains(0.35), 0.2);
  }
}

/**
 * A soft kick drum: a damped circular membrane. Its (0,1) and (1,1) modes (1 : 1.594) fall in pitch as the head's tension
 * relaxes after the hit, under a short felt-beater click.
 */
function drum(at, gain) {
  onset(at, 'kick');
  const start = Math.round(at * SR);
  let p0 = 0;
  let p1 = 0;
  let last = 0;
  let hp = 0;
  for (let k = 0; k < SR * 0.35; k++) {
    const t = k / SR;
    const f = 48 + 70 * Math.exp(-t / 0.03);
    p0 += (TAU * f) / SR;
    p1 += (TAU * f * 1.594) / SR;
    const n = white();
    hp = 0.8 * (hp + n - last);
    last = n;
    const v = Math.sin(p0) * Math.exp(-t / 0.16) + 0.3 * Math.sin(p1) * Math.exp(-t / 0.06) + 0.2 * hp * Math.exp(-t / 0.003);
    mix(start + k, v * gain, panGains(0), 0);
  }
}

/** Shaker: a short burst of bright noise. */
function shaker(at, gain, pan) {
  onset(at, 'shaker');
  const start = Math.round(at * SR);
  let last = 0;
  let hp = 0;
  for (let k = 0; k < SR * 0.06; k++) {
    const t = k / SR;
    const n = white();
    hp = 0.9 * (hp + n - last);
    last = n;
    mix(start + k, hp * Math.exp(-t / 0.022) * Math.min(1, t / 0.004) * gain, panGains(pan), 0.1);
  }
}

/** Swelling filtered noise that starts a beat before a cue and blooms into it (the handover's warm lift). */
function bloom(at, gain = 0.05) {
  onset(at - BEAT, 'bloom');
  const start = Math.round((at - BEAT) * SR);
  const len = Math.round(1.4 * SR);
  let lp = 0;
  for (let k = 0; k < len; k++) {
    const t = k / SR - 0.5;
    lp += 0.04 * (white() - lp);
    const env = t < 0 ? (1 + t / 0.5) ** 2 : Math.exp(-t / 0.35);
    mix(start + k, lp * env * gain * 6, panGains(0), 0.6);
  }
}

// ---- Arrangement ----------------------------------------------------------------------------------------------------

// Pad chords, each held until the next. Changes land on cues, so on the beat.
const CHORDS = [
  [0, [50, 57, 62, 64, 66], 0.5], // Dadd9: the food waits
  [CUES.split, [43, 55, 59, 62, 66], 0.6], // Gmaj7: someone nearby
  [CUES.phoneIn, [42, 54, 57, 62, 66, 69], 0.7], // D/F#: PawonFood
  [CUES.toMap, [45, 57, 61, 64, 69], 0.72], // A: it's on the map
  [SCENES.rescue, [47, 54, 59, 62, 66], 0.8], // Bm7: the rescue builds
  [CUES.reserved, [43, 55, 59, 62, 67], 0.85], // G
  [CUES.handover, [50, 57, 62, 66, 69], 0.95], // D: the handover
  [CUES.success, [45, 57, 61, 64, 69, 73], 0.95], // A
  [CUES.reveal, [38, 50, 57, 62, 66, 69, 76], 0.9], // D: resolves on the logo
];
CHORDS.forEach(([at, notes, level], i) => {
  onset(at, 'chord');
  const until = i + 1 < CHORDS.length ? CHORDS[i + 1][0] : SCENES.end;
  notes.forEach((n, k) => padNote(at, until, n, level * 0.055, { attack: i === 0 ? 1.4 : 0.5, pan: (k / (notes.length - 1)) * 0.6 - 0.3 }));
});
const chordAt = (t) => CHORDS.filter(([at]) => at <= t + 1e-6).pop()[1];

// Marimba arpeggio from the split to the reveal: quarter notes, then eighths, then eighths with octave sparkles.
const EIGHTH = BEAT / 2;
const PATTERN = [0, 2, 1, 3, 2, 4, 3, 1];
let step = 0;
for (let t = CUES.split; t < CUES.reveal - 0.05; t += EIGHTH, step++) {
  const sparse = t < CUES.phoneIn;
  if (sparse && step % 2) continue;
  const tones = [...new Set(chordAt(t).map((n) => { let m = n; while (m < 62) m += 12; return m; }))].sort((a, b) => a - b);
  const note = tones[PATTERN[step % PATTERN.length] % tones.length];
  const build = t < SCENES.rescue ? 0.11 : 0.14;
  strike(t, note, (step % 4 === 0 ? 1.25 : 1) * build, { pan: step % 2 ? 0.35 : -0.35 });
  if (t >= SCENES.rescue && step % 4 === 2) strike(t, note + 12, 0.05, { partials: BELL, pan: 0.5 });
}

// Shakers on the off-beat eighths from the shutter, and a soft kick on every beat of the rescue.
for (let t = CUES.shutter, n = 0; t < CUES.reveal - 0.1; t += BEAT, n++) {
  shaker(t + EIGHTH, t < SCENES.rescue ? 0.035 : 0.05, n % 2 ? 0.25 : -0.25);
  if (t >= SCENES.rescue - 0.01) drum(t, 0.32);
}

// Kitchen ambience and a clock: time passes and nobody comes.
{
  let b0 = 0;
  let b1 = 0;
  const end = CUES.split + 0.35;
  for (let i = 0; i < end * SR; i++) {
    const t = i / SR;
    b0 = 0.996 * b0 + 0.05 * white();
    b1 = 0.996 * b1 + 0.05 * white();
    const env = Math.min(1, t / 0.4) * Math.min(1, (end - t) / 0.5);
    dry[0][i] += b0 * 0.05 * env;
    dry[1][i] += b1 * 0.05 * env;
  }
  // The clock ticks on beats 1, 3, 5 and 7: once a second, locked to the grid.
  for (let n = 1; n < 8; n += 2) tick(n * BEAT);
}

// Sound effects on the story beats. Each whoosh rides the spring that moves the picture on that cut.
strike(CUES.problemText, 74, 0.13, { partials: BELL });
strike(CUES.problemText, 81, 0.07, { partials: BELL, pan: 0.3 });
motionWhoosh(CUES.split, springs.glide, { gain: 0.24 });
strike(CUES.routeTag, 81, 0.05, { partials: BELL, pan: -0.2 });
strike(CUES.arrive, 86, 0.06, { partials: BELL, pan: 0.2 });
motionWhoosh(CUES.phoneIn, springs.land, { low: 250, high: 2200, gain: 0.2, panFrom: 0, panTo: 0 });
strike(CUES.detect, 93, 0.035, { partials: BELL, pan: 0.25 });
shutter(CUES.shutter);
motionWhoosh(CUES.toMap, springs.ui, { strike: 1, low: 600, high: 4000, gain: 0.07, panFrom: 0.4, panTo: -0.4 });
strike(CUES.cardOut, 88, 0.09, { partials: BELL });
strike(CUES.cardOut + 0.06, 95, 0.06, { partials: BELL, pan: 0.3, grace: true });
motionWhoosh(CUES.cardOut, springs.float, { strike: 0.3, low: 500, high: 3200, gain: 0.08, panFrom: 0, panTo: 0 });
tap(CUES.select);
motionWhoosh(CUES.toChat, springs.ui, { strike: 1, low: 600, high: 4000, gain: 0.07, panFrom: 0.4, panTo: -0.4 });
strike(CUES.reserved, 81, 0.1, { partials: BELL });
strike(CUES.reserved + 0.09, 86, 0.1, { partials: BELL, pan: 0.2, grace: true });
bloom(CUES.handover);
motionWhoosh(CUES.cut, springs.ui, { strike: 0.3, low: 250, high: 1800, gain: 0.12, panFrom: 0, panTo: 0 });
beep(CUES.qr);
[86, 90, 93].forEach((n, i) => strike(CUES.success + i * 0.05, n, 0.08, { partials: BELL, pan: i * 0.2 - 0.2, grace: i > 0 }));
motionWhoosh(CUES.reveal, springs.glide, { strike: 0.3, low: 400, high: 2600, gain: 0.12, panFrom: 0, panTo: 0 });
[74, 78, 81, 86, 88].forEach((n, i) => strike(CUES.logo + i * 0.045, n, 0.08, { partials: BELL, pan: i * 0.15 - 0.3, grace: i > 0 }));

// ---- Reverb, master, write ------------------------------------------------------------------------------------------

/** A small Schroeder reverb (damped combs into allpasses) on the send bus. */
function reverb(input, combMs, allpassMs) {
  const out = new Float32Array(N);
  const pre = Math.round(0.015 * SR);
  for (const ms of combMs) {
    const len = Math.round((ms / 1000) * SR);
    const buf = new Float32Array(len);
    let idx = 0;
    let store = 0;
    for (let i = 0; i < N; i++) {
      const y = buf[idx];
      store = y * 0.7 + store * 0.3;
      buf[idx] = (i >= pre ? input[i - pre] : 0) + store * 0.82;
      idx = (idx + 1) % len;
      out[i] += y / combMs.length;
    }
  }
  for (const ms of allpassMs) {
    const len = Math.round((ms / 1000) * SR);
    const buf = new Float32Array(len);
    let idx = 0;
    for (let i = 0; i < N; i++) {
      const b = buf[idx];
      const x = out[i];
      buf[idx] = x + b * 0.5;
      out[i] = b - x * 0.5;
      idx = (idx + 1) % len;
    }
  }
  return out;
}
const wet = [reverb(send[0], [29.7, 37.1, 41.1, 43.7], [5.0, 1.7]), reverb(send[1], [30.5, 36.3, 42.4, 44.9], [5.3, 1.9])];

// Fade to near-silence by 19.8 s so the first speaker can come in at 20 s.
const fadeFrom = SCENES.end - 1.4;
const fadeTo = SCENES.end - 0.2;
// 30 Hz high-pass (RBJ biquad) keeps sub-bass rumble off small speakers.
const w0 = (TAU * 30) / SR;
const q = Math.sin(w0) / (2 * Math.SQRT1_2);
const a0 = 1 + q;
const hp = { b0: (1 + Math.cos(w0)) / 2 / a0, b1: -(1 + Math.cos(w0)) / a0, a1: (-2 * Math.cos(w0)) / a0, a2: (1 - q) / a0 };
const z = [[0, 0, 0, 0], [0, 0, 0, 0]];
const pcm = Buffer.alloc(N * 4);
let peak = 0;
for (let i = 0; i < N; i++) {
  const t = i / SR;
  const fade = t < fadeFrom ? 1 : t > fadeTo ? 0 : 0.5 + 0.5 * Math.cos((Math.PI * (t - fadeFrom)) / (fadeTo - fadeFrom));
  const edge = Math.min(1, t / 0.01);
  for (let c = 0; c < 2; c++) {
    const x = dry[c][i] + wet[c][i] * 0.6;
    const [x1, x2, y1, y2] = z[c];
    const y = hp.b0 * x + hp.b1 * x1 + hp.b0 * x2 - hp.a1 * y1 - hp.a2 * y2;
    z[c] = [x, x1, y, y1];
    const v = Math.tanh(y * MASTER) * fade * edge;
    peak = Math.max(peak, Math.abs(v));
    pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), (i * 2 + c) * 2);
  }
}

const header = Buffer.alloc(44);
header.write('RIFF', 0);
header.writeUInt32LE(36 + pcm.length, 4);
header.write('WAVE', 8);
header.write('fmt ', 12);
header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20);
header.writeUInt16LE(2, 22);
header.writeUInt32LE(SR, 24);
header.writeUInt32LE(SR * 4, 28);
header.writeUInt16LE(4, 32);
header.writeUInt16LE(16, 34);
header.write('data', 36);
header.writeUInt32LE(pcm.length, 40);
mkdirSync(path.dirname(OUT), { recursive: true });
writeFileSync(OUT, Buffer.concat([header, pcm]));
events.sort((a, b) => a.t - b.t);
writeFileSync(EVENTS, JSON.stringify({ bpm: BPM, beat: BEAT, events }, null, 1));
console.log(`Wrote ${path.relative(process.cwd(), OUT)}: ${(N / SR).toFixed(3)} s at ${BPM} BPM, peak ${(20 * Math.log10(peak)).toFixed(1)} dBFS, ${events.length} onsets`);

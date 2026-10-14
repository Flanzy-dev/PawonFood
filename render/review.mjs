// Watches a rendered video and reports what a reviewer would catch: banned easing in the source, dead (frozen) frames,
// black frames, single-frame pops, and motion or sound that starts off the beat grid. It also writes contact sheets,
// frame strips around every cut and a spectrogram to out/review/, for looking at the frames themselves.
//
//   node review.mjs                              the ad: out/pawonfood-ad-20s.mp4, scenes and beat grid from web/adCues.js
//   node review.mjs out/pawonfood-promo.mp4 --scenes 0,1.6,3.2,4.8,6.4,8      any video; no beat grid
//
// Exits 1 when a check fails. Needs ffmpeg and ffprobe (FFMPEG_PATH overrides ffmpeg).

import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { BEAT, CUES, SCENES } from './web/adCues.js';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const FFMPEG = process.env.FFMPEG_PATH || 'ffmpeg';
const FFPROBE = process.env.FFMPEG_PATH ? path.join(path.dirname(FFMPEG), `ffprobe${path.extname(FFMPEG)}`) : 'ffprobe';

// Thresholds. YDIF is the mean absolute change in luma (0–255) from the previous frame.
const FREEZE_LIMIT = 0.2; // s: no stretch may be frozen for longer
const LOW_MOTION = 0.02; // YDIF: a frame this still counts as low motion
const ONSET_FLOOR = 0.12; // YDIF: an onset must at least reach this
const ONSET_RATIO = 4; // and be this many times the median of the 5 frames before it
const POP_RATIO = 6; // a pop is a one-frame spike this many times both neighbours
const GRID_TOLERANCE = 1; // frames

// ---- Arguments --------------------------------------------------------------------------------------------------------

const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args.splice(i, 2)[1] : undefined;
};
const sceneArg = flag('--scenes');
const video = path.resolve(ROOT, args[0] ?? 'out/pawonfood-ad-20s.mp4');
const isAd = !sceneArg;
const OUT = path.join(ROOT, 'out', 'review', isAd ? 'ad' : path.basename(video, path.extname(video)));
if (!existsSync(video)) fail(`No video at ${video}. Render it first.`);

function fail(message) {
  console.error(message);
  process.exit(1);
}

function run(cmd, cmdArgs) {
  const r = spawnSync(cmd, cmdArgs, { cwd: ROOT, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 });
  if (r.error) fail(`${cmd}: ${r.error.message}`);
  if (r.status !== 0) fail(`${cmd} ${cmdArgs.join(' ')}\n${r.stderr.slice(-2000)}`);
  return r;
}

// ---- 1. Lint: no duration-and-curve easing anywhere in the engine ------------------------------------------------------

// [pattern, what, applies to files matching]
const BANNED = [
  [/\bease(In|Out|InOut)\w*/, 'easing curve', /\.(m?js|html|css)$/],
  [/cubic-bezier/, 'CSS cubic-bezier', /\.(m?js|html|css)$/],
  [/(^|[;{\s])transition\s*:/, 'CSS transition', /\.(html|css)$/],
  [/@keyframes/, 'CSS keyframes', /\.(html|css)$/],
  [/(^|[;{\s])animation\s*:/, 'CSS animation', /\.(html|css)$/],
];
const lint = [];
const walk = (dir) =>
  readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(dir, e.name)) : /\.(js|mjs|html|css)$/.test(e.name) ? [path.join(dir, e.name)] : []));
for (const file of [...walk(path.join(ROOT, 'web')), path.join(ROOT, 'audio', 'ad-audio.mjs')]) {
  readFileSync(file, 'utf8')
    .split('\n')
    .forEach((line, i) => {
      for (const [re, what, applies] of BANNED) if (applies.test(file) && re.test(line)) lint.push(`${path.relative(ROOT, file)}:${i + 1}  ${what}: ${line.trim().slice(0, 90)}`);
    });
}

// ---- 2. Probe ----------------------------------------------------------------------------------------------------------

const probe = JSON.parse(run(FFPROBE, ['-v', 'error', '-select_streams', 'v:0', '-count_frames', '-show_entries', 'stream=width,height,r_frame_rate,nb_read_frames', '-of', 'json', video]).stdout).streams[0];
const [num, den] = probe.r_frame_rate.split('/').map(Number);
const fps = num / den;
const frames = Number(probe.nb_read_frames);
const duration = frames / fps;

const bounds = isAd ? Object.values(SCENES) : sceneArg.split(',').map(Number);
const sceneNames = isAd ? Object.keys(SCENES).slice(0, -1) : bounds.slice(0, -1).map((_, i) => `scene${i + 1}`);
const sceneOf = (t) => {
  let i = bounds.length - 2;
  while (i > 0 && t < bounds[i] - 1e-9) i--;
  return i;
};

// ---- 3. One analysis pass: motion per frame, freezes, black frames ------------------------------------------------------

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
const statsFile = path.relative(ROOT, path.join(OUT, 'ydif.txt')).replaceAll('\\', '/');
const analysis = run(FFMPEG, [
  '-hide_banner', '-nostats', '-i', video,
  '-vf', `signalstats,metadata=mode=print:key=lavfi.signalstats.YDIF:file=${statsFile},freezedetect=n=-60dB:d=${FREEZE_LIMIT},blackdetect=d=0.03:pix_th=0.10`,
  '-an', '-f', 'null', '-',
]).stderr;

const ydif = [];
for (const line of readFileSync(path.join(OUT, 'ydif.txt'), 'utf8').split('\n')) {
  const m = line.match(/YDIF=([\d.]+)/);
  if (m) ydif.push(Number(m[1]));
}
rmSync(path.join(OUT, 'ydif.txt'));
ydif[0] = 0;

const freezes = [];
for (const m of analysis.matchAll(/freeze_start: ([\d.]+)|freeze_end: ([\d.]+)/g)) {
  if (m[1] !== undefined) freezes.push({ start: Number(m[1]), end: duration });
  else freezes[freezes.length - 1].end = Number(m[2]);
}
const blacks = [...analysis.matchAll(/black_start:([\d.]+) black_end:([\d.]+)/g)].map((m) => ({ start: Number(m[1]), end: Number(m[2]) }));

// ---- 4. Onsets, pops and the beat grid ----------------------------------------------------------------------------------

const median = (xs) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)] ?? 0;
const quantile = (xs, q) => [...xs].sort((a, b) => a - b)[Math.floor((xs.length - 1) * q)] ?? 0;

// A spring released at time T leaves frame floor(T·fps) unchanged, so its first change shows in the next frame.
const firstChange = (t) => Math.floor(t * fps + 1e-9) + 1;
const cueList = isAd ? Object.entries({ ...SCENES, ...CUES }).filter(([, t]) => t > 0 && t < duration) : [];
const eighth = BEAT / 2;
const gridMiss = (n) => {
  // Frames from the nearest eighth-note release (beats are eighths too).
  const k = Math.round((n - 1) / fps / eighth);
  let best = Infinity;
  for (const j of [k - 1, k, k + 1]) best = Math.min(best, Math.abs(n - firstChange(j * eighth)));
  return best;
};
const nearestCue = (n) => {
  let best = null;
  for (const [name, t] of cueList) {
    const d = n - firstChange(t);
    if (!best || Math.abs(d) < Math.abs(best.d)) best = { name, d };
  }
  return best;
};

const onsets = [];
for (let n = 6; n < ydif.length; n++) {
  const before = median(ydif.slice(n - 5, n));
  if (ydif[n] >= ONSET_FLOOR && ydif[n] > ONSET_RATIO * before && ydif[n] > ydif[n - 1]) {
    // Walk back (up to 3 frames) to where the rise began: the first frame that already moved above the baseline.
    let m = n;
    while (n - m < 3 && ydif[m - 1] < ydif[m] && ydif[m - 1] > 1.5 * before + 0.02) m--;
    if (onsets.length && m - onsets[onsets.length - 1].frame < 4) continue;
    onsets.push({ frame: m, t: m / fps, ydif: ydif[n], miss: isAd ? gridMiss(m) : null, cue: isAd ? nearestCue(m) : null });
  }
}
// A one-frame spike is a glitch unless a cue fires on that frame (a camera flash is meant to be instant).
const pops = [];
for (let n = 1; n < ydif.length - 1; n++) {
  if (ydif[n] >= ONSET_FLOOR && ydif[n] > POP_RATIO * Math.max(ydif[n - 1], ydif[n + 1], 0.01)) {
    const cue = isAd ? nearestCue(n) : null;
    pops.push({ frame: n, t: n / fps, ydif: ydif[n], onCue: cue && Math.abs(cue.d) <= GRID_TOLERANCE ? cue.name : null });
  }
}
const glitches = pops.filter((p) => !p.onCue);

// Sound: every onset the synth logged must sit on an eighth (grace notes trail an on-grid onset on purpose).
let audio = null;
const eventsFile = path.join(ROOT, 'out', 'ad-audio-events.json');
if (isAd && existsSync(eventsFile)) {
  const { events } = JSON.parse(readFileSync(eventsFile, 'utf8'));
  const off = events.filter((e) => !e.grace && Math.abs(e.t / eighth - Math.round(e.t / eighth)) > 1e-3);
  audio = { total: events.length, grace: events.filter((e) => e.grace).length, off };
}

// ---- 5. Pictures to look at --------------------------------------------------------------------------------------------

const TILE = 162;
bounds.slice(0, -1).forEach((start, i) => {
  const len = bounds[i + 1] - start;
  const cols = Math.ceil((len * 10) / 5);
  run(FFMPEG, [
    '-hide_banner', '-loglevel', 'error', '-ss', String(start), '-t', String(len), '-i', video,
    '-vf', `fps=10,scale=${TILE}:-2,tile=${cols}x5:padding=4:margin=4:color=white`, '-frames:v', '1', '-update', '1', '-y',
    path.join(OUT, `sheet-${i + 1}-${sceneNames[i]}.png`),
  ]);
});
const cuts = isAd ? ['opportunity', 'connect', 'rescue', 'reveal'].map((k) => [k, SCENES[k]]).concat([['cut', CUES.cut], ['handover', CUES.handover]]) : bounds.slice(1, -1).map((t, i) => [`cut${i + 1}`, t]);
for (const [name, t] of cuts) {
  const f = Math.round(t * fps);
  run(FFMPEG, [
    '-hide_banner', '-loglevel', 'error', '-i', video,
    '-vf', `select=between(n\\,${f - 6}\\,${f + 5}),scale=${TILE}:-2,tile=12x1:padding=4:margin=4:color=white`, '-fps_mode', 'vfr', '-frames:v', '1', '-update', '1', '-y',
    path.join(OUT, `cut-${String(f).padStart(3, '0')}-${name}.png`),
  ]);
}
const hasAudio = run(FFPROBE, ['-v', 'error', '-select_streams', 'a', '-show_entries', 'stream=index', '-of', 'csv=p=0', video]).stdout.trim() !== '';
if (hasAudio) {
  run(FFMPEG, ['-hide_banner', '-loglevel', 'error', '-i', video, '-lavfi', 'showspectrumpic=s=1600x480:legend=1:scale=log', '-frames:v', '1', '-update', '1', '-y', path.join(OUT, 'spectrum.png')]);
}
writeFileSync(path.join(OUT, 'motion.csv'), ['frame,t,scene,ydif', ...ydif.map((y, n) => `${n},${(n / fps).toFixed(3)},${sceneNames[sceneOf(n / fps)]},${y}`)].join('\n'));

// ---- 6. Report ---------------------------------------------------------------------------------------------------------

const pad = (s, n) => String(s).padEnd(n);
const lines = [];
const say = (s = '') => lines.push(s);
say(`Review of ${path.relative(ROOT, video)}: ${probe.width}×${probe.height}, ${fps} fps, ${frames} frames (${duration.toFixed(3)} s)`);
say();
say(`Lint (banned easing): ${lint.length ? `${lint.length} FAIL` : 'pass'}`);
lint.forEach((l) => say(`  ${l}`));
say();
say(`${pad('Scene', 13)}${pad('frames', 9)}${pad('longest freeze', 16)}${pad('low-motion', 12)}${pad('YDIF p10', 10)}${pad('median', 8)}${pad('max jump', 10)}${isAd ? 'off-grid onsets' : ''}`);
const verdicts = [];
sceneNames.forEach((name, i) => {
  const [a, b] = [Math.round(bounds[i] * fps), Math.round(bounds[i + 1] * fps)];
  const ys = ydif.slice(Math.max(1, a), b);
  const freeze = freezes.filter((f) => f.end > bounds[i] && f.start < bounds[i + 1]).reduce((m, f) => Math.max(m, Math.min(f.end, bounds[i + 1]) - Math.max(f.start, bounds[i])), 0);
  const low = ys.filter((y) => y < LOW_MOTION).length;
  const offGrid = onsets.filter((o) => o.frame >= a && o.frame < b && o.miss > GRID_TOLERANCE).length;
  verdicts.push(freeze <= FREEZE_LIMIT && offGrid === 0);
  say(`${pad(name, 13)}${pad(b - a, 9)}${pad(`${freeze.toFixed(2)} s`, 16)}${pad(low, 12)}${pad(quantile(ys, 0.1).toFixed(3), 10)}${pad(median(ys).toFixed(3), 8)}${pad(Math.max(...ys).toFixed(2), 10)}${isAd ? offGrid : ''}`);
});
say();
say(`Freezes over ${FREEZE_LIMIT} s: ${freezes.length ? freezes.map((f) => `${f.start.toFixed(2)}–${f.end.toFixed(2)} s`).join(', ') : 'none'}`);
say(`Black frames: ${blacks.length ? blacks.map((b) => `${b.start.toFixed(2)}–${b.end.toFixed(2)} s`).join(', ') : 'none'}`);
say(`Pops (one-frame spikes): ${pops.length ? pops.map((p) => `f${p.frame} (${p.t.toFixed(2)} s, ${p.ydif.toFixed(2)}${p.onCue ? `, on cue ${p.onCue}` : ', GLITCH'})`).join(', ') : 'none'}`);
const lowRuns = [];
for (let n = 1; n < ydif.length; n++) {
  if (ydif[n] >= LOW_MOTION) continue;
  const last = lowRuns[lowRuns.length - 1];
  if (last && last[1] === n - 1) last[1] = n;
  else lowRuns.push([n, n]);
}
say(`Low-motion frames (YDIF < ${LOW_MOTION}): ${lowRuns.length ? lowRuns.map(([a, b]) => (a === b ? `f${a}` : `f${a}–${b}`)).join(', ') : 'none'}`);
if (isAd) {
  say();
  say(`Motion onsets (${onsets.length}); expected first change = the frame after a release on the ${60 / BEAT} BPM grid:`);
  for (const o of onsets) {
    const cue = o.cue ? `${o.cue.name} ${o.cue.d >= 0 ? '+' : ''}${o.cue.d}f` : '';
    say(`  f${pad(o.frame, 5)}${pad(`${o.t.toFixed(3)} s`, 10)}YDIF ${pad(o.ydif.toFixed(2), 7)}grid ${o.miss <= GRID_TOLERANCE ? 'ok ' : 'OFF'} (${o.miss}f)   nearest cue: ${cue}`);
  }
  say();
  say('Cues (beat → frame):');
  say(`  ${cueList.map(([name, t]) => `${name} ${t / BEAT}→f${Math.round(t * fps)}`).join(', ')}`);
  say();
  if (audio) {
    say(`Audio onsets: ${audio.total} (${audio.grace} grace notes), off the eighth grid: ${audio.off.length ? audio.off.map((e) => `${e.kind}@${e.t}`).join(', ') : 'none'}`);
  } else {
    say('Audio onsets: no out/ad-audio-events.json (run npm run audio:ad)');
  }
}
say();
say(`Sheets, cut strips, spectrum and motion.csv: ${path.relative(ROOT, OUT)}`);

const failed = lint.length > 0 || freezes.length > 0 || blacks.length > 0 || glitches.length > 0 || verdicts.includes(false) || (audio && audio.off.length > 0);
say(failed ? 'RESULT: FAIL' : 'RESULT: pass');
writeFileSync(path.join(OUT, 'report.txt'), lines.join('\n'));
console.log(lines.join('\n'));
process.exit(failed ? 1 : 0);

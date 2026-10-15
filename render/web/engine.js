// Frame-addressed render engine. seek(frame) paints frame N at t = N / fps and never reads a real clock, so the headless
// driver (render.mjs) can capture every frame exactly. Without ?capture the same paint path runs in a rAF preview loop.

import { color, family, springs } from './tokens.js';
import { fade } from './ease.js';
import { drift, tuned } from './spring.js';
import intro from './scenes/intro.js';
import share from './scenes/share.js';
import nearby from './scenes/nearby.js';
import pickup from './scenes/pickup.js';
import outro from './scenes/outro.js';
import adProblem from './scenes/adProblem.js';
import adOpportunity from './scenes/adOpportunity.js';
import adConnect from './scenes/adConnect.js';
import adRescue from './scenes/adRescue.js';
import adReveal from './scenes/adReveal.js';

/**
 * What can be rendered (?comp=). `transition` is the fade-through between scenes, in seconds; 0 means hard cuts,
 * for scenes that paint their own match cuts. `dolly` is a slow camera push-in over each scene (the fraction it has
 * zoomed by the scene's end), for scenes that hold still after their elements land. `portrait` forces the 9:16 stage.
 * `audio` is a WAV, relative to render/, that render.mjs muxes into the MP4.
 */
const COMPOSITIONS = {
  // The 8 s feature promo, in landscape or portrait.
  promo: { scenes: [intro, share, nearby, pickup, outro], transition: 0.32, dolly: 0.03 },
  // The 20 s opener of the pitch video (portrait only).
  ad: { scenes: [adProblem, adOpportunity, adConnect, adRescue, adReveal], transition: 0, portrait: true, audio: 'out/ad-audio.wav' },
};

/** Design stages, in scene units. A taller-than-wide output gets the portrait layouts. */
const STAGES = { landscape: { w: 1920, h: 1080, portrait: false }, portrait: { w: 1080, h: 1920, portrait: true } };

const ASSETS = '/assets/';
const IMAGES = {
  lodeh: `${ASSETS}images/food/lodeh.jpg`,
  // The other photo pins on the ad's map.
  ayam: `${ASSETS}images/food/ayam.jpg`,
  sayur: `${ASSETS}images/food/sayur.jpg`,
  roti: `${ASSETS}images/food/roti.jpg`,
  wordmark: `${ASSETS}images/brand/wordmark.png`,
  // Watercolour scenes for the ad, generated with Figma AI in the style of the onboarding art (see AD.md).
  kitchen: '/media/kitchen.png',
  room: '/media/room.png',
  handover: '/media/handover.png',
};

const params = new URLSearchParams(location.search);
const capture = params.has('capture');
const compName = params.get('comp') ?? 'promo';
const comp = COMPOSITIONS[compName];
if (!comp) throw new Error(`Unknown composition "${compName}" (have: ${Object.keys(COMPOSITIONS).join(', ')})`);
const fallback = comp.portrait ? STAGES.portrait : STAGES.landscape;
const width = Number(params.get('w')) || fallback.w;
const height = Number(params.get('h')) || fallback.h;
const fps = Number(params.get('fps')) || 30;
const stage = comp.portrait || height > width ? STAGES.portrait : STAGES.landscape;

const fadeSpring = comp.transition ? tuned(1.2, comp.transition / 2) : null;

const timeline = [];
let cursor = 0;
for (const scene of comp.scenes) {
  timeline.push({ scene, start: cursor });
  cursor += scene.duration;
}
const duration = cursor;
const frames = Math.round(duration * fps);

const canvas = document.getElementById('stage');
canvas.width = width;
canvas.height = height;
const ctx = canvas.getContext('2d', { alpha: false });
// A fading scene is painted here first, so scenes can use globalAlpha freely.
const layer = document.createElement('canvas');
layer.width = width;
layer.height = height;
const lctx = layer.getContext('2d');
// Photos are drawn far below their native size (the feed-card thumbnail); 'high' keeps them sharp.
ctx.imageSmoothingQuality = 'high';
lctx.imageSmoothingQuality = 'high';

// Fit the stage to the output size, letterboxed if the aspect differs (e.g. 4:3 still uses the landscape layouts).
const scale = Math.min(width / stage.w, height / stage.h);
const offsetX = (width - stage.w * scale) / 2;
const offsetY = (height - stage.h * scale) / 2;

let env = null;

async function loadAssets() {
  const faces = [
    new FontFace(family.display, `url(${ASSETS}fonts/BricolageGrotesque.ttf)`, { weight: '200 800' }),
    new FontFace(family.ui, `url(${ASSETS}fonts/Inter.ttf)`, { weight: '100 900' }),
  ];
  for (const face of await Promise.all(faces.map((f) => f.load()))) document.fonts.add(face);

  const images = await Promise.all(
    Object.entries(IMAGES).map(async ([key, src]) => {
      const img = new Image();
      img.src = src;
      await img.decode();
      return [key, img];
    }),
  );

  const res = await fetch(`${ASSETS}images/brand/logo_tungku.svg`);
  if (!res.ok) throw new Error(`logo_tungku.svg: HTTP ${res.status}`);
  const svg = new DOMParser().parseFromString(await res.text(), 'image/svg+xml');
  const logo = new Path2D(svg.querySelector('path').getAttribute('d'));

  await document.fonts.ready;
  return { img: Object.fromEntries(images), logo };
}

function paintScene(c, entry, t) {
  c.save();
  c.setTransform(scale, 0, 0, scale, offsetX, offsetY);
  if (comp.dolly) {
    // The heavy dolly spring keeps an almost even pace, so a scene never sits dead still after its elements land.
    const k = 1 + drift(t - entry.start, 0, springs.dolly, comp.dolly, entry.scene.duration);
    c.translate(stage.w / 2, stage.h / 2);
    c.scale(k, k);
    c.translate(-stage.w / 2, -stage.h / 2);
  }
  entry.scene.paint(c, t - entry.start, env);
  c.restore();
}

function paint(t) {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1;
  ctx.fillStyle = color.background;
  ctx.fillRect(0, 0, width, height);

  let i = timeline.length - 1;
  while (i > 0 && t < timeline[i].start) i--;
  const current = timeline[i];
  const local = t - current.start;
  if (i === 0 || !comp.transition || local >= comp.transition) {
    paintScene(ctx, current, t);
    return;
  }
  // The outgoing scene fades out over the first half, the incoming one fades in over the second, each on an overdamped
  // spring that settles within its half.
  const half = comp.transition / 2;
  const [entry, opacity] = local < half ? [timeline[i - 1], 1 - fade(local, 0, fadeSpring)] : [current, fade(local, half, fadeSpring)];
  lctx.setTransform(1, 0, 0, 1, 0, 0);
  lctx.clearRect(0, 0, width, height);
  paintScene(lctx, entry, t);
  ctx.globalAlpha = opacity;
  ctx.drawImage(layer, 0, 0);
  ctx.globalAlpha = 1;
}

function seek(frame) {
  const f = Math.min(frames - 1, Math.max(0, Math.round(frame)));
  paint(f / fps);
  return f;
}

const ready = loadAssets().then((assets) => {
  env = { ...assets, stage };
  // Chrome resamples a photo differently the first time it is drawn at a given size than on later draws. Painting the
  // timeline once up front (every 0.2 s, and each scene's last frame) means a frame comes out identical whether it is
  // rendered alone or mid-sequence.
  for (let t = 0; t < duration; t += 0.2) paint(t);
  for (const { scene, start } of timeline) paint(start + scene.duration - 1 / fps);
  seek(0);
});

const layout = stage.portrait ? 'portrait' : 'landscape';
window.__render = { ready, meta: { width, height, fps, frames, duration, layout, comp: compName, audio: comp.audio ?? null }, seek };

if (!capture) ready.then(startPreview);

function startPreview() {
  document.body.classList.add('preview');
  document.body.style.background = color.ink;
  const play = document.getElementById('play');
  const scrub = document.getElementById('scrub');
  const label = document.getElementById('time');
  scrub.max = String(frames - 1);

  let playing = true;
  let frame = 0;
  let origin = performance.now();

  const show = (f) => {
    frame = seek(f);
    scrub.value = String(frame);
    label.textContent = `${frame + 1} / ${frames} · ${(frame / fps).toFixed(2)} s`;
  };
  const setPlaying = (on) => {
    playing = on;
    play.textContent = on ? 'Pause' : 'Play';
    if (on) origin = performance.now() - (frame / fps) * 1000;
  };
  const tick = (now) => {
    if (playing) show(Math.floor(((now - origin) / 1000) * fps) % frames);
    requestAnimationFrame(tick);
  };

  play.addEventListener('click', () => setPlaying(!playing));
  scrub.addEventListener('input', () => {
    setPlaying(false);
    show(Number(scrub.value));
  });
  addEventListener('keydown', (e) => {
    if (e.code === 'Space') {
      e.preventDefault();
      setPlaying(!playing);
    } else if (e.code === 'ArrowLeft' || e.code === 'ArrowRight') {
      setPlaying(false);
      show(frame + (e.code === 'ArrowRight' ? 1 : -1));
    }
  });
  requestAnimationFrame(tick);
}

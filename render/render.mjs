// Headless render driver: serves web/, opens it in headless Chrome, paints and captures every frame, and pipes the PNGs
// into ffmpeg (or writes them to a folder with --frames-dir). Muxes the composition's audio track when it has one.

import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { existsSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';
import { launch, openPage } from './cdp.mjs';
import { startServer } from './server.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));

const USAGE = `Usage: node render.mjs [options]

  --comp <name>        composition: promo (default, 8 s) or ad (20 s, 9:16, with audio)
  --portrait           9:16 promo: 1080×1920 and out/pawonfood-promo-portrait.mp4 unless set below
  --width <px>         output width (default 1920, or 1080 for ad/--portrait; even)
  --height <px>        output height (default 1080, or 1920 for ad/--portrait; even)
  --fps <n>            frames per second (default 30)
  --out <file>         MP4 path (default out/pawonfood-promo[-portrait].mp4 or out/pawonfood-ad-20s.mp4)
  --crf <n>            x264 quality, lower is better (default 18)
  --no-audio           leave the composition's audio track out
  --from <frame>       first frame to render (default 0)
  --to <frame>         last frame to render, inclusive (default: last)
  --frames-dir <dir>   write numbered PNGs instead of encoding an MP4
  -h, --help           show this help

Any output taller than it is wide uses the portrait layouts.
Env: CHROME_PATH (browser executable), FFMPEG_PATH (default: ffmpeg on PATH).`;

const { values: opt } = parseArgs({
  options: {
    comp: { type: 'string', default: 'promo' },
    portrait: { type: 'boolean' },
    width: { type: 'string' },
    height: { type: 'string' },
    fps: { type: 'string', default: '30' },
    out: { type: 'string' },
    crf: { type: 'string', default: '18' },
    'no-audio': { type: 'boolean' },
    from: { type: 'string' },
    to: { type: 'string' },
    'frames-dir': { type: 'string' },
    help: { type: 'boolean', short: 'h' },
  },
});

function int(name, value, { min = 0, even = false } = {}) {
  const n = Number(value);
  if (!Number.isInteger(n) || n < min) throw new Error(`--${name} must be an integer ≥ ${min} (got "${value}")`);
  if (even && n % 2) throw new Error(`--${name} must be even for yuv420p video (got ${n})`);
  return n;
}

/** Encodes piped PNG frames to H.264. With `audio`, muxes that WAV as AAC from `audioStart` seconds in. */
function ffmpegSink(out, fps, crf, audio, audioStart) {
  mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
  const input = ['-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'png', '-i', '-'];
  const sound = audio ? ['-ss', audioStart.toFixed(3), '-i', audio] : [];
  const mux = audio ? ['-map', '0:v', '-map', '1:a', '-c:a', 'aac', '-b:a', '192k', '-shortest'] : [];
  const ff = spawn(
    process.env.FFMPEG_PATH || 'ffmpeg',
    ['-hide_banner', '-loglevel', 'error', '-y', ...input, ...sound, ...mux,
      '-c:v', 'libx264', '-preset', 'medium', '-crf', String(crf), '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out],
    { stdio: ['pipe', 'ignore', 'pipe'] },
  );
  let stderr = '';
  ff.stderr.on('data', (d) => (stderr = (stderr + d).slice(-4000)));
  const exited = new Promise((resolve, reject) => {
    ff.once('error', (err) => reject(new Error(`Could not start ffmpeg: ${err.message}`)));
    ff.once('close', (code) => (code === 0 ? resolve() : reject(new Error(`ffmpeg exited with code ${code}\n${stderr}`))));
  });
  exited.catch(() => {}); // awaited in write()/end(); this only stops an early failure from crashing as unhandled
  ff.stdin.on('error', () => {}); // EPIPE when ffmpeg dies; the reason comes through `exited`
  return {
    label: out,
    async write(png) {
      if (!ff.stdin.write(png)) await Promise.race([once(ff.stdin, 'drain'), exited]);
    },
    async end() {
      ff.stdin.end();
      await exited;
    },
    abort: () => ff.kill(),
  };
}

function dirSink(dir) {
  mkdirSync(dir, { recursive: true });
  return {
    label: dir,
    write: async (png, frame) => writeFileSync(path.join(dir, `frame_${String(frame).padStart(5, '0')}.png`), png),
    end: async () => {},
    abort: () => {},
  };
}

async function main() {
  if (opt.help) {
    console.log(USAGE);
    return;
  }
  const ad = opt.comp === 'ad';
  const tall = ad || opt.portrait;
  const width = int('width', opt.width ?? (tall ? '1080' : '1920'), { min: 2, even: true });
  const height = int('height', opt.height ?? (tall ? '1920' : '1080'), { min: 2, even: true });
  const fps = int('fps', opt.fps, { min: 1 });
  const crf = int('crf', opt.crf);
  const out = opt.out ?? (ad ? 'out/pawonfood-ad-20s.mp4' : opt.portrait ? 'out/pawonfood-promo-portrait.mp4' : 'out/pawonfood-promo.mp4');

  let server;
  let chrome;
  let sink;
  let finished = false;
  try {
    let url;
    ({ server, url } = await startServer());
    chrome = await launch({ width, height });
    const page = await openPage(chrome.browser, { width, height });
    await page.goto(`${url}/index.html?capture=1&comp=${encodeURIComponent(opt.comp)}&w=${width}&h=${height}&fps=${fps}`);
    const meta = await page.evaluate('window.__render.ready.then(() => window.__render.meta)', { awaitPromise: true });
    if (page.errors.length) throw new Error(`Page failed to load:\n${page.errors.join('\n')}`);

    const first = opt.from === undefined ? 0 : int('from', opt.from);
    const last = Math.min(meta.frames - 1, opt.to === undefined ? meta.frames - 1 : int('to', opt.to));
    if (first > last) throw new Error(`Nothing to render: --from ${first} is past --to ${last} (the video has ${meta.frames} frames)`);
    const total = last - first + 1;

    let audio = null;
    if (meta.audio && !opt['no-audio'] && !opt['frames-dir']) {
      audio = path.resolve(here, meta.audio);
      if (!existsSync(audio)) throw new Error(`Missing audio track ${meta.audio}: run "npm run audio:ad" first, or pass --no-audio`);
    }
    console.log(
      `Rendering ${meta.comp} frames ${first}–${last} of ${meta.frames} (${meta.duration.toFixed(2)} s) at ${width}×${height}, ${fps} fps, ${meta.layout}` +
        (audio ? `, audio ${meta.audio}` : ''),
    );

    sink = opt['frames-dir'] ? dirSink(opt['frames-dir']) : ffmpegSink(out, fps, crf, audio, first / fps);
    const started = performance.now();
    for (let f = first; f <= last; f++) {
      await page.evaluate(`window.__render.seek(${f})`);
      if (page.errors.length) throw new Error(`Page error at frame ${f}:\n${page.errors.join('\n')}`);
      await sink.write(await page.screenshot(), f);
      const done = f - first + 1;
      if (process.stdout.isTTY || done % fps === 0 || done === total) {
        const rate = done / ((performance.now() - started) / 1000);
        const line = `frame ${done}/${total}  ${rate.toFixed(1)} frames/s`;
        process.stdout.write(process.stdout.isTTY ? `\r${line}` : `${line}\n`);
      }
    }
    if (process.stdout.isTTY) process.stdout.write('\n');
    await sink.end();
    finished = true;

    const seconds = (performance.now() - started) / 1000;
    const size = opt['frames-dir'] ? '' : `, ${(statSync(out).size / 1024 / 1024).toFixed(2)} MB`;
    console.log(`Done in ${seconds.toFixed(1)} s → ${sink.label}${size}`);
  } finally {
    if (sink && !finished) sink.abort();
    await chrome?.close();
    server?.close();
  }
}

main().catch((err) => {
  console.error(`\n${err.message}`);
  process.exitCode = 1;
});

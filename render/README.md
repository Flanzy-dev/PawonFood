# PawonFood render

This is a headless render engine. It paints every frame of an animation on a `<canvas>`, captures each frame in headless Chrome and encodes the frames into an MP4 with ffmpeg. It has two compositions:

- **`ad`**: the 20-second, 9:16 opener of the pitch video. It has a synthesized soundtrack, and every cut sits on a 120 BPM beat grid. The story runs kitchen → nearby student → PawonFood → "Temukan. Pesan. Ambil." → logo. The voice-over script, cue sheet and CapCut guide are in [AD.md](AD.md).
- **`promo`**: an 8-second feature promo in landscape or portrait: brand reveal → Bagikan (AI photo check) → Peta (1 km radius) → Pindai QR → end card.

It has no npm dependencies. You need Node 22.4+ (for the built-in `WebSocket`), Chrome or Edge, and `ffmpeg`/`ffprobe` on PATH.

```bash
cd render
npm run render:ad                    # → out/pawonfood-ad-20s.mp4 (1080×1920, 30 fps, 600 frames, with audio)
                                     #   preview: http://127.0.0.1:4317/?comp=ad
npm run review:ad                    # watch the ad: dead frames, pops, beat lock, contact sheets → out/review/ad/
npm test                             # the spring physics tests
npm run render                       # → out/pawonfood-promo.mp4 (1920×1080, 30 fps, 240 frames)
npm run render:portrait              # → out/pawonfood-promo-portrait.mp4 (1080×1920, 9:16 for Reels/TikTok/Stories)
npm run preview                      # → http://127.0.0.1:4317/ real-time preview with a scrubber
                                     #   portrait preview: http://127.0.0.1:4317/?w=1080&h=1920
node render.mjs --help               # all options
node render.mjs --from 96 --to 143   # render just one scene
node render.mjs --frames-dir frames  # numbered PNGs instead of an MP4
node render.mjs --width 1280 --height 720 --fps 60
node review.mjs out/pawonfood-promo.mp4 --scenes 0,1.6,3.2,4.8,6.4,8   # review any video
```

`CHROME_PATH` and `FFMPEG_PATH` override the browser and encoder paths.

## How it works

```text
render.mjs ─ server.mjs   serves web/ at /, and ../app/assets at /assets (fonts, logo, photos; read-only)
           ─ cdp.mjs      starts headless Chrome and drives it over the DevTools protocol
           ─ for each frame: __render.seek(n) → Page.captureScreenshot (PNG) → ffmpeg stdin → libx264 yuv420p
```

- **Frame-addressed, not clock-driven.** `seek(n)` paints frame n at `t = n / fps` and never reads a real timer. A slow machine still renders every frame and drops none. The preview runs the same `seek` from a `requestAnimationFrame` loop.
- **Deterministic.** Animation is a pure function of `t`, and random detail (the map blocks, the QR modules) uses a seeded PRNG. Before the first capture, the engine paints the timeline once, because Chrome resamples a photo differently the first time it draws it at a given size. A frame rendered alone is byte-identical to the same frame rendered mid-sequence.
- **Two layouts.** An output wider than it is tall uses the 1920×1080 landscape stage. A taller one uses the 1080×1920 portrait stage, with the caption stacked over a larger phone and the end-card slogan broken into four lines. Scenes read the stage from `env.stage` and get their caption and phone positions from `featureLayout()` in `draw.js`.
- **Errors fail loudly.** A page exception, a `console.error` or a failed asset load stops the render with the message.

## Motion: closed-form springs only

Duration-and-curve easing (ease-in/out cubics, back curves, CSS transitions or keyframes) is banned in this engine, and `review.mjs` fails if it finds any. Every moving value is a damped harmonic oscillator, `m·x″ + c·x′ + k·(x − to) = 0`, solved analytically in `web/spring.js`. Nothing is integrated or stored between frames, so determinism holds.

| Function | Use |
| --- | --- |
| `spring(preset, { from, to, velocity })` | Returns `t => { x, v }`: the exact position and velocity since release. It covers under-, critically and overdamped springs. |
| `springAt(t, start, preset, opts)` | A spring released at `start`. |
| `struck(t, start, preset, strength)` | A spring struck on a beat (released with `strength` × ω₀). It moves on the first frame after the beat. |
| `chain(t, preset, from, keys)` | Retargets mid-flight and keeps position *and* velocity through each key (CSS keyframes reset velocity). |
| `drift(t, start, preset, amount, reach)` | Slow camera moves that are still moving at a cut, so there are no dead frames. |
| `enter`, `fade`, `pop` (in `ease.js`) | Struck `ui`, `fade` and `pop` springs for arrivals, opacity and small pops. |

The presets in `tokens.js` (`springs`) are physical: unit mass, stiffness and damping. Each is documented by its damping ratio and its settle time in beats:

- `ui`, `snap`, `glide`: critically damped.
- `pop`, `land`, `float`: underdamped, with real overshoot.
- `fade`: overdamped.
- `camera`, `dolly`: heavy, slow dollies.

`npm test` checks that the closed form satisfies the equation of motion in every regime, that `chain` is continuous in position and velocity, and that every preset settles when it claims to.

## The ad's beat grid

`web/adCues.js` holds the ad's tempo (120 BPM, one beat = 0.5 s = 15 frames) and every story cue as `beat(n)`. It throws if a cue is off the grid. Scenes animate on the cues and the synth (`audio/ad-audio.mjs`) plays on them.

- The synth writes every sound onset to `out/ad-audio-events.json`.
- `review.mjs` checks that every sound onset and every visible motion onset lands on the grid (within one frame).
- When adding a moment to the ad, add a cue on a whole beat and start its spring there. A quick follow-up within the same gesture may sit an eighth (half a beat) later.

## Files

| Path | What it does |
| --- | --- |
| `web/engine.js` | Compositions (`?comp=`), timeline, asset loading, the fade-through and per-scene dolly of the promo, `window.__render`, preview loop. |
| `web/spring.js` | Closed-form damped springs: `spring`, `springAt`, `struck`, `chain`, `drift`, `settleTime`, `tuned`. |
| `web/adCues.js` | The ad's 120 BPM grid and story cues. The ad scenes and the soundtrack both read them, so picture and sound stay in sync. |
| `web/scenes/ad*.js` | The five ad scenes. They paint their own match cuts (the ad uses hard cuts between scenes). |
| `web/media/` | The ad's watercolour illustrations (Figma AI; prompts and the recurring-customer description in AD.md). |
| `audio/ad-audio.mjs` | Code-only synth that writes `out/ad-audio.wav` and its onset list. It uses modal bars, a membrane kick and whooshes shaped by the picture's spring velocities; `render.mjs` muxes the WAV as AAC. |
| `review.mjs` | The reviewer. It covers lint for banned easing, freezes, black frames, pops, beat lock in picture and sound, contact sheets, cut strips and a spectrogram. |
| `test/spring.test.mjs` | Physics tests for `spring.js` (`npm test`). |
| `web/tokens.js` | Colours, fonts and spring presets, mirrored from `DESIGN_SYSTEM.md` and `app/lib/core/theme/app_colors.dart`. |
| `web/ease.js` | `clamp`, `lerp`, the `enter`/`fade`/`pop` spring helpers, seeded PRNG. |
| `web/draw.js` | Shared painters (phone mockup, pills, captions, pins, QR, logo, check mark, steam) and `featureLayout()`. |
| `web/scenes/*.js` | One file per scene: `{ duration, paint(ctx, t, env) }`, drawn on `env.stage` (landscape or portrait). |

## Adding or lengthening a scene

1. Copy a scene in `web/scenes/` and change its `duration` and `paint`. `t` is local time in seconds from the scene's start. Past `duration`, the scene must keep painting a sensible continuation of its final state, because the next scene may paint it under a match cut.
2. Add it to the composition in `web/engine.js`. Total length and frame count follow automatically.
3. Take colours, fonts and springs from `tokens.js`. Use `ctx.globalAlpha *=`, never `=`, so a scene can be painted faded inside another. Keep UI copy in Indonesian and word for word with the app.
4. Lay the scene out from `env.stage` (or `featureLayout()`). Then render, and run `review.mjs` on the result.

## Copy and credits

All on-screen text comes from the app or the PRD: the onboarding titles, the camera and scan screens, the Peta header and the slogan. Tier names (Pawon Friend, Pawon Elite, Pawon Hero) are left out of the video on purpose. The video leads with **GRATIS** and rescue, in line with the PRD's positioning (not a cheap-food app).

- Photo `sayur lodeh`: Midori, [CC BY 3.0](https://commons.wikimedia.org/wiki/File:Sayur_lodeh.JPG), via Wikimedia Commons. The end card shows this credit.
- Fonts: Bricolage Grotesque and Inter, SIL Open Font License 1.1.
- The wordmark and the Tungku logo are PawonFood's own brand assets.

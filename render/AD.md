# PawonFood 20-second ad: production package

This is the opening 20 seconds of the team's two-minute hackathon pitch video. The video is rendered by this engine. This page holds everything the team adds or changes by hand (the voice-over, the music swap and the final export), plus how the picture and sound are timed.

| | |
| --- | --- |
| File | `out/pawonfood-ad-20s.mp4` |
| Video | H.264, yuv420p, **1080×1920 (9:16)**, **30 fps**, **600 frames = 20.000 s** |
| Audio | AAC 48 kHz stereo, 20.000 s, about −16.5 LUFS integrated, peak about −3 dBFS, silent from 19.8 s |
| Rebuild | `cd render && npm run render:ad` (about 1.5 minutes). `--no-audio` gives a silent video for your own soundtrack. |
| Check | `npm run review:ad` reports dead frames, pops and beat lock, and writes contact sheets to `out/review/ad/`. The last self-review is in `out/review/critique.md`. |
| Preview | `npm run preview`, then open `http://127.0.0.1:4317/?comp=ad` |

## Timing and motion

- **Every cut is on the beat.** The ad runs at **120 BPM**: one beat is 0.5 s, exactly 15 frames. The brief's scene bounds (0, 4, 7, 11, 16, 20 s) are beats 0, 8, 14, 22, 32 and 40.
  - Every story beat is a cue on this grid in `web/adCues.js`, which refuses an off-grid cue.
  - The scenes animate on these cues and `audio/ad-audio.mjs` plays on them, so picture and sound share one clock.
- **Real springs, no easing curves.** Every moving value is the exact, closed-form solution of a damped spring (`web/spring.js`), with its mass, stiffness and damping in `web/tokens.js`.
  - Motion that starts on a beat is *struck*: released with a velocity, so it moves on the very first frame after the beat.
  - A chained move keeps its velocity when it is retargeted. For example, the listing card floats up, bobs, and drops back into the phone.
  - Slow camera dollies keep every shot alive, with no dead frames.
- **Sound follows the motion.** Each whoosh is shaped by the speed of the spring that moves the picture on that cut. The voices are physical models: marimba and chime bars, and a membrane kick.

## Timeline

| Time | Scene | What happens | On-screen text |
| --- | --- | --- | --- |
| 00:00–00:04 | Problem | Kos kitchen. A container of freshly cooked rice and sayur lodeh sits on the counter. A slow dolly push-in, steam rising; from 1.5 s the light sinks toward dusk and the steam thins: nobody has come for it. | **Masak kebanyakan?** (0.5 s, leaves on 3.5 s) |
| 00:04–00:07 | Opportunity | Match cut: the kitchen settles into a top panel, still drifting, and the customer (a student, standing in the same kitchen) lands below. At 5.0 s a walking route runs from the food down the margin to her phone, arriving at 6.0 s with a pulse. | **Jangan biarkan jadi sia-sia.** (4.5 s) · "300 m · ± 4 mnt jalan kaki" (5.5 s) |
| 00:07–00:11 | PawonFood connects | The phone is thrown up and lands with a little give. AI detection closes on the meal (8.0), shutter (8.5), push to the Peta map (9.0); the listing card floats out of the phone and bobs (10.0). | **Kenalkan, PawonFood.** (7.5) · "Temukan makanan di sekitarmu." (9.5) |
| 00:11–00:16 | Rescue in action | Card pressed with a tap ripple (11.5) → push to the chat (12.0): "Saya ambil ya." and "Ambil gratis disetujui" (12.5) → a window opens from the listing photo (13.0) onto the same customer receiving the container (13.5) → illustrative QR check (14.0–14.5) → success mark (15.0). | **Temukan. Pesan. Ambil.** (each word lights on its action: 11.5, 12.5, 13.5) |
| 00:16–00:20 | Brand reveal | Cream floods out from the success mark (16.0). Logo (16.5) with a little steam rising from the Tungku, wordmark, then one line per beat and the terracotta underline (18.5). A slow push-in carries it under the speaker. | **Dari dapur ke komunitas.** (17.0) / **Masak kebanyakan?** (17.5) / **Bagikan, jangan buang.** (18.0) |

## Voice-over (record it yourselves)

There is no Indonesian text-to-speech voice on the build machine, so the video has no voice-over. Record it, then lay it in CapCut (below). Aim for a warm, unhurried read at about 2.3 words per second. Each line must finish before its end time.

| In | Out | Line |
| --- | --- | --- |
| 00:00.4 | 00:03.4 | Masak kebanyakan? Sayang kalau sampai terbuang. |
| 00:04.2 | 00:06.8 | Padahal, tetangga di dekatmu bisa ikut menikmatinya. |
| 00:07.3 | 00:10.6 | PawonFood menghubungkan makanan berlebih dengan orang di sekitarmu. |
| 00:11.4 | 00:15.4 | Temukan, pesan, ambil. Beri makanan kesempatan kedua. (Land the three words on 11.5, 12.5 and 13.5, when they light up.) |
| 00:16.4 | 00:19.0 | PawonFood. Dari dapur ke komunitas. |

Recording tips:

- Record in a quiet, soft-furnished room (a closet full of clothes works), phone 15–20 cm from the mouth, slightly off-axis.
- Record each line 2–3 times and keep the best take.
- Leave 0.3 s of silence before and after each line so you can trim cleanly.

## CapCut assembly

1. New project with a **9:16** canvas. Import `pawonfood-ad-20s.mp4` and the VO takes.
2. Place each VO line at its "In" time from the table, then trim the silences.
3. Keep the music under the voice. Select the video's audio track and lower it by about **−8 dB** wherever a line plays (with keyframes), or use CapCut's auto-ducking. The voice should sit clearly on top.
4. Optional, replacing the music:
   - Mute the video's audio, or render with `npm run render:ad -- --no-audio` (the extra `--` passes the flag through npm).
   - Then add a licensed track, such as a calm, warm, lightly electronic piece at **120 BPM**, so its beat still lines up with the cuts. Only use music whose licence covers this use, for example YouTube Audio Library or Pixabay Music.
   - Start it on a downbeat at 00:00, and keep a clean ending by 00:19.8.
5. Make sure nothing extends past **00:20.00**. The pitch speaker starts right after.

## Music and sound-effect cue sheet (built-in placeholder score, 120 BPM)

| Time | Cue | Sound |
| --- | --- | --- |
| 00:00–00:04 | Kitchen waits | Room tone and a soft clock tick on 0.5, 1.5, 2.5 and 3.5; a Dadd9 pad fades in |
| 00:00.5 | "Masak kebanyakan?" lands | Soft bell (D5 + A5) |
| 00:04.0 | Split frame | Whoosh shaped by the panel's spring. The pad opens to Gmaj7 and quarter-note marimba begins. |
| 00:05.5 / 00:06.0 | Distance tag / route reaches her | Small bells |
| 00:07.0 | Phone lands | Whoosh shaped by the landing spring. Pad on D/F#, eighth-note marimba. |
| 00:08.0 / 00:08.5 | AI detection / shutter | High tick, then camera click; shakers start on the off-beats |
| 00:09.0 | Push to the map | Light swish. Pad on A. |
| 00:10.0 | Card floats out | Chime (E6, B6) and a soft whoosh that pulses with the card's bob |
| 00:11.0–16.0 | Rescue | Membrane kick on every beat, shaker on the off-beats, marimba eighths with octave sparkles |
| 00:11.5 | Card pressed ("Temukan.") | UI tap |
| 00:12.0 / 00:12.5 | Push to chat / "Ambil gratis disetujui" ("Pesan.") | Swish, then a two-note chime (A5 → D6) |
| 00:13.0–13.5 | Window opens onto the handover ("Ambil.") | Warm swell blooming into 13.5; the pad lands on D |
| 00:14.5 / 00:15.0 | QR read / success mark | Gentle beep / bell arpeggio D6–F♯6–A6 |
| 00:16.0–16.5 | End card | Flood whoosh, then a logo shimmer (D6–F♯6–A6–D7–E7) |
| 00:16–19.8 | Resolve | D major pad, cosine fade to silence by 19.8 s |

## Generated art

`web/media/kitchen.png`, `room.png` and `handover.png` were generated with Figma AI (`gemini-3.1-flash-image`, 768×1376) to match the watercolour onboarding art in `app/assets/images/brand/welcome_*.jpg`. Each prompt starts with the same style line:

> Vertical 9:16 illustration. Soft watercolor and ink illustration on warm cream paper, loose brush texture, hand-drawn black ink outlines, muted forest green (#2F5D39) and terracotta (#B15732) accents, …

**Recurring customer.** The student in `room.png` and in `handover.png` is the same person. Any regenerated image that shows her uses this description word for word:

> A young Indonesian university student woman, about 20, with straight dark-brown hair just past her shoulders, parted slightly off-centre with soft strands framing her face; an oval face, small dark eyes, lightly rosy cheeks and a warm, friendly smile; she wears a navy-blue short-sleeved polo shirt with a collar and three buttons, and olive-green trousers. (A dark olive-khaki canvas backpack.)

| File | Subject (rest of the prompt) |
| --- | --- |
| `kitchen.png` | A small, lived-in Indonesian kos kitchen. One neatly packed, lidded clear container of white rice and green sayur lodeh with tempeh sits centred in the lower third, with warm window light and an empty upper third. No people, no text. |
| `room.png` | The recurring customer, waist up and centred, standing in the `kitchen.png` kitchen (described in text, since Figma AI takes no reference image): cream tiled counter, green two-burner stove with a wok, pale green rice cooker, spice jars labelled "Sambal", "Ketumbar", "Garam", "Pepper", wooden window with a pilea in a terracotta pot, dark green open shelf with pots below. The counter has no food container. She glances down at a phone held in both hands at chest height, backpack on one shoulder. Empty upper third, face at about 40% height, phone at about 58%, no other text. |
| `handover.png` | At a kos doorway, a friendly woman in an apron hands the same container to the recurring customer. Both are equals and neighbours; hands and container are centred. No text. |

If you regenerate an image, check the new anchor points before rendering:

- `scenes/adProblem.js`: `CONTAINER`.
- `adOpportunity.js`: `STUDENT_PHONE` (where the route ends) and `STUDENT_FRAME` (what the panel frames on).
- `adRescue.js`: `CONTAINER`.

The kitchen spice jars carry legible labels (Sambal, Ketumbar, garam, pepper). These are real words, not generated gibberish.

## Accuracy notes

- It is an **illustrated** product ad. The end card says "Ilustrasi produk · prototipe".
- Every phone screen follows the real app's screens and copy: camera "Langkah 1 dari 3", Peta, the listing card, and the chat with "Ambil gratis disetujui".
- The QR is illustrative and encodes nothing.
- There are no statistics, testimonials, partners or impact numbers. Tier names are left out on purpose.
- The AI step is shown as detection ("Makanan terdeteksi, siap difoto"), not as a food-safety guarantee.
- **Slogan:** "Dari dapur ke komunitas" is the official slogan (PRD, README, app and this ad agree since 2026-10-15; it was "Dari dapur ke dapur" before). Keep it consistent with the rest of the pitch.

## Export checklist

- [ ] 1080×1920, 9:16, 30 fps
- [ ] Duration exactly 00:20.00, no black frames at either end
- [ ] H.264 at a high bitrate (CapCut: "Recommended" or 20+ Mbps), AAC 48 kHz, 192 kbps or more
- [ ] VO clearly above the music; no clipping (peaks below −1 dBFS)
- [ ] Text still readable on a phone: "Masak kebanyakan?", "Jangan biarkan jadi sia-sia.", "Kenalkan, PawonFood.", "Temukan. Pesan. Ambil.", slogan
- [ ] Nothing important under the platform UI: keep the top 250 px and bottom 320 px free of key text
- [ ] No watermark or template end card from the editor
- [ ] Credits shown: the lodeh photo (Midori, CC BY 3.0) is on the end card

## Credits

- Photo "Sayur lodeh": Midori, CC BY 3.0, via Wikimedia Commons.
- Fonts: Bricolage Grotesque and Inter, SIL Open Font License 1.1.
- Wordmark, Tungku logo and onboarding art: PawonFood's own assets. Ad illustrations: generated with Figma AI for this project.
- Music and sound effects: synthesized by `audio/ad-audio.mjs`; no samples.

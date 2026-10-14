// The 20 s ad's beat grid and story beats. The ad runs at 120 BPM: one beat is 0.5 s (exactly 15 frames at 30 fps) and
// a bar is 2 s, so the brief's scene bounds (0, 4, 7, 11, 16, 20 s) all land on beats. Every cut and every motion onset
// is a cue on this grid; the scenes animate on the cues and audio/ad-audio.mjs plays on them, from this one source.

export const BPM = 120;
export const BEAT = 60 / BPM;
export const beat = (n) => n * BEAT;

export const SCENES = { problem: beat(0), opportunity: beat(8), connect: beat(14), rescue: beat(22), reveal: beat(32), end: beat(40) };

export const CUES = {
  problemText: beat(1), // "Masak kebanyakan?" lands
  dusk: beat(3), // the light starts turning to dusk
  problemOut: beat(7), // the line lifts away, gone by the cut
  split: beat(8), // cut: the kitchen settles into the top panel
  route: beat(10), // the walking route starts drawing to the student
  routeTag: beat(11), // "300 m · ± 4 mnt jalan kaki"
  arrive: beat(12), // the route reaches the student
  phoneIn: beat(14), // cut: the phone rises in
  headline: beat(15), // "Kenalkan, PawonFood."
  detect: beat(16), // the camera's AI detection box closes on the meal
  shutter: beat(17), // camera shutter
  toMap: beat(18), // the screen pushes to the Peta map
  tagline: beat(19), // "Temukan makanan di sekitarmu."
  cardOut: beat(20), // the listing card lifts out of the phone
  select: beat(23), // card pressed: "Temukan."
  toChat: beat(24), // the card drops back and the screen pushes to the chat
  reserved: beat(25), // "Ambil gratis disetujui": "Pesan."
  cut: beat(26), // a window opens from the listing photo onto the handover
  handover: beat(27), // the handover fills the frame: "Ambil."
  qrSweep: beat(28), // the illustrative QR card pops and its scan line sweeps
  qr: beat(29), // "QR terbaca"
  success: beat(30), // success check
  reveal: beat(32), // cut: cream floods into the end card
  logo: beat(33), // logo pops
  tagline2: beat(34), // "Dari dapur ke komunitas."
  slogan: beat(35), // "Masak kebanyakan?"
  answer: beat(36), // "Bagikan, jangan buang."; the last slow push-in starts
  underline: beat(37), // the terracotta underline and the footer
};

// Every cue sits on a whole beat, so every cut lands on a whole frame.
for (const [name, t] of Object.entries({ ...SCENES, ...CUES })) {
  const n = t / BEAT;
  if (Math.abs(n - Math.round(n)) > 1e-9) throw new Error(`Cue ${name} (${t} s) is off the ${BPM} BPM grid`);
}

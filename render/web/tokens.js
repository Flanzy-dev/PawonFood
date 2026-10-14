// Colour, type and motion tokens, mirrored from DESIGN_SYSTEM.md and app/lib/core/theme/app_colors.dart.
// Scenes take every colour and font from here; never hardcode them in a scene.

export const color = {
  primary: '#2F5D39',
  primaryDark: '#203D27',
  ink: '#142319',
  inkMuted: '#555953',
  background: '#FAF6ED',
  surface: '#FFFFFF',
  surfaceSand: '#F3EBDE',
  mapSand: '#E8DDC9',
  border: '#E5DED1',
  accent: '#B15732',
  accentInk: '#6F2B18',
  successTint: '#E3EDE4',
  cameraBg: '#111A15',
  // Sampled from the hi-fi mockups (same set as AppColors).
  mapRoad: '#F4EEE0',
  mapBlock: '#DDD1B9',
  mapPark: '#D5DCB6',
  avatarOlive: '#5E752F',
  cameraControl: '#2A3530',
  detectBox: '#CFE3D0',
  onGreenMuted: '#CFE0D2',
  cameraText: '#D9D3C2',
};

/** `hex` with an alpha channel, for shadows, tints and glows. */
export function alpha(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${n >> 16}, ${(n >> 8) & 255}, ${n & 255}, ${a})`;
}

// Registered under private names so a locally installed copy of either font can never stand in.
export const family = { display: 'PawonDisplay', ui: 'PawonUI' };

/** Bricolage Grotesque: headings, captions, prices. */
export const display = (size, weight = 800) => `${weight} ${size}px ${family.display}`;

/** Inter: UI text inside the phone mockups. */
export const ui = (size, weight = 400) => `${weight} ${size}px ${family.ui}`;

/** Stagger between items of one gesture, in seconds (DESIGN_SYSTEM.md → Motion). */
export const motion = { stagger: 0.04 };

/**
 * Spring presets (spring.js): unit mass, stiffness in N/m, damping in N·s/m. The render engine moves everything with
 * these instead of duration-and-curve easing. Settle = within 0.5 % of the target; one beat of the ad is 0.5 s.
 */
export const springs = {
  // ζ 1.0, settles in 0.5 s (1 beat): arrivals, captions, in-phone screen pushes.
  ui: { mass: 1, stiffness: 220.85, damping: 29.72 },
  // ζ 1.0, settles in 0.25 s: presses and other quick follow-ups.
  snap: { mass: 1, stiffness: 883.38, damping: 59.44 },
  // ζ 0.6, settles in 0.5 s with a real 9.5 % overshoot: small things that pop in (logo, pins, marks, tags).
  pop: { mass: 1, stiffness: 331.11, damping: 21.84 },
  // ζ 1.0, settles in 1 s (2 beats): large moves (panels, flood fills, the handover window).
  glide: { mass: 1, stiffness: 55.21, damping: 14.86 },
  // ζ 0.75, settles in 1 s with a 2.8 % overshoot: a heavy object coming to rest (the phone).
  land: { mass: 1, stiffness: 51.62, damping: 10.78 },
  // ζ 0.5, settles in 1.25 s with a 16 % overshoot and a bob: the listing card lifting out of the phone.
  float: { mass: 1, stiffness: 53.81, damping: 7.34 },
  // ζ 1.2, settles in 0.5 s and never overshoots: opacity.
  fade: { mass: 1, stiffness: 441.53, damping: 50.43 },
  // ζ 2.5, slow mode ≈ 3 s: a heavy camera dolly that keeps drifting through a scene instead of stopping dead.
  camera: { mass: 1, stiffness: 2.55, damping: 7.99 },
  // ζ 2.5, slow mode ≈ 8 s: a heavier dolly whose speed barely drops over a few seconds (holds, end card).
  dolly: { mass: 1, stiffness: 0.359, damping: 2.995 },
};

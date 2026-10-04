
# Design System

Source: `PawonFood UI apps.pdf` (mobile) and `PawonFood UI.pdf` (landing page). Hex values were sampled from the mockups.

## Direction

Warm, earthy and trustworthy, like a home kitchen ("dapur rumahan").

- Green and earth tones signal sustainability and health.
- Cream backgrounds, rounded white cards, and terracotta reserved for urgency.
- Mobile-first, friendly, low cognitive load. A student should understand the home screen in 5 seconds.

## Colors

```css
--primary:        #2F5D39   /* forest green: primary buttons, active chips, FAB, own chat bubbles, GRATIS text */
--primary-dark:   #203D27   /* landing hero background, pressed states */
--ink:            #142319   /* headings and body text */
--ink-muted:      #555953   /* secondary text, inactive nav icons */
--background:     #FAF6ED   /* app and page background (cream) */
--surface:        #FFFFFF   /* cards, inputs, sheets */
--surface-sand:   #F3EBDE   /* points pill, price box, inactive segment, quantity "−" */
--map-sand:       #E8DDC9   /* map base */
--border:         #E5DED1   /* card, input and chip outlines */
--accent:         #B15732   /* terracotta: "Sisa N porsi" badge, map pins, star rating, paid price pin outline */
--accent-ink:     #6F2B18   /* "Bisa ditawar" pill text, "Tawar lagi" outline text */
--success-tint:   #E3EDE4   /* tier tags, category tag, accepted-offer card */
--camera-bg:      #111A15   /* camera / scanner screen */
--food-warm:      #C18A52   /* photo placeholder (lauk) */
--food-green:     #A8B46A   /* photo placeholder (sayur) */
--error:          #B3261E   /* validation errors, "Habis" (not in mockups; choose to match the palette) */
```

Rules:

- Green means action and positive state. Terracotta means urgency or price, used sparingly.
- **GRATIS** is shown in bold green, not red.

## Typography

- **Display / headings:** a heavy, tight geometric grotesque (looks like *Bricolage Grotesque* in the mockups;
  confirm in Figma). Used for screen titles, the landing hero, section titles and prices.
- **UI / body:** a clean humanist sans (*Inter* is an acceptable fallback).

Mobile scale (390pt-wide frame):

| Token | Size / line height | Weight | Use |
| --- | --- | --- | --- |
| title-xl | 28 / 34 | Bold (display) | Screen headline ("Lapar? Masih ada yang hangat di dekatmu.") |
| title-l | 22 / 28 | Bold (display) | Detail title, big price ("Rp5.000") |
| title-m | 18 / 24 | Semibold | Section title ("Segera habis di sekitarmu"), card title |
| body | 15–16 / 22 | Regular | Body, inputs, chat |
| label | 13–14 / 18 | Semibold | Chips, badges, buttons |
| caption | 12 / 16 | Regular | Meta ("Lokasi kamu", timestamps) |

Web scale: hero display ~64/68, H2 ~40/48, body 18/28.

## Spacing & Radius

- 4/8 spacing system: 4, 8, 12, 16, 24, 32, 48, 64. Screen side padding is 16.
- Radius:
  - 8: small badges
  - 12: photo thumbnails and stat tiles
  - 16: cards, inputs and buttons
  - 20: large cards and the map card
  - full: chips, pills and the FAB
- Elevation: mostly flat with 1px `--border` outlines. Soft shadows only on the bottom nav, sheets and the FAB.

## Components

States for every interactive component: default, pressed, focused, disabled, loading.

#### Navigation

- *Bottom nav*: 5 items (Beranda, Peta, **Bagikan**, Pesan, Profil).
  - Bagikan is a raised green circular FAB with the PawonFood logo.
  - The active item is green with a bold label; inactive items use `--ink-muted`.
- *Top bar*: back button (white circle), centered title, optional action.
- *Step progress*: "Langkah N dari 3" with 3 segments (green when done, sand when pending).

#### Inputs & controls

- *Search field*: white, rounded, search icon, placeholder "Cari lauk, nasi, roti...".
- *Filter chips*: pill shape. Active is filled `--primary` with white text; inactive is white with a border. Scroll horizontally.
- *Text input*: white, 16 radius, border; error text below.
- *Quantity stepper*: "−" sand circle, value, "+" green circle.
- *Segmented control*: Gratis / Jual murah. Sand track; the selected segment is white.
- *Price input*: "Rp" prefix and "/porsi" suffix, plus the "Boleh ditawar" checkbox.
- *Time chips*: equal-width options (19.00 / 20.30 / 22.00). The selected chip is filled green.

#### Buttons

- *Primary*: filled `--primary`, cream/white text, 16 radius, 52–56 tall (e.g. "Bagikan sekarang", "Ambil · Rp5.000").
- *Outline*: white with a green outline (e.g. "Chat"). *Accent outline*: terracotta outline (e.g. "Tawar lagi").
- *Pill CTA*: compact green pill ("Lihat peta penuh", "Lihat detail").
- *Sticky bottom bar*: a white bar holding the main CTAs on detail and share screens.

#### Content

- *Food card*:
  - Left: square photo with an "✓ AI" white badge (top) and a terracotta "Sisa N porsi" badge (bottom).
  - Right: name, provider, tier tag, ~~original price~~ and the bold price (or **GRATIS**), a chat icon, and a distance pill.
- *Badges / pills*:
  - Tier tag: `--success-tint` background, green text.
  - Distance pill: sand.
  - Points pill: sand with a terracotta coin icon.
  - "Foto asli, dicek AI": white with a shield icon.
- *Stat tile*: white bordered tile with label, value and caption (Jarak / Ambil sebelum / Kategori).
- *Price box*: sand panel showing the struck-through and current price, plus a "Bisa ditawar" pill.
- *Quick-offer chips*: 3 equal outlined buttons (Rp3.000 / Rp4.000 / Tulis sendiri).
- *Avatar*: green circle with cream initials (e.g. "BS").
- *Mini-map card*: map sand background, dashed green 1 km radius, user dot, provider pins, a "Radius 1 km · bisa jalan kaki" label and a CTA.

#### Chat

- *Own bubble*: green with white text. *Other bubble*: white with a border. Timestamps sit below in caption style.
- *Offer bubble*: a green card with "Tawaran kamu", a big price and details.
- *Accepted card*: `--success-tint` panel with a check icon, "Tawaran Rp4.000 diterima", the pickup code in a white
  monospace box (PWN-4821) and a "Sudah saya ambil" button.
- *Quick replies*: outlined pills (Saya OTW / Masih ada? / Tawar lagi).
- *Composer*: rounded input and a green circular send button.
- *Thread row*: avatar, name, time, item · price, last message, plus a status label (Tawaran diterima / Siap diambil / Habis).
- *Safety banner*: muted note about not transferring money outside the app.

#### Profile

- *Level card*: shows the current tier and points, the "[X] poin lagi" text, and a 3-step tier track
  (Sekarang / Berikutnya / Puncak).
- *Impact stats*: 3 big numbers (porsi dibagikan, porsi diselamatkan, kg batal jadi sampah).
- *Reward row*: icon, title, cost and a "Tukar" button.
- *Settings list rows*.

**AI camera** (step 1 of the share flow)

- Dark full-screen layout (`--camera-bg`) with a rounded preview.
- Light-green bounding box labeled with the detected category (e.g. "Lauk matang").
- Status row: check icon and "Makanan terdeteksi, siap difoto".
- Large cream shutter button, with "Tips foto" and "Balik" on either side.
- While inference runs, show "AI sedang memindai..." with a green scan line moving up and down over the photo.

## Map

- Pins are price labels:
  - Paid: white with a terracotta outline.
  - Free ("Gratis"): white with a green outline.
  - Selected: filled green.
- The user location is a green dot in a white ring, inside a dashed 1 km radius circle.
- Dense areas use a **cluster** with a count instead of stacked pins.
- The selected pin opens a bottom preview card (photo, name, provider · porsi · deadline, price, walking time). Tapping the card opens the detail; there is no separate button.

## Voice & Copy

- Casual Indonesian addressed as "kamu". Short, warm and practical.
  Examples: "Lapar? Masih ada yang hangat di dekatmu.", "Semua sudah diisi. Cek sebentar, lalu bagikan."
- Tiers: **Sobat Pawon → Food Savior → Pahlawan Pangan**. Never use "Borjuis".
- Categories: *Lauk matang*, *Bahan mentah*. Filters: *Bisa jalan kaki*, *Sedang hangat*, *Makan gratis*.
- Prices: `Rp5.000` (dot thousands separator). Times: `20.30` (dot). Distance: `300 m`, `± 4 mnt jalan kaki`.

## Landing Page

Sections of `PawonFood UI.pdf`, from top to bottom:

1. **Nav**: logo; Cara kerja, Keamanan pangan, Untuk warung, Tentang; pill CTA "Unduh aplikasi".
2. **Hero** on `--primary-dark`:
   - Eyebrow "Dari dapur ke dapur · Yogyakarta".
   - Display headline "Masak kebanyakan? Bagikan, jangan buang." and a short explanation paragraph.
   - CTAs "Unduh aplikasi" / "Daftar jadi penyedia" with the line "Setiap foto makanan dicek AI sebelum tayang".
   - Phone mockup of the home screen.
3. **Mission statement**: "...dimulai dari satu porsi yang tidak jadi dibuang."
4. **Kenapa pakai PawonFood**: 4 benefits (Murah atau gratis, Cukup jalan kaki, Harga bisa ditawar, Fotonya asli),
   followed by a food marquee (Nasi rames ● Gorengan ● Sayur lodeh ● ...).
5. **Cara kerja**: "Satu aplikasi, dua sisi dapur", with two 3-step columns:
   *Kalau kamu lapar* and *Kalau kamu masak kebanyakan*.
6. **Yang membuat PawonFood berbeda**: numbered 01–03 (Dapur rumah ikut berbagi, Harga fleksibel, Keamanan dicek AI).
7. **Untuk warung, katering, dan ibu kos**:
   - Headline "Sisa dagangan jadi pemasukan, bukan sampah".
   - 3 benefits (jual sisa, tampil teratas, sertifikat) and the CTA "Daftarkan warungmu".
   - Photo placeholders.
8. **Final CTA**: "Dari dapur ke dapur, dalam jarak jalan kaki." with App Store / Google Play buttons.
9. **Footer**: Produk / Mitra / Tentang link columns, © 2026 PawonFood.

## Responsive

- App: designed for a 390pt-wide phone frame. Support 360–430pt widths with fluid cards.
- Web breakpoints:
  - Mobile: < 640px (hero stacks, phone mockup below the text)
  - Tablet: 640–1024px
  - Desktop: > 1024px (two-column hero)

## Accessibility

- Touch targets are at least 44×44pt; chips and quick replies are at least 40pt tall.
- Text on cream and white meets WCAG AA. Green `#2F5D39` on white or cream works for text and buttons.
- Meaning is never carried by color alone: badges always include text ("Sisa 2 porsi", "✓ AI", "Gratis").
- The camera screen announces the validation result as text, not only the bounding box color.


# Design system

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
--border:         #E5DED1   /* card and chip edges, dividers (decorative) */
--border-strong:  #8A8578   /* outline of controls: checkbox, radio, switch, text fields (3.4:1 on cream, WCAG 1.4.11) */
--accent:         #B15732   /* terracotta: "Sisa N porsi" badge, map pin ring, star rating */
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
| title-m | 18 / 24 | Semibold | Section title ("Pilihan untukmu di sekitar"), card title |
| body | 15–16 / 22 | Regular | Body, inputs, chat |
| label | 13–14 / 18 | Semibold | Chips, badges, buttons |
| caption | 12 / 16 | Regular | Meta ("Lokasi kamu", timestamps) |

Web scale: hero display ~64/68, H2 ~40/48, body 18/28.

## Spacing & radius

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

### Navigation

- *Bottom nav*: 5 items (Beranda, Peta, Bagikan, Pesan, Profil).
  - 68 dp tall plus the system gesture inset. The mockups draw the inset as a 24 px area under the bar with the Android
    gesture handle (a 108 x 4 pill, 8 px above the bottom edge) on every phone screen.
  - Bagikan is a raised green circular FAB with the PawonFood logo.
  - The active item is green with a bold label; inactive items use `--ink-muted`.
- *Top bar*: back button (white circle), centered title, optional action.
- *Step progress*: "Langkah N dari 3" with 3 segments (green when done, sand when pending).

### Inputs & controls

- *Search field*: white, rounded, search icon, placeholder "Cari lauk, nasi, roti...".
- *Filter chips*: pill shape. Active is filled `--primary` with white text; inactive is white with a border. Scroll horizontally.
- *Text input*: white, 16 radius, border; error text below.
- *Quantity stepper*: "−" sand circle, value, "+" green circle.
- *Segmented control*: Gratis / Jual murah. Sand track; the selected segment is white.
- *Price input*: full-width field with "Rp" prefix and "/porsi" suffix. Under it sits the "Boleh ditawar" checkbox row with a muted line "Pembeli bisa ajukan harga lewat chat" (`AppCheckbox.helper`).
- *Time chips*: equal-width options (19.00 / 20.30 / 22.00). The selected chip is filled green.

### Buttons

- *Primary*: filled `--primary`, cream/white text, 16 radius, 52–56 tall (e.g. "Bagikan sekarang", "Ambil · Rp5.000").
- *Outline*: white with a green outline (e.g. "Chat"). *Accent outline*: terracotta outline (e.g. "Tawar lagi").
- *Pill CTA*: compact green pill ("Lihat detail").
- *Sticky bottom bar*: a white bar holding the main CTAs on detail and share screens.

### Content

- *Food card*:
  - Left: square photo with an "✓ AI" white badge (top) and a terracotta "Sisa N porsi" badge (bottom).
  - Right: name, provider, tier tag, ~~original price~~ and the bold price (or "GRATIS"), a chat icon, and a distance pill.
- *Badges / pills*:
  - Tier tag: `--success-tint` background, green text.
  - Distance pill: sand.
  - Points pill: sand with a terracotta coin icon.
  - "Foto asli, dicek AI": white with a shield icon.
- *Stat tile*: white bordered tile with label, value and caption (Jarak / Ambil sebelum / Kategori).
- *Price box*: sand panel showing the struck-through and current price, plus a "Bisa ditawar" pill.
- *Quick-offer chips*: 3 equal outlined buttons (Rp3.000 / Rp4.000 / Tulis sendiri).
- *Avatar*: green circle with cream initials (e.g. "BS").
- *Mini-map card*: map sand background, dashed green 1 km radius, user dot, up to two food-photo pins
  (a small dot marks the spot and the photo circle sits beside it, clear of the other overlays), a "Radius 1 km ·
  bisa jalan kaki" label and a round green 48 px button bottom-right with the
  fluent:full-screen-maximize-16-filled icon (accessible label "Lihat peta penuh").

### Chat

- *Own bubble*: green with white text. *Other bubble*: white with a border. Timestamps sit below in caption style.
- *Offer bubble*: a green card with "Tawaran kamu", a big price and details.
- *Reservation card*: `--success-tint` panel with a check icon and "Tawaran Rp4.000 diterima". It carries the next
  step: "Pilih cara bayar" (+ "Lihat rute") until a payment method is chosen, then "Pindai QR" (+ "Lihat rute"), with
  a dark "Lunas" tag when paid by QRIS. The provider sees "Buka QR ambil". No pickup code.
- *Waiting card*: tint panel "Menunggu jawaban [penyedia]" with "Batalkan tawaran" while an offer is pending.
- *Quick replies*: outlined pills (Saya OTW / Masih ada? / Bisa diantar?).
- *Declined card*: tint panel "Tawaranmu belum diterima" with the provider's lowest price, a green "Tawar Rp… · ongkir Rp…"
  button and an accent-outline "Tawar lagi" button.
- *Composer*: a round outlined "+" (only while the user can still haggle) that opens the "Tawar" sheet (Tawar harga
  makanan / Tawar ongkir), the rounded input, and a green circular send button with the fluent:send-16-filled icon.
- *Thread row*: avatar, name, time, item · price, last message, plus a status label (Tawaran diterima / Siap diambil / Habis).
- *Safety banner*: muted note about not transferring money outside the app.

### Profile

- *Level card*: shows the current tier and points, the "[X] poin lagi" text, and a tier stepper: a line through three
  dots with the caption and tier name under each (Sekarang / Berikutnya / Top Impact).
- *Impact stats*: 3 big numbers (porsi dibagikan, porsi diselamatkan, kg batal jadi sampah).
- *Reward row*: icon, title, cost and a "Tukar" button.
- *Settings list rows*.

### AI camera

Step 1 of the share flow.

- Dark full-screen layout (`--camera-bg`) with a rounded preview.
- Plain camera: no bounding box, scan line or "memindai" label. Hint: "Arahkan kamera ke makanan".
- Large cream shutter button, with "Tips foto" and "Balik" on either side.
- The AI check runs in the background after the shutter. The review form (step 2) shows "AI sedang mengenali makanan..." with a small spinner, then fills in name, category, description and health tags. A photo the AI rejects is explained on the form with a "Foto ulang" button.
- The Figma hi-fi camera screens (C12–C14) still show the older box and status row.

## Motion

Motion is quiet and explains a change (what appeared, what was pressed, where a screen came from). No
confetti, parallax or decoration loops. Tokens live in `app/lib/core/motion/motion.dart`.

| Token | Value | Use |
| --- | --- | --- |
| fast | 150 ms | press feedback, small colour changes, toggles |
| base | 220 ms | chips, tabs, segmented thumb, radio dots, tab fades, cross-fades |
| slow | 320 ms | page pushes, sheets, cards appearing, success marks |
| stagger | 40 ms per item, max 8 items | list entrances |
| enter / exit / move | easeOutCubic / easeInCubic / easeInOutCubic | arriving / leaving / moving between positions |
| pop | easeOutBack | only small things: check marks, radio dots, a selected map pin. Things that pop start at 50-60 % scale with a fade, never from zero |

- **Press feedback:** buttons, chips and cards shrink to 0.97 (cards 0.98, icon buttons 0.92) while pressed and spring
  back on release. The shrink lets go as soon as the finger drags past the touch slop, so scrolling over a card never presses it.
- **Pages:** drill-in screens fade in while sliding 6% from the right; task flows (camera, scanner, payment, map
  picker) rise from below; result and auth screens cross-fade. Tabs fade through quickly (150 ms), with no movement.
- **Lists:** items rise 12 px and fade in, staggered, only on a screen's first appearance (not on scroll or filter).
- **State changes:** cards and notes cross-fade (`FadeSwitch`); the segmented thumb slides; numbers count up
  (points, impact, "+10 poin"); progress bars fill.
- **Success:** on full success screens (Pembayaran berhasil, Makanan terselamatkan!, Makananmu sudah tayang!,
  Voucher berhasil diklaim!) and on a successful QR scan, `--primary` floods the screen from the check (520 ms),
  holds while a large cream check draws (400 ms), then shrinks back into the round badge (560 ms, `exit`: it speeds
  up and stops dead at the badge, no slow landing), which plays one soft ring. The scan flood shrinks away into the
  viewfinder the same way and opens onto the review screen. This is the one
  deliberate large-surface motion; it never uses `pop`, absorbs taps while up, and never plays before a failure
  (an expired scan gets no green). Inline checks (the route arrival) just pop the circle and draw the check.
  Failure and clock marks pop in.
- **Live states:** the QR scan line sweeps (the camera has no AI scan line any more); "Menunggu ... memindai" fades in and out (opacity, never size); the scanner corners stay still;
  typing dots while an offer waits; the route marker walks along the path.
- **Welcome hero:** three food photos slide every 4 s (`slow`, `move`) with page dots under the photo; a manual swipe
  resets the timer, and the slide never starts under a finger or while another screen covers Welcome. It is the one sanctioned loop and does not auto-advance under reduced motion.
- **Reduced motion:** when the OS "remove animations" setting is on, every animation is skipped and final values show
  at once (`Motion.reduced`). Widget tests run in this mode.

## Map

- Pins are the food's photo in a circle, with no price on the pin (the preview card shows it):
  - Paid: terracotta ring.
  - Free: green ring.
  - Selected: a larger photo circle with a green ring.
  - The Beranda mini-map uses the same photo circle (smaller), beside a dot on the listing's exact spot.
- The user location is a green dot in a white ring, inside a dashed 1 km radius circle.
- Dense areas use a cluster with a count instead of stacked pins.
- The selected pin opens a bottom preview card (photo, name, provider · porsi · deadline, price, walking time). Tapping the card opens the detail; there is no separate button.

## Voice & copy

- Casual Indonesian addressed as "kamu". Short, warm and practical.
  Examples: "Lapar? Masih ada yang hangat di dekatmu.", "Semua sudah diisi. Cek sebentar, lalu bagikan."
- Tiers: **Pawon Friend → Pawon Elite → Pawon Hero**. Never use "Borjuis".
- Category chips (Beranda and Peta, intentionally English): *All*, *Ready-to-Eat*, *Fresh Ingredient*, *Sealed Food*.
  Filters (Semua makanan only): *Bisa jalan kaki*, *Sedang hangat*, *Makan gratis*.
- Card labels (one per card, in this priority): *Hampir habis*, *Segar* (fresh raw ingredients), *Sehat* (health tags),
  *Populer*, *Terbaru*. Sort options on Semua makanan: *Rekomendasi*, *Terdekat*, *Segera habis*. The labels and the
  "Pilihan sehat" / "Ide resep" sections are not in the Figma yet.
- Prices: `Rp5.000` (dot thousands separator). Times: `20.30` (dot). Distance: `300 m`, `± 4 mnt jalan kaki`.

## Landing page

Built in `/web` (Next.js). Sections of `PawonFood UI.pdf`, from top to bottom, with the 2026-10-16 audit changes:

1. **Nav**: logo; Cara kerja, Keamanan pangan, Untuk penyedia, Tentang (each links to a real section); pill CTA "Unduh aplikasi". Hamburger menu below 900 px.
2. **Hero** on `--primary-dark` with a wood-grain texture:
   - Eyebrow "Hyperlocal Community Food Rescue Platform".
   - Display headline "Masak kebanyakan? Bagikan, jangan buang." and a short paragraph that mentions pickup or delivery.
   - CTAs "Unduh aplikasi" / "Daftar jadi penyedia" with the line "Setiap foto makanan dicek AI sebelum tayang".
   - Phone mockup of the current Beranda (drawn in HTML/CSS) with two floating chips.
3. **Mission statement** (Tentang): "...dimulai dari satu porsi yang tidak jadi dibuang."
4. **Data band** "Kenapa ini penting": 23–48 juta ton, 5–19 juta ton, 80% from households (Bappenas 2021).
5. **Kenapa pakai PawonFood**: 4 benefits (Gratis/harga tetap/tawar, Jalan kaki atau diantar, Ambil dengan QR, Poin dampak), then a food marquee.
6. **Cara kerja**: "Satu aplikasi, dua sisi dapur", two 3-step columns: *Kalau kamu lapar* and *Kalau kamu masak kebanyakan*.
7. **Yang membuat PawonFood berbeda**: comparison table (category columns, no brand names): household sellers, no MoU, no commission, pickup or delivery, negotiable price, QR handover.
8. **Keamanan pangan**: camera-only photos checked by AI, pickup deadline with QR, open ratings with suspension; plus the "tempat bertemunya penjual dan pembeli" disclaimer.
9. **Untuk penyedia** ("Untuk dapur rumah, warung, dan katering"): tanpa MoU dan tanpa komisi, cukup foto, Sertifikat Dapur/Resto Peduli Lingkungan; CTA "Daftar jadi penyedia"; kitchen watercolour.
10. **Story band** on tan: "Dari dapur ke dapur, dalam jarak jalan kaki." with the hand-over watercolour. Text is `--ink` (cream on tan is only 2.1:1).
11. **Final CTA** "Mulai dari Pogung. Lalu seluruh Jogja." with App Store / Google Play buttons (links not set yet).
12. **Footer**: Produk / Mitra / Tentang link columns, © 2026 PawonFood, photo credits. The contact line shows only when `contactEmail` is set.

Wood texture: a grayscale tile (`public/textures/wood.jpg`, cut from the Figma render) blended with `overlay` over a flat green. The flat greens (hero `#3c6346`, Cara kerja `#324c37`, final CTA `#426a4c`) are measured from the Figma design, which renders lighter than the PDF.

## Responsive

- App: designed for a 390pt-wide phone frame. Support 360–430pt widths with fluid cards.
- Web breakpoints:
  - Mobile: < 640px (hero stacks, phone mockup below the text)
  - Tablet: 640–1024px
  - Desktop: > 1024px (two-column hero)

## Accessibility

- Touch targets are at least 44×44pt (map locate and ad close buttons 48). The one deliberate exception is the filter chip row (40pt tall, as in Figma).
- Control outlines (checkbox, radio, switch, text fields) use `--border-strong`, at least 3:1 against the surface; `--border` is only for card edges and dividers.
- Large text: no fixed heights on text containers. Cards whose text blocks are stacked (food cards, impact tiles, search field) size themselves with `textScaleOf(context)`; tab labels stop growing at 1.3×; rows use `Flexible`/`Wrap`; sheets and the Welcome sheet scroll when they outgrow the screen.
- Irreversible actions ask first with `confirmAction` (Keluar, Tolak tawaran, Batalkan tawaran). Buttons that start a navigation or a payment guard against a second tap.
- Rows built on `InkWell` inside `Semantics(excludeSemantics: true)` must also set `Semantics.onTap`, or screen readers cannot activate them.
- Text on cream and white meets WCAG AA. Green `#2F5D39` on white or cream works for text and buttons.
- Meaning is never carried by color alone: badges always include text ("Sisa 2 porsi", "✓ AI", "Gratis").
- The camera screen announces the validation result as text, not only the bounding box color.

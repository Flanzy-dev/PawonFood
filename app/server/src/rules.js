// The rules layer: turns a validated visual observation into a listing decision. The model never decides this.
// The check only tells food from not food. It does not judge freshness or spoilage; the provider's declaration does.
// Order matters: a non-food photo is rejected before quality is considered.

export const REASONS = {
  notFood: 'Gambar terdeteksi bukan makanan. Mohon foto ulang.',
  blurry: 'Foto buram. Pegang kamera lebih stabil, lalu foto ulang.',
  too_dark: 'Foto terlalu gelap. Cari tempat yang lebih terang, lalu foto ulang.',
  obstructed: 'Makanan tertutup sebagian. Pastikan makanan terlihat jelas, lalu foto ulang.',
  too_far: 'Makanan terlalu kecil di foto. Dekatkan kamera, lalu foto ulang.',
  unknownCategory: 'AI belum yakin kategorinya. Pilih kategori yang sesuai sebelum membagikan.',
  approved: 'Foto lolos validasi',
};

/** Returns `{decision, listing_eligible, reason}` for an observation from schema.parseObservation. */
export function decide(obs) {
  if (!obs.is_food || obs.category === 'bukan_makanan') {
    return { decision: 'rejected', listing_eligible: false, reason: REASONS.notFood };
  }
  if (obs.image_quality !== 'good') {
    return { decision: 'retake', listing_eligible: false, reason: REASONS[obs.image_quality] };
  }
  if (obs.category === 'unknown') {
    return { decision: 'pending_review', listing_eligible: true, reason: REASONS.unknownCategory };
  }
  return { decision: 'approved', listing_eligible: true, reason: REASONS.approved };
}

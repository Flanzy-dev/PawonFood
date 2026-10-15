// Strict validation of the model's answer. Anything that does not fit the contract is a ModelResponseError, so a
// malformed answer can never turn into an approval.

export const CATEGORIES = ['makanan_matang', 'bahan_mentah', 'makanan_kemasan', 'bukan_makanan', 'unknown'];
export const VISUAL_CONDITIONS = ['no_visible_issues', 'minor_concerns', 'visible_spoilage', 'cannot_assess'];
export const IMAGE_QUALITIES = ['good', 'blurry', 'too_dark', 'obstructed', 'too_far'];

export const MAX_NOTES = 8;
export const MAX_NOTE_LENGTH = 80;
export const MAX_NAME_LENGTH = 60;

// Other spellings of the app's category keys that a model may plausibly use.
const CATEGORY_ALIASES = { sealed_food: 'makanan_kemasan' };

export class ModelResponseError extends Error {}

/** Pulls the JSON object out of the model text: drops reasoning blocks and code fences, keeps the outermost braces. */
export function extractJson(text) {
  if (typeof text !== 'string') throw new ModelResponseError('model content is not text');
  const cleaned = text.replace(/<think>[\s\S]*?<\/think>/gi, '').replace(/```(?:json)?/gi, '');
  const start = cleaned.indexOf('{');
  const end = cleaned.lastIndexOf('}');
  if (start < 0 || end <= start) throw new ModelResponseError('no JSON object in model content');
  try {
    return JSON.parse(cleaned.slice(start, end + 1));
  } catch {
    throw new ModelResponseError('model content is not valid JSON');
  }
}

const clean = (s) => s.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim();

// Notes that claim a confidence score or certify safety are dropped: the model was told not to make them, and the
// app must never show them as if PawonFood had checked the food.
const FORBIDDEN_NOTE = /\d+(?:[.,]\d+)?\s*%|aman (?:untuk )?dikonsumsi|aman dimakan|layak (?:makan|konsumsi)|safe to eat|safe for consumption|kedaluwarsa \d|expire/i;

function notes(value, field) {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw new ModelResponseError(`${field} is not a list`);
  const out = [];
  for (const item of value) {
    if (typeof item !== 'string') throw new ModelResponseError(`${field} has a non-text item`);
    const note = clean(item).slice(0, MAX_NOTE_LENGTH);
    if (note && !FORBIDDEN_NOTE.test(note) && !out.includes(note)) out.push(note);
    if (out.length === MAX_NOTES) break;
  }
  return out;
}

function oneOf(value, allowed, field) {
  if (typeof value !== 'string') throw new ModelResponseError(`${field} is missing`);
  const v = value.trim().toLowerCase();
  if (!allowed.includes(v)) throw new ModelResponseError(`${field} has an unexpected value`);
  return v;
}

/** Normalises the category; values outside the contract become "unknown" so the provider has to pick one. */
export function normalizeCategory(value) {
  if (typeof value !== 'string') return 'unknown';
  const v = value.trim().toLowerCase();
  const mapped = CATEGORY_ALIASES[v] ?? v;
  return CATEGORIES.includes(mapped) ? mapped : 'unknown';
}

/** Validates a parsed model answer and returns the visual observation (no eligibility fields). */
export function parseObservation(raw) {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) throw new ModelResponseError('model answer is not an object');
  if (typeof raw.is_food !== 'boolean') throw new ModelResponseError('is_food is missing');

  let foodName = null;
  if (raw.food_name !== undefined && raw.food_name !== null) {
    if (typeof raw.food_name !== 'string') throw new ModelResponseError('food_name is not text');
    foodName = clean(raw.food_name).slice(0, MAX_NAME_LENGTH) || null;
  }

  return {
    is_food: raw.is_food,
    category: normalizeCategory(raw.category),
    food_name: raw.is_food ? foodName : null,
    visual_condition: oneOf(raw.visual_condition, VISUAL_CONDITIONS, 'visual_condition'),
    visible_signs: notes(raw.visible_signs, 'visible_signs'),
    image_quality: oneOf(raw.image_quality, IMAGE_QUALITIES, 'image_quality'),
    warnings: notes(raw.warnings, 'warnings'),
  };
}

/** Model text in, validated observation out. */
export function parseModelOutput(text) {
  return parseObservation(extractJson(text));
}

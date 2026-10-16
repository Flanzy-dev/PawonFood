import assert from 'node:assert/strict';
import { test } from 'node:test';

import { MAX_DESCRIPTION_LENGTH, MAX_NOTES, ModelResponseError, parseModelOutput } from '../src/schema.js';
import { observation } from './helpers.js';

const parse = (o) => parseModelOutput(typeof o === 'string' ? o : JSON.stringify(o));

test('a well-formed answer passes through unchanged', () => {
  assert.deepEqual(parse(observation()), observation());
});

test('code fences, reasoning blocks and prose around the JSON are stripped', () => {
  const text = `<think>looks like fried chicken</think>Here you go:\n\`\`\`json\n${JSON.stringify(observation())}\n\`\`\``;
  assert.deepEqual(parse(text), observation());
});

test('extra fields such as confidence scores are dropped', () => {
  const r = parse({ ...observation(), confidence: 0.97, listing_eligible: true, safe: true });
  assert.equal('confidence' in r, false);
  assert.equal('listing_eligible' in r, false, 'eligibility never comes from the model');
});

test('unexpected categories become unknown; the sealed_food alias maps to makanan_kemasan', () => {
  assert.equal(parse(observation({ category: 'dessert' })).category, 'unknown');
  assert.equal(parse(observation({ category: 42 })).category, 'unknown');
  assert.equal(parse(observation({ category: 'Sealed_Food' })).category, 'makanan_kemasan');
  assert.equal(parse(observation({ category: ' BAHAN_MENTAH ' })).category, 'bahan_mentah');
});

test('notes are trimmed, capped, de-duplicated, and stripped of scores and safety claims', () => {
  const r = parse(observation({
    visible_signs: ['  jamur putih  ', 'jamur putih', '95% segar', 'aman dikonsumsi', 'x'.repeat(200), ...Array(20).fill(0).map((_, i) => `tanda ${i}`)],
  }));
  assert.equal(r.visible_signs[0], 'jamur putih');
  assert.equal(r.visible_signs.includes('95% segar'), false);
  assert.equal(r.visible_signs.includes('aman dikonsumsi'), false);
  assert.equal(r.visible_signs[1].length, 80);
  assert.equal(r.visible_signs.length, MAX_NOTES);
});

test('food_name is cleared for non-food and cut to 60 characters', () => {
  assert.equal(parse(observation({ is_food: false, category: 'bukan_makanan', food_name: 'Kursi' })).food_name, null);
  assert.equal(parse(observation({ food_name: 'n'.repeat(100) })).food_name.length, 60);
  assert.equal(parse(observation({ food_name: '   ' })).food_name, null);
});

test('description: optional, trimmed, cut to 160, cleared for non-food, claims and scores dropped', () => {
  assert.equal(parse(observation({ description: '  Nasi dan  ayam. ' })).description, 'Nasi dan ayam.');
  assert.equal(parse(observation({ description: 'd'.repeat(300) })).description.length, MAX_DESCRIPTION_LENGTH);
  assert.equal(parse(observation({ description: '   ' })).description, null);
  assert.equal(parse({ ...observation(), description: undefined }).description, null, 'older prompts send none');
  assert.equal(parse(observation({ description: 'Ayam goreng, aman dikonsumsi.' })).description, null);
  assert.equal(parse(observation({ description: 'Ayam goreng 95% matang.' })).description, null);
  assert.equal(parse(observation({ is_food: false, category: 'bukan_makanan', description: 'Sebuah kursi.' })).description, null);
  assert.throws(() => parse(observation({ description: 12 })), ModelResponseError);
});

test('malformed answers are errors, never defaults', () => {
  const bad = [
    'Sorry, I cannot help with that.',
    '{"is_food": true, "category": ',
    '[1, 2, 3]',
    JSON.stringify(observation({ is_food: 'yes' })),
    JSON.stringify({ ...observation(), is_food: undefined }),
    JSON.stringify(observation({ visual_condition: 'fresh' })),
    JSON.stringify(observation({ image_quality: undefined })),
    JSON.stringify(observation({ visible_signs: 'jamur' })),
    JSON.stringify(observation({ warnings: [1, 2] })),
    JSON.stringify(observation({ food_name: 12 })),
  ];
  for (const text of bad) assert.throws(() => parseModelOutput(text), ModelResponseError, text);
  assert.throws(() => parseModelOutput(null), ModelResponseError);
});

test('health_signals: allow-listed and deduplicated, missing means none, never for non-food', () => {
  assert.deepEqual(parse(observation({ health_signals: [' Protein ', 'protein', 'digoreng', 'superfood', 'rendah_gula'] })).health_signals, ['protein', 'digoreng']);
  const { health_signals: _, ...old } = observation();
  assert.deepEqual(parse(old).health_signals, [], 'answers from before the field still parse');
  assert.deepEqual(parse(observation({ is_food: false, category: 'bukan_makanan', health_signals: ['sayur_buah'] })).health_signals, []);
  assert.throws(() => parse(observation({ health_signals: 'protein' })), ModelResponseError);
  assert.throws(() => parse(observation({ health_signals: [1] })), ModelResponseError);
});

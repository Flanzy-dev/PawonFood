import assert from 'node:assert/strict';
import { test } from 'node:test';

import { decide, REASONS } from '../src/rules.js';
import { observation } from './helpers.js';

test('clear food in good condition is approved for each supported category', () => {
  for (const category of ['makanan_matang', 'bahan_mentah', 'makanan_kemasan']) {
    assert.deepEqual(decide(observation({ category })), { decision: 'approved', listing_eligible: true, reason: REASONS.approved });
  }
});

test('non-food is rejected, whatever else the model says', () => {
  assert.equal(decide(observation({ is_food: false, category: 'bukan_makanan' })).decision, 'rejected');
  assert.equal(decide(observation({ is_food: true, category: 'bukan_makanan' })).decision, 'rejected');
  assert.equal(decide(observation({ is_food: false, category: 'makanan_matang' })).decision, 'rejected');
  assert.equal(decide(observation({ is_food: false, image_quality: 'blurry' })).reason, REASONS.notFood);
});

test('poor image quality asks for a retake before any condition call is trusted', () => {
  for (const q of ['blurry', 'too_dark', 'obstructed', 'too_far']) {
    const r = decide(observation({ image_quality: q, visual_condition: 'visible_spoilage' }));
    assert.equal(r.decision, 'retake', q);
    assert.equal(r.listing_eligible, false);
    assert.equal(r.reason, REASONS[q]);
  }
  assert.equal(decide(observation({ visual_condition: 'cannot_assess' })).decision, 'retake');
});

test('visible spoilage is rejected', () => {
  const r = decide(observation({ visual_condition: 'visible_spoilage', visible_signs: ['jamur hijau'] }));
  assert.deepEqual(r, { decision: 'rejected', listing_eligible: false, reason: REASONS.spoilage });
});

test('unknown category and minor concerns go to review, still eligible', () => {
  assert.deepEqual(decide(observation({ category: 'unknown' })), { decision: 'pending_review', listing_eligible: true, reason: REASONS.unknownCategory });
  assert.deepEqual(decide(observation({ visual_condition: 'minor_concerns' })), { decision: 'pending_review', listing_eligible: true, reason: REASONS.minorConcerns });
});

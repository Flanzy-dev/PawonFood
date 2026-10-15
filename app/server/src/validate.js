// One validation: model observation → strict schema → rules layer. Returns the public response contract.

import { decide } from './rules.js';
import { parseModelOutput } from './schema.js';

/**
 * @returns {Promise<{is_food: boolean, category: string, food_name: string|null, visual_condition: string,
 *   visible_signs: string[], image_quality: string, warnings: string[], listing_eligible: boolean,
 *   decision: 'approved'|'pending_review'|'retake'|'rejected', reason: string}>}
 */
export async function validateFood(image, provider) {
  const text = await provider.describe(image);
  const observation = parseModelOutput(text);
  return { ...observation, ...decide(observation) };
}

import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { loadConfig } from '../src/config.js';
import { ProviderError } from '../src/qwen.js';
import { REASONS } from '../src/rules.js';
import { baseConfig, makeJpeg, makePng, observation, providerReturning, startApp } from './helpers.js';

const KEY = baseConfig().qwen.apiKey;
const photo = makeJpeg(1280, 720);

function post(url, body = photo, headers = { 'Content-Type': 'image/jpeg' }) {
  return fetch(`${url}/v1/food-validation`, { method: 'POST', body, headers });
}

describe('POST /v1/food-validation', () => {
  test('valid food: full contract with a server-side decision', async () => {
    const app = await startApp({ provider: providerReturning(observation({ category: 'bahan_mentah', food_name: 'Sayur bayam' })) });
    after(app.close);
    const res = await post(app.url);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('cache-control'), 'no-store');
    assert.deepEqual(await res.json(), {
      ...observation({ category: 'bahan_mentah', food_name: 'Sayur bayam' }),
      decision: 'approved',
      listing_eligible: true,
      reason: REASONS.approved,
    });
  });

  test('non-food, blurry and unknown-category photos', async () => {
    const cases = [
      [observation({ is_food: false, category: 'bukan_makanan', food_name: null }), 'rejected', false],
      [observation({ image_quality: 'blurry' }), 'retake', false],
      [observation({ category: 'kue_basah' }), 'pending_review', true],
    ];
    for (const [answer, decision, eligible] of cases) {
      const app = await startApp({ provider: providerReturning(answer) });
      const body = await (await post(app.url)).json();
      await app.close();
      assert.equal(body.decision, decision, JSON.stringify(answer));
      assert.equal(body.listing_eligible, eligible);
    }
  });

  test('a malformed model answer is a 502, never an approval', async () => {
    const app = await startApp({ provider: providerReturning('I think this is food, probably fine!') });
    after(app.close);
    const res = await post(app.url);
    assert.equal(res.status, 502);
    assert.equal((await res.json()).error.code, 'model_bad_response');
  });

  test('a model timeout is a 504 with a generic message', async () => {
    const app = await startApp({ provider: { describe: async () => { throw new ProviderError('model_timeout', 'no answer within 20000 ms'); } } });
    after(app.close);
    const res = await post(app.url);
    assert.equal(res.status, 504);
    assert.deepEqual(await res.json(), { error: { code: 'model_timeout', message: 'The AI check took too long. Try again.' } });
  });

  test('upstream errors never reach the client, and the API key never reaches the logs', async () => {
    const leaky = { describe: async () => { throw new ProviderError('model_unavailable', `upstream 401: Incorrect API key ${KEY}`); } };
    const app = await startApp({ provider: leaky });
    after(app.close);
    const res = await post(app.url);
    const text = await res.text();
    assert.equal(res.status, 502);
    assert.equal(text.includes('401'), false);
    assert.equal(text.includes(KEY), false);
    const log = app.lines.join('\n');
    assert.match(log, /"error":"model_unavailable"/);
    assert.match(log, /upstream 401/);
    assert.equal(log.includes(KEY), false);
  });

  test('logs one structured line per request without image data', async () => {
    const app = await startApp({ provider: providerReturning(observation()) });
    after(app.close);
    await post(app.url);
    const entry = JSON.parse(app.lines.at(-1));
    assert.equal(entry.event, 'request');
    assert.equal(entry.status, 200);
    assert.equal(entry.decision, 'approved');
    assert.equal(entry.image, '1280x720');
    assert.equal(typeof entry.req_id, 'string');
    assert.equal(app.lines.join('').includes(photo.toString('base64').slice(0, 24)), false);
  });

  describe('upload validation', () => {
    let app;
    before(async () => {
      app = await startApp({ provider: providerReturning(observation()) });
    });
    after(() => app.close());

    test('empty body → 400', async () => {
      assert.equal((await post(app.url, Buffer.alloc(0))).status, 400);
    });
    test('wrong or mismatched type → 415', async () => {
      assert.equal((await post(app.url, photo, { 'Content-Type': 'image/gif' })).status, 415);
      assert.equal((await post(app.url, makePng(800, 600))).status, 415);
      assert.equal((await post(app.url, Buffer.from('<svg/>'.repeat(50)))).status, 415);
    });
    test('too small → 422', async () => {
      const res = await post(app.url, makeJpeg(200, 200));
      assert.equal(res.status, 422);
      assert.equal((await res.json()).error.code, 'upload_invalid');
    });
    test('too large → 413', async () => {
      const big = Buffer.concat([photo, Buffer.alloc(70 * 1024)]);
      assert.equal((await post(app.url, big)).status, 413);
    });
  });

  test('rate limit → 429 with Retry-After', async () => {
    const app = await startApp({ provider: providerReturning(observation()), config: baseConfig({ rateLimitPerMin: 2 }) });
    after(app.close);
    assert.equal((await post(app.url)).status, 200);
    assert.equal((await post(app.url)).status, 200);
    const res = await post(app.url);
    assert.equal(res.status, 429);
    assert.ok(Number(res.headers.get('retry-after')) >= 1);
  });

  test('client token gate', async () => {
    const app = await startApp({ provider: providerReturning(observation()), config: baseConfig({ clientToken: 'pawon-demo-token' }) });
    after(app.close);
    assert.equal((await post(app.url)).status, 401);
    assert.equal((await post(app.url, photo, { 'Content-Type': 'image/jpeg', 'X-Pawon-Client': 'wrong' })).status, 401);
    assert.equal((await post(app.url, photo, { 'Content-Type': 'image/jpeg', 'X-Pawon-Client': 'pawon-demo-token' })).status, 200);
  });
});

describe('other routes', () => {
  test('healthz, 404 and 405', async () => {
    const app = await startApp({ provider: providerReturning(observation()) });
    after(app.close);
    assert.deepEqual(await (await fetch(`${app.url}/healthz`)).json(), { status: 'ok' });
    assert.equal((await fetch(`${app.url}/nope`)).status, 404);
    assert.equal((await fetch(`${app.url}/v1/food-validation`)).status, 405);
  });
});

describe('config', () => {
  test('the key comes from the environment; missing key or fake-in-production fail fast', () => {
    assert.equal(loadConfig({ QWEN_API_KEY: 'k' }).qwen.apiKey, 'k');
    assert.equal(loadConfig({ QWEN_API_KEY: 'k' }).qwen.model, 'qwen3-vl-plus');
    assert.throws(() => loadConfig({}), /QWEN_API_KEY/);
    assert.throws(() => loadConfig({ QWEN_PROVIDER: 'fake', NODE_ENV: 'production' }), /production/);
    assert.equal(loadConfig({ QWEN_PROVIDER: 'fake' }).provider, 'fake');
    assert.throws(() => loadConfig({ QWEN_API_KEY: 'k', MAX_UPLOAD_BYTES: 'lots' }), /MAX_UPLOAD_BYTES/);
  });
});

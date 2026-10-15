import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createQwenProvider, ProviderError } from '../src/qwen.js';
import { makeJpeg } from './helpers.js';

const KEY = 'sk-test-secret-key-123';
const image = { buffer: makeJpeg(800, 600), type: 'image/jpeg' };
const json = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
const provider = (fetchImpl, timeoutMs = 1000) => createQwenProvider({ apiKey: KEY, baseUrl: 'https://example.test/v1', model: 'qwen3-vl-plus', timeoutMs, fetchImpl });

async function providerError(promise) {
  try {
    await promise;
  } catch (e) {
    assert.ok(e instanceof ProviderError, `expected ProviderError, got ${e}`);
    return e;
  }
  assert.fail('expected a ProviderError');
}

test('sends an OpenAI-compatible request with the photo inline and the key only in the header', async () => {
  let seen;
  const p = provider(async (url, init) => {
    seen = { url, init, body: JSON.parse(init.body) };
    return json({ choices: [{ message: { content: '{"ok":1}' } }] });
  });
  assert.equal(await p.describe(image), '{"ok":1}');
  assert.equal(seen.url, 'https://example.test/v1/chat/completions');
  assert.equal(seen.init.headers.Authorization, `Bearer ${KEY}`);
  assert.equal(seen.body.model, 'qwen3-vl-plus');
  assert.equal(seen.body.temperature, 0);
  const parts = seen.body.messages[1].content;
  assert.match(parts[0].image_url.url, /^data:image\/jpeg;base64,/);
  assert.equal(seen.init.body.includes(KEY), false);
});

test('reasoning_effort is only sent when configured', async () => {
  const bodies = [];
  const capture = async (_url, init) => {
    bodies.push(JSON.parse(init.body));
    return json({ choices: [{ message: { content: '{}' } }] });
  };
  await provider(capture).describe(image);
  await createQwenProvider({ apiKey: 'ollama', baseUrl: 'http://localhost:11434/v1', model: 'qwen3.5:4b', timeoutMs: 1000, reasoningEffort: 'none', fetchImpl: capture }).describe(image);
  assert.equal('reasoning_effort' in bodies[0], false);
  assert.equal(bodies[1].reasoning_effort, 'none');
});

test('content given as a list of text parts is joined', async () => {
  const p = provider(async () => json({ choices: [{ message: { content: [{ type: 'text', text: '{"a":' }, { type: 'text', text: '1}' }] } }] }));
  assert.equal(await p.describe(image), '{"a":1}');
});

test('a slow upstream becomes model_timeout', async () => {
  const hang = (_url, init) => new Promise((_, reject) => init.signal.addEventListener('abort', () => reject(init.signal.reason)));
  const e = await providerError(provider(hang, 50).describe(image));
  assert.equal(e.code, 'model_timeout');
});

test('upstream HTTP errors become model_unavailable, with the key masked in the log detail', async () => {
  const e = await providerError(provider(async () => json({ error: { message: `Invalid key ${KEY}` } }, 401)).describe(image));
  assert.equal(e.code, 'model_unavailable');
  assert.match(e.detail, /^upstream 401/);
  assert.equal(e.detail.includes(KEY), false);
  assert.equal((await providerError(provider(async () => json({}, 500)).describe(image))).code, 'model_unavailable');
});

test('network failures become model_unavailable', async () => {
  const e = await providerError(provider(async () => { throw new TypeError('fetch failed', { cause: { code: 'ECONNREFUSED' } }); }).describe(image));
  assert.equal(e.code, 'model_unavailable');
  assert.match(e.detail, /ECONNREFUSED/);
});

test('non-JSON bodies and answers without text become model_bad_response', async () => {
  const html = async () => new Response('<html>gateway</html>', { status: 200 });
  assert.equal((await providerError(provider(html).describe(image))).code, 'model_bad_response');
  assert.equal((await providerError(provider(async () => json({ choices: [] })).describe(image))).code, 'model_bad_response');
  assert.equal((await providerError(provider(async () => json({ choices: [{ message: { content: null } }] })).describe(image))).code, 'model_bad_response');
});

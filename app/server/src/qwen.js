// Server-side client for a Qwen vision model behind an OpenAI-compatible chat/completions API (Alibaba Cloud Model
// Studio by default). The API key never leaves this process; upstream errors are reduced to a code for the client
// and a short detail for the log.

import { buildMessages } from './prompt.js';

export class ProviderError extends Error {
  /** @param {'model_timeout'|'model_unavailable'|'model_bad_response'} code */
  constructor(code, detail) {
    super(code);
    this.code = code;
    this.detail = detail;
  }
}

async function readSnippet(res) {
  try {
    return (await res.text()).slice(0, 300);
  } catch {
    return '';
  }
}

/** Text of the first choice; the content may be a string or a list of typed parts. */
function contentText(data) {
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    const text = content.filter((p) => p && p.type === 'text' && typeof p.text === 'string').map((p) => p.text).join('');
    if (text) return text;
  }
  return null;
}

export function createQwenProvider({ apiKey, baseUrl, model, timeoutMs, reasoningEffort = '', fetchImpl = globalThis.fetch }) {
  const redact = (s) => (apiKey ? String(s).split(apiKey).join('[redacted]') : String(s));

  return {
    name: 'qwen',
    model,
    /** Sends the photo to the model and returns its raw text answer. Throws ProviderError. */
    async describe({ buffer, type }) {
      const body = {
        model,
        temperature: 0,
        max_tokens: 800,
        messages: buildMessages(`data:${type};base64,${buffer.toString('base64')}`),
        ...(reasoningEffort ? { reasoning_effort: reasoningEffort } : {}),
      };
      let res;
      try {
        res = await fetchImpl(`${baseUrl}/chat/completions`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(timeoutMs),
        });
      } catch (e) {
        if (e?.name === 'TimeoutError' || e?.name === 'AbortError') throw new ProviderError('model_timeout', `no answer within ${timeoutMs} ms`);
        throw new ProviderError('model_unavailable', redact(`network error: ${e?.cause?.code ?? e?.name ?? 'unknown'}`));
      }
      if (!res.ok) {
        throw new ProviderError('model_unavailable', redact(`upstream ${res.status}: ${await readSnippet(res)}`));
      }
      let data;
      try {
        data = await res.json();
      } catch (e) {
        if (e?.name === 'TimeoutError' || e?.name === 'AbortError') throw new ProviderError('model_timeout', `no answer within ${timeoutMs} ms`);
        throw new ProviderError('model_bad_response', 'upstream body is not JSON');
      }
      const text = contentText(data);
      if (text === null) throw new ProviderError('model_bad_response', 'upstream answer has no text content');
      return text;
    },
  };
}

/** Local development without a key: every photo is described as cooked food in good condition. */
export function createFakeProvider(answer = FAKE_ANSWER) {
  return {
    name: 'fake',
    model: 'fake',
    async describe() {
      return typeof answer === 'function' ? answer() : answer;
    },
  };
}

export const FAKE_ANSWER = JSON.stringify({
  is_food: true,
  category: 'makanan_matang',
  food_name: 'Ayam goreng',
  visual_condition: 'no_visible_issues',
  visible_signs: [],
  image_quality: 'good',
  warnings: [],
});

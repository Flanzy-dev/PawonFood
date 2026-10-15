// Reads the server configuration from environment variables. Secrets stay in the environment, never in code.

export const DEFAULT_BASE_URL = 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1';
export const DEFAULT_MODEL = 'qwen3-vl-plus';

export class ConfigError extends Error {}

function int(env, name, fallback, min, max) {
  const raw = env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new ConfigError(`${name} must be an integer between ${min} and ${max}`);
  }
  return value;
}

export function loadConfig(env = process.env) {
  const provider = (env.QWEN_PROVIDER || 'qwen').toLowerCase();
  if (provider !== 'qwen' && provider !== 'fake') throw new ConfigError('QWEN_PROVIDER must be "qwen" or "fake"');
  if (provider === 'fake' && env.NODE_ENV === 'production') {
    throw new ConfigError('QWEN_PROVIDER=fake is not allowed in production: it would approve photos without a model');
  }
  const apiKey = env.QWEN_API_KEY || '';
  if (provider === 'qwen' && !apiKey) throw new ConfigError('QWEN_API_KEY is not set (or set QWEN_PROVIDER=fake for local development)');

  return {
    port: int(env, 'PORT', 8787, 0, 65535),
    host: env.HOST || '0.0.0.0',
    provider,
    qwen: {
      apiKey,
      baseUrl: (env.QWEN_BASE_URL || DEFAULT_BASE_URL).replace(/\/+$/, ''),
      model: env.QWEN_MODEL || DEFAULT_MODEL,
      timeoutMs: int(env, 'QWEN_TIMEOUT_MS', 20000, 1000, 120000),
      // Sent as `reasoning_effort` only when set. "none" turns thinking off on local Ollama models (qwen3.5), which
      // otherwise spend the token budget reasoning and never reach the JSON.
      reasoningEffort: env.QWEN_REASONING_EFFORT || '',
    },
    maxUploadBytes: int(env, 'MAX_UPLOAD_BYTES', 5 * 1024 * 1024, 1024, 20 * 1024 * 1024),
    rateLimitPerMin: int(env, 'RATE_LIMIT_PER_MIN', 10, 1, 100000),
    trustProxy: env.TRUST_PROXY === '1',
    clientToken: env.PAWON_CLIENT_TOKEN || '',
  };
}

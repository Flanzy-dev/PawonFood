// Entry point: `npm start` (reads .env when present).

import { ConfigError, loadConfig } from './config.js';
import { createLogger } from './log.js';
import { createFakeProvider, createQwenProvider } from './qwen.js';
import { createApp } from './server.js';

let config;
try {
  config = loadConfig();
} catch (e) {
  if (e instanceof ConfigError) {
    console.error(`Config error: ${e.message}`);
    process.exit(1);
  }
  throw e;
}

const log = createLogger({ secrets: [config.qwen.apiKey, config.clientToken] });
const provider = config.provider === 'fake' ? createFakeProvider() : createQwenProvider(config.qwen);
if (config.provider === 'fake') log('warn', 'fake_provider', { note: 'every photo is described as cooked food; development only' });

const server = createApp({ config, provider, log });
server.listen(config.port, config.host, () => {
  const { port } = server.address();
  log('info', 'listening', { port, provider: provider.name, model: provider.model, rate_limit_per_min: config.rateLimitPerMin });
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    log('info', 'shutdown', { signal });
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 5000).unref();
  });
}

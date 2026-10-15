// Tiny synthetic images: only the headers the server reads, so tests need no fixture files.

import { createApp } from '../src/server.js';
import { createLogger } from '../src/log.js';

export function makePng(width, height) {
  const buf = Buffer.alloc(33);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(buf, 0);
  buf.writeUInt32BE(13, 8);
  buf.write('IHDR', 12, 'latin1');
  buf.writeUInt32BE(width, 16);
  buf.writeUInt32BE(height, 20);
  buf.writeUInt8(8, 24); // bit depth
  buf.writeUInt8(2, 25); // colour type RGB
  return buf;
}

export function makeJpeg(width, height) {
  const app0 = Buffer.from([0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]);
  const sof = Buffer.alloc(19);
  sof.writeUInt16BE(0xffc0, 0);
  sof.writeUInt16BE(17, 2);
  sof.writeUInt8(8, 4);
  sof.writeUInt16BE(height, 5);
  sof.writeUInt16BE(width, 7);
  sof.writeUInt8(3, 9);
  const sos = Buffer.from([0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00]);
  return Buffer.concat([Buffer.from([0xff, 0xd8]), app0, sof, sos, Buffer.alloc(64, 0x11), Buffer.from([0xff, 0xd9])]);
}

export const observation = (overrides = {}) => ({
  is_food: true,
  category: 'makanan_matang',
  food_name: 'Ayam goreng',
  visual_condition: 'no_visible_issues',
  visible_signs: [],
  image_quality: 'good',
  warnings: [],
  health_signals: [],
  ...overrides,
});

export const baseConfig = (overrides = {}) => ({
  port: 0,
  host: '127.0.0.1',
  provider: 'fake',
  qwen: { apiKey: 'sk-test-secret-key-123', baseUrl: 'http://upstream.invalid', model: 'qwen3-vl-plus', timeoutMs: 1000 },
  maxUploadBytes: 64 * 1024,
  rateLimitPerMin: 100,
  trustProxy: false,
  clientToken: '',
  ...overrides,
});

/** Starts the app on a random port with the given provider. Returns `{url, lines, close}`; `lines` collects logs. */
export async function startApp({ provider, config = baseConfig() }) {
  const lines = [];
  const log = createLogger({ sink: (l) => lines.push(l), secrets: [config.qwen.apiKey, config.clientToken] });
  const server = createApp({ config, provider, log });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  return {
    url: `http://127.0.0.1:${port}`,
    lines,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

export const providerReturning = (answer) => ({ name: 'stub', model: 'stub', describe: async () => (typeof answer === 'string' ? answer : JSON.stringify(answer)) });

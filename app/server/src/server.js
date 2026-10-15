// HTTP layer: POST /v1/food-validation (raw JPEG/PNG body) and GET /healthz. Built on node:http with no dependencies.

import { randomUUID, timingSafeEqual } from 'node:crypto';
import http from 'node:http';

import { checkUpload, UploadError } from './image.js';
import { ProviderError } from './qwen.js';
import { createRateLimiter } from './rate_limit.js';
import { ModelResponseError } from './schema.js';
import { validateFood } from './validate.js';

// Messages for the client: generic on purpose. Provider status codes and bodies only go to the log.
const PUBLIC_ERRORS = {
  unauthorized: [401, 'Missing or invalid client token.'],
  rate_limited: [429, 'Too many requests. Try again shortly.'],
  model_timeout: [504, 'The AI check took too long. Try again.'],
  model_unavailable: [502, 'The AI check is unavailable right now. Try again.'],
  model_bad_response: [502, 'The AI check returned an unreadable answer. Try again.'],
  not_found: [404, 'Not found.'],
  method_not_allowed: [405, 'Method not allowed.'],
  internal: [500, 'Something went wrong. Try again.'],
};

function send(res, status, body, headers = {}) {
  const json = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(json),
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
    ...headers,
  });
  res.end(json);
}

function sendError(res, code, { message, status, headers } = {}) {
  const [defaultStatus, defaultMessage] = PUBLIC_ERRORS[code] ?? PUBLIC_ERRORS.internal;
  send(res, status ?? defaultStatus, { error: { code, message: message ?? defaultMessage } }, headers);
}

function tokenMatches(given, expected) {
  if (typeof given !== 'string') return false;
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

// Above `limit` the rest of the upload is read and discarded, so the client still gets a clean 413 (closing a socket
// with unread data makes it a connection reset). Far above it, the connection is cut instead.
const HARD_LIMIT_FACTOR = 4;

class BodyTooLargeError extends Error {}

/** Reads the body. Resolves to a Buffer, or null when it exceeded `limit`; rejects when it is absurdly large. */
function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const hardLimit = limit * HARD_LIMIT_FACTOR;
    const declared = Number(req.headers['content-length']);
    if (Number.isFinite(declared) && declared > hardLimit) {
      reject(new BodyTooLargeError());
      return;
    }
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > hardLimit) {
        req.removeAllListeners('data');
        reject(new BodyTooLargeError());
      } else if (size <= limit) {
        chunks.push(chunk);
      }
    });
    req.on('end', () => resolve(size > limit ? null : Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

const tooLarge = (config) => `The image is larger than ${config.maxUploadBytes} bytes.`;

function clientIp(req, trustProxy) {
  if (trustProxy) {
    const forwarded = req.headers['x-forwarded-for'];
    if (typeof forwarded === 'string' && forwarded.trim()) return forwarded.split(',')[0].trim();
  }
  return req.socket.remoteAddress ?? 'unknown';
}

/**
 * Creates the HTTP server (not yet listening).
 * @param {{config: object, provider: {describe: Function}, log: Function, now?: () => number}} deps
 */
export function createApp({ config, provider, log, now = Date.now }) {
  const limiter = createRateLimiter({ limit: config.rateLimitPerMin, now });

  async function validationRoute(req, res, ctx) {
    // Early answers still drain the upload (resume), so the client reads the status instead of a connection reset.
    if (config.clientToken && !tokenMatches(req.headers['x-pawon-client'], config.clientToken)) {
      req.resume();
      return sendError(res, 'unauthorized');
    }
    const slot = limiter.take(clientIp(req, config.trustProxy));
    if (!slot.ok) {
      req.resume();
      return sendError(res, 'rate_limited', { headers: { 'Retry-After': String(slot.retryAfterSec) } });
    }

    let body;
    try {
      body = await readBody(req, config.maxUploadBytes);
    } catch (e) {
      if (!(e instanceof BodyTooLargeError)) throw e;
      ctx.error = 'upload_too_large';
      res.on('finish', () => req.destroy());
      return sendError(res, 'upload_invalid', { status: 413, message: tooLarge(config), headers: { Connection: 'close' } });
    }
    if (body === null) {
      ctx.error = 'upload_too_large';
      return sendError(res, 'upload_invalid', { status: 413, message: tooLarge(config) });
    }
    ctx.bytes = body.length;
    const info = checkUpload(body, req.headers['content-type']);
    ctx.image = `${info.width}x${info.height}`;

    const result = await validateFood({ buffer: body, type: info.type }, provider);
    ctx.decision = result.decision;
    send(res, 200, result);
  }

  async function handle(req, res) {
    const started = now();
    const reqId = randomUUID();
    res.setHeader('X-Request-Id', reqId);
    const url = new URL(req.url ?? '/', 'http://localhost');
    const ctx = {};
    try {
      if (url.pathname === '/healthz') {
        if (req.method !== 'GET') return sendError(res, 'method_not_allowed');
        return send(res, 200, { status: 'ok' });
      }
      if (url.pathname === '/v1/food-validation') {
        if (req.method !== 'POST') return sendError(res, 'method_not_allowed', { headers: { Allow: 'POST' } });
        return await validationRoute(req, res, ctx);
      }
      return sendError(res, 'not_found');
    } catch (e) {
      if (e instanceof UploadError) {
        ctx.error = e.code;
        return sendError(res, e.code, { status: e.status, message: e.message });
      }
      if (e instanceof ProviderError) {
        ctx.error = e.code;
        ctx.detail = e.detail;
        return sendError(res, e.code);
      }
      if (e instanceof ModelResponseError) {
        ctx.error = 'model_bad_response';
        ctx.detail = e.message;
        return sendError(res, 'model_bad_response');
      }
      ctx.error = 'internal';
      ctx.detail = e?.message;
      return sendError(res, 'internal');
    } finally {
      log(res.statusCode >= 500 ? 'error' : 'info', 'request', {
        req_id: reqId,
        method: req.method,
        route: url.pathname,
        status: res.statusCode,
        ms: now() - started,
        ...ctx,
      });
    }
  }

  const server = http.createServer((req, res) => {
    handle(req, res).catch(() => {
      if (!res.headersSent) sendError(res, 'internal');
    });
  });
  // Limits for slow clients: the whole request must arrive within 30 s.
  server.requestTimeout = 30_000;
  server.headersTimeout = 15_000;
  return server;
}

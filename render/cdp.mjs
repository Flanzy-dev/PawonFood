// Minimal Chrome DevTools Protocol client over Node's built-in WebSocket: launch headless Chrome, attach to a page,
// evaluate, screenshot. Just enough for render.mjs, so the tool needs no npm dependencies.

import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const env = process.env;
const CANDIDATES = {
  win32: [
    `${env.PROGRAMFILES}\\Google\\Chrome\\Application\\chrome.exe`,
    `${env['PROGRAMFILES(X86)']}\\Google\\Chrome\\Application\\chrome.exe`,
    `${env.LOCALAPPDATA}\\Google\\Chrome\\Application\\chrome.exe`,
    `${env['PROGRAMFILES(X86)']}\\Microsoft\\Edge\\Application\\msedge.exe`,
    `${env.PROGRAMFILES}\\Microsoft\\Edge\\Application\\msedge.exe`,
  ],
  darwin: ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'],
  linux: ['/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/microsoft-edge'],
};

function findBrowser() {
  if (env.CHROME_PATH) return env.CHROME_PATH;
  const found = (CANDIDATES[process.platform] ?? []).find((p) => existsSync(p));
  if (!found) throw new Error('Chrome or Edge not found. Set CHROME_PATH to the browser executable.');
  return found;
}

class Connection {
  #ws;
  #id = 0;
  #pending = new Map();
  #listeners = new Set();

  constructor(ws) {
    this.#ws = ws;
    ws.addEventListener('message', ({ data }) => {
      const msg = JSON.parse(data);
      if (msg.id === undefined) {
        for (const fn of this.#listeners) fn(msg);
        return;
      }
      const call = this.#pending.get(msg.id);
      if (!call) return;
      this.#pending.delete(msg.id);
      if (msg.error) call.reject(new Error(`${call.method}: ${msg.error.message}`));
      else call.resolve(msg.result);
    });
    ws.addEventListener('close', () => {
      for (const call of this.#pending.values()) call.reject(new Error(`${call.method}: DevTools connection closed`));
      this.#pending.clear();
    });
  }

  send(method, params = {}, sessionId) {
    const id = ++this.#id;
    this.#ws.send(JSON.stringify({ id, method, params, sessionId }));
    return new Promise((resolve, reject) => this.#pending.set(id, { resolve, reject, method }));
  }

  /** Subscribes to protocol events. Returns an unsubscribe function. */
  on(fn) {
    this.#listeners.add(fn);
    return () => this.#listeners.delete(fn);
  }

  close() {
    this.#ws.close();
  }
}

/** Starts headless Chrome with a throwaway profile. Returns the browser connection and a close() that cleans up. */
export async function launch({ width, height }) {
  const profile = mkdtempSync(path.join(os.tmpdir(), 'pawon-render-'));
  const proc = spawn(
    findBrowser(),
    [
      '--headless=new',
      '--remote-debugging-port=0',
      `--user-data-dir=${profile}`,
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-extensions',
      '--mute-audio',
      '--hide-scrollbars',
      '--force-color-profile=srgb',
      '--force-device-scale-factor=1',
      `--window-size=${width},${height}`,
      '--disable-background-timer-throttling',
      '--disable-renderer-backgrounding',
      '--disable-backgrounding-occluded-windows',
      'about:blank',
    ],
    { stdio: ['ignore', 'ignore', 'pipe'] },
  );
  const exited = once(proc, 'exit').catch(() => {}); // a spawn failure is reported by the startup promise below
  try {
    const browser = await connect(proc);
    return { browser, close: () => shutdown(browser, proc, exited, profile) };
  } catch (err) {
    proc.kill();
    await exited;
    rmSync(profile, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
    throw err;
  }
}

async function connect(proc) {
  const endpoint = await new Promise((resolve, reject) => {
    let log = '';
    const timer = setTimeout(() => reject(new Error('Chrome did not open DevTools within 30 s')), 30_000);
    proc.stderr.on('data', (chunk) => {
      if (log === null) return; // keep draining stderr after startup so the pipe never fills
      log += chunk;
      const match = log.match(/DevTools listening on (ws:\/\/\S+)/);
      if (match) {
        log = null;
        clearTimeout(timer);
        resolve(match[1]);
      }
    });
    proc.once('error', (err) => {
      clearTimeout(timer);
      reject(err);
    });
    proc.once('exit', (code) => {
      clearTimeout(timer);
      reject(new Error(`Chrome exited (code ${code}) before DevTools was ready:\n${log ?? ''}`));
    });
  });

  const ws = new WebSocket(endpoint);
  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true });
    ws.addEventListener('error', () => reject(new Error(`Could not connect to ${endpoint}`)), { once: true });
  });
  return new Connection(ws);
}

async function shutdown(browser, proc, exited, profile) {
  await browser.send('Browser.close').catch(() => {});
  browser.close();
  const timeout = setTimeout(() => proc.kill(), 5_000);
  await exited;
  clearTimeout(timeout);
  // Chrome can hold profile files for a moment after exit on Windows.
  rmSync(profile, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}

const describe = (details) => details.exception?.description ?? details.text;

/** Opens a page target at a fixed viewport and collects its errors in `errors` (exceptions, console.error, failed loads). */
export async function openPage(browser, { width, height }) {
  const { targetId } = await browser.send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await browser.send('Target.attachToTarget', { targetId, flatten: true });
  const send = (method, params) => browser.send(method, params, sessionId);

  const errors = [];
  browser.on((msg) => {
    if (msg.sessionId !== sessionId) return;
    if (msg.method === 'Runtime.exceptionThrown') errors.push(describe(msg.params.exceptionDetails));
    else if (msg.method === 'Runtime.consoleAPICalled' && msg.params.type === 'error') errors.push(msg.params.args.map((a) => a.value ?? a.description).join(' '));
    else if (msg.method === 'Log.entryAdded' && msg.params.entry.level === 'error') errors.push(`${msg.params.entry.text} ${msg.params.entry.url ?? ''}`.trim());
  });
  const next = (method) =>
    new Promise((resolve) => {
      const off = browser.on((msg) => {
        if (msg.sessionId === sessionId && msg.method === method) {
          off();
          resolve(msg.params);
        }
      });
    });

  await send('Runtime.enable');
  await send('Page.enable');
  await send('Log.enable');
  await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });

  return {
    errors,
    async goto(url) {
      const loaded = next('Page.loadEventFired');
      const { errorText } = await send('Page.navigate', { url });
      if (errorText) throw new Error(`Could not load ${url}: ${errorText}`);
      await loaded;
    },
    async evaluate(expression, { awaitPromise = false } = {}) {
      const { result, exceptionDetails } = await send('Runtime.evaluate', { expression, awaitPromise, returnByValue: true });
      if (exceptionDetails) throw new Error(describe(exceptionDetails));
      return result.value;
    },
    async screenshot() {
      const { data } = await send('Page.captureScreenshot', { format: 'png', optimizeForSpeed: true, captureBeyondViewport: false });
      return Buffer.from(data, 'base64');
    },
  };
}

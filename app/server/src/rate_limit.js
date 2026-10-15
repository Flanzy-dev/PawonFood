// Fixed one-minute window per client key, in memory. Enough for one instance; a shared store is needed once the
// server scales out.

const WINDOW_MS = 60_000;
const MAX_TRACKED = 10_000;

export function createRateLimiter({ limit, now = Date.now }) {
  const windows = new Map();

  function prune(t) {
    for (const [key, w] of windows) if (t - w.start >= WINDOW_MS) windows.delete(key);
  }

  return {
    /** Counts one request. Returns `{ok: true}` or `{ok: false, retryAfterSec}`. */
    take(key) {
      const t = now();
      if (windows.size > MAX_TRACKED) prune(t);
      let w = windows.get(key);
      if (!w || t - w.start >= WINDOW_MS) {
        w = { start: t, count: 0 };
        windows.set(key, w);
      }
      if (w.count >= limit) return { ok: false, retryAfterSec: Math.max(1, Math.ceil((w.start + WINDOW_MS - t) / 1000)) };
      w.count += 1;
      return { ok: true };
    },
  };
}

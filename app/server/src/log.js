// Structured JSON-line logging. Callers never pass the image or the provider's raw body; as a second line of defence,
// every configured secret is masked in the serialized line.

export function createLogger({ sink = (line) => process.stdout.write(line + '\n'), secrets = [], now = () => new Date() } = {}) {
  const masked = secrets.filter((s) => typeof s === 'string' && s.length >= 4);
  return function log(level, event, fields = {}) {
    let line = JSON.stringify({ ts: now().toISOString(), level, event, ...fields });
    for (const s of masked) line = line.split(s).join('[redacted]');
    sink(line);
  };
}

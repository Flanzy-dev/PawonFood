// Upload checks: type by magic bytes (the Content-Type header alone is not trusted), size and pixel dimensions.
// Images are only held in memory for the request; nothing is written to disk.

export const MIN_SIDE = 320;
export const MAX_SIDE = 4096;

export class UploadError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function pngInfo(buf) {
  // Signature, then the IHDR chunk: length (4), "IHDR" (4), width (4), height (4).
  if (buf.length < 24 || buf.toString('latin1', 12, 16) !== 'IHDR') return null;
  return { type: 'image/png', width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

// SOF0..SOF15 carry the frame size, except DHT (C4), JPG (C8) and DAC (CC).
const isSof = (m) => m >= 0xc0 && m <= 0xcf && m !== 0xc4 && m !== 0xc8 && m !== 0xcc;

function jpegInfo(buf) {
  let i = 2;
  while (i + 3 < buf.length) {
    if (buf[i] !== 0xff) return null;
    let marker = buf[i + 1];
    while (marker === 0xff && i + 2 < buf.length) marker = buf[++i + 1]; // fill bytes
    if (marker === 0xd8 || marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      i += 2; // markers without a length
      continue;
    }
    if (marker === 0xd9 || marker === 0xda) return null; // end of image or scan data before any frame header
    if (i + 3 >= buf.length) return null;
    const length = buf.readUInt16BE(i + 2);
    if (length < 2) return null;
    if (isSof(marker)) {
      if (i + 8 >= buf.length) return null;
      return { type: 'image/jpeg', height: buf.readUInt16BE(i + 5), width: buf.readUInt16BE(i + 7) };
    }
    i += 2 + length;
  }
  return null;
}

/** Returns `{type, width, height}` for a JPEG or PNG buffer, or null when the bytes are neither (or are truncated). */
export function sniffImage(buf) {
  if (buf.length >= 8 && buf.subarray(0, 8).equals(PNG_SIGNATURE)) return pngInfo(buf);
  if (buf.length >= 4 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return jpegInfo(buf);
  return null;
}

/** Validates an uploaded photo. Throws [UploadError] with an HTTP status; returns the sniffed info on success. */
export function checkUpload(buf, contentType) {
  if (!buf || buf.length === 0) throw new UploadError(400, 'upload_invalid', 'The request has no image.');
  const declared = (contentType || '').split(';')[0].trim().toLowerCase();
  if (declared !== 'image/jpeg' && declared !== 'image/png') {
    throw new UploadError(415, 'upload_invalid', 'Send the photo as image/jpeg or image/png.');
  }
  const info = sniffImage(buf);
  if (!info) throw new UploadError(415, 'upload_invalid', 'The file is not a readable JPEG or PNG image.');
  if (info.type !== declared) throw new UploadError(415, 'upload_invalid', 'The image type does not match the Content-Type header.');
  const short = Math.min(info.width, info.height);
  const long = Math.max(info.width, info.height);
  if (short < MIN_SIDE || long > MAX_SIDE) {
    throw new UploadError(422, 'upload_invalid', `Image sides must be between ${MIN_SIDE} and ${MAX_SIDE} px.`);
  }
  return info;
}

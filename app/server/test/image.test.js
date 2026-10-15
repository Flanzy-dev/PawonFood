import assert from 'node:assert/strict';
import { test } from 'node:test';

import { checkUpload, sniffImage } from '../src/image.js';
import { makeJpeg, makePng } from './helpers.js';

test('reads PNG and JPEG dimensions from the headers', () => {
  assert.deepEqual(sniffImage(makePng(1280, 720)), { type: 'image/png', width: 1280, height: 720 });
  assert.deepEqual(sniffImage(makeJpeg(720, 1280)), { type: 'image/jpeg', width: 720, height: 1280 });
});

test('unknown bytes and truncated headers are not images', () => {
  assert.equal(sniffImage(Buffer.from('GIF89a........')), null);
  assert.equal(sniffImage(Buffer.from('%PDF-1.7')), null);
  assert.equal(sniffImage(makePng(800, 600).subarray(0, 20)), null);
  assert.equal(sniffImage(makeJpeg(800, 600).subarray(0, 24)), null);
});

test('checkUpload accepts a camera-sized JPEG', () => {
  assert.equal(checkUpload(makeJpeg(1280, 720), 'image/jpeg').type, 'image/jpeg');
  assert.equal(checkUpload(makePng(1080, 1920), 'image/png; charset=binary').type, 'image/png');
});

test('checkUpload rejects empty bodies, other types, mismatches and bad sizes', () => {
  const code = (fn) => {
    try {
      fn();
    } catch (e) {
      return e.status;
    }
    return 200;
  };
  assert.equal(code(() => checkUpload(Buffer.alloc(0), 'image/jpeg')), 400);
  assert.equal(code(() => checkUpload(makeJpeg(800, 600), 'image/gif')), 415);
  assert.equal(code(() => checkUpload(makeJpeg(800, 600), undefined)), 415);
  assert.equal(code(() => checkUpload(Buffer.from('not an image at all'), 'image/jpeg')), 415);
  assert.equal(code(() => checkUpload(makePng(800, 600), 'image/jpeg')), 415, 'declared type must match the bytes');
  assert.equal(code(() => checkUpload(makeJpeg(200, 900), 'image/jpeg')), 422, 'too small');
  assert.equal(code(() => checkUpload(makeJpeg(5000, 900), 'image/jpeg')), 422, 'too large');
});

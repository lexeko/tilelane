// Verify the rendered fixture with Node's built-ins and the existing ImageMagick tool.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const [folder, backend] = process.argv.slice(2);
const log = fs.readFileSync(path.join(folder, 'runtime.log'), 'utf8');
assert(!['TypeError', 'ReferenceError', 'Binding loop', 'Failed to load configuration'].some(error => log.includes(error)), log);
const line = log.split('\n').find(line => line.includes('STATUS_METRICS '));
assert(line, 'Missing rendered status metrics');
const metrics = JSON.parse(line.split('STATUS_METRICS ')[1]);
assert.equal(metrics.length, 40, 'Missing status fixture cells');
for (const item of metrics) {
  if (['Dropbox', 'Tailscale'].includes(item.name))
    assert(Math.abs(item.paintedSize - item.target) < 0.05, JSON.stringify(item));
}
const image = path.join(folder, 'icons.png');
const [width, height] = execFileSync('magick', [image, '-format', '%w %h', 'info:'], { encoding: 'utf8' }).trim().split(/\s+/).map(Number);
const raw = execFileSync('magick', [image, '-depth', '8', 'rgb:-'], { maxBuffer: width * height * 3 + 1024 });
assert.equal(raw.length, width * height * 3);
const dpr = width / 800;
assert.equal(height / 320, dpr);
const cellSize = Math.round(80 * dpr);
for (const [index, item] of metrics.entries()) {
  const col = index % 10, row = Math.floor(index / 10);
  let left = cellSize, right = -1, top = cellSize, bottom = -1;
  for (let y = 0; y < cellSize; y++) {
    for (let x = 0; x < cellSize; x++) {
      const offset = ((row * cellSize + y) * width + col * cellSize + x) * 3;
      if (Math.max(raw[offset], raw[offset + 1], raw[offset + 2]) <= 16) continue;
      left = Math.min(left, x); right = Math.max(right, x);
      top = Math.min(top, y); bottom = Math.max(bottom, y);
    }
  }
  // Qt's software scene graph omits Shapes; GPU verifies Dropbox's pixels.
  // The native painted-bounds assertion above still applies in software mode.
  if (item.name === 'Dropbox' && right === -1 && backend === 'software') continue;
  assert(right >= 0, JSON.stringify(item));
  const extent = Math.max(right - left + 1, bottom - top + 1) / dpr;
  assert(Math.abs(extent - item.target) <= 1.5, JSON.stringify({ item, extent }));
  assert(Math.abs((left + right + 1) / 2 / dpr - 40) <= 1, item.name + ': horizontal center');
  assert(Math.abs((top + bottom + 1) / 2 / dpr - 40) <= 1, item.name + ': vertical center');
}
console.log('status icons: pass (native Dropbox/Tailscale, panel/battery/weather glyphs, tray; four UI scales)');

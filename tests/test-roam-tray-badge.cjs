const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const helper = path.join(__dirname, '../scripts/roam-tray-badge');

function image({ dot = null, width = 48, height = 48, alpha = 255 } = {}) {
    const pixels = Array(width * height * 4).fill(0);
    if (dot) {
        for (let y = dot.y; y < dot.y + 4; y++) {
            for (let x = dot.x; x < dot.x + 4; x++) {
                const offset = (y * width + x) * 4;
                pixels.splice(offset, 4, alpha, ...dot.color);
            }
        }
    }
    return { type: 'a(iiay)', data: [[width, height, pixels]] };
}

function classify(input) {
    const result = spawnSync(helper, ['--classify'], {
        input: JSON.stringify(input),
        encoding: 'utf8'
    });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.trim();
}

const red = [237, 86, 86];
assert.equal(classify(image({ dot: { x: 34, y: 8, color: red } })), '1');
assert.equal(classify(image()), '0');
assert.equal(classify(image({ dot: { x: 5, y: 8, color: red } })), '0');
assert.equal(classify(image({ dot: { x: 34, y: 8, color: [86, 86, 237] } })), '0');
assert.equal(classify(image({ dot: { x: 34, y: 8, color: red }, alpha: 0 })), '0');

const short = image({ dot: { x: 34, y: 8, color: red } });
short.data[0][2].pop();
assert.equal(classify(short), '');
assert.equal(classify(image({ width: 65, height: 48 })), '');
assert.equal(classify({ type: 's', data: [] }), '');

const invalidId = spawnSync(helper, ['Roam_status_icon_1_extra'], { encoding: 'utf8' });
assert.equal(invalidId.status, 0, invalidId.stderr);
assert.equal(invalidId.stdout, '');

function runWithFakeBusctl(payloadText) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tilelane-roam-badge-'));
    try {
        const payloadPath = path.join(dir, 'pixmap.json');
        fs.writeFileSync(payloadPath, payloadText);
        const busctlPath = path.join(dir, 'busctl');
        fs.writeFileSync(busctlPath, `#!/usr/bin/env bash
set -euo pipefail
case "\${*: -1}" in
  RegisteredStatusNotifierItems) printf '{"type":"as","data":[":1.42/StatusNotifierItem"]}\\n' ;;
  Id) printf '{"type":"s","data":"Roam_status_icon_1"}\\n' ;;
  IconPixmap) cat "${payloadPath}" ;;
esac
`, { mode: 0o755 });
        return spawnSync(helper, ['Roam_status_icon_1'], {
            encoding: 'utf8',
            env: { ...process.env, PATH: `${dir}:${process.env.PATH}` }
        });
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
}

// Multi-size SNI IconPixmap payload exceeding 128 KiB JSON (e.g. 128px + 48px).
const multiSize = {
    type: 'a(iiay)',
    data: [
        [128, 128, Array(128 * 128 * 4).fill(0)],
        image({ dot: { x: 34, y: 8, color: red } }).data[0]
    ]
};
const multiJson = JSON.stringify(multiSize);
assert.ok(multiJson.length > 131072, 'Expected multi-size payload > 128 KiB');
const multiResult = runWithFakeBusctl(multiJson);
assert.equal(multiResult.status, 0, multiResult.stderr);
assert.equal(multiResult.stdout.trim(), '1');

// Oversized payload (> 2 MiB) is skipped cleanly without failing.
const oversized = runWithFakeBusctl('x'.repeat(2097152 + 64));
assert.equal(oversized.status, 0, oversized.stderr);
assert.equal(oversized.stdout.trim(), '');

process.stdout.write('11 Roam badge cases passed\n');

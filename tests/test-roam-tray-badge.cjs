const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
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

process.stdout.write('9 Roam badge cases passed\n');

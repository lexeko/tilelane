// Check owned text surfaces and render the production bookmark label.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
function qmlFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? qmlFiles(file) : entry.name.endsWith('.qml') ? [file] : [];
  }).sort();
}
const blocks = [];
for (const file of [path.join(root, 'Bar.qml'), ...qmlFiles(path.join(root, 'qml'))]) {
  const source = fs.readFileSync(file, 'utf8');
  // Formatted QML closes each object at its opening indentation. TextMetrics
  // and TextInput are deliberately excluded.
  const found = [...source.matchAll(/^([ \t]*)(?:contentItem: )?Text \{\n.*?^\1\}/gms)];
  assert.equal(found.length, [...source.matchAll(/\bText\s*\{/g)].length,
    `Unrecognized Text declaration: ${file}`);
  blocks.push(...found.map(match => ({ file, text: match[0] })));
}
const bookmark = blocks.filter(block => path.basename(block.file) === 'StartMenu.qml'
  && block.text.includes('placeRow.modelData.name'));
assert.equal(bookmark.length, 1, 'Production bookmark label not found');

const work = fs.mkdtempSync(path.join(os.tmpdir(), 'tilelane-plain-text-'));
try {
  fs.copyFileSync(path.join(root, 'qml/PlacesLogic.js'), path.join(work, 'PlacesLogic.js'));
  fs.writeFileSync(path.join(work, 'Commons.js'), '.pragma library\nvar Color = {menu: {text: "white"}};\n'
    + 'var Style = {font: {menuFamily: "sans-serif", body: 14}};\n');
  const fixture = fs.readFileSync(path.join(__dirname, 'fixtures/bookmark-text.qml.in'), 'utf8');
  const indent = bookmark[0].text.match(/^[ \t]*/)[0];
  const label = bookmark[0].text.split('\n').map(line => line.startsWith(indent) ? line.slice(indent.length) : line).join('\n');
  fs.writeFileSync(path.join(work, 'tst_BookmarkText.qml'), fixture.replace('BOOKMARK_TEXT_OBJECT', () => label));
  const runner = fs.existsSync('/usr/lib/qt6/bin/qmltestrunner') ? '/usr/lib/qt6/bin/qmltestrunner' : 'qmltestrunner';
  const result = spawnSync(runner, ['-input', work], {
    env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', QSG_RHI_BACKEND: 'software' },
    encoding: 'utf8', timeout: 30000,
  });
  process.stdout.write((result.stdout || '') + (result.stderr || ''));
  if (result.error) throw result.error;
  assert.equal(result.status, 0, 'Production bookmark rendering failed');
} finally {
  fs.rmSync(work, { recursive: true, force: true });
}

const unsafe = blocks.filter(block => !/\btextFormat:\s*Text\.PlainText\b/.test(block.text));
assert.equal(unsafe.length, 0, `Text surfaces without explicit plain text: ${unsafe.map(b => path.relative(root, b.file)).join(', ')}`);
assert(blocks.length, 'No production Text surfaces checked');
console.log(`plain text: pass (${blocks.length} owned surfaces; production bookmark rendering)`);

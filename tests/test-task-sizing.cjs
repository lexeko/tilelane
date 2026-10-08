// Exercise production task sizing and reactive layout without desktop windows.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFile, spawn } = require('node:child_process');
const { promisify } = require('node:util');
const { setTimeout: delay } = require('node:timers/promises');

const run = promisify(execFile);
const root = path.resolve(__dirname, '..');
const omarchy = process.env.OMARCHY_PATH || '/usr/share/omarchy';

async function main() {
  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'tilelane-task-sizing-'));
  let shell;
  let exited;
  let log = '';
  try {
    fs.cpSync(path.join(root, 'qml'), path.join(work, 'qml'), { recursive: true });
    fs.copyFileSync(path.join(__dirname, 'quickshell/task-sizing.qml'), path.join(work, 'shell.qml'));
    // Replace only the panel-window boundary. Layout uses production components.
    fs.writeFileSync(path.join(work, 'qml/components/TaskContextMenu.qml'), `import QtQuick
Item {
    property var anchorItem
    property var bar
    property var actions
    property var applicationCatalog
    property var pinnedApplications
    property string address: ""
    property string title: ""
    property string desktopId: ""
    property bool open: false
    property bool launcherOnly: false
    property bool minimized: false
    property bool fullscreen: false
    property bool maximized: false
    property bool floating: false
}
`);
    for (const name of ['Commons', 'Ui']) {
      fs.symlinkSync(path.join(omarchy, 'shell', name), path.join(work, name));
    }
    shell = spawn('quickshell', ['--path', work, '--no-color'], {
      env: { ...process.env, QT_QPA_PLATFORM: 'offscreen' },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    exited = new Promise(resolve => {
      shell.once('error', error => { log += error.message; resolve(); });
      shell.once('close', resolve);
    });
    shell.stdout.on('data', chunk => { log += chunk; });
    shell.stderr.on('data', chunk => { log += chunk; });
    async function ipc(method, ...args) {
      const result = await run('quickshell', ['ipc', '--pid', String(shell.pid),
        'call', 'test.tasks', method, ...args.map(String)], { timeout: 5000 });
      return result.stdout;
    }
    async function waitFor(predicate) {
      const deadline = performance.now() + 8000;
      let last;
      while (performance.now() < deadline) {
        try {
          last = JSON.parse(await ipc('state'));
          if (predicate(last)) return last;
        } catch { /* IPC may not be ready yet. */ }
        await delay(50);
      }
      throw new Error(`Layout did not settle: ${JSON.stringify(last)}`);
    }
    const configure = (width, titles, scale = 1, pinned = 0) =>
      ipc('configure', width, encodeURIComponent(JSON.stringify(titles)), scale, pinned);

    await waitFor(s => !s.tasks.length);
    const long = 'A long document title that should retain a readable beginning';
    await configure(700, ['~', 'Short', long, long]);
    const roomy = await waitFor(s => s.tasks.length === 4 && s.tasks[2].width === 224);
    // Diagnostics expose geometry and addresses, never window titles.
    for (const task of roomy.tasks) {
      assert.deepEqual(Object.keys(task).sort(), ['address', 'preferred', 'width']);
    }
    const shortWidth = roomy.tasks[0].width;
    assert(shortWidth > 42 && shortWidth < 80);
    assert(!roomy.overflow);
    assert(roomy.tasks.every(t => t.width === t.preferred));
    await configure(500, ['~', 'Short', long, long]);
    const compact = await waitFor(s => s.tasks[2].width > 105 && s.tasks[2].width < 224);
    assert(!compact.overflow);
    assert.equal(compact.tasks[0].width, shortWidth);
    assert(Math.abs(compact.tasks.reduce((sum, t) => sum + t.width, 0) + 12 - 500) < .01);
    await configure(300, ['~', 'Short', long, long]);
    const crowded = await waitFor(s => s.overflow && s.tasks[2].width === 105);
    assert.equal(crowded.tasks[0].width, shortWidth);
    await configure(300, ['~', 'Short']);
    await waitFor(s => s.tasks.length === 2 && !s.overflow);
    await configure(500, [long, long, long]);
    await waitFor(s => s.tasks.length === 3 && !s.overflow && s.tasks.every(t => t.width > 105 && t.width < 224));
    // Pin changes reduce available width without changing the tasks.
    await configure(450, [long, long, long], 1, 4);
    await waitFor(s => s.overflow && s.tasks.every(t => t.width === 105));
    await configure(500, ['~', '~', '~'], 1, 4);
    await waitFor(s => !s.overflow && s.tasks.every(t => t.width < 80));
    for (const scale of [1.25, 1.5, 2]) {
      await configure(315 * scale, [long, long, long], scale);
      await waitFor(s => s.overflow && s.tasks.every(t => Math.abs(t.width - 105 * scale) < .01));
      await configure(600 * scale, [long, long, long], scale);
      await waitFor(s => !s.overflow && s.tasks.every(t => t.width > 105 * scale && t.width < 224 * scale));
    }
    for (const scale of [1, 1.25, 1.5, 2]) {
      // Adding the fourth task crosses the overflow threshold after shrinking.
      await configure(400 * scale, [long, long, long], scale);
      await waitFor(s => s.tasks.length === 3 && !s.overflow);
      await configure(400 * scale, [long, long, long, long], scale);
      await waitFor(s => s.overflow && s.scrollOffset > 0
        && Math.abs(s.scrollOffset + s.viewportWidth - s.contentWidth) < .01);
      await ipc('scrollToStart');
      await waitFor(s => s.scrollOffset === 0);
      await configure(400 * scale, Array(8).fill(long), scale);
      await waitFor(s => s.tasks.length === 8
        && Math.abs(s.scrollOffset + s.viewportWidth - s.contentWidth) < .01);
      // Already visible insertions must not move the list; hidden insertions
      // are revealed on either side, clear of the 24px edge fades.
      await ipc('scrollToStart');
      await ipc('insert', 1, '0xinserted');
      await waitFor(s => s.tasks.length === 9 && s.scrollOffset === 0);
      await ipc('insert', 7, '0xright');
      await waitFor(s => s.tasks.length === 10 && s.scrollOffset > 0
        && fullyVisible(s, '0xright', scale));
      await ipc('insert', 2, '0xleft');
      const revealed = await waitFor(s => s.tasks.length === 11 && fullyVisible(s, '0xleft', scale));
      const savedOffset = revealed.scrollOffset;
      await ipc('focus', 10);
      await ipc('move', 9, 10);
      await configure(400 * scale, Array(11).fill(long + ' changed'), scale);
      await delay(100);
      assert.equal(JSON.parse(await ipc('state')).scrollOffset, savedOffset,
        'Focus, title changes, or reordering moved the scroll position');
      await ipc('scrollToStart');
      await ipc('transientTask');
      await delay(100);
      assert.equal(JSON.parse(await ipc('state')).scrollOffset, 0,
        'A task removed before layout moved the scroll position');
      await configure(400 * scale, [long, long], scale);
      await waitFor(s => s.tasks.length === 2 && !s.overflow && s.scrollOffset === 0);
    }
    function fullyVisible(s, address, scale) {
      const index = s.tasks.findIndex(t => t.address === address);
      if (index < 0) return false;
      const left = s.tasks.slice(0, index).reduce((sum, t) => sum + t.width + 4 * scale, 0);
      const right = left + s.tasks[index].width;
      const start = s.scrollOffset + (s.scrollOffset > .5 ? 24 * scale : 0);
      const end = s.scrollOffset + s.viewportWidth
        - (s.scrollOffset < s.contentWidth - s.viewportWidth - .5 ? 24 * scale : 0);
      return left >= start - .01 && right <= end + .01;
    }
    await configure(0, []);
    await waitFor(s => !s.tasks.length && !s.overflow);
    assert(!/TypeError|ReferenceError|Binding loop/.test(log), log);
    console.log('task sizing: pass (widths, 105px floor, overflow, new-task reveal, scroll preservation, removal, pins, scales, title omission)');
  } catch (error) {
    console.error(log);
    throw error;
  } finally {
    if (shell) {
      shell.kill();
      const forceKill = setTimeout(() => shell.kill('SIGKILL'), 5000);
      await exited;
      clearTimeout(forceKill);
    }
    fs.rmSync(work, { recursive: true, force: true });
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });

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
    const compact = await waitFor(s => s.tasks[2].width > 140 && s.tasks[2].width < 224);
    assert(!compact.overflow);
    assert.equal(compact.tasks[0].width, shortWidth);
    assert(Math.abs(compact.tasks.reduce((sum, t) => sum + t.width, 0) + 12 - 500) < .01);
    await configure(300, ['~', 'Short', long, long]);
    const crowded = await waitFor(s => s.overflow && s.tasks[2].width === 140);
    assert.equal(crowded.tasks[0].width, shortWidth);
    await configure(300, ['~', 'Short']);
    await waitFor(s => s.tasks.length === 2 && !s.overflow);
    await configure(500, [long, long, long]);
    await waitFor(s => s.tasks.length === 3 && !s.overflow && s.tasks.every(t => t.width > 140 && t.width < 224));
    // Pin changes reduce available width without changing the tasks.
    await configure(500, [long, long, long], 1, 4);
    await waitFor(s => s.overflow && s.tasks.every(t => t.width === 140));
    await configure(500, ['~', '~', '~'], 1, 4);
    await waitFor(s => !s.overflow && s.tasks.every(t => t.width < 80));
    for (const scale of [1.25, 1.5, 2]) {
      await configure(420 * scale, [long, long, long], scale);
      await waitFor(s => s.overflow && s.tasks.every(t => Math.abs(t.width - 140 * scale) < .01));
      await configure(600 * scale, [long, long, long], scale);
      await waitFor(s => !s.overflow && s.tasks.every(t => t.width > 140 * scale && t.width < 224 * scale));
    }
    await configure(0, []);
    await waitFor(s => !s.tasks.length && !s.overflow);
    console.log('task sizing: pass (natural width, compression, minimum, overflow, titles, removal, pins, scale, empty lane)');
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

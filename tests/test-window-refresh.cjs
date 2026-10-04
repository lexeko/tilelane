// Exercise the production model against an isolated Hyprland IPC fixture.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { execFile, spawn } = require('node:child_process');
const { promisify } = require('node:util');
const { setTimeout: delay } = require('node:timers/promises');

const run = promisify(execFile);
async function waitFor(predicate, message) {
  const deadline = performance.now() + 5000;
  while (performance.now() < deadline) {
    const value = await predicate();
    if (value) return value;
    await delay(20);
  }
  throw new Error(message);
}

async function main() {
  const root = path.resolve(__dirname, '..');
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'tilelane-window-refresh-'));
  const servers = [];
  const connections = new Set();
  const requests = [];
  let events;
  let shell;
  let exited;
  let log = '';
  let clients = [{
    address: '0xaaa', class: 'fixture', initialClass: 'fixture', title: 'Fixture',
    workspace: { id: 1, name: '1' }, monitor: 0, pid: 0, mapped: true,
    floating: false, stableId: '18000001', fullscreen: 0, xwayland: true,
  }];
  try {
    const models = path.join(folder, 'qml/models');
    fs.mkdirSync(models, { recursive: true });
    for (const name of ['WindowModel.qml', 'WindowState.js']) {
      fs.copyFileSync(path.join(root, 'qml/models', name), path.join(models, name));
    }
    fs.copyFileSync(path.join(__dirname, 'quickshell/window-refresh.qml'), path.join(folder, 'shell.qml'));
    const runtime = path.join(folder, 'runtime');
    fs.mkdirSync(runtime, { mode: 0o700 });
    const sockets = path.join(runtime, 'hypr/fixture');
    fs.mkdirSync(sockets, { recursive: true });
    for (const name of ['.socket.sock', '.socket2.sock']) {
      const server = net.createServer(connection => {
        connections.add(connection);
        connection.on('close', () => connections.delete(connection));
        if (name === '.socket2.sock') {
          events = connection;
        } else {
          connection.once('data', data => {
            const request = data.toString();
            requests.push(request);
            const response = {
              'j/version': { version: '0.56.2' },
              'j/monitors': [{ id: 0, name: 'TEST', x: 0, y: 0, width: 1920, height: 1080,
                scale: 1, focused: true, activeWorkspace: { id: 1, name: '1' } }],
              'j/workspaces': [{ id: 1, name: '1', monitor: 'TEST', monitorID: 0 }],
              'j/clients': clients,
              'j/activewindow': clients[0] || {},
              'j/activeworkspace': { id: 1, name: '1', monitor: 'TEST', monitorID: 0 },
            }[request] || {};
            connection.end(JSON.stringify(response));
          });
        }
      });
      servers.push(server);
      await new Promise((resolve, reject) => {
        server.once('error', reject);
        server.listen(path.join(sockets, name), resolve);
      });
    }
    const env = { ...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QPA_PLATFORMTHEME: '',
      XDG_RUNTIME_DIR: runtime, HYPRLAND_INSTANCE_SIGNATURE: 'fixture' };
    shell = spawn('quickshell', ['--path', folder, '--no-color'], { env, stdio: ['ignore', 'pipe', 'pipe'] });
    exited = new Promise(resolve => {
      shell.once('error', error => { log += error.message; resolve(); });
      shell.once('close', resolve);
    });
    shell.stdout.on('data', chunk => { log += chunk; });
    shell.stderr.on('data', chunk => { log += chunk; });
    async function state() {
      try {
        const result = await run('quickshell', ['ipc', '--pid', String(shell.pid),
          'call', 'test.windows', 'state'], { env, timeout: 3000 });
        return JSON.parse(result.stdout);
      } catch { return {}; }
    }
    const refreshCount = () => requests.filter(request => request === 'j/clients').length;
    const emit = event => events.write(event + '\n');
    await waitFor(async () => events && (await state()).count === 1,
      'Production model did not load the fixture window');
    await delay(150); // Let the initial missing-PID refresh finish.
    let baseline = refreshCount();
    emit('unrelated>>ignored');
    await delay(120);
    assert.equal(refreshCount(), baseline, 'Unrelated events caused a refresh');
    for (const floating of [true, false]) {
      clients[0].floating = floating;
      emit(`changefloatingmode>>aaa,${Number(floating)}`);
      await waitFor(async () => (await state()).record?.floating === floating, 'Floating state stayed stale');
      assert.equal(refreshCount(), baseline + 1, 'Expected one refresh per change');
      baseline++;
    }
    clients[0].floating = true;
    emit('changefloatingmode>>aaa,1\nchangefloatingmode>>aaa,0\nchangefloatingmode>>aaa,1');
    await waitFor(async () => (await state()).record?.floating === true,
      'Rapid toggles did not converge to compositor state');
    await delay(120);
    assert.equal(refreshCount(), baseline + 1, 'Event burst was not coalesced');
    baseline++;
    clients = [];
    emit('changefloatingmode>>aaa,0\nclosewindow>>aaa');
    await waitFor(async () => (await state()).count === 0, 'Closed window remained in model');
    await waitFor(() => refreshCount() === baseline + 1, 'Pending refresh never ran');
    await delay(150);
    assert.equal((await state()).count, 0, 'Refresh resurrected the closed window');
    assert.equal(refreshCount(), baseline + 1, 'Refresh continued while idle');
    assert(!/TypeError|ReferenceError|Binding loop/.test(log), log);
    console.log('window refresh: pass (float/tile, event burst, close race, idle)');
  } catch (error) {
    console.error(log);
    console.error('Compositor requests:', requests);
    throw error;
  } finally {
    if (shell) {
      shell.kill();
      const forceKill = setTimeout(() => shell.kill('SIGKILL'), 5000);
      await exited;
      clearTimeout(forceKill);
    }
    for (const connection of connections) connection.destroy();
    await Promise.all(servers.map(server => new Promise(resolve => server.close(resolve))));
    fs.rmSync(folder, { recursive: true, force: true });
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });

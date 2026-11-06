// Real production model, file watcher, and compositor socket; no desktop changes.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { execFile, spawn } = require('node:child_process');
const { promisify } = require('node:util');
const { setTimeout: delay } = require('node:timers/promises');
const run = promisify(execFile);

async function main() {
  const root = path.resolve(__dirname, '..');
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'tilelane-workspaces-'));
  const servers = [], connections = new Set(), requests = [];
  let shell, exited, events, log = '';
  let externalActive = 12;
  let values = [
    { id: 1, name: '1', monitor: 'eDP-1', monitorID: 0 },
    { id: 12, name: '12', monitor: 'DP-1', monitorID: 4 },
    { id: 18, name: '18', monitor: 'DP-1', monitorID: 4 },
  ];
  try {
    fs.mkdirSync(path.join(folder, 'qml/models'), { recursive: true });
    for (const file of ['models/WorkspaceModel.qml', 'WorkspaceLogic.js', 'TaskLogic.js']) {
      fs.copyFileSync(path.join(root, 'qml', file), path.join(folder, 'qml', file));
    }
    fs.copyFileSync(path.join(__dirname, 'quickshell/workspaces.qml'), path.join(folder, 'shell.qml'));
    const runtime = path.join(folder, 'runtime');
    const sockets = path.join(runtime, 'hypr/fixture');
    fs.mkdirSync(sockets, { recursive: true, mode: 0o700 });
    fs.chmodSync(runtime, 0o700);
    const stateFile = path.join(folder, 'state/omarchy/monitor-workspaces');
    fs.mkdirSync(path.dirname(stateFile), { recursive: true });
    fs.writeFileSync(stateFile, '0\teDP-1\tLaptop\n1\tDP-1\tExternal\n');
    for (const name of ['.socket.sock', '.socket2.sock']) {
      const server = net.createServer(connection => {
        connections.add(connection);
        connection.on('close', () => connections.delete(connection));
        if (name === '.socket2.sock') { events = connection; return; }
        connection.once('data', data => {
          const request = data.toString();
          requests.push(request);
          if (request.startsWith('dispatch ')) { connection.end('ok'); return; }
          const response = {
            'j/version': { version: '0.56.2' },
            'j/monitors': [
              { id: 0, name: 'eDP-1', x: 0, y: 0, width: 1920, height: 1080, scale: 1,
                focused: true, activeWorkspace: { id: 1, name: '1' } },
              { id: 4, name: 'DP-1', x: 1920, y: 0, width: 1920, height: 1080, scale: 1,
                focused: false, activeWorkspace: { id: externalActive, name: String(externalActive) } },
            ],
            'j/workspaces': values,
            'j/clients': [], 'j/activewindow': {},
            'j/activeworkspace': values[0],
          }[request] || {};
          connection.end(JSON.stringify(response));
        });
      });
      servers.push(server);
      await new Promise((resolve, reject) => {
        server.once('error', reject);
        server.listen(path.join(sockets, name), resolve);
      });
    }
    const env = { ...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QPA_PLATFORMTHEME: '',
      XDG_RUNTIME_DIR: runtime, HYPRLAND_INSTANCE_SIGNATURE: 'fixture',
      XDG_STATE_HOME: path.join(folder, 'state') };
    shell = spawn('quickshell', ['--path', folder, '--no-color'], { env, stdio: ['ignore', 'pipe', 'pipe'] });
    exited = new Promise(resolve => {
      shell.once('error', error => { log += error.message; resolve(); });
      shell.once('close', resolve);
    });
    shell.stdout.on('data', data => { log += data; });
    shell.stderr.on('data', data => { log += data; });
    async function call(method, ...args) {
      const result = await run('quickshell', ['ipc', '--pid', String(shell.pid), 'call',
        'test.workspaces', method, ...args], { env, timeout: 3000 });
      return JSON.parse(result.stdout);
    }
    async function waitFor(predicate) {
      const deadline = performance.now() + 6000;
      while (performance.now() < deadline) {
        try { if (await predicate()) return; } catch {}
        await delay(30);
      }
      throw new Error('Production workspace state did not converge: ' + JSON.stringify(await call('state')));
    }
    await waitFor(async () => events && (await call('state')).externalLabel === '2');
    let state = await call('state');
    assert.deepEqual(state.laptop, [1, 2, 3, 4, 5]);
    assert.deepEqual(state.external, [11, 12, 13, 14, 15, 18]);
    assert.equal(await call('activate', '11', 'DP-1'), true);
    await waitFor(() => requests.includes('dispatch o.workspaces.focus(1, "DP-1")'));
    const dispatchCount = () => requests.filter(request => request.startsWith('dispatch ')).length;
    const count = dispatchCount();
    assert.equal(await call('activate', '2', 'DP-1'), false);
    assert.equal(await call('activate', '11', 'eDP-1'), false);
    assert.equal(dispatchCount(), count);

    // An unplugged monitor's workspace temporarily lives on this output.
    externalActive = 23;
    values.push({ id: 23, name: '23', monitor: 'DP-1', monitorID: 4 });
    events.write('moveworkspacev2>>23,23,DP-1\n');
    await waitFor(async () => (await call('state')).external.includes(23));
    state = await call('state');
    assert.equal(state.externalBlock, 1);
    assert.equal(state.externalLabel, '3');
    assert.equal(await call('activate', '23', 'DP-1'), true);
    await waitFor(() => requests.includes('dispatch hl.dsp.focus({ workspace = "23" })'));

    // Atomic state replacement must update the UI bindings without a model event.
    fs.writeFileSync(stateFile + '.new', '0\teDP-1\tLaptop\n2\tDP-1\tExternal\n');
    fs.renameSync(stateFile + '.new', stateFile);
    await waitFor(async () => (await call('state')).externalBlock === 2);
    assert.deepEqual((await call('state')).external, [21, 22, 23, 24, 25, 12, 18]);
    fs.writeFileSync(stateFile, '0\teDP-1\tLaptop\n1\tDP-1\tExternal\n');
    await waitFor(async () => (await call('state')).externalBlock === 1);
    fs.unlinkSync(stateFile);
    await waitFor(async () => (await call('state')).externalBlock === 2);
    fs.writeFileSync(stateFile, '0\teDP-1\tLaptop\n1\tDP-1\tExternal\n');
    await waitFor(async () => (await call('state')).externalBlock === 1);
    values = values.filter(workspace => workspace.id !== 23);
    externalActive = 12;
    events.write('moveworkspacev2>>23,23,DP-2\n');
    await waitFor(async () => {
      const state = await call('state');
      return !state.external.includes(23) && state.externalLabel === '2';
    });
    // Allow the coalesced refresh after the move event to finish.
    await delay(150);
    const baseline = requests.length;
    await delay(150);
    assert.equal(requests.length, baseline, 'Workspace model polls while idle');
    assert(!/TypeError|ReferenceError|Binding loop/.test(log), log);
    console.log('workspaces: pass (per-monitor bindings, unfocused activation, guests, file replace/delete/recreate, move events, idle)');
  } catch (error) {
    console.error(log);
    console.error('Compositor requests:', requests);
    throw error;
  } finally {
    if (shell) { shell.kill('SIGTERM'); await exited; }
    for (const connection of connections) connection.destroy();
    await Promise.all(servers.map(server => new Promise(resolve => server.close(resolve))));
    fs.rmSync(folder, { recursive: true, force: true });
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });

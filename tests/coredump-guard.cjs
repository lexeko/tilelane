// Run a test command and reject new user core dumps, including helper crashes.
const { spawnSync, spawn } = require('node:child_process');
const { constants } = require('node:os');
const { setTimeout: delay } = require('node:timers/promises');

function journal(...args) {
  const result = spawnSync('journalctl', ['--no-pager', ...args], {
    encoding: 'utf8', timeout: 15000, maxBuffer: 16 * 1024 * 1024,
    env: { ...process.env, LC_ALL: 'C' }, stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.error) throw result.error;
  if (result.status !== 0 || result.stderr.trim())
    throw new Error(result.stderr.trim() || 'journalctl failed with status ' + result.status);
  return result.stdout;
}

function journalCursor(query = journal) {
  const match = query('-n', '0', '--show-cursor').match(/^-- cursor: (.+)$/m);
  if (!match) throw new Error('Cannot establish the journal cursor before testing');
  return match[1];
}

function newCrashes(cursor, uid, query = journal) {
  const records = query('--after-cursor=' + cursor, '-o', 'json',
    'SYSLOG_IDENTIFIER=systemd-coredump');
  const crashes = new Map();
  for (const line of records.split(/\r?\n/).filter(line => line.trim())) {
    const record = JSON.parse(line);
    if (!record || typeof record !== 'object' || Array.isArray(record))
      throw new Error('Invalid journal record');
    // Catch large dumps before compression finishes; completion adds the path.
    const early = String(record.MESSAGE || '').match(/^Process (\d+) \((.*?)\) of user (\d+) terminated abnormally/);
    if (early && Number(early[3]) === uid) crashes.set(early[1], early[2]);
    if (String(record.COREDUMP_UID) === String(uid)) {
      if (record.COREDUMP_PID === undefined) throw new Error('Core dump has no PID');
      crashes.set(String(record.COREDUMP_PID), record.COREDUMP_EXE || record.COREDUMP_COMM || 'unknown');
    }
  }
  return crashes;
}

function execute(command) {
  return new Promise((resolve, reject) => {
    const child = spawn(command[0], command.slice(1), { stdio: 'inherit' });
    child.once('error', reject);
    child.once('close', (code, signal) => resolve(code ?? (128 + (constants.signals[signal] || 0))));
  });
}

async function runChecked(command, {
  query = journal, run = execute, wait = delay, settleMs = 3000,
  uid = process.getuid(), log = console.log, error = console.error,
} = {}) {
  let cursor;
  try {
    cursor = journalCursor(query);
  } catch (failure) {
    error('Core-dump guard unavailable: ' + failure.message);
    return 2;
  }
  let status;
  try {
    status = await run(command);
  } catch (failure) {
    error('Cannot run test: ' + failure.message);
    status = 127;
  }
  // Allow asynchronous helper exit and journal submission to settle.
  await wait(settleMs);
  let crashes;
  try {
    crashes = newCrashes(cursor, uid, query);
  } catch (failure) {
    error('Core-dump check failed: ' + failure.message);
    return status || 2;
  }
  if (crashes.size) {
    for (const [pid, executable] of crashes)
      error(`New core dump during test: PID ${pid}, ${executable}`);
    error('Concurrent application crashes also require review; attribution is not automatic.');
    return status || 1;
  }
  log('Core-dump guard: no new user core dumps recorded during the test window');
  return status;
}

module.exports = { journalCursor, newCrashes, runChecked };
if (require.main === module) {
  const command = process.argv.slice(2);
  if (command[0] === '--') command.shift();
  if (!command.length) {
    console.error('Usage: coredump-guard.cjs -- COMMAND [ARG ...]');
    process.exitCode = 1;
  } else {
    runChecked(command).then(status => { process.exitCode = status; })
      .catch(error => { console.error(error); process.exitCode = 2; });
  }
}

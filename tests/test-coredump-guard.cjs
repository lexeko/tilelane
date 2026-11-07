const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { journalCursor, newCrashes, runChecked } = require('./coredump-guard.cjs');

async function main() {
  let assertions = 0;
  const check = (actual, expected) => { assert.deepEqual(actual, expected); assertions++; };
  const early = { MESSAGE: 'Process 42 (test-helper) of user 1000 terminated abnormally with signal 11/SEGV, processing...' };
  const completed = { COREDUMP_UID: '1000', COREDUMP_PID: '42', COREDUMP_EXE: '/usr/lib/test-helper' };
  const other = { ...completed, COREDUMP_UID: '2000', COREDUMP_PID: '43' };
  check(journalCursor(() => '-- cursor: fixture-cursor\n'), 'fixture-cursor');
  assert.throws(() => journalCursor(() => ''), /Cannot establish/);
  check([...newCrashes('fixture-cursor', 1000, (...args) => {
    check(args, ['--after-cursor=fixture-cursor', '-o', 'json', 'SYSLOG_IDENTIFIER=systemd-coredump']);
    return [early, other, completed].map(JSON.stringify).join('\n');
  })], [['42', '/usr/lib/test-helper']]);
  check([...newCrashes('cursor', 1000, () => JSON.stringify(early))], [['42', 'test-helper']]);
  for (const malformed of ['bad json', 'null', '[]', '{"COREDUMP_UID":"1000"}'])
    assert.throws(() => newCrashes('cursor', 1000, () => malformed));

  async function scenario(status, records, expected) {
    const order = [];
    check(await runChecked(['fixture', 'a b', '$(literal)'], {
      uid: 1000, settleMs: 17, log() {}, error() {},
      query: (...args) => {
        if (args.includes('--show-cursor')) { order.push('cursor'); return '-- cursor: bounded\n'; }
        check(args[0], '--after-cursor=bounded'); order.push('postcheck'); return records;
      },
      run: async command => { check(command, ['fixture', 'a b', '$(literal)']); order.push('run'); return status; },
      wait: async ms => { check(ms, 17); order.push('settle'); },
    }), expected);
    check(order, ['cursor', 'run', 'settle', 'postcheck']);
  }
  await scenario(0, '', 0);
  await scenario(0, JSON.stringify(completed), 1);
  await scenario(7, '', 7);
  await scenario(7, JSON.stringify(early), 7);
  await scenario(0, 'bad json', 2);
  await scenario(7, 'bad json', 7);
  check(await runChecked(['must-not-launch'], {
    query() { throw new Error('unavailable'); },
    run() { assert.fail('Launched without journal access'); }, error() {},
  }), 2);
  check(await runChecked(['missing'], {
    query: (...args) => args.includes('--show-cursor') ? '-- cursor: bounded' : '',
    run() { throw new Error('ENOENT'); }, wait: async () => {}, error() {}, log() {},
  }), 127);

  // Exercise the real CLI, process exit/signal handling, and journal transport.
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'tilelane-guard-'));
  try {
    fs.writeFileSync(path.join(folder, 'journalctl'), `#!/bin/sh
if [ "$GUARD_DENIED" = yes ]; then printf 'permission denied\\n' >&2; exit 0; fi
case "$*" in
  *--show-cursor*) printf '%s\\n' '-- cursor: fixture-cursor' ;;
  *--after-cursor=fixture-cursor*) printf '%s' "$GUARD_RECORDS" ;;
  *) exit 9 ;;
esac
`, { mode: 0o700 });
    const guard = path.join(__dirname, 'coredump-guard.cjs');
    const invoke = (command, overrides = {}) => spawnSync(process.execPath, [guard, '--', ...command], {
      encoding: 'utf8', timeout: 10000,
      env: { ...process.env, PATH: folder + path.delimiter + process.env.PATH, GUARD_RECORDS: '', ...overrides },
    });
    let result = invoke([process.execPath, '-e', 'process.exit(7)']);
    check(result.status, 7); assert.match(result.stdout, /no new user core dumps/);
    result = invoke([process.execPath, '-e', ''], {
      GUARD_RECORDS: JSON.stringify({ ...completed, COREDUMP_UID: String(process.getuid()) }),
    });
    check(result.status, 1); assert.match(result.stderr, /PID 42, \/usr\/lib\/test-helper/);
    result = invoke([process.execPath, '-e', 'process.kill(process.pid, "SIGTERM")']);
    check(result.status, 143);
    result = invoke([process.execPath, '-e', 'throw Error("must not launch")'], { GUARD_DENIED: 'yes' });
    check(result.status, 2); assert.match(result.stderr, /permission denied/);
    assert.doesNotMatch(result.stderr, /must not launch/);
    result = invoke(['tilelane-missing-guard-test-command']);
    check(result.status, 127); assert.match(result.stdout, /no new user core dumps/);
  } finally {
    fs.rmSync(folder, { recursive: true, force: true });
  }
  console.log(`core-dump guard: pass (${assertions} checks, including real CLI, signals, journal failures)`);
}

main().catch(error => { console.error(error); process.exitCode = 1; });

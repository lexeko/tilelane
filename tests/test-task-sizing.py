#!/usr/bin/env python3
"""Exercise production task sizing and reactive lane layout without desktop windows."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
OMARCHY = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy'))
with tempfile.TemporaryDirectory(prefix='tilelane-task-sizing-') as temporary:
    work = Path(temporary)
    shutil.copytree(ROOT / 'qml', work / 'qml')
    shutil.copy2(ROOT / 'tests/quickshell/task-sizing.qml', work / 'shell.qml')
    # Only the external panel-window boundary is replaced: layout uses the real
    # TaskLane, TaskButton, PinnedLauncher, font metrics, and pointer geometry.
    (work / 'qml/components/TaskContextMenu.qml').write_text("""import QtQuick
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
""")
    for name in ('Commons', 'Ui'):
        (work / name).symlink_to(OMARCHY / 'shell' / name, target_is_directory=True)
    with (work / 'shell.log').open('w+') as log:
        process = subprocess.Popen(['quickshell', '--path', str(work), '--no-color'],
                                   env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen'},
                                   stdout=log, stderr=log)
        def ipc(method, *args):
            return subprocess.check_output(['quickshell', 'ipc', '--pid', str(process.pid),
                                            'call', 'test.tasks', method, *map(str, args)],
                                           text=True, stderr=subprocess.DEVNULL, timeout=5)
        def wait_for(predicate):
            deadline = time.monotonic() + 8
            last = None
            while time.monotonic() < deadline:
                try:
                    last = json.loads(ipc('state'))
                    if predicate(last):
                        return last
                except (subprocess.SubprocessError, ValueError):
                    pass
                time.sleep(.05)
            raise AssertionError(f'Layout did not settle: {last}')
        def configure(width, titles, scale=1, pinned=0):
            ipc('configure', width, quote(json.dumps(titles), safe=''), scale, pinned)
        try:
            wait_for(lambda s: not s['tasks'])
            long = 'A long document title that should retain a readable beginning'
            configure(700, ['~', 'Short', long, long])
            roomy = wait_for(lambda s: len(s['tasks']) == 4 and s['tasks'][2]['width'] == 224)
            # Diagnostics expose geometry and addresses, never window titles.
            assert all(set(t) == {'address', 'width', 'preferred'} for t in roomy['tasks']), roomy
            short_width = roomy['tasks'][0]['width']
            assert 42 < short_width < 80, roomy
            assert not roomy['overflow'], roomy
            assert all(t['width'] == t['preferred'] for t in roomy['tasks']), roomy
            configure(500, ['~', 'Short', long, long])
            compact = wait_for(lambda s: 140 < s['tasks'][2]['width'] < 224)
            assert not compact['overflow'], compact
            assert compact['tasks'][0]['width'] == short_width, compact
            assert abs(sum(t['width'] for t in compact['tasks']) + 12 - 500) < .01, compact
            configure(300, ['~', 'Short', long, long])
            crowded = wait_for(lambda s: s['overflow'] and s['tasks'][2]['width'] == 140)
            assert crowded['tasks'][0]['width'] == short_width, crowded
            configure(300, ['~', 'Short'])
            wait_for(lambda s: len(s['tasks']) == 2 and not s['overflow'])
            configure(500, [long, long, long])
            wait_for(lambda s: len(s['tasks']) == 3 and not s['overflow'] and all(140 < t['width'] < 224 for t in s['tasks']))
            # Pin changes reduce the same lane's available width without changing its tasks.
            configure(500, [long, long, long], pinned=4)
            wait_for(lambda s: s['overflow'] and all(t['width'] == 140 for t in s['tasks']))
            configure(500, ['~', '~', '~'], pinned=4)
            wait_for(lambda s: not s['overflow'] and all(t['width'] < 80 for t in s['tasks']))
            for scale in (1.25, 1.5, 2):
                configure(420 * scale, [long, long, long], scale)
                wait_for(lambda s: s['overflow'] and all(abs(t['width'] - 140 * scale) < .01 for t in s['tasks']))
                configure(600 * scale, [long, long, long], scale)
                wait_for(lambda s: not s['overflow'] and all(140 * scale < t['width'] < 224 * scale for t in s['tasks']))
            configure(0, [], 1)
            wait_for(lambda s: not s['tasks'] and not s['overflow'])
            print('task sizing: pass (natural width, compression, minimum, overflow, titles, removal, pins, scale, empty lane)')
        except Exception:
            log.flush()
            print((work / 'shell.log').read_text())
            raise
        finally:
            process.terminate()
            process.wait(timeout=10)

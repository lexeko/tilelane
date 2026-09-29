#!/usr/bin/env python3
"""Exercise the production model against an isolated Hyprland IPC fixture."""

import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading
import time


def wait_for(predicate, message):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.02)
    raise AssertionError(message)


class Compositor:
    def __init__(self, directory):
        self.clients = [{
            "address": "0xaaa", "class": "fixture", "initialClass": "fixture",
            "title": "Fixture", "workspace": {"id": 1, "name": "1"},
            "monitor": 0, "pid": 0, "mapped": True, "floating": False,
            "stableId": "18000001", "fullscreen": 0, "xwayland": True,
        }]
        self.requests = []
        self.events = None
        self.stopped = threading.Event()
        self.sockets = []
        self.threads = []
        for name, handler in [(".socket.sock", self.query), (".socket2.sock", self.subscribe)]:
            server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            server.bind(str(directory / name))
            server.listen()
            server.settimeout(0.1)
            self.sockets.append(server)
            thread = threading.Thread(target=self.serve, args=(server, handler), daemon=True)
            thread.start()
            self.threads.append(thread)

    def serve(self, server, handler):
        while not self.stopped.is_set():
            try:
                connection, _ = server.accept()
            except TimeoutError:
                continue
            handler(connection)

    def subscribe(self, connection):
        self.events = connection

    def query(self, connection):
        with connection:
            connection.settimeout(2)
            request = connection.recv(65536).decode()
            self.requests.append(request)
            response = {
                "j/version": {"version": "0.56.2"},
                "j/monitors": [{"id": 0, "name": "TEST", "x": 0, "y": 0,
                                "width": 1920, "height": 1080, "scale": 1,
                                "focused": True, "activeWorkspace": {"id": 1, "name": "1"}}],
                "j/workspaces": [{"id": 1, "name": "1", "monitor": "TEST", "monitorID": 0}],
                "j/clients": self.clients,
                "j/activewindow": self.clients[0] if self.clients else {},
                "j/activeworkspace": {"id": 1, "name": "1", "monitor": "TEST", "monitorID": 0},
            }.get(request, {})
            connection.sendall(json.dumps(response).encode())

    def emit(self, event):
        self.events.sendall((event + "\n").encode())

    def refresh_count(self):
        return self.requests.count("j/clients")

    def close(self):
        self.stopped.set()
        for thread in self.threads:
            thread.join(timeout=3)
        for server in self.sockets:
            server.close()
        if self.events:
            self.events.close()


def main():
    root = Path(__file__).resolve().parent.parent
    with tempfile.TemporaryDirectory(prefix="tilelane-window-refresh.") as temporary:
        folder = Path(temporary)
        models = folder / "qml/models"
        models.mkdir(parents=True)
        for name in ["WindowModel.qml", "WindowState.js"]:
            shutil.copy2(root / "qml/models" / name, models / name)
        shutil.copy2(root / "tests/quickshell/window-refresh.qml", folder / "shell.qml")
        runtime = folder / "runtime"
        runtime.mkdir(mode=0o700)
        sockets = runtime / "hypr/fixture"
        sockets.mkdir(parents=True)
        compositor = Compositor(sockets)
        environment = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="",
                           XDG_RUNTIME_DIR=str(runtime), HYPRLAND_INSTANCE_SIGNATURE="fixture")
        with (folder / "result.log").open("w+") as log:
            process = subprocess.Popen(["quickshell", "--path", str(folder), "--no-color"],
                                       env=environment, stdout=log, stderr=log)

            def state():
                result = subprocess.run(["quickshell", "ipc", "--pid", str(process.pid),
                                         "call", "test.windows", "state"], env=environment,
                                        capture_output=True, text=True, timeout=3)
                try:
                    return json.loads(result.stdout)
                except json.JSONDecodeError:
                    return {}

            try:
                wait_for(lambda: compositor.events is not None and state().get("count") == 1,
                         "Production model did not load the fixture window")
                time.sleep(0.15)  # Let the initial missing-PID refresh finish.
                baseline = compositor.refresh_count()
                compositor.emit("unrelated>>ignored")
                time.sleep(0.12)
                assert compositor.refresh_count() == baseline, "Unrelated events caused a refresh"

                for floating in [True, False]:
                    compositor.clients[0]["floating"] = floating
                    compositor.emit("changefloatingmode>>aaa," + str(int(floating)))
                    wait_for(lambda: state().get("record", {}).get("floating") is floating,
                             "Floating state stayed stale")
                    assert compositor.refresh_count() == baseline + 1, "Expected one refresh per change"
                    baseline += 1

                compositor.clients[0]["floating"] = True
                compositor.emit("changefloatingmode>>aaa,1\nchangefloatingmode>>aaa,0\nchangefloatingmode>>aaa,1")
                wait_for(lambda: state().get("record", {}).get("floating") is True,
                         "Rapid toggles did not converge to compositor state")
                time.sleep(0.12)
                assert compositor.refresh_count() == baseline + 1, "Event burst was not coalesced"
                baseline += 1

                compositor.clients = []
                compositor.emit("changefloatingmode>>aaa,0\nclosewindow>>aaa")
                wait_for(lambda: state().get("count") == 0, "Closed window remained in model")
                wait_for(lambda: compositor.refresh_count() == baseline + 1, "Pending refresh never ran")
                time.sleep(0.15)
                assert state().get("count") == 0, "Refresh resurrected the closed window"
                assert compositor.refresh_count() == baseline + 1, "Refresh continued while idle"
                log.flush()
                log.seek(0)
                contents = log.read()
                assert not any(error in contents for error in ["TypeError", "ReferenceError", "Binding loop"]), contents
                print("window refresh: pass (float/tile, event burst, close race, idle)")
            except Exception:
                log.flush()
                log.seek(0)
                print(log.read())
                print("Compositor requests:", compositor.requests)
                raise
            finally:
                process.terminate()
                process.wait(timeout=5)
                compositor.close()


if __name__ == "__main__":
    main()

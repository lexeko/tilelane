#!/usr/bin/env python3
"""Run a test command and reject new user core dumps, including helper crashes."""

import json
import os
import re
import subprocess
import sys
import time


def journal(*arguments):
    result = subprocess.run(
        ["journalctl", "--no-pager", *arguments],
        capture_output=True, text=True, check=True, timeout=15,
        env={**os.environ, "LC_ALL": "C"},
    )
    if result.stderr.strip():
        raise RuntimeError(result.stderr.strip())
    return result.stdout


def journal_cursor():
    match = re.search(r"^-- cursor: (.+)$", journal("-n", "0", "--show-cursor"), re.M)
    if not match:
        raise RuntimeError("Cannot establish the journal cursor before testing")
    return match[1]


def new_crashes(cursor, uid):
    records = journal("--after-cursor=" + cursor, "-o", "json",
                      "SYSLOG_IDENTIFIER=systemd-coredump")
    crashes = {}
    for line in records.splitlines():
        record = json.loads(line)
        # The early processing message catches large dumps before compression
        # finishes. The structured completion entry supplies the executable.
        message = record.get("MESSAGE", "")
        early = re.match(r"Process (\d+) \((.*?)\) of user (\d+) terminated abnormally", message)
        if early and int(early[3]) == uid:
            crashes[early[1]] = early[2]
        if str(record.get("COREDUMP_UID", "")) == str(uid):
            pid = str(record["COREDUMP_PID"])
            crashes[pid] = record.get("COREDUMP_EXE", record.get("COREDUMP_COMM", "unknown"))
    return crashes


def run_checked(command, settle_seconds=3):
    try:
        cursor = journal_cursor()
    except (OSError, subprocess.SubprocessError, RuntimeError) as error:
        print(f"Core-dump guard unavailable: {error}", file=sys.stderr)
        return 2
    try:
        result = subprocess.run(command, check=False)
        status = result.returncode if result.returncode >= 0 else 128 - result.returncode
    except OSError as error:
        print(f"Cannot run test: {error}", file=sys.stderr)
        status = 127
    # Allow asynchronous helper exit and systemd journal submission to settle.
    time.sleep(settle_seconds)
    try:
        crashes = new_crashes(cursor, os.getuid())
    except (OSError, subprocess.SubprocessError, RuntimeError, ValueError, KeyError) as error:
        print(f"Core-dump check failed: {error}", file=sys.stderr)
        return status or 2
    if crashes:
        for pid, executable in crashes.items():
            print(f"New core dump during test: PID {pid}, {executable}", file=sys.stderr)
        print("Concurrent application crashes also require review; attribution is not automatic.", file=sys.stderr)
        return status or 1
    print("Core-dump guard: no new user core dumps recorded during the test window", flush=True)
    return status


if __name__ == "__main__":
    command = sys.argv[1:]
    if command[:1] == ["--"]:
        command = command[1:]
    if not command:
        sys.exit("Usage: coredump_guard.py -- COMMAND [ARG ...]")
    sys.exit(run_checked(command))

#!/usr/bin/env python3
import contextlib
import io
import json
import os
import subprocess
import unittest
from unittest.mock import patch

import coredump_guard as guard


class CoredumpGuardTest(unittest.TestCase):
    def test_cursor_bounds_the_query_and_other_users_are_ignored(self):
        rows = [
            {"COREDUMP_UID": "1000", "COREDUMP_PID": "42", "COREDUMP_EXE": "/usr/lib/test-helper"},
            {"COREDUMP_UID": "2000", "COREDUMP_PID": "43", "COREDUMP_EXE": "/usr/lib/other-helper"},
        ]
        with patch.object(guard, "journal", return_value="\n".join(map(json.dumps, rows))) as query:
            self.assertEqual(guard.new_crashes("test-cursor", 1000), {"42": "/usr/lib/test-helper"})
        self.assertIn("--after-cursor=test-cursor", query.call_args.args)

    def test_incomplete_core_is_detected_and_completion_deduplicated(self):
        early = {"MESSAGE": "Process 42 (test-helper) of user 1000 terminated abnormally with signal 11/SEGV, processing..."}
        completed = {"COREDUMP_UID": "1000", "COREDUMP_PID": "42", "COREDUMP_EXE": "/usr/lib/test-helper"}
        with patch.object(guard, "journal", return_value=json.dumps(early)):
            self.assertEqual(guard.new_crashes("cursor", 1000), {"42": "test-helper"})
        with patch.object(guard, "journal", return_value="\n".join(map(json.dumps, [early, completed]))):
            self.assertEqual(guard.new_crashes("cursor", 1000), {"42": "/usr/lib/test-helper"})

    def run_case(self, status, records):
        with patch.object(guard, "journal_cursor", return_value="cursor"), \
             patch.object(guard.subprocess, "run", return_value=subprocess.CompletedProcess([], status)), \
             patch.object(guard, "new_crashes", return_value=records) as check, \
             contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            result = guard.run_checked(["test"], settle_seconds=0)
            check.assert_called_once_with("cursor", os.getuid())
            return result

    def test_successful_test_fails_when_helper_crashes(self):
        self.assertEqual(self.run_case(0, {"42": "helper"}), 1)

    def test_clean_test_passes(self):
        self.assertEqual(self.run_case(0, {}), 0)

    def test_command_failure_is_preserved_and_still_checked(self):
        self.assertEqual(self.run_case(7, {}), 7)
        self.assertEqual(self.run_case(7, {"42": "helper"}), 7)

    def test_inaccessible_journal_stops_test_before_launch(self):
        with patch.object(guard, "journal_cursor", side_effect=RuntimeError("unavailable")), \
             patch.object(guard.subprocess, "run") as command, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(guard.run_checked(["test"], settle_seconds=0), 2)
            command.assert_not_called()

    def test_failed_postcheck_cannot_report_success(self):
        with patch.object(guard, "journal_cursor", return_value="cursor"), \
             patch.object(guard.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)), \
             patch.object(guard, "new_crashes", side_effect=ValueError("invalid journal JSON")), \
             contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(guard.run_checked(["test"], settle_seconds=0), 2)


if __name__ == "__main__":
    unittest.main()

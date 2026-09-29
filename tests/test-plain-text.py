#!/usr/bin/env python3
"""Check owned text surfaces and render the production bookmark label."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import textwrap


ROOT = Path(__file__).resolve().parents[1]
# Formatted QML closes each object at its opening indentation. Nested objects
# have greater indentation; TextMetrics and TextInput are deliberately excluded.
TEXT_BLOCK = re.compile(r"^([ \t]*)(?:contentItem: )?Text \{\n.*?^\1\}", re.M | re.S)
blocks = []
for path in [ROOT / "Bar.qml", *sorted((ROOT / "qml").rglob("*.qml"))]:
    source = path.read_text()
    found = list(TEXT_BLOCK.finditer(source))
    declarations = re.findall(r"\bText\s*\{", source)
    assert len(found) == len(declarations), f"Unrecognized Text declaration: {path}"
    blocks.extend((path, match.group()) for match in found)

bookmark = [block for path, block in blocks
            if path.name == "StartMenu.qml" and "placeRow.modelData.name" in block]
assert len(bookmark) == 1, "Production bookmark label not found"

with tempfile.TemporaryDirectory(prefix="tilelane-plain-text-") as temporary:
    work = Path(temporary)
    shutil.copy2(ROOT / "qml/PlacesLogic.js", work / "PlacesLogic.js")
    (work / "Commons.js").write_text(
        '.pragma library\nvar Color = {menu: {text: "white"}};\n'
        'var Style = {font: {menuFamily: "sans-serif", body: 14}};\n'
    )
    fixture = (ROOT / "tests/fixtures/bookmark-text.qml.in").read_text()
    (work / "tst_BookmarkText.qml").write_text(
        fixture.replace("BOOKMARK_TEXT_OBJECT", textwrap.dedent(bookmark[0]))
    )
    runner = "/usr/lib/qt6/bin/qmltestrunner"
    if not Path(runner).exists():
        runner = "qmltestrunner"
    result = subprocess.run(
        [runner, "-input", str(work)],
        env={**os.environ, "QT_QPA_PLATFORM": "offscreen", "QSG_RHI_BACKEND": "software"},
        capture_output=True, text=True, timeout=30,
    )
    print(result.stdout + result.stderr, end="")
    if result.returncode:
        raise SystemExit(result.returncode)

unsafe = [str(path.relative_to(ROOT)) for path, block in blocks
          if not re.search(r"\btextFormat:\s*Text\.PlainText\b", block)]
assert not unsafe, "Text surfaces without explicit plain text: " + ", ".join(unsafe)
assert blocks, "No production Text surfaces checked"
print(f"plain text: pass ({len(blocks)} owned surfaces; production bookmark rendering)")

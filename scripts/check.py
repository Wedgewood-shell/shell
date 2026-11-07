#!/usr/bin/env python3
"""Load and exercise the configuration in an isolated Quickshell instance.

Requires a running Wayland session. Does not open menus, activate devices,
launch apps, capture media, or execute session/display actions.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="quickshell-check-") as directory:
    target = Path(directory) / "config"
    shutil.copytree(root, target)
    harness = (target / "tests/smoke.qml").read_text().replace('import ".."\n', '')
    (target / "shell.qml").write_text(harness)
    try:
        result = subprocess.run(
            ["quickshell", "--path", str(target), "--no-color"],
            capture_output=True, text=True, timeout=15,
        )
    except subprocess.TimeoutExpired as error:
        raise SystemExit("Smoke check timed out") from error
    output = result.stdout + result.stderr
    print(output, end="")
    passed = result.returncode == 0 and "SMOKE PASS:" in output
    failed = any(token in output for token in ("FAIL:", "ERROR:", "ReferenceError:", "TypeError:", "Unable to assign", "Binding loop", "Cannot assign"))
    raise SystemExit(0 if passed and not failed else 1)

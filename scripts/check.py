#!/usr/bin/env python3
"""Load and exercise the configuration in an isolated Quickshell instance.

Requires a running Wayland session. Default smoke checks keep menus closed.
--transitions briefly shows test surfaces without taking keyboard focus. Neither
mode activates devices, launches apps, captures media, or runs session/display actions.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys

root = Path(__file__).resolve().parent.parent
harness_name = "transitions" if "--transitions" in sys.argv else "smoke"
pass_marker = "TRANSITIONS PASS:" if harness_name == "transitions" else "SMOKE PASS:"
with tempfile.TemporaryDirectory(prefix="quickshell-check-") as directory:
    target = Path(directory) / "config"
    shutil.copytree(root, target, ignore=shutil.ignore_patterns(".git", "__pycache__", "*.tmp"))
    harness = (target / "tests" / (harness_name + ".qml")).read_text().replace('import ".."\n', '')
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
    passed = result.returncode == 0 and pass_marker in output
    failed = any(token in output for token in ("FAIL:", "ERROR:", "ReferenceError:", "TypeError:", "Unable to assign", "Binding loop", "Cannot assign"))
    raise SystemExit(0 if passed and not failed else 1)

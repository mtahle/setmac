"""Tests for output.py — JSON-line emission protocol."""

from __future__ import annotations

import json
import threading
from io import StringIO
from unittest.mock import patch

import pytest

import setmac.output as output_mod
from setmac.output import (
    emit,
    emit_auth_required,
    emit_complete,
    emit_config_status,
    emit_error,
    emit_log,
    emit_progress,
    emit_status,
    emit_uninstalled,
)


def capture_emit(fn, *args, **kwargs) -> dict:
    """Call fn(*args, **kwargs) and return the parsed JSON dict it printed."""
    buf = StringIO()
    with patch("setmac.output._lock", threading.Lock()):
        with patch("builtins.print", side_effect=lambda line, flush=False: buf.write(line + "\n")):
            fn(*args, **kwargs)
    line = buf.getvalue().strip()
    assert line, "emit produced no output"
    return json.loads(line)


# ─── emit() base function ────────────────────────────────────

def test_emit_produces_valid_json():
    data = capture_emit(emit, "status", tool="git", status="installed")
    assert data["type"] == "status"
    assert data["tool"] == "git"
    assert data["status"] == "installed"


def test_emit_omits_none_fields():
    data = capture_emit(emit, "log", message="hello")
    assert "tool" not in data
    assert "status" not in data
    assert "version" not in data


def test_emit_includes_all_non_none_fields():
    data = capture_emit(emit, "status", tool="git", status="installed", version="2.42.0")
    assert data["version"] == "2.42.0"


# ─── Typed helpers ───────────────────────────────────────────

def test_emit_status_installed():
    data = capture_emit(emit_status, "git", "installed", version="2.42.0")
    assert data == {"type": "status", "tool": "git", "status": "installed", "version": "2.42.0"}


def test_emit_status_not_installed():
    data = capture_emit(emit_status, "git", "not_installed")
    assert data["status"] == "not_installed"
    assert "version" not in data


def test_emit_progress():
    data = capture_emit(emit_progress, "git", "Installing git...")
    assert data["type"] == "progress"
    assert data["status"] == "installing"
    assert data["message"] == "Installing git..."
    assert data["tool"] == "git"


def test_emit_log_with_tool():
    data = capture_emit(emit_log, "some line", tool="git")
    assert data["type"] == "log"
    assert data["tool"] == "git"
    assert data["message"] == "some line"


def test_emit_log_without_tool():
    data = capture_emit(emit_log, "global log")
    assert "tool" not in data
    assert data["message"] == "global log"


def test_emit_error():
    data = capture_emit(emit_error, "git", "install failed")
    assert data["type"] == "error"
    assert data["status"] == "error"
    assert data["message"] == "install failed"
    assert data["tool"] == "git"


def test_emit_complete():
    data = capture_emit(emit_complete, "git", version="2.42.0")
    assert data["type"] == "complete"
    assert data["status"] == "installed"
    assert data["version"] == "2.42.0"


def test_emit_uninstalled():
    data = capture_emit(emit_uninstalled, "git")
    assert data["type"] == "uninstalled"
    assert data["status"] == "not_installed"


def test_emit_auth_required():
    data = capture_emit(emit_auth_required, "homebrew", "Admin password needed")
    assert data["type"] == "auth_required"
    assert data["tool"] == "homebrew"
    assert data["message"] == "Admin password needed"


def test_emit_config_status():
    buf = StringIO()
    with patch("builtins.print", side_effect=lambda line, flush=False: buf.write(line + "\n")):
        emit_config_status("nvim", "~/.config/nvim", "nvim", "bundled+system")
    data = json.loads(buf.getvalue().strip())
    assert data["type"] == "config_status"
    assert data["tool"] == "nvim"
    assert data["source"] == "~/.config/nvim"
    assert data["target"] == "nvim"
    assert data["status"] == "bundled+system"


# ─── Thread safety ───────────────────────────────────────────

def test_concurrent_emits_produce_valid_json_lines():
    """Fire many emits from multiple threads and verify all lines parse as valid JSON."""
    lines: list[str] = []
    lock = threading.Lock()

    def record(line, flush=False):
        with lock:
            lines.append(line)

    n_threads = 20
    n_each = 50

    with patch("builtins.print", side_effect=record):
        threads = [
            threading.Thread(target=lambda i=i: [emit_log(f"msg-{i}-{j}") for j in range(n_each)])
            for i in range(n_threads)
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

    assert len(lines) == n_threads * n_each
    for line in lines:
        parsed = json.loads(line)  # must not raise
        assert parsed["type"] == "log"

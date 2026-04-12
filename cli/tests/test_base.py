"""Tests for installers/base.py — check_tool() and run_tool() with mocked subprocess."""

from __future__ import annotations

import json
from io import StringIO
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from setmac.registry import CheckSpec, InstallSpec, Tool


# ─── Helpers ─────────────────────────────────────────────────

def make_tool(
    id: str = "git",
    check_command: str | None = "command -v git",
    check_path: str | None = None,
    version_command: str | None = None,
    method: str = "brew_formula",
    target: str | None = "git",
    requires_admin: bool = False,
) -> Tool:
    return Tool(
        id=id,
        name=id.title(),
        description="",
        category="essentials",
        icon="star",
        icon_color="blue",
        depends_on=[],
        check=CheckSpec(
            command=check_command,
            path=check_path,
            version_command=version_command,
        ),
        install=InstallSpec(
            method=method,
            target=target,
            script=None,
            url=None,
            requires_admin=requires_admin,
        ),
    )


def completed(returncode: int, stdout: str = "", stderr: str = "") -> MagicMock:
    m = MagicMock()
    m.returncode = returncode
    m.stdout = stdout
    m.stderr = stderr
    return m


def capture_output(fn, *args, **kwargs) -> list[dict]:
    """Call fn and return all JSON lines emitted to stdout."""
    lines: list[str] = []
    with patch("builtins.print", side_effect=lambda line, flush=False: lines.append(line)):
        fn(*args, **kwargs)
    return [json.loads(l) for l in lines]


# ─── check_tool: path strategy ───────────────────────────────

def test_check_tool_path_installed(tmp_path):
    marker = tmp_path / "marker.sh"
    marker.touch()
    tool = make_tool(check_command=None, check_path=str(marker))

    from setmac.installers.base import check_tool
    installed, version = check_tool(tool)
    assert installed is True


def test_check_tool_path_not_installed(tmp_path):
    tool = make_tool(check_command=None, check_path=str(tmp_path / "nonexistent"))

    from setmac.installers.base import check_tool
    installed, version = check_tool(tool)
    assert installed is False


# ─── check_tool: command strategy ────────────────────────────

def test_check_tool_command_installed():
    tool = make_tool(check_command="command -v git")
    with patch("setmac.installers.base._run_quiet", return_value=completed(0, "/usr/bin/git")):
        from setmac.installers.base import check_tool
        installed, _ = check_tool(tool)
    assert installed is True


def test_check_tool_command_not_installed():
    tool = make_tool(check_command="command -v git")
    with patch("setmac.installers.base._run_quiet", return_value=completed(1)):
        from setmac.installers.base import check_tool
        installed, _ = check_tool(tool)
    assert installed is False


def test_check_tool_command_takes_priority_over_cask_fallback():
    """If check.command passes, brew_cask path check should not matter."""
    tool = make_tool(check_command="command -v cursor", method="brew_cask", target="cursor")
    with patch("setmac.installers.base._run_quiet", return_value=completed(0)):
        from setmac.installers.base import check_tool
        installed, _ = check_tool(tool)
    assert installed is True


# ─── check_tool: version extraction ──────────────────────────

def test_check_tool_returns_version_when_installed():
    tool = make_tool(
        check_command="command -v git",
        version_command="git --version",
    )

    def fake_run_quiet(cmd, timeout=10):
        if "version" in cmd:
            return completed(0, stdout="git version 2.42.0")
        return completed(0, stdout="/usr/bin/git")

    with patch("setmac.installers.base._run_quiet", side_effect=fake_run_quiet):
        from setmac.installers.base import check_tool
        installed, version = check_tool(tool)
    assert installed is True
    assert version == "git version 2.42.0"


def test_check_tool_strips_ansi_from_version():
    tool = make_tool(
        check_command="command -v git",
        version_command="git --version",
    )

    def fake_run_quiet(cmd, timeout=10):
        if "version" in cmd:
            return completed(0, stdout="\x1b[32mgit version 2.42.0\x1b[0m")
        return completed(0)

    with patch("setmac.installers.base._run_quiet", side_effect=fake_run_quiet):
        from setmac.installers.base import check_tool
        _, version = check_tool(tool)
    assert "\x1b" not in (version or "")
    assert "git version 2.42.0" in (version or "")


def test_check_tool_no_version_when_not_installed():
    tool = make_tool(check_command="command -v git", version_command="git --version")
    with patch("setmac.installers.base._run_quiet", return_value=completed(1)):
        from setmac.installers.base import check_tool
        installed, version = check_tool(tool)
    assert installed is False
    assert version is None


# ─── run_tool: idempotency ────────────────────────────────────

def test_run_tool_skips_if_already_installed():
    tool = make_tool()
    with patch("setmac.installers.base.check_tool", return_value=(True, "2.42.0")):
        msgs = capture_output(__import__("setmac.installers.base", fromlist=["run_tool"]).run_tool, tool)
    types = [m["type"] for m in msgs]
    assert "status" in types
    assert "progress" not in types


def test_run_tool_installs_if_not_installed():
    tool = make_tool()
    check_calls = [False, True]  # first check: not installed; second: installed

    def fake_check(t):
        return (check_calls.pop(0), "2.42.0" if check_calls == [] else None)

    with patch("setmac.installers.base.check_tool", side_effect=fake_check):
        with patch("setmac.installers.base.install_tool", return_value=True):
            msgs = capture_output(__import__("setmac.installers.base", fromlist=["run_tool"]).run_tool, tool)

    types = [m["type"] for m in msgs]
    assert "progress" in types
    assert "complete" in types
    assert "error" not in types


def test_run_tool_emits_error_on_install_failure():
    tool = make_tool()
    with patch("setmac.installers.base.check_tool", return_value=(False, None)):
        with patch("setmac.installers.base.install_tool", return_value=False):
            msgs = capture_output(__import__("setmac.installers.base", fromlist=["run_tool"]).run_tool, tool)

    types = [m["type"] for m in msgs]
    assert "error" in types


def test_run_tool_does_not_crash_on_exception():
    tool = make_tool()
    with patch("setmac.installers.base.check_tool", side_effect=RuntimeError("unexpected")):
        msgs = capture_output(__import__("setmac.installers.base", fromlist=["run_tool"]).run_tool, tool)

    types = [m["type"] for m in msgs]
    assert "error" in types

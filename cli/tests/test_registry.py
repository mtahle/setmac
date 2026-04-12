"""Tests for registry.py — manifest loading, dependency resolution, validation."""

from __future__ import annotations

import json
import pytest
from pathlib import Path
from setmac.registry import Registry, SUPPORTED_SCHEMA_VERSION


# ─── Fixture helpers ─────────────────────────────────────────

def make_manifest(tools: list[dict], schema_version: int = SUPPORTED_SCHEMA_VERSION) -> dict:
    return {
        "schema_version": schema_version,
        "version": "0.0.0",
        "name": "test",
        "description": "test manifest",
        "author": "test",
        "tools": tools,
    }


def make_tool(
    id: str,
    depends_on: list[str] = (),
    method: str = "brew_formula",
    check_command: str | None = "command -v test",
    check_path: str | None = None,
) -> dict:
    check = {}
    if check_command:
        check["command"] = check_command
    if check_path:
        check["path"] = check_path
    return {
        "id": id,
        "name": id.title(),
        "description": "",
        "category": "essentials",
        "icon": "star",
        "icon_color": "blue",
        "depends_on": list(depends_on),
        "check": check,
        "install": {"method": method, "target": id},
    }


def write_manifest(tmp_path: Path, data: dict) -> Path:
    p = tmp_path / "tools.json"
    p.write_text(json.dumps(data))
    return p


# ─── Schema version ──────────────────────────────────────────

def test_correct_schema_version_loads(tmp_path):
    p = write_manifest(tmp_path, make_manifest([make_tool("git")]))
    r = Registry(p)
    assert len(r.tools) == 1


def test_wrong_schema_version_raises(tmp_path):
    p = write_manifest(tmp_path, make_manifest([make_tool("git")], schema_version=999))
    with pytest.raises(ValueError, match="schema_version"):
        Registry(p)


# ─── install_order (topological sort) ────────────────────────

def test_single_tool_no_deps(tmp_path):
    p = write_manifest(tmp_path, make_manifest([make_tool("git")]))
    r = Registry(p)
    order = r.install_order(["git"])
    assert [t.id for t in order] == ["git"]


def test_respects_dependency_order(tmp_path):
    tools = [
        make_tool("b", depends_on=["a"]),
        make_tool("a"),
    ]
    p = write_manifest(tmp_path, make_manifest(tools))
    r = Registry(p)
    order = r.install_order(["a", "b"])
    ids = [t.id for t in order]
    assert ids.index("a") < ids.index("b")


def test_transitive_dependencies_included(tmp_path):
    tools = [
        make_tool("c", depends_on=["b"]),
        make_tool("b", depends_on=["a"]),
        make_tool("a"),
    ]
    p = write_manifest(tmp_path, make_manifest(tools))
    r = Registry(p)
    order = r.install_order(["c"])  # only request c
    ids = [t.id for t in order]
    assert set(ids) == {"a", "b", "c"}
    assert ids.index("a") < ids.index("b") < ids.index("c")


def test_missing_dependency_id_is_skipped_gracefully(tmp_path):
    # "b" depends on "nonexistent"; registry should still build and sort
    tools = [make_tool("b", depends_on=["nonexistent"])]
    p = write_manifest(tmp_path, make_manifest(tools))
    r = Registry(p)
    order = r.install_order(["b"])
    assert len(order) == 1
    assert order[0].id == "b"


def test_install_order_is_deterministic(tmp_path):
    tools = [make_tool(id) for id in ["z", "y", "x", "a"]]
    p = write_manifest(tmp_path, make_manifest(tools))
    r = Registry(p)
    order1 = [t.id for t in r.install_order(["z", "y", "x", "a"])]
    order2 = [t.id for t in r.install_order(["a", "x", "y", "z"])]
    assert order1 == order2


def test_empty_tool_list_returns_empty_order(tmp_path):
    p = write_manifest(tmp_path, make_manifest([make_tool("git")]))
    r = Registry(p)
    assert r.install_order([]) == []


# ─── Cycle detection ─────────────────────────────────────────

def test_circular_dependency_raises(tmp_path):
    tools = [
        make_tool("a", depends_on=["b"]),
        make_tool("b", depends_on=["a"]),
    ]
    p = write_manifest(tmp_path, make_manifest(tools))
    with pytest.raises(ValueError, match="Circular dependency"):
        Registry(p)


def test_self_dependency_raises(tmp_path):
    tools = [make_tool("a", depends_on=["a"])]
    p = write_manifest(tmp_path, make_manifest(tools))
    with pytest.raises(ValueError, match="Circular dependency"):
        Registry(p)


def test_longer_cycle_raises(tmp_path):
    tools = [
        make_tool("a", depends_on=["c"]),
        make_tool("b", depends_on=["a"]),
        make_tool("c", depends_on=["b"]),
    ]
    p = write_manifest(tmp_path, make_manifest(tools))
    with pytest.raises(ValueError, match="Circular dependency"):
        Registry(p)


# ─── Check spec validation ───────────────────────────────────

def test_tool_without_check_command_or_path_raises(tmp_path):
    tool = make_tool("bad", check_command=None, check_path=None)
    p = write_manifest(tmp_path, make_manifest([tool]))
    with pytest.raises(ValueError, match="check.command or check.path"):
        Registry(p)


def test_tool_with_only_path_is_valid(tmp_path):
    tool = make_tool("cursor", check_command=None, check_path="/Applications/Cursor.app")
    p = write_manifest(tmp_path, make_manifest([tool]))
    r = Registry(p)
    assert r.get("cursor") is not None


def test_tool_with_only_command_is_valid(tmp_path):
    tool = make_tool("git", check_command="command -v git", check_path=None)
    p = write_manifest(tmp_path, make_manifest([tool]))
    r = Registry(p)
    assert r.get("git") is not None


# ─── by_category / get ───────────────────────────────────────

def test_by_category_filters_correctly(tmp_path):
    tools = [
        make_tool("git"),   # category: essentials (default in make_tool)
        make_tool("nvim"),
    ]
    tools[1]["category"] = "cli-tools"
    p = write_manifest(tmp_path, make_manifest(tools))
    r = Registry(p)
    assert [t.id for t in r.by_category("essentials")] == ["git"]
    assert [t.id for t in r.by_category("cli-tools")] == ["nvim"]


def test_get_returns_none_for_unknown_id(tmp_path):
    p = write_manifest(tmp_path, make_manifest([make_tool("git")]))
    r = Registry(p)
    assert r.get("does-not-exist") is None

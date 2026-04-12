"""Uninstall commands."""

import click

from setmac.installers.base import uninstall_tool
from setmac.output import emit_error
from setmac.registry import Registry


@click.command("uninstall")
@click.argument("tool_id")
def uninstall_cmd(tool_id):
    """Uninstall a tool by ID."""
    registry = Registry()
    tool = registry.get(tool_id)
    if not tool:
        emit_error(tool_id, f"Unknown tool: {tool_id}")
        raise SystemExit(1)
    uninstall_tool(tool)

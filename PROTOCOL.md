# CLI ↔ GUI JSON-Line Protocol

The Python CLI communicates with the SwiftUI GUI via newline-delimited JSON on **stdout**. Each line is a self-contained JSON object. The GUI reads lines as they arrive and updates state in real time.

## Direction

`CLI → GUI` only. The GUI never sends JSON to the CLI.
The GUI sends data in one direction only: **stdin** (the admin password as a raw line after `auth_required`).

## Schema version

The `tools.json` manifest carries a `schema_version` integer. The CLI validates it on startup; the Swift `ManifestLoader` checks it after decode. Both sides must agree on `schema_version: 1` (current).

There is no per-session protocol handshake. Breaking changes to the message schema should increment `schema_version` in `tools.json` and be coordinated with a GUI update.

## Message format

Every message is a JSON object with a `type` field. All other fields are optional and type-dependent.

```
{"type": "<type>", ["tool": "<id>",] ["message": "<text>",] ["status": "<str>",] ["version": "<str>",] ...}
```

## Message types

### `status`
Emitted during `setmac status` for each tool.

| Field    | Type   | Notes                              |
|----------|--------|------------------------------------|
| `type`   | string | `"status"`                         |
| `tool`   | string | Tool ID                            |
| `status` | string | `"installed"` or `"not_installed"` |
| `version`| string | Optional version string            |

### `progress`
Emitted when a tool install begins.

| Field    | Type   | Notes           |
|----------|--------|-----------------|
| `type`   | string | `"progress"`    |
| `tool`   | string | Tool ID         |
| `status` | string | `"installing"`  |
| `message`| string | Human-readable  |

### `complete`
Emitted when a tool install finishes successfully.

| Field    | Type   | Notes                |
|----------|--------|----------------------|
| `type`   | string | `"complete"`         |
| `tool`   | string | Tool ID              |
| `status` | string | `"installed"`        |
| `version`| string | Optional version     |

### `uninstalled`
Emitted when a tool is successfully removed.

| Field    | Type   | Notes              |
|----------|--------|--------------------|
| `type`   | string | `"uninstalled"`    |
| `tool`   | string | Tool ID            |
| `status` | string | `"not_installed"`  |

### `error`
Emitted on any failure (install, check, or process exit with non-zero code).

| Field    | Type   | Notes         |
|----------|--------|---------------|
| `type`   | string | `"error"`     |
| `tool`   | string | Tool ID (may be absent for global errors) |
| `status` | string | `"error"`     |
| `message`| string | Error detail  |

### `log`
Emitted for informational lines (brew output, script stdout, etc.).

| Field    | Type   | Notes                     |
|----------|--------|---------------------------|
| `type`   | string | `"log"`                   |
| `tool`   | string | Optional tool context     |
| `message`| string | Log line                  |

### `auth_required`
Emitted when a tool install needs an admin password. The GUI must respond by writing the password as a plain text line to **stdin**, followed by `\n`.

| Field    | Type   | Notes                    |
|----------|--------|--------------------------|
| `type`   | string | `"auth_required"`        |
| `tool`   | string | Tool ID                  |
| `message`| string | Human-readable prompt    |

After receiving `auth_required`, the GUI must write the password to stdin **before** the CLI times out (default: 30 s). An empty line or no response is treated as cancellation.

### `config_status`
Emitted by `setmac configs list` for each tracked config file.

| Field    | Type   | Notes                                                   |
|----------|--------|---------------------------------------------------------|
| `type`   | string | `"config_status"`                                       |
| `tool`   | string | Tool ID                                                 |
| `source` | string | System path (e.g. `~/.config/nvim`)                    |
| `target` | string | Bundle-relative path (e.g. `nvim`)                     |
| `status` | string | `"bundled"`, `"system"`, `"bundled+system"`, `"missing"` |

## Invariants

- Every message is a single line terminated by `\n`.
- The CLI flushes stdout after every message (`flush=True`).
- Unknown `type` values must be silently ignored by the GUI.
- The stream ends when the CLI process exits; the GUI must handle unexpected exit gracefully.
- `tool` is absent from global messages (e.g. `error` from a failed process launch).

## Backwards compatibility

Unknown fields in a message must be ignored. New message types must be ignored by older GUIs. Removing or renaming existing fields or types is a breaking change and requires a `schema_version` bump.

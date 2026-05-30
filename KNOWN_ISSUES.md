# Known Issues

Tracked known issues and limitations for `schwab-marketdata-skill`. For
resolved issues see [CHANGELOG.md](./CHANGELOG.md).

## Open

### Depends on a pinned `schwab-marketdata-mcp` version range

This skill orchestrates the `schwab-marketdata-mcp` server over MCP. It
declares a compatible MCP server version range (`>=0.3,<0.4` style pin in
the CHANGELOG compatibility matrix). If the installed MCP server falls
outside that range, the Activation handshake (3 × `health_check`) is
expected to fail — by design — rather than run against an incompatible
tool surface.

### Handshake failure needs a manual MCP host reload

Because the MCP server is a long-running stdio process, editing the
server's `.env` (e.g. fixing a missing credential) does **not** take
effect until the MCP host window is reloaded
(`Cmd+Shift+P → Developer: Reload Window`). A handshake that keeps failing
after an `.env` fix almost always means the host has not been reloaded.

## Upstream / Deferred

- **No code dependencies** — this repo ships Markdown skills only; the
  only dependabot ecosystem is `github-actions`, a no-op until workflows
  land under `.github/workflows/`.

## Resolved

See [CHANGELOG.md](./CHANGELOG.md) for the full history.

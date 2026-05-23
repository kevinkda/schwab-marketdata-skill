# FAQ

> The 35 most-asked questions and short answers. Detailed
> discussion is linked from each answer.

## Source

For the original Chinese version, see
[`../../schwab-marketdata-ops/references/faq.md`](../../schwab-marketdata-ops/references/faq.md).

## Getting started

### 1. What does this skill do?

It packages the usage patterns, error handling, OAuth flow, and
playbook orchestration for the 12 Schwab Market Data tools (quotes /
price history / option chain / movers / instruments / health /
server_info) exposed by the
[`schwab-marketdata-mcp`](https://github.com/kevinkda/schwab-marketdata-mcp)
server, into a skill loadable by Cursor / Claude / Kiro CLI and
similar agents. The skill itself is a **read-only documentation
package**; all tool calls are actually executed by the MCP server.

### 2. How does this relate to Schwab's official SDK?

Schwab does not have an official Python SDK.
`schwab-marketdata-mcp` internally uses
[`schwab-py`](https://github.com/alexgolec/schwab-py) (a
community-maintained unofficial Python client). This skill does not
depend on schwab-py directly; it only calls schwab-marketdata-mcp
through MCP.

### 3. Can I redistribute the data I pull?

**No**. Schwab Market Data is **non-redistributable** (see
[`tos-snapshot.md`](tos-snapshot.md)). The
`schwab-marketdata-workflows` skill verifies the target repo is
private via `gh repo view --json isPrivate` before writing any
markdown.

## Installation & registration

### 4. Do I need a Schwab account first?

Yes. It must be a Schwab **Brokerage** account (not Schwab
Bank-only), and you must register an app at
[Schwab Developer Portal](https://developer.schwab.com/) to get an
App Key / Secret. See
[`quick-start/step-1-developer-portal-app.md`](quick-start/step-1-developer-portal-app.md).

### 5. How long does app approval take?

Usually 1–3 business days; occasionally up to 5 days under backlog.

### 6. Do I have to use `uv`? Can I use pip / poetry?

**`uv` is recommended** (the repo ships a `uv.lock`), but as long as
you can run `pip install -e .` + `pip install -r requirements*.txt`
to start the server, that works too. Just point the `command` in
`mcp.json` at the corresponding binary.

### 7. Is Windows supported?

**v0.1 does not support Windows**. `platform_supported_v1` =
`["macos>=11", "linux"]`. Reason: token-file permissions and
cron / launchd health-check automation have not been ported. WSL2
(Linux subsystem) does work.

## OAuth & token

### 8. Can the 7-day refresh_token expiry be extended?

No. This is a hard limit of Schwab OAuth. No client (schwab-py,
this server, any fork) can bypass it. See
[`oauth/oauth-token-lifecycle.md`](oauth/oauth-token-lifecycle.md).

### 9. Can I fully automate (unattended)?

**No**. A human must run `auth login_flow` at least once every 7
days. You can use cron + desktop notifications to maximize the
window (see
[`quick-start/step-7-cron-launchd-setup.md`](quick-start/step-7-cron-launchd-setup.md)).

### 10. Can I copy token.json to another machine?

**No**. The refresh_token is rotate-on-use, which is incompatible
with cross-machine sharing. Each machine must run OAuth
independently. See
[`operations/multi-machine-multi-account.md`](operations/multi-machine-multi-account.md).

### 11. How do I choose between `login_flow` and `manual_flow`?

Standard laptop → `login_flow` (default); SSH-only / containers /
WSL2 → `manual_flow`. See
[`oauth/oauth-overview.md`](oauth/oauth-overview.md).

### 12. The browser is showing an SSL error — what now?

`login_flow` uses a self-signed certificate, so the browser will
warn. Click Advanced → Proceed. See
[`oauth/oauth-login-flow.md`](oauth/oauth-login-flow.md).

## Rate limits

### 13. What is the per-minute request cap?

Community estimate ~120 req/min/user. The server defaults to
`SCHWAB_RATE_LIMIT_PER_MIN=120`. See
[`operations/rate-limit-token-bucket.md`](operations/rate-limit-token-bucket.md).

### 14. Does the server wait when no slot is available?

**No**. When the token-bucket is at 0 slots, the server raises
`SchwabRateLimitError` immediately and lets the agent back off
itself. This avoids blocking other concurrent tools. See
[`troubleshooting/rate-limit-token-bucket-empty.md`](troubleshooting/rate-limit-token-bucket-empty.md).

### 15. Can I raise `SCHWAB_RATE_LIMIT_PER_MIN`?

**Do not exceed 120**. Schwab's server-side limit will fire first
and may suspend your account-level quota.

### 16. What happens when multiple agents share one server?

The token-bucket is shared at server **process** scope. Multi-agent
totals must stay ≤ 120/min. See
[`operations/rate-limit-token-bucket.md`](operations/rate-limit-token-bucket.md).

## Calls / business

### 17. Must symbols be UPPERCASE?

Yes. `"aapl"` is rejected immediately by Pydantic. See
[`troubleshooting/validation-symbol.md`](troubleshooting/validation-symbol.md).

### 18. How do I query an index?

Add a `$` prefix: `get_quote("$SPX")` / `get_quote("$DJI")`. See
[`tools/tool-reference-quotes.md`](tools/tool-reference-quotes.md).

### 19. What is the OSI option symbol format?

Fixed 21 characters: `{ROOT:6}{YYMMDD:6}{C|P:1}{STRIKE×1000:8}`. See
[`concepts/osi-option-symbol.md`](concepts/osi-option-symbol.md).

### 20. `get_price_history` complains about Cartesian product — why?

The 4-tuple `(period_type, period, frequency_type, frequency)` only
accepts a restricted set of combinations. See
[`troubleshooting/validation-pricehistory-cartesian.md`](troubleshooting/validation-pricehistory-cartesian.md).

### 21. What is the per-call symbol cap on `get_quotes`?

50 symbols. Chunk it yourself when you have more. See
[`troubleshooting/validation-batch-50.md`](troubleshooting/validation-batch-50.md).

### 22. Why don't errors throw exceptions?

The server wraps all schwab-py exceptions into `{"error": "..."}`
dicts, so the agent receives structured data rather than
language-specific exceptions. See
[`error-recovery.md`](error-recovery.md).

## Security

### 23. I accidentally committed `.env` — what now?

**Step 1**: go to the Developer Portal and **Reset App Secret**
(this is what actually severs attacker access). Then follow the
branch-review flow in
[`credentials-rotate-runbook.md`](credentials-rotate-runbook.md).
**Do not** force-push the main branch.

### 24. What if token.json ended up on iCloud / Dropbox?

The server refuses to start by default
(`SchwabAuthError(reason="cloud_path_detected")`). Either set
`--config-dir` to a non-synced path, or override explicitly with
`--i-understand-cloud-sync-risk` (not recommended). See
[`troubleshooting/auth-overview.md`](troubleshooting/auth-overview.md).

### 25. How are credentials kept private?

`.env` is local-only and `chmod 600`; `token.json` lives under the
allow-list path with `chmod 600`; pre-commit hooks (gitleaks +
detect-secrets) block secret commits. See
[`quick-start/step-2-credentials-env.md`](quick-start/step-2-credentials-env.md).

## Skill / agent

### 26. What is the relationship between the skill and the MCP server?

The skill is **documentation** (describing how to use the server);
the server is the **process** that actually runs the tool calls.
They communicate via the MCP protocol. The skill declares a
`compatible_mcp_version` range in its frontmatter; on activation
the agent calls `get_server_info` to validate.

### 27. Why must `get_server_info` be called before `health_check`?

This is the **Activation handshake**. `get_server_info` validates
version compatibility; `health_check` validates that the token is
actually usable. If either check fails, the agent must stop and
not silently fall back. See
[`concepts/key-concepts.md`](concepts/key-concepts.md).

### 28. How do I choose between the ops and workflows skills?

ops is **single tool call** + troubleshooting; workflows is
**multi-step playbooks** (writing markdown into private repos).
See the README.

### 29. Must the agent reply in Simplified Chinese?

Yes. Both skills' `language_directive` field forces Simplified
Chinese.

### 30. Client compatibility?

Cursor / Claude Code / Kiro CLI / Cline / Roo Code and other
skills-compatible agents. See the README and the Compatibility
table in ops/SKILL.md.

## Failure & recovery

### 31. Every tool returns SchwabAuthError — what now?

Run `auth login_flow` to re-do OAuth. See
[`troubleshooting/auth-overview.md`](troubleshooting/auth-overview.md).

### 32. How do I file an issue / report a bug?

Include the last 100 lines of server.log (**redact Bearer / token /
App Key first**), the call args, and expected vs actual behavior.
File at the `schwab-marketdata-mcp` repo issue tracker.

### 33. Can I fork and modify?

Yes, but you must keep the ToS notice + credential-protection
logic (`.env` allow-list, token path allow-list, cloud-sync
detection, pre-commit hooks) — these are legal- / security-level
contracts.

### 34. Where can I read the server's internal source code?

`schwab-marketdata-mcp` repository `src/schwab_marketdata_mcp/`.
Architecture diagram in
[`concepts/architecture-overview.md`](concepts/architecture-overview.md).

### 35. What if I want Trader API (order placement) functionality?

This server **does not support** and **will not support** the
Trader API (it is read-only market data by design). If you need
order placement, build a separate server and carefully evaluate
the legal / licensing / security risks.

## References

- Full reference index: see the `## Reference index` section in
  ops/SKILL.md
- Quick Start 7 steps: [`quick-start/`](quick-start/)
- Error model: [`error-recovery.md`](error-recovery.md)

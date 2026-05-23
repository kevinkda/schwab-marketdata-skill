# Integration — Rust MCP client

> Use the MCP client from your own **Rust application** to call the
> `schwab-marketdata-mcp` server.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/integration/rust-mcp-client.md`](../../../schwab-marketdata-ops/references/integration/rust-mcp-client.md).

## Crate selection

Two mainstream options today:

| Option | Crate | Status |
| ------ | ----- | ------ |
| **rmcp** (official Rust SDK) | `rmcp` | <https://github.com/modelcontextprotocol/rust-sdk> (Anthropic / community-maintained, officially recommended starting 2025) |
| Self-rolled stdio + JSON-RPC | tokio + serde_json | No new dependency; suits very minimal use cases |

> ⚠️ The Rust SDK API was still iterating quickly through 2025;
> **strongly recommend pinning a concrete version in `Cargo.toml`**
> rather than `"*"`. Check
> <https://crates.io/crates/rmcp> for the current stable release
> before running the snippets below.

This document gives examples for both approaches.

## Option A: use `rmcp` (recommended)

### Install

```bash
cargo new my-schwab-app
cd my-schwab-app
cargo add tokio --features full
cargo add rmcp                       # pin to the latest stable you've tested
cargo add anyhow
cargo add serde_json
```

### Minimal hello-world

```rust
// src/main.rs
use anyhow::Result;
use rmcp::{
    model::CallToolRequestParam,
    service::{ServiceExt, RunningService},
    transport::TokioChildProcess,
    RoleClient,
};
use std::path::PathBuf;
use tokio::process::Command;

#[tokio::main]
async fn main() -> Result<()> {
    let server_repo: PathBuf = dirs::home_dir()
        .expect("home dir")
        .join("code/kevinkda/schwab-marketdata-mcp");

    let mut cmd = Command::new("uv");
    cmd.args([
        "--directory",
        server_repo.to_str().unwrap(),
        "run",
        "schwab-marketdata-mcp",
    ]);

    let transport = TokioChildProcess::new(&mut cmd)?;
    let service: RunningService<RoleClient, ()> = ().serve(transport).await?;

    let result = service
        .call_tool(CallToolRequestParam {
            name: "health_check".into(),
            arguments: Some(serde_json::json!({}).as_object().unwrap().clone()),
        })
        .await?;

    println!("{:#?}", result);
    service.cancel().await?;
    Ok(())
}
```

> Tip: `rmcp`'s API surface changes during the 0.x phase. If the
> snippet above fails to compile, look at the README / examples in
> the current `rmcp` release and apply the smallest necessary
> changes.

## Option B: minimal self-rolled stdio + JSON-RPC

If you'd rather avoid `rmcp` (pre-1.0), you can talk JSON-RPC over
stdio directly:

### Install

```bash
cargo add tokio --features full
cargo add serde_json
cargo add anyhow
```

### Minimal implementation

```rust
// src/main.rs
use anyhow::{Context, Result};
use serde_json::{json, Value};
use std::path::PathBuf;
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    process::{Child, Command},
};

struct McpStdio {
    child: Child,
    next_id: u64,
}

impl McpStdio {
    async fn spawn(server_repo: &str) -> Result<Self> {
        let child = Command::new("uv")
            .args(["--directory", server_repo, "run", "schwab-marketdata-mcp"])
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::inherit())
            .spawn()
            .context("spawn server")?;
        Ok(Self { child, next_id: 1 })
    }

    async fn request(&mut self, method: &str, params: Value) -> Result<Value> {
        let id = self.next_id;
        self.next_id += 1;
        let req = json!({
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params,
        });
        let stdin = self.child.stdin.as_mut().context("stdin")?;
        stdin.write_all(req.to_string().as_bytes()).await?;
        stdin.write_all(b"\n").await?;
        stdin.flush().await?;

        let stdout = self.child.stdout.as_mut().context("stdout")?;
        let mut reader = BufReader::new(stdout);
        let mut line = String::new();
        reader.read_line(&mut line).await?;
        let resp: Value = serde_json::from_str(line.trim())?;
        if let Some(err) = resp.get("error") {
            anyhow::bail!("mcp error: {err}");
        }
        Ok(resp.get("result").cloned().unwrap_or(Value::Null))
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let server_repo = dirs::home_dir()
        .expect("home dir")
        .join("code/kevinkda/schwab-marketdata-mcp");
    let mut mcp = McpStdio::spawn(server_repo.to_str().unwrap()).await?;

    // initialize
    mcp.request(
        "initialize",
        json!({
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": { "name": "my-schwab-app", "version": "0.1.0" }
        }),
    )
    .await?;

    // call tools/call
    let result = mcp
        .request(
            "tools/call",
            json!({ "name": "health_check", "arguments": {} }),
        )
        .await?;
    println!("{}", serde_json::to_string_pretty(&result)?);
    Ok(())
}
```

Note: this is a **minimal** implementation — it does not handle
server-pushed notifications nor concurrent request-id routing. For
production use, prefer `rmcp`.

## Error-handling template

Regardless of A / B: when a business tool fails, the server returns
`result.content[0].text` as a JSON string carrying an `error` field.
On the Rust side, parse and dispatch:

```rust
let payload: Value = serde_json::from_str(&text)?;
if let Some(err_type) = payload.get("error").and_then(|v| v.as_str()) {
    match err_type {
        "SchwabValidationError" => return Err(anyhow!("input invalid")),
        "SchwabAuthError"       => return Err(anyhow!("token expired, re-auth")),
        "SchwabRateLimitError"  => {
            // Simple backoff
            let retry_after = payload
                .get("retry_after_seconds")
                .and_then(|v| v.as_u64())
                .unwrap_or(2);
            tokio::time::sleep(std::time::Duration::from_secs(retry_after)).await;
            // Caller retries
        }
        other => return Err(anyhow!("server error: {other}")),
    }
}
```

## What not to do

- **Do not** inject App Key / App Secret into the server via
  environment variables from the Rust process — the server reads
  `.env` only.
- **Do not** share a single `McpStdio` across threads without a
  lock — stdio is a sequential channel.
- **Do not** `cargo install` an MCP client crate globally and use
  it like a CLI — that decouples your project from `Cargo.lock` and
  makes builds non-reproducible.

## References

- Official Rust SDK: <https://github.com/modelcontextprotocol/rust-sdk>
- Full schema for the 12 tools: [`../tools/index.md`](../tools/index.md)
- Python / TypeScript equivalents: [`python-mcp-client.md`](python-mcp-client.md) / [`typescript-mcp-client.md`](typescript-mcp-client.md)

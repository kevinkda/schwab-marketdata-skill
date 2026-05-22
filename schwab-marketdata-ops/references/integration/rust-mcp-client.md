# Integration — Rust MCP client

> 在你自己的 **Rust 应用**里作为 MCP 客户端调用 `schwab-marketdata-mcp`
> server。

## 包选择

社区目前有两条主流路径：

| 选项 | crate | 状态 |
| ---- | ----- | ---- |
| **rmcp**（官方 Rust SDK） | `rmcp` | <https://github.com/modelcontextprotocol/rust-sdk>（Anthropic / 社区维护，2025 年起为官方推荐） |
| 自实现 stdio + JSON-RPC | tokio + serde_json | 没引入新依赖；适合极简 use case |

> ⚠️ Rust SDK API 在 2025 年仍在快速迭代，**强烈建议在 `Cargo.toml` 里
> 锁定具体版本**而不是 `"*"`。在你跑下面 snippet 之前先去
> <https://crates.io/crates/rmcp> 看最新 stable 版本。

下文用 `rmcp` 与自实现两种方式各给一份示例。

## 选项 A：用 `rmcp`（推荐）

### 安装

```bash
cargo new my-schwab-app
cd my-schwab-app
cargo add tokio --features full
cargo add rmcp                       # 锁定到你测过的最新 stable 版
cargo add anyhow
cargo add serde_json
```

### 最小 hello-world

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

> 提示：`rmcp` 的 API surface 在 0.x 阶段会变。如果上面 snippet 编译失败，
> 优先去 `rmcp` 的 README / examples 找当前版本的对应写法，再做最小改动。

## 选项 B：极简自实现 stdio + JSON-RPC

如果你不想引入 `rmcp`（pre-1.0），可以自己跟 server 走 JSON-RPC over
stdio：

### 安装

```bash
cargo add tokio --features full
cargo add serde_json
cargo add anyhow
```

### 极简实现

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

注意这是 **极简** 实现 —— 没处理 server 端推送的 notification、没处理
并发请求 id 路由。生产用还是建议走 `rmcp`。

## 错误处理模板

不论 A / B：业务 tool 失败时，server 返回的 result.content[0].text 是
JSON 字符串，含 `error` 字段。Rust 端解析后做：

```rust
let payload: Value = serde_json::from_str(&text)?;
if let Some(err_type) = payload.get("error").and_then(|v| v.as_str()) {
    match err_type {
        "SchwabValidationError" => return Err(anyhow!("input invalid")),
        "SchwabAuthError"       => return Err(anyhow!("token expired, re-auth")),
        "SchwabRateLimitError"  => {
            // 简单退避
            let retry_after = payload
                .get("retry_after_seconds")
                .and_then(|v| v.as_u64())
                .unwrap_or(2);
            tokio::time::sleep(std::time::Duration::from_secs(retry_after)).await;
            // 调用方 retry
        }
        other => return Err(anyhow!("server error: {other}")),
    }
}
```

## 不要做的事

- **不要** 在 Rust 进程里把 App Key / App Secret 通过环境变量注入
  server —— server 只读 `.env`。
- **不要** 在多 thread 间共享同一个 `McpStdio` 而不加锁 —— stdio 是顺序
  通道。
- **不要** 用 `cargo install` 全局安装某个 mcp client crate 当成 CLI 用
  —— 那会让你的项目脱离 `Cargo.lock`，难以复现。

## 参考

- 官方 Rust SDK：<https://github.com/modelcontextprotocol/rust-sdk>
- 12 tool 完整 schema：[`../tools/index.md`](../tools/index.md)
- Python / TypeScript 等价文档：[`python-mcp-client.md`](python-mcp-client.md) / [`typescript-mcp-client.md`](typescript-mcp-client.md)

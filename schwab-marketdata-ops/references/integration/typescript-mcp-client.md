# Integration — TypeScript MCP client

> 在你自己的 **TypeScript / Node.js 应用**里作为 MCP 客户端调用
> `schwab-marketdata-mcp` server。用官方
> `@modelcontextprotocol/sdk`（<https://www.npmjs.com/package/@modelcontextprotocol/sdk>）。

## 适用场景

- 你在写 Next.js / Express / Fastify backend
- 你需要把 schwab 数据塞进 Web UI、Slack bot、或自己的 API gateway
- 你已经有 Node 项目，希望避免引入 Python 工具链

## 前置条件

- Node.js ≥ 18（推荐 ≥ 20，Web Streams API 稳定）
- npm / pnpm / yarn 任一
- 已完成 [Quick Start Step 1-4](../quick-start/step-1-developer-portal-app.md)

## 安装

```bash
mkdir my-schwab-app && cd my-schwab-app
npm init -y
npm install @modelcontextprotocol/sdk
npm install -D typescript tsx @types/node
npx tsc --init
```

## 最小 hello-world：health_check

```typescript
// src/hello.ts
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { homedir } from "node:os";
import { join } from "node:path";

const SERVER_REPO = join(homedir(), "code/kevinkda/schwab-marketdata-mcp");

async function main() {
    const transport = new StdioClientTransport({
        command: "uv",
        args: ["--directory", SERVER_REPO, "run", "schwab-marketdata-mcp"],
    });
    const client = new Client(
        { name: "my-schwab-app", version: "0.1.0" },
        { capabilities: {} },
    );
    await client.connect(transport);

    const result = await client.callTool({ name: "health_check", arguments: {} });
    console.log((result.content[0] as { text: string }).text);

    await client.close();
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
```

```bash
npx tsx src/hello.ts
# 期望：
#   {"server_version": "0.1.x", "token_state": "valid", ...}
```

## 调 get_quote（含错误处理）

```typescript
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { homedir } from "node:os";
import { join } from "node:path";

const SERVER_REPO = join(homedir(), "code/kevinkda/schwab-marketdata-mcp");

class SchwabClient {
    private client: Client;

    private constructor(client: Client) {
        this.client = client;
    }

    static async connect(): Promise<SchwabClient> {
        const transport = new StdioClientTransport({
            command: "uv",
            args: ["--directory", SERVER_REPO, "run", "schwab-marketdata-mcp"],
        });
        const client = new Client(
            { name: "my-schwab-app", version: "0.1.0" },
            { capabilities: {} },
        );
        await client.connect(transport);
        return new SchwabClient(client);
    }

    async call<T = unknown>(name: string, args: Record<string, unknown>): Promise<T> {
        const result = await this.client.callTool({ name, arguments: args });
        const text = (result.content[0] as { text: string }).text;
        const payload = JSON.parse(text) as { error?: string } & T;
        if (payload.error) {
            throw new SchwabError(payload.error, payload);
        }
        return payload;
    }

    async close(): Promise<void> {
        await this.client.close();
    }
}

class SchwabError extends Error {
    constructor(public readonly errorType: string, public readonly payload: unknown) {
        super(`${errorType}: ${JSON.stringify(payload)}`);
    }
}

async function main() {
    const c = await SchwabClient.connect();
    try {
        const info = await c.call<{ server_version: string }>("get_server_info", {});
        console.log("server_version:", info.server_version);

        for (const sym of ["VOO", "QQQ", "SPY"]) {
            type Quote = { symbol: string; quote: { lastPrice: number } };
            const quote = await c.call<Quote>("get_quote", { symbol: sym });
            console.log(sym, "=", quote.quote.lastPrice);
        }
    } finally {
        await c.close();
    }
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
```

## 错误处理模板

```typescript
async function safeCall<T>(
    client: SchwabClient,
    name: string,
    args: Record<string, unknown>,
    maxRetries = 2,
): Promise<T> {
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
            return await client.call<T>(name, args);
        } catch (err) {
            if (!(err instanceof SchwabError)) throw err;
            if (err.errorType === "SchwabValidationError") throw err;
            if (err.errorType === "SchwabAuthError") throw err;
            if (err.errorType === "SchwabRateLimitError" && attempt < maxRetries) {
                await new Promise((r) => setTimeout(r, 2 ** attempt * 1000));
                continue;
            }
            throw err;
        }
    }
    throw new Error("unreachable");
}
```

## Express / Next.js 集成模式

把 `SchwabClient` 做成进程级单例，在 server 启动时连接，关闭时
`client.close()`：

```typescript
// lib/schwab.ts
import { SchwabClient } from "./schwab-client";

let _instance: Promise<SchwabClient> | null = null;

export function getSchwab(): Promise<SchwabClient> {
    if (!_instance) {
        _instance = SchwabClient.connect();
    }
    return _instance;
}

// pages/api/quote.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { getSchwab } from "@/lib/schwab";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    const symbol = String(req.query.symbol ?? "").toUpperCase();
    if (!/^[A-Z$./ ]{1,21}$/.test(symbol)) {
        return res.status(400).json({ error: "invalid symbol" });
    }
    const c = await getSchwab();
    const quote = await c.call("get_quote", { symbol });
    res.json(quote);
}
```

## 性能建议

- **进程级单例**：每个 Node 进程持一个 MCP session，复用 server stdio。
- **避免在 Edge Runtime 跑**：MCP stdio transport 需要 Node `child_process`
  能力，Vercel Edge / Cloudflare Workers 跑不动；放到 Node serverless 或
  long-running container。
- **批量优先**：用 `get_quotes(symbols=[...])`，不要循环 `get_quote`。

## 不要做的事

- **不要** 把 schwab 数据原样塞回浏览器 client（用户绕过你的 server 直
  连 MCP 等于把你机器上的 token 暴露出去）—— 后端聚合后再 expose 到
  前端。
- **不要** 用 webpack / tsup bundle `@modelcontextprotocol/sdk` 时把
  Node-only 模块也打进 bundle —— 必须保持 Node runtime。

## 参考

- 官方 TypeScript SDK：<https://github.com/modelcontextprotocol/typescript-sdk>
- 12 tool 完整 schema：[`../tools/index.md`](../tools/index.md)
- Python 客户端等价文档：[`python-mcp-client.md`](python-mcp-client.md)

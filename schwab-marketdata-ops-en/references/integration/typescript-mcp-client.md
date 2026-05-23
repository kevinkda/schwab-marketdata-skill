# Integration — TypeScript MCP client

> Use the MCP client from your own **TypeScript / Node.js
> application** to call the `schwab-marketdata-mcp` server. Uses the
> official `@modelcontextprotocol/sdk` package
> (<https://www.npmjs.com/package/@modelcontextprotocol/sdk>).

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/integration/typescript-mcp-client.md`](../../../schwab-marketdata-ops/references/integration/typescript-mcp-client.md).

## When to use

- You're writing a Next.js / Express / Fastify backend
- You need to surface Schwab data inside a web UI, Slack bot, or
  your own API gateway
- You already have a Node project and want to avoid pulling in a
  Python toolchain

## Prerequisites

- Node.js ≥ 18 (≥ 20 recommended for stable Web Streams API)
- npm / pnpm / yarn
- [Quick Start Step 1-4](../quick-start/step-1-developer-portal-app.md)
  completed

## Install

```bash
mkdir my-schwab-app && cd my-schwab-app
npm init -y
npm install @modelcontextprotocol/sdk
npm install -D typescript tsx @types/node
npx tsc --init
```

## Minimal hello-world: health_check

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
# Expected:
#   {"server_version": "0.1.x", "token_state": "valid", ...}
```

## Calling get_quote (with error handling)

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

## Error-handling template

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

## Express / Next.js integration pattern

Treat `SchwabClient` as a process-level singleton; connect at
startup, `client.close()` at shutdown:

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

## Performance guidance

- **Process-level singleton**: each Node process holds one MCP
  session and reuses the server stdio.
- **Avoid Edge Runtime**: the MCP stdio transport requires Node's
  `child_process`; Vercel Edge / Cloudflare Workers cannot run it.
  Deploy on Node serverless or a long-running container.
- **Batch first**: use `get_quotes(symbols=[...])`, not a loop of
  `get_quote`.

## What not to do

- **Do not** forward Schwab data verbatim to the browser client
  (letting users bypass your server and connect to MCP directly
  exposes the token on your machine) — aggregate on the backend
  and expose a narrower API.
- **Do not** bundle Node-only modules from
  `@modelcontextprotocol/sdk` into a webpack / tsup bundle — keep
  the Node runtime.

## References

- Official TypeScript SDK: <https://github.com/modelcontextprotocol/typescript-sdk>
- Full schema for the 12 tools: [`../tools/index.md`](../tools/index.md)
- Python client equivalent: [`python-mcp-client.md`](python-mcp-client.md)

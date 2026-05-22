# Quick Start — Step 1: Register a Schwab Developer Portal app

> **Goal**: Create a **Market Data Production** app on the Schwab
> Developer Portal and obtain the two credentials: `App Key` and
> `App Secret`. Every later step depends on this.

## Prerequisites

- [ ] You have a Schwab personal account (not Schwab Bank — must be a
      Brokerage account)
- [ ] Your browser can reach <https://developer.schwab.com> (some
      corporate networks block it)
- [ ] You have carefully read
      <https://www.schwab.com/legal/terms> and
      <https://developer.schwab.com/legal>, and understand that Market
      Data is **non-redistributable**.

## Steps

1. Open <https://developer.schwab.com/dashboard/apps> in a browser and
   log in with your Schwab Brokerage account.
2. Click **Create App**.
3. Fill in the form:
   - **App Name**: pick a recognizable name (recommended pattern:
     `marketdata-personal-<your-handle>`). The name cannot be edited
     after creation, but you can delete and recreate.
   - **App Description**: a single-line purpose description, for example
     `Personal market-data research; private use only`.
   - **Callback URL**:
     - **login_flow** (default) → `https://127.0.0.1:8182`
     - **manual_flow** (headless / SSH-only) → `https://127.0.0.1`
   - **API Product**: select **Market Data Production** (required; do
     NOT select Trader API — neither this skill nor the MCP server
     calls the Trader API).
4. After submission, wait for Schwab review (usually 1–3 business days;
   the status will go from `Pending` → `Approved`).
5. Once the app is `Approved`, open the app's detail page:
   - Click **App Key**: copy it (~32 alphanumeric characters).
   - Click **App Secret** → **View**: copy it (~16 characters).

## Expected outcome

- App status = `Approved`
- App Key (32 chars) copied to clipboard or a secure scratch note
- App Secret (16 chars) copied to clipboard or a secure scratch note
- Callback URL is character-for-character identical to the upcoming
  `.env` `SCHWAB_CALLBACK_URL`

## Verification checklist

- [ ] App detail page shows `Status: Approved` (not `Pending` /
      `Suspended`)
- [ ] App Key is ~32 characters, fully alphanumeric
- [ ] Callback URL is recorded to clipboard or a secure location
- [ ] You can reach <https://developer.schwab.com/dashboard/apps> and
      see this app

## Common failures

| Symptom | Cause / fix |
| ------- | ----------- |
| App stuck in `Pending` for more than 5 business days | Schwab review backlog; use the app detail page's Contact channel to follow up |
| No **Market Data Production** option appears | Only personal Brokerage accounts have this product; Schwab Bank-only accounts do not |
| Registration succeeded but OAuth fails with `unsupported_response_type` | The app did not actually enable the Market Data Production product; delete the app and recreate it, making sure the product is selected |
| Callback URL has a trailing slash but `.env` does not (or vice versa) | They must be **character-for-character identical**; the next step uses `--dry-run` to verify this up front |

## Next step

→ [Step 2: Credentials & .env setup](step-2-credentials-env.md)

## References

- Upstream OAuth flow deep-dive: [`../oauth/oauth-overview.md`](../oauth/oauth-overview.md)
- ToS key excerpts: [`../tos-snapshot.md`](../tos-snapshot.md)
- Credential-leak emergency runbook: [`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)

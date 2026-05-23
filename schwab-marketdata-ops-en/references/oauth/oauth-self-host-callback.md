# OAuth — Self-host the callback endpoint

> **Advanced**: terminate the OAuth callback at your own https
> reverse proxy or public endpoint, fully independent of schwab-py's
> local 8182 listener. **Not recommended** as a default — every
> additional public hop expands the leak surface. Consider it only
> when both `login_flow` and `manual_flow` are infeasible.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/oauth/oauth-self-host-callback.md`](../../../schwab-marketdata-ops/references/oauth/oauth-self-host-callback.md).

## When to use

- The local machine has no browser at all + no browser anywhere can
  paste the redirect URL (extremely rare)
- A team shares a single OAuth app and wants the callback to land on
  a team-owned https endpoint for centralized auditing (**Note**:
  Market Data is non-redistributable, so team sharing already
  violates ToS; this section is provided purely as a technical
  reference)
- Intranet environments where loopback https listeners are forbidden
  by security policy, but you have a controllable internal https
  endpoint

## Mandatory preconditions

1. Must be **https** (Schwab does not accept http callbacks).
2. The endpoint must be registered on the Developer Portal as the
   callback URL **byte-for-byte** (including or excluding the
   trailing slash consistently).
3. You must be able to retrieve the full redirect URL the callback
   received (including `?code=...&state=...`).
4. You must feed the redirect URL back into the schwab-py CLI to
   complete the token exchange within 5 minutes (OAuth code expires
   in 5 minutes).

## Recommended architecture

```text
┌───────────────────┐    1. browser opens authorize URL
│  You (any machine)│ ────────────────────────────────────────────▶ Schwab OAuth
└───────────────────┘
         ▲                                                              │
         │ 4. copy redirect URL, paste into the target machine's manual_flow CLI
         │                                                              ▼
         │                                          ┌───────────────────────┐
         │      3. land in log / shared secret store │ Your https endpoint   │
         │  ◀────────────────────────────────────── │ (e.g. nginx + lua)    │
         │                                          └───────────────────────┘
         │                                                      ▲
         │                                                      │ 2. Schwab redirects
         │                                                      │    ?code=...&state=...
         ▼                                                      │
┌───────────────────┐
│  Target machine  │
│  manual_flow CLI │
└───────────────────┘
```

## Implementation notes

### 1. Simplest nginx + lua recipe

```nginx
server {
    listen 443 ssl http2;
    server_name oauth.example.com;

    ssl_certificate     /etc/letsencrypt/live/oauth.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/oauth.example.com/privkey.pem;

    location /schwab/callback {
        # Write the full query string into a protected log (root-only readable)
        access_log /var/log/nginx/schwab-oauth.log redirect_url_with_query;
        # Return a static HTML page prompting the user to copy the address bar
        default_type text/html;
        return 200 '<!doctype html><html><body><h1>OAuth callback received</h1>
            <p>Copy the full URL from the address bar and paste into your manual_flow CLI.</p>
            </body></html>';
    }
}

log_format redirect_url_with_query '$time_iso8601 $remote_addr $request_uri';
```

The `/var/log/nginx/schwab-oauth.log` file must be `chmod 600`
(root-readable only) and rotated / deleted within 5 minutes (the
OAuth code goes stale, but `state` provides CSRF protection and is
still sensitive).

### 2. After the callback, finish via `manual_flow`

```bash
# Step A: open the authorize URL provided by schwab-py in your browser
uv run python -m schwab_marketdata_mcp.auth manual_flow

# Step B: browser jumps to https://oauth.example.com/schwab/callback?code=...
# Step C: grab the full redirect URL from the address bar OR from the server log
# Step D: paste it back into the CLI stdin
```

Alternatively, your callback endpoint can **echo the full URL into
the HTML page**, letting the user copy from the page (avoiding the
SSH-into-server-to-read-log overhead).

## Security guidance

- The callback endpoint **should not** call the token endpoint
  itself (i.e. do not replace schwab-py's second leg). Doing so
  forces you to put the App Secret on the public endpoint,
  expanding the leak surface. Let the schwab-py CLI complete the
  token exchange on a machine you trust.
- The endpoint must log only the `?code=` and `?state=` parameters,
  never persist the full query string into a centralized log.
- Add the endpoint to a firewall allow-list: only Schwab egress IP
  ranges (Schwab does not publish stable IPs; relax to US East
  data-center ASNs if needed).
- TLS must use a valid certificate (Let's Encrypt / commercial CA);
  do not self-sign — Schwab does not validate the cert during
  redirect, but the user's browser does, and self-signing degrades
  UX.

## What not to do

- **Do not** use ngrok / Cloudflare Tunnel as a long-term callback
  endpoint — URL drift will repeatedly invalidate the Portal
  registration.
- **Do not** register the callback URL as `http://` — Schwab
  rejects.
- **Do not** forward the OAuth code to a third-party webhook — the
  code is a credential; keep it local for the token exchange.

## When to fall back to `login_flow` / `manual_flow`

In the vast majority of cases, `manual_flow` already suffices: you
just need **any** browser that can reach Schwab + the ability to
copy/paste a URL. If even that is impossible, fixing the browser /
clipboard issue is far simpler than maintaining a public https
endpoint.

## References

- End-to-end OAuth: [`oauth-overview.md`](oauth-overview.md)
- Default flow `login_flow`: [`oauth-login-flow.md`](oauth-login-flow.md)
- Headless flow `manual_flow`: [`oauth-manual-flow.md`](oauth-manual-flow.md)
- ToS on non-redistribution: [`../tos-snapshot.md`](../tos-snapshot.md)

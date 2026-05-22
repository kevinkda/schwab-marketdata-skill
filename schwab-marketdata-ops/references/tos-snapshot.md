# Schwab ToS — relevant excerpts (snapshot)

> **Disclaimer** — this file is a **convenience reference**, not legal
> advice.  Always verify against the current online text before relying
> on any of these clauses.  The authors of `schwab-marketdata-mcp` and
> this skill assume no responsibility for your interpretation.
>
> Sources (publicly accessible, no login required):
> * Schwab Online Services Agreement — <https://www.schwab.com/legal/terms>
> * Charles Schwab International Terms of Use — <https://international.schwab.com/terms-of-use>
> * Charles Schwab Third Party Terms — <https://www.schwab.com/legal/third-party-terms>
>
> Additional gated source (requires Schwab Developer Portal login;
> **not** mirrored here):
> * <https://developer.schwab.com/legal>

## Why this snapshot exists

Plan §9.1 mandates that the ops skill keep a **verbatim** copy of the
clauses we cite, so a future maintainer can verify we did not invent
clause numbers or rewrite the text.  The two excerpts below are pulled
from the "Market Information" section of the agreements at the URLs
above.  **Numbering / clause IDs are intentionally omitted** because
Schwab does not publish stable clause numbers and we refuse to invent
any.

## Excerpt 1 — non-redistribution

> "You will not redistribute or facilitate the redistribution of Market
> Information, nor will you provide access to Market Information to
> anyone who is not authorized by Schwab to receive Market
> Information."

## Excerpt 2 — automated-access prohibition

> "With the exception of applications commonly known as Web Browser
> software, or other applications formally promoted, endorsed or
> approved by Schwab in writing, you agree not to use any software,
> program, application or [...] device to access or log on to any
> Schwab Service [...] to automate the process of obtaining,
> downloading, transferring [...]"

## How this affects the project

1. Any markdown / report this server writes (e.g. via the workflows
   skill) **must** stay in **private** repositories.  The workflows
   skill enforces `gh repo view --json isPrivate` before writing.
2. Use of `schwab-py` only counts as Schwab-approved automation if the
   user has **registered their own app** in the Schwab Developer Portal
   and obtained Market Data Production access there.  Without that, the
   excerpt 2 prohibition applies.
3. `schwab-py` is an **unofficial** wrapper.  We do not represent that
   its existence is itself approved by Schwab.  Read the Developer
   Portal terms at <https://developer.schwab.com/legal> (login
   required) and decide for yourself.

## What we deliberately do NOT do

* We do **not** quote any clause numbers / section IDs.  Schwab does
  not publish a stable numbering scheme; inventing one would be both
  inaccurate and easy to misread as a citation.
* We do **not** mirror text behind a login wall (Developer Portal).
* We do **not** offer a legal opinion on whether your specific use is
  compliant.  That is between you, your attorney, and Schwab.

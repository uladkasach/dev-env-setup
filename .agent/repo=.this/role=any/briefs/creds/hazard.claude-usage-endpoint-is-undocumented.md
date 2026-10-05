# hazard.claude-usage-endpoint-is-undocumented

## .what

every number `brains.auth.usage` renders comes from **one undocumented endpoint**:

```
GET https://api.anthropic.com/api/oauth/usage
```

anthropic never published it, never promised it, and owes no notice before a change. the
vision named this the feature's top risk and paired it with a documented fallback — a
subshell snapshot of the interactive `claude /usage` widget, driven through a duct.

**that fallback does not exist.** it was never built, never stubbed, and until this brief it
was not on the deferred list either. so the feature today has exactly one leg.

## .why it matters

the blast radius is total, not partial. the endpoint is not one row of the render — it is
every row of it:

| the endpoint does this | brains.auth.usage does this |
|------------------------|-----------------------------|
| answers 200 with the windows | renders the tree |
| answers 404 / moves / is retired | renders **every** account as failed, forever |

`brains.auth.set` and `brains.auth.use` survive a retirement — they touch `/oauth/token` and
`/oauth/profile`, which are separate surfaces. only the **read** dies. so the failure is a
feature that stores and swaps accounts it can no longer measure, which is precisely what it
was built to do.

## .how it will look when it happens

the render already tells the truth, which is the mitigation that IS in place. an endpoint
that stops answers does not fake a number — it produces a named error node per account, and
the exit code says whose fault it is:

```
🧠 claude budget
   ├─ kai@example.com: 💥 the usage endpoint refused (http 404)
   └─
```

what it will NOT do is say "the endpoint was retired" — the code cannot know that. a total,
simultaneous failure across every account, with a 4xx that is not 401, is the signature.

## .the two guards against a silent death

1. **the pinned `User-Agent`.** an unrecognized UA buckets the request into a rate-limited
   path that 429s persistently. so a UA drift LOOKS like a retirement. rule out
   `hazard.claude-oauth-user-agent-429.md` before you conclude the endpoint is gone.
2. **the leaf is isolated.** the request lives in one place. a swap to an official API — or
   to the TUI snapshot — is a change to one leaf, not to the render, the severity table, the
   exit codes, or any of the 123 clamps. that isolation is the real hedge; the unbuilt
   fallback is not.

## 🛑 .the reset fields are OPT-IN, and the user-agent gates them

the same endpoint reports whether an account holds a usage reset, but only when asked the
way the cli asks. measured 2026-10-04 against cli 2.1.280:

```
GET /api/oauth/usage?cedar_ember=1&at_wall=1
User-Agent: claude-cli/<version> (external, cli)
```

| field | what it holds |
|---|---|
| `cedar_ember.grants[]` | saved reset grants: `resets_left`, `usable_now`, `ends_at` |
| `juniper_tide` | the weekly session reset: `available`, `resets_per_week`, `next_available_at`, `ineligible_reason` |

three traps, each a false read rather than an error:

| the read | what you see | what it means |
|---|---|---|
| no query flags | both fields `null` | the server was never asked. NOT "no reset" |
| any other user-agent | `ineligible_reason: "surface"` | the server did not see the cli. NOT "no reset" |
| `juniper_tide.ineligible_reason: "not_at_wall"` | `available: false` | it is offered only once a limit is hit |

⇒ `_brains_auth_reset_line` renders a `surface` read as `?`, never as "none" — that would be a
confident lie about an account that may hold a reset. it names only a reset that EXISTS, so an
account with none shows no reset row at all; that includes absent fields, so if the flags ever
stop to take effect, the reset rows go quiet on every account at once — read that as the signature.

⇒ the field names are internal codenames and will change with no notice. to rediscover
them, read what the installed cli asks for: `rhx brains.claude.strings --pattern 'cedar_ember|juniper_tide'`.

## .what to do if it dies

in preference order:

1. **look for an official API first.** the whole reason this endpoint is undocumented is that
   anthropic had no supported one. if they ship one, take it — `rule.require.solve-at-cause`.
2. **build the TUI snapshot the vision named.** drive `claude /usage` headless through
   `src/grove.provision/2.shell/2.7.aliases/ductwork.sh`, capture the rendered widget, parse the two windows out of it. this is a
   screen-scrape: it breaks on a cosmetic re-render, it is slower, and it needs a live claude
   session per account — which fights the one-holder-per-token invariant
   (`hazard.claude-oauth-one-holder-per-token.md`), since a session must be signed in as the
   account it measures. that conflict is the honest reason it was not built, and it is why
   this is a backstop rather than a second leg.
3. **accept the read is gone**, and keep `set` / `use`. an account fleet you can enroll and
   swap is still worth more than none.

## .the honest status

this is a **recorded, accepted risk**, not a mitigated one. the wisher accepted the
undocumented endpoint knowingly at vision time. this brief exists so that acceptance is
findable later — so the day it breaks, whoever reads the failure knows within a minute that
it was foreseen, what the signature is, and which three moves are open.

## .see also

- `hazard.claude-oauth-user-agent-429.md` — rule this out first; it mimics a retirement
- `hazard.claude-oauth-one-holder-per-token.md` — why the TUI fallback is hard, not merely slow
- `hazard.claude-oauth-refresh-rotation.md` — the token lifecycle the read depends on
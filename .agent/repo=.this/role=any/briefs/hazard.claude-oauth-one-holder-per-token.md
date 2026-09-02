# hazard: a claude oauth refresh token tolerates exactly ONE holder

## .what

a claude oauth `refresh_token` is **single-use with server-side rotation** (see
`hazard.claude-oauth-refresh-rotation.md`). the direct consequence, once you keep copies of a
token in more than one place, is this:

> **two holders of one refresh token cannot both stay live. whoever refreshes second is
> rejected, and the human is logged out.**

so any design that stores a subscription's token in two stores at once carries a latent
lockout. the fix is not "sync them" — it is to make sure only one store ever holds the live
copy of a given token.

## .why this is a hazard

it looks safe. a keyrack copy plus the `~/.claude` copy feels like redundancy — a backup. it
is not. it is two independent clients of a single-use secret:

- the global `claude` cli refreshes its token whenever the access token expires, and writes
  the rotated pair back into `~/.claude/.credentials.json`. the keyrack copy is now dead.
- a budget read that refreshes the keyrack copy rotates the token server-side, and the token
  the open `claude` session holds is now dead — the session drops to `401` mid-flight.

the second case is the one that actually bit: a probe refreshed a token read out of the live
`~/.claude/.credentials.json` and locked the human out of their session.

## .the rule

partition by holder, never duplicate:

| the subscription is... | its live token lives in... | who may refresh it |
|------------------------|----------------------------|--------------------|
| **active** (the global cli is signed in as it) | `~/.claude/.credentials.json` | the `claude` cli, alone |
| **parked** (stored, not signed in) | the keyrack | the budget reader, alone |

a slug is in exactly one of those states at a time.

## .never record which slug is active — derive it

the obvious implementation is a marker file that names the active slug. **it is wrong**, and the
reason is the whole lesson:

> a human may run `claude /login` at any moment and swap the account without a word to your tool.

any state your tool records about "who is signed in" is therefore a claim that goes stale behind
your back, with no event to correct it. act on that stale claim and you stow the live token under
the *wrong* slug — which corrupts two accounts at once.

so identity must be **derived from the live credential**, on every read, never remembered:

1. `GET https://api.anthropic.com/api/oauth/profile` with the live **access** token → `200` with
   `.account.uuid` + `.account.email`. authoritative, because it is derived from the token itself:
   whoever swapped it, and whenever, the answer tracks. (a read only — issue **no** refresh here,
   or you re-arm the lockout above.)
2. fallback, when the live access token has expired and the api would only answer `401`:
   `~/.claude.json` → `.oauthAccount.accountUuid` / `.emailAddress`.

   ⚠️ **this fallback can be CONFIDENTLY WRONG — measured, not theorized (2026-08-31).**
   `~/.claude.json` named `vlad@ahbode.com` while the live token in `.credentials.json` actually
   belonged to `seaturtle@ehmpath.com`. the two files are written at different moments and no
   mechanism keeps them in step, so the profile is a *lagging* record, never a second source of
   truth. a sweep that trusted it rendered seaturtle's budget under vlad's name.

### an identity read has THREE outcomes, not two

this is the trap that makes the stale fallback dangerous:

| outcome | what it means | how it must be treated |
|---------|---------------|------------------------|
| **known** | the api answered `200` for the token in hand | trustworthy |
| **unknown** | every source failed | refuse — do NOT overwrite or refresh |
| **confidently wrong** | a fallback answered, but its answer is stale | the dangerous one |

a guard built on "did the read succeed?" catches the second and **misses the third** — a stale
fallback succeeds. so a fallback answer is not equal in standing to an api answer:

- it may name a *display* identity (a label beside a number)
- it must NOT authorize a *mutation* — no park, no overwrite, no refresh decision may rest on it

when the api cannot be reached and the decision would rotate or overwrite a credential, treat
the identity as **unknown** and refuse, rather than act on a record that may lag reality.

a swap of your own must write **both** files — tokens into `.credentials.json` *and* the profile
block into `~/.claude.json` — or claude's own view names the prior account until it next refreshes.

### there is no fact left to cache

an earlier cut kept a `uuid -> slug` join table, because a slug was a name we invented and the
two had to be joined somewhere. that need is gone: each key is cut at the account's own email
(a keyrack **reach**), so the email the identity read returns is already the name the key is
filed under. cache no state — the whole answer is re-derived from the live token every time.

## .what this forces on each operation

- **a budget read of the ACTIVE account** must take the access token already present in
  `~/.claude/.credentials.json` and issue **zero refreshes**. an expired one is claude's to
  renew, not ours — report that as its own named fix.
- **a budget read of a PARKED account** refreshes freely, because no other client holds that
  token, and writes the rotated one back to the keyrack.
- **a swap** must **park before it installs**: harvest the live refresh token out of
  `~/.claude` into the keyrack at the prior account's reach, *then* overwrite. the keyrack copy
  of an active account is stale by construction, so an overwrite without the harvest step
  orphans that account — it needs a full browser re-auth to recover.
- **a swap out of a hand-made login** needs no ceremony from the human. its reach is *derived*
  (above), so the swap stows it automatically under that name. only a login whose identity
  cannot be read at all — api unreachable AND profile file unreadable — is refused, because
  then the token would be overwritten with no name to reclaim it under.

## .the tell

if you catch yourself about to write "keep the two copies in sync", stop. a single-use secret
has no consistent two-copy state — only a race with a loser. re-partition instead.

## .in brains.auth.*

`_brains_auth_whoami` derives the identity (api first, profile file second);
`_brains_auth_active_reach` reads the email off it — which IS the account's name, since each
key is cut at its owner's email (a keyrack **reach**), so no join table sits in between;
`_brains_auth_node_for_reach` branches on that and takes the live access token for the active
account; `_brains_auth_park_active` harvests before `_brains_auth_install_creds` overwrites; and
`_brains_auth_sync_profile` writes claude's profile block after a swap so its view agrees.

detection costs one api call, so it is done **once** per command and passed down — a per-account
re-detect would multiply it by the number of subscriptions.

## .why the reach makes this safer

the earlier scheme filed each account under an invented handle (`…__FOR__caseyatahction`), so
"which account is signed in?" had to be answered in two hops: derive the identity, then join it
to our handle. that join was a second place to be wrong, and the join table was a record that
could drift from the live login.

with the key cut at the account's own email, the identity read *is* the lookup key. one hop, no
table, so the class of bug where we correctly detect the account and still read the wrong key
cannot occur.

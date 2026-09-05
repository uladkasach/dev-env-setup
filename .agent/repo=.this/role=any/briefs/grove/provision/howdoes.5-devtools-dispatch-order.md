# howdoes: `5.devtools` dispatches by dependency, never by digit

## .what

`5.devtools/_.sh`'s dispatch list is the order of record. a directory number is a
stable NAME, never a position — `5.11.usql` already runs before `5.10.repos`. this
brief traces why each swap exists.

## node and rust come first

node and rust are the two runtimes every leaf beneath them leans on. `5.3.brains`
installs through npm, so node must already be there.

## treesitter runs third, right behind rust

its `cargo install` needs cargo, and cargo arrives with `5.2.rust`. its directory
number is `5.14` — the free tail, since `5.3` is taken — because this list, not the
digits, is the order.

## gh runs after brains

gh is useless without a credential, and the only source of one on a grove is
keyrack, which ships inside rhachet, which `5.3.brains` installs. at `2.4` it once
asserted a dependency the shell did not have, and its auth phase failed on every
grove run tens of bundles before its first consumer.

## rack sits between aws and gh, out of numeric order

📜 2026-08-10: keyrack alone was not enough. the token's VALUE was live and
readable in ssm, and every consumer still answered `absent 🫧`, because a
`keyrack get` finds a slug through the host manifest in `$HOME` — and a manifest
dies with the box that held it. `5.12.rack` writes that entry, so it must precede
gh, its consumer, and must follow `5.6.aws`, since it reads the value out of ssm
through the aws cli. gh at `5.4` and aws at `5.6` put rack's two constraints on
opposite sides of its own number.

⇒ a renumber to align the digits (aws → `5.4`, rack → `5.5`, gh → `5.6`) is a
clean rework, deferred so the bundle lands without churn across six neighbor
paths and every brief that names them.

## identity runs right after gh

git's `user.name`/`user.email` are derived from the account this box's own github
credential authenticates as, so the identity cannot exist before gh holds a
login.

⇒ three bundles wear this same shape — `5.15.identity`, `5.14.treesitter`, and
`5.4.gh`: numbered for their subject while the real dependency is a tool or
credential that lands later. when a phase declines because its dependency comes
later, move the phase.

## repos runs late, reach runs last

`5.10.repos` clones every org repo, the one step whose value depends on every
tool above it already on the box. it is also gh's first and only consumer, so
`5.4` before `5.10` is the claim that matters.

`5.13.reach` runs last, and only that repo clone lets it exist at all. it gives
this box an identity in each env its suites target, and it reads two inputs from
clones: the role name from `ahbode/infrastructure`, the account id from a repo's
`declapract.use.yml`. before `5.10.repos` there is no declaration to read, so this
bundle correctly declines until then.

## every install here is a bundle, never a function on a roll

a roll reaches only what somebody remembers to write, so a declared but undriven
install reads as live and is dead — `install_ripgrep`, `install_usql`,
`install_yubikey_agent`, and `install_rust` each sat that way, two of them with
comments that told a human to source the file and call them by hand. a bundle is
reached by the filesystem instead (`rule.require.bundle-as-sole-declaration`).

⚠️ one home per concern, in both directions: ripgrep is `2.1.toolkit`'s, on its
essential list. a ripgrep bundle here would give one concern two owners. toolkit
is the right owner — it runs in section 2, and `rg` is what nvim, claude, and rhx
reach for long before section 5.

## .see also

- `5.devtools/_.sh` — the dispatch list this brief explains
- `rule.require.bundle-as-sole-declaration` — why every install is a bundle
- `rule.require.one-command-provision` — the defect shapes this order avoids

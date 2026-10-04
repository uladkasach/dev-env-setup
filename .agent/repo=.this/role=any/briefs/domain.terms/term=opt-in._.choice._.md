# domain.term: opt-in

term.chosen   = opt-in
term.kind     = adj
term.boundary = bundle        # ⚠️ a SECOND boundary now exists — see below
term.synonyms.forbidden:
- optional
- opt-out
- enabled
- feature-flag
- toggle

## .what
of a bundle: it RUNS on every applicable box and converges only what the human ASKED for.
the default is none, and the ask is what turns it on.

it is a second, independent gate. a bundle must clear the BOX gate (can this box class
run it at all) AND the opt-in gate (did the human ask) — see `define.6-apps-is-laptop-only.md`.

⚠️ **the ask is recorded two ways, and the word covers both.** what parts them is WHERE the
human's answer lives, never whether it is an opt-in:

| mechanism | where the ask lives | lifespan | opt-out |
|---|---|---|---|
| `--include <app>` — `6.apps` | the command | that ONE run | skips; never uninstalls |
| a declared flag — `5.18.openhours` | the tree | until a human edits it | tears down |

⇒ a per-run flag suits an APP, whose absence costs a human an editor. it is wrong for a GATE,
which a human would have to re-request on every apply or silently lose. so a gate declares
its ask in the tree and converges (`rule.require.one-command-provision`).

🛑 `--include` validates against `GROVE_OPTIN_APPS`, which only `6.apps` bundles append to.
so `--include openhours` names an app no bundle offers and is refused.

## 🔴 .a SECOND boundary — recorded 2026-09-24, and the split is OWED

`rule.require.a-grove-reaches-its-own-org-only` uses `opt-in` for a different subject, and
the concept underneath is the same one: **a default of none, turned on by an explicit
declaration.** what differs is the boundary, so the repair is to QUALIFY rather than to
coin (`rule.require.boundary-qualified-terms`, its context arm):

| boundary | of WHAT | who declares it | lifespan |
|---|---|---|---|
| `bundle` | a bundle converges what the human asked for | a HUMAN, per box | one run, or until edited |
| `reach` | one org grants another org's groves reach into a named account | an ORG, per account+role | until that org revokes it |

⚠️ **they are not interchangeable, and the flat name invites the swap.** a `bundle` opt-in is
a per-box convenience whose absence costs a human an editor; a `reach` opt-in is a permanent
cross-account grant whose over-application is the defect the rule above was written from.

⇒ the qualified names are `bundle.opt-in` and `reach.opt-in`. this cluster is not renamed yet
— the gap is recorded here so the next reader does not read one sense as both, and the rename
is owed on the next touch, files first, no sweep.

## .refs
where the term is declared / used:
- src/bundle.upgrade.sh                          # GROVE_OPTIN_APPS, grove_optin, grove_optin_decline
- src/grove.provision._.sh                        # `--include`, and the refusal of a name no bundle offers
- src/grove.provision/6.apps/6.1.flatpaks/_.sh    # three names offered by ONE bundle
- src/grove.provision/6.apps/6.2.codium/_.sh      # the one-name shape
- src/grove.provision/5.devtools/5.18.openhours/_.sh  # the DECLARED-flag mechanism
- .agent/repo=.this/role=any/briefs/grove/provision/define.6-apps-is-laptop-only.md
- .agent/repo=.this/role=any/briefs/grove/provision/howto.opt-into-openhours.md

⚠️ the OFFERED set lives in the bundles and nowhere else. the parser holds no list of app
names — it validates `--include` against what the tree built while it sourced
(`rule.require.bundle-as-sole-declaration`).

## .reason
see the ref-level cluster beside this choice:
- `term=opt-in._.choice.reason.md` — etymology, disputes, evidence

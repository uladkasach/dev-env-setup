# domain.term: opt-in

term.chosen   = opt-in
term.kind     = adj
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

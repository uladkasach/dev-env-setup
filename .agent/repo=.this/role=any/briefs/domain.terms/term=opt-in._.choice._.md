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
of a bundle: it RUNS on every applicable box and installs only the apps the human named
on the command. the default is none, and a name is what turns one on.

it is a second, independent gate. a bundle must clear the BOX gate (can this box class
run it at all) AND the opt-in gate (did the human ask) — see `define.6-apps-is-laptop-only.md`.

## .refs
where the term is declared / used:
- src/bundle.upgrade.sh                          # GROVE_OPTIN_APPS, grove_optin, grove_optin_decline
- src/grove.provision._.sh                        # `--include`, and the refusal of a name no bundle offers
- src/grove.provision/6.apps/6.1.flatpaks/_.sh    # three names offered by ONE bundle
- src/grove.provision/6.apps/6.2.codium/_.sh      # the one-name shape
- .agent/repo=.this/role=any/briefs/grove/provision/define.6-apps-is-laptop-only.md

⚠️ the OFFERED set lives in the bundles and nowhere else. the parser holds no list of app
names — it validates `--include` against what the tree built while it sourced
(`rule.require.bundle-as-sole-declaration`).

## .reason
see the ref-level cluster beside this choice:
- `term=opt-in._.choice.reason.md` — etymology, disputes, evidence

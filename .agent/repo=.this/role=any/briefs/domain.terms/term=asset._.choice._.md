# domain.term: asset

term.chosen   = asset
term.kind     = noun
term.synonyms.forbidden:
- template     (implies a substitution pass; an asset is copied BYTE FOR BYTE)
- fixture      (test vocabulary; an asset ships to a real machine)
- resource     (generic to the point of empty — every file is a resource)
- payload      (allowed ONLY for the two systemd-driven files; see .reason)
- blob         (says opaque; an asset is read, diffed, and reviewed)
- static file  (names what it is not, and every file in `src/` is static)

## .what
a file under `src/` that a bundle phase **copies onto a box unchanged**, and whose live copy a
verify can therefore `cmp` against the checkout.

an asset is the alternative to a heredoc. the same bytes written inline in a phase have no
second copy to diff, so a verify can prove PRESENCE and never CURRENCY.

## .the test
a file is an asset when all three hold:
- it lives under `src/` — the deployable unit `git.grove.push --from src` carries
- exactly one bundle phase copies it, and copies it verbatim
- that bundle's verify diffs the live copy against `$GROVE_SRC/...`

a file that fails the third is not yet an asset; it is a copy with no owner.

⚠️ the third condition exists to catch **drift** — the live copy silently differs from the
declaration while it still exists and still runs. that is the whole job of the `cmp`, and the
reason an existence test cannot qualify a file as an asset (`term=drift._.choice._.md`).

## .refs
- src/firefox/autoconfig.js                        # 1.3.1.firefox
- src/firefox/firefox.cfg                          # 1.3.1.firefox
- src/machine/kitty.snapshot.terminals.sh          # 4.3.4.snapshot
- src/machine/kitty_snap_lowbatt{,.service,.timer} # 4.3.4.snapshot
- src/machine/machine_usage_snapshot               # 1.7.usage
- src/machine/machine_resource_procs_monitor       # 1.6.2.monitor
- src/init.lua, src/tmux.conf, src/starship.toml   # the long-extant ones
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.bundles-own-their-dependencies.md

## .reason
see the ref-level cluster beside this choice:
- `term=asset._.choice.reason.md` — the two 2026-07-31 grove failures that settled it, why
  `payload` is bounded rather than forbidden, and why the word is not `template`

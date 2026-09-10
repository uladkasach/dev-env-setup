# domain.term: install

term.chosen   = ⛔ RETIRED — see `.the retirement` below
term.kind     = verb
term.status   = RETIRED 2026-09-07, superseded by `grove.provision` + `asset`

## ⛔ .the retirement

this cluster was authored 2026-09-06 against a tree that no longer exists. every contract it
anchored on has been deleted, and its central argument was **decided the other way** by the
human on 2026-08-31: *"Full rename — I did mean everywhere"*.

| this cluster claimed | what actually holds |
|---|---|
| `install` is the canonical verb | `grove.provision` is. `install` is retired repo-wide |
| `provision` is a FORBIDDEN synonym | `provision` is the CHOSEN word (`term=grove.provision`) |
| `src/install_env._.sh` is the dispatcher | deleted 2026-07-30 in the hard cut |
| `rule.require.root-install-invocation` depends on the prefix | renamed `rule.require.every-function-has-a-driver`, and it dropped the prefix test outright |
| ~7 heredoc'd artifacts live in `install_env.pt1` | they are **assets** under `src/machine/`, copied by a bundle phase |

⚠️ so this file is kept as a **tombstone**, never as a live term. it is here because a reader
who types the old word needs a page that says what it became — the same reason
`term=devenv._.choice._.md` survives its own family's retirement.

## ✅ .the claim it got right, and where that lesson lives now

the cluster's measurement was real, and it is the exact defect main's `asset` term exists to
close:

> **an `install_*` that heredocs a repo-authored artifact has no absence to test. its real
> precondition is a stale copy, and staleness is invisible until it misleads.**

measured 2026-09-06: the orphan-hunt fix sat in `src/` for hours while
`~/.local/bin/machine_resource_procs_find_orphan` kept the old copy and offered `kill -9` on six
healthy chrome zygotes. no report anywhere said the binary was behind — because `install`'s name
promises **absence**, so a present binary reads as satisfied.

⇒ the repair is not a better verb. it is a second copy to compare against:

- `term=asset._.choice._.md` — a file under `src/` a phase copies UNCHANGED, so a verify can
  `cmp` the live copy against the checkout. a heredoc has no second copy, so a verify can prove
  PRESENCE and never CURRENCY
- `rule.require.judge-declared-state-not-live-state` — the rule that demands the diff
- `rule.require.upgrade-entries-verify-themselves` — why every claim owes a verify half

## .where the word still appears, legitimately

- `rule.require.install-via-procedures` — the brief keeps its name on purpose. its subject is
  broader than the retired verb: *never hand a human a one-off command*. its own `.note on this
  brief's own name` records that `install` is superseded
- `pkg_install` — the shared runtime's package call. it names an apt/dnf verb, not this repo's

## .reason

see the ref-level file beside this choice:

- `term=install._.choice.reason.md` — the two-column split that made the word ambiguous, and why
  the ambiguity is now carried by `asset` rather than by a widened verb

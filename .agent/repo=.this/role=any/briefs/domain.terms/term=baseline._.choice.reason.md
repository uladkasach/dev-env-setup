# domain.term.choice.reason: baseline

## .etymology

borrowed from surveyance and from test practice, where a baseline is the measured
floor all else is read against — not the typical case, and not a limit. that is
exactly the sense here: the set of node versions a box is guaranteed to hold,
whatever any one repo asks for on top.

`5.1.node` names it `GROVE_NODE_BASELINE`, and the operation that widens it with
the checkout's own pin is `grove_node_versions_wanted`.

## .the measurement that earned the term

grove-1, 2026-08-03. the bundle had provisioned this box, and every claim it made
read ✔. then a plain `cd` into the checkout:

```
Can't find an installed Node version matching v22.21.0.
Do you want to install it? answer [y/N]:
```

that call sat 4m16s. the box held `v24.18.0`, `v24.18.1`, `system` — and no 22.x
at all, because `fnm install --lts` and `.nvmrc` were two lists that named two
versions and knew of each other not at all.

⚠️ the word matters here because the bug was a **conflation**. every sentence in
the bundle said "node is installed", and that sentence was true of the DEFAULT
and false of the set. one word across both is what let a green run sit beside a
shell that hung.

## ⚠️ .why `default` is the forbidden synonym that costs the most

fnm has both concepts and names them separately — `fnm default` sets the one,
`fnm list` shows the set. this repo had a word for the first and no word for the
second, so the second went unnamed and therefore unverified: `provision.verify`
asserted `fnm's default node is v24.18.1 ✔` and could not see that a pinned
version was absent.

a concept with no name gets no claim. `rule.require.upgrade-entries-verify-themselves`
cannot be honored for a fact the vocabulary cannot state.

## .why `allowlist` was declined

an allowlist implies the unlisted are refused. the opposite is true here: a
version outside the baseline installs on demand, silently, because the cd hook
carries `--install-if-missing`. the baseline decides what is already on disk, not
what is permitted.

## ⚠️ .the boundary — a baseline is not a guarantee

this is the distinction most apt to be lost by a later reader, so it is recorded
rather than implied:

| concept | what it does | where it lives |
|---|---|---|
| the baseline | holds common versions, so the common case costs no download | `5.1.node` |
| the hardened hook | makes a prompt impossible, for ANY version | `src/zshrc.sh` |

a baseline reaches only repos already known, and a grove clones repos nobody
enumerated. so the baseline is an optimization and the hook is the guarantee. to
offer the baseline AS the guarantee is the failhide shape — a real improvement
reported as a closed hole.

`prove.fnm-cd-never-prompts` exists to keep that line honest: it deliberately
picks a version the baseline does NOT carry, because a probe that tested a
baseline version would prove the optimization and call it the guarantee.

## .disputes

none open.

`preinstalled` was weighed and declined: it names WHEN the versions arrive rather
than WHAT the set is for, and by that logic every asset this repo copies is
preinstalled — so the word separates no concept from any other.

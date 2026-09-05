# domain.term: bootstrap (in `grove.bootstrap`)

term.chosen   = bootstrap
term.kind     = noun
term.synonyms.forbidden:
- entrypoint
- init
- setup
- installer
- prelude
- preinstall
- onboard

## .what
the act that puts this repo onto a **bare** machine, so `grove.provision` can then run at all.
it is the one step that cannot be a step of the run it starts.

## .where
`grove.bootstrap.sh` at repo root — fetched standalone, driven only by `readme.md`.

## .refs
where the term is declared / used:
- grove.bootstrap.sh                                             # the artifact
- readme.md                                                       # the human's entrypoint, which drives it
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.every-function-has-a-driver.md  # its one exemption from the step driver

## .why it is NOT `entrypoint`
`grove.provision._.sh` is already declared **THE** entrypoint, and that singularity is load-bear —
it is the reason one run converges the whole machine
(`rule.require.grove-provision-as-the-only-entrypoint`). a second file named `entrypoint` would
put one word on two concepts and make "which entrypoint?" a permanent question
(`ubiqlang.ambiguous-from-overload`).

the two also differ in kind: an entrypoint is where the work *starts*; a bootstrap is what makes
a start *possible*.

## .why the FILE carries the prefix too
the term is prefixed per the glossary's rule — a `grove.bootstrap` is conceivable (a wake path
could fairly claim the word), so a bare term would silently claim the whole repo.

the file carries it as well, and that was a **correction**: the first draft left the file bare
(`bootstrap.sh`), on the argument that repo root supplies the context. that argument was true but
beside the point — see the `.reason` for why the deferral was the error, not the name.

## .reason
see the ref-level cluster beside this choice:
- `term=grove.bootstrap._.choice.reason.md` — etymology, the rejected words, evidence

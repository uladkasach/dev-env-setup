# domain.term: trust

term.chosen   = grove.trust
term.kind     = noun
term.synonyms.forbidden:
- hostkey       # the box's asset, not ours — see .reason
- fingerprint   # the evidence that backs a trust, not the trust itself
- knownhost     # names the file that stores it, not the concept

## .what
our recorded belief that a given endpoint IS a given grove — the `~/.ssh/known_hosts`
entry that lets a headless ssh reach a grove without a human at the prompt.

## .refs
where the term is declared / used:
- .agent/repo=.this/role=any/skills/git.grove.trust.gen.sh   # findsert a grove's trust

## .reason
see the ref-level cluster beside this choice:
- `term=grove.trust._.choice.reason.md` — etymology, the hostkey dispute, evidence

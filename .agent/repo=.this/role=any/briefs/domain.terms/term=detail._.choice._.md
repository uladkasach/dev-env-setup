# domain.term: detail

term.chosen   = detail
term.kind     = noun
term.synonyms.forbidden:
- the log
- output
- verbose

## .what

the failure-level output a **summary** names but does not carry.

a tool that reports a tally writes two artifacts. its SUMMARY holds the counts, the timings,
and the PATHS of its logs — and that is what a caller captures. its DETAIL holds the error
strings, and it stays where the tool wrote it. a caller that captures the summary and cites
it as the detail sends a reader to a file that cannot answer.

## .the pair

| word | holds | who reads it |
|---|---|---|
| summary | the tally, the timings, the paths | a gate, to count |
| **detail** | the error strings | a human, to diagnose |

⚠️ `summary` is ordinary english and is NOT itemized — only `detail` earns a cluster, because
its absence was the defect. see the `.reason`.

## .refs

- `.agent/repo=.this/role=any/skills/git.grove.provision.test.sh` — rung 4 fetches the detail
  onto the failure path, since its own fix-text asks a reader to sort by error string
- `rhx git.repo.test` — the tool whose two artifacts named this split

## .reason

see the ref-level cluster beside this choice:
- `term=detail._.choice.reason.md` — etymology, the measurement, forbidden synonyms

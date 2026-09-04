# domain.term: sink

term.chosen   = sink
term.kind     = noun
term.synonyms.forbidden:
- filter
- sanitizer
- scrubber
- cleaner
- strip (as a NOUN — `strip` is the verb this noun performs)

## .what

the ONE place remote-chosen bytes are made inert before they reach a terminal that
obeys them. `__duct_strip_escapes` is the sink; every relay feeds it AT CAPTURE.

a sink has three properties, and a reader with fewer is not one:

1. **one per boundary** — a second sink is m.9, and the copy nobody re-reads drifts
2. **fed at CAPTURE, never at print** — a value with three readers and a strip at one
   of them is guarded at one of three
3. **it takes EVERY stream the boundary CARRIES REMOTE TEXT ON** — stdout and stderr
   both, or it guards half its input while it reads as whole.
   ⚠️ measured 2026-09-01: WHICH streams those are is a property of the ARGUMENTS, not
   of the tool. `rsync -az` writes zero bytes to stdout; `-az --no-links` writes a skip
   notice that NAMES a remote file. so a one-stream sink can be correct, and it turns
   incorrect the moment somebody widens the flags. see the `.reason`.

## .refs

- `src/ductwork.sh` — `__duct_strip_escapes`, the sink itself
- `.agent/repo=.this/role=any/skills/git.grove.push.sh` — `STALE` is stripped at capture
- `.agent/repo=.this/role=any/skills/aws.ec2.get.sh` — the whole render is piped, not a field list
- `src/grove.provision/2.shell/2.7.aliases/configure.verify.sh` — RUNS the sink and reads its hex back

## .reason

see `term=sink._.choice.reason.md` — why a `grep` is not a sink, and the two
measurements that each cost a sink half its input.

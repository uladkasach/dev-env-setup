# domain.term.choice.reason: pull

## .etymology
the mirror of `push`, and again git's own word — content moves from there to here. settled in
the same round as `push` so the pair stays symmetric
(`rule.prefer.symmetric-term-pairs`): one motion, two directions, read at a glance.

chosen over:
- `download` — http/web jargon, same objection as `upload` for push
- `fetch` — collides with git's OWN `fetch` (which gets refs without a merge); to reuse it
  for content transfer would overload one word onto two distinct concepts
- `copy-from` / `retrieve` — mechanical, and each breaks the push/pull symmetry

## .disputes
none yet.

## .evidence
- symmetry: `git.grove.push` / `git.grove.pull` name the same transfer in two directions
- narrative: work happens ON the grove — a log, an artifact, an edit in a remote tree. the
  developer says "pull it back" to inspect or commit from the machine that holds the repo
- the pair is the reason grove needs neither a bespoke `send`-style transfer nor an scp
  wrapper: push/pull already name both directions of content motion

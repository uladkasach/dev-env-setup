# domain.term: arrow

term.chosen   = arrow
term.kind     = noun
term.boundary = brains (a claude settings path that resolves to another)
term.synonyms.forbidden:
- link      (the generic unix word; it hides that the chain can be two hops, and that a write
             through it lands at the far end)
- alias     (overloaded here — `grove.alias` and the shell aliases already hold it)
- pointer   (reads as a value inside a file, never a path on disk)

## .what
an **arrow** is a claude settings path that is a symlink, or a chain of symlinks, to another
settings file. every tree's `.claude/settings.json` is an arrow (two hops) to
`~/.claude/settings.json`, so a write that a tree's init makes to "its" settings lands in home.

the word names the DIRECTION, which is the whole hazard: a write travels along it to the far end.

## .refs
- src/grove.provision/5.devtools/5.3.brains/configure.upsert.sh   # the boot gate's arrow check
- src/grove.provision/5.devtools/5.3.brains/configure.verify.sh   # the writable ✋ names it
- .play/permanent/prove.claude-home-settings-refuses-a-foreign-write.play.sh   # the fixture's arrow

## .reason
- `term=brains.arrow._.choice.reason.md`

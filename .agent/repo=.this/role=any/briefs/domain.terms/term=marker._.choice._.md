# domain.term: marker

term.chosen   = marker
term.kind     = noun
term.synonyms.forbidden:
- sentinel     (says "watches for a condition"; a marker asserts a fact and watches none)
- guard        (the guard is the `grep`; the marker is what it looks FOR — see .reason)
- tag          (already spoken for: `--for`'s applicability tags)
- fingerprint  (implies derivation from content — the whole point is that it is not)
- signature    (reads cryptographic; a marker proves no claim about authorship)
- header       (names a position in a file, not a claim about it)
- comment      (what it is spelled as, not what it does)

## .what
a fixed line a bundle appends into a file it does not own, so a later run can ask
"is my block already here?" without a read of the block itself.

it is what makes an APPEND idempotent. the append is not idempotent on its own;
only the marker's findsert makes it so.

## .what it is NOT

a **local file that remembers a remote fact** is a `record`, never a marker. a
marker sits inside the artifact it speaks about, so it cannot outlive its
subject; a record is held apart from its subject and therefore can. that
difference is the whole guarantee this term carries — see `.reason`, where a
mis-spelled record survived a box rebuild and reported an apply on a terminated
instance.

## .the form
```sh
# grove: <the claim, in words>
```

`grove:` scopes it to this repo, so a marker never collides with a line the
file's other writers put there. the words after it name the CLAIM — never the
command, and never the bundle slug (a bundle may be renamed; its claim does not
move).

## .the test
a line is a marker when all three hold:
- it is FIXED — no value derived from the block below it
- the `grep` that finds it is the only thing that decides whether to append
- an edit to the code beneath it leaves the marker untouched

a guard that greps a fragment of the code it writes fails the third, and is the
defect this term exists to name (`rule.forbid.two-writers-on-one-artifact`).

## .the migration a marker rename owes
a marker is a contract with every box already provisioned. to rename one without
a legacy grep beside it is to append a second block to every extant box — the
repair breaks idempotence once, everywhere, on the run that lands it.

## .refs
- src/grove.provision/1.system/1.1.keybinds/configure.upsert.sh   # `# grove: keynav autostart at login`
- src/grove.provision/1.system/1.2.power/configure.upsert.sh      # `# grove: start each login in the battery power profile`
- src/grove.provision/5.devtools/5.1.node/configure.upsert.sh     # `# grove: fnm + pnpm on PATH for login shells` — the first one
- src/grove.provision/4.terminal/4.3.kitty/4.3.1.terminfo/        # the `~/.bashrc` appender
- .agent/repo=.this/role=any/briefs/evidence/rule.forbid.two-writers-on-one-artifact.md

## .reason
see the ref-level cluster beside this choice:
- `term=marker._.choice.reason.md` — the etymology, why it is not the `guard`, and
  the 2026-07-31 audit that found two guards which could never match

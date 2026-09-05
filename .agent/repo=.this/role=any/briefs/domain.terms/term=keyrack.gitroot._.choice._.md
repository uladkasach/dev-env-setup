# domain.term: keyrack.gitroot

term.chosen   = keyrack.gitroot
term.kind     = noun
term.synonyms.forbidden:
- rackroot
- scratch repo
- keyrack repo
- workdir

## .what
the directory a keyrack call is run FROM — a git root, because rhachet's cli refuses
every keyrack subcommand outside one.

on a box whose checkout is a real clone that is the cwd. on a box whose checkout was
PUSHED (which has no `.git` by design), it is a throwaway `git init` directory the
`5.12.rack` bundle owns, at `$HOME/.local/state/keyrack.gitroot`.

## .refs
- `src/grove.provision/5.devtools/5.12.rack/_.sh`             # `…_rack_gitroot`, the owner
- `src/grove.provision/5.devtools/5.12.rack/configure.upsert.sh`
- `src/grove.provision/5.devtools/5.12.rack/configure.verify.sh`
- `src/grove.provision/5.devtools/5.13.reach/configure.verify.sh`
- `.agent/repo=.this/role=any/skills/aws.reach.set.sh`        # `GITROOT`, the reader

## ⚠️ .the gitroot a HELPER runs from is not one it chose

the rows above are calls this repo makes, so each picks its own gitroot. the credential
helper cannot: **git invokes it from whatever repo the human stands in**, and a grove
holds ~200 clones.

that bit on 2026-08-08. `git tree set` inside `ahbode/svc-chat` dropped to an interactive
username prompt on a duct — because svc-chat's own `.agent/keyrack.yml` `extends` a file
it does not vendor, so the manifest read THREW, and the helper declined rather than
answered. the rack was perfectly healthy; the cwd was the whole fault.

⇒ so `git-credential-keyrack` must reach a gitroot it controls, never the ambient one.
`prove.git-creds-from-any-clone.play.sh` is the clamp: it runs the helper from a clone
whose manifest cannot load, and demands a token anyway. run it after any change to how
the helper picks its root.

## .why the `keyrack.` prefix, and why the BARE word stays in code
this dir requires a term to carry its bounded context (`.readme.md`), and `git root` is
a generic phrase every git repo has. the prefix says WHICH one: the root a KEYRACK call
runs from, which is a different question from "where is this repo's top level".

⚠️ the prefix is on the TERM, not on every identifier. in code the context is already
carried by scope — `grove_provision_5_12_rack_gitroot` and, inside a skill whose whole
job is one keyrack pair, a plain `GITROOT`. to spell `KEYRACK_GITROOT` there would
repeat what the file already says (see the resolved `rackroot` dispute, which turned on
exactly this).

## .reason
see the ref-level cluster beside this choice:
- `term=keyrack.gitroot._.choice.reason.md` — etymology, the synonym drift this round
  caught

# S5 — each tree is an atomic, efficient, self-contained unit

## .said

why was it killed? and can we get it to continue from where it left off? e.g., do each tree one by one?

and should we just have it also backed up for the tree in a reproducible way?
but yeah, it'd be great if each tree could be atomically backed up

that would enable us to get more efficient with when we back trees up too
or a subset of the git state right?

and then lets implement
so, we get atomic tree backups
which carry their git and their brain transcripts

then the only thing thats global is the global claude config and the global rhachet config right?

core objectives is atomic, efficient, self contained per tree

maximally

and that partial --all backups resume from the last tree not already synced (e.g., trees that had no movement are already deduped via hashes or mtimes)

for efficiency

and clamp via tests that we do retain the transcripts

cause the transcripts is what we learn from

they're equally as important as the code itself

cause thats what enables us to get the feedback loop to rapidly improve ourselves

and ensure there are no timestamps anywhere that dox us

as usual

## .settled

- the three objectives, each pushed as far as it goes: **atomic**, **efficient**, **self-contained
  per tree**
- a tree's unit carries its own git (the commits, branches, stash, and reflog tips origin lacks),
  its checkout state, its changed files, and its brain transcripts; it restores with no other unit
- the only global units are `home=.claude` and `home=.rhachet`
- a run that stopped partway resumes at the first tree not yet synced: each unit records its own
  last put, the stalest goes first
- a tree with no movement since its last put is deduped by a metadata read, never a pack
- the same holds for `restore --all`: a tree already restored here is skipped
- the transcripts weigh as much as the code: they are the feedback loop the crews improve by. a
  test clamps that a tree's transcripts ride in its unit and come back byte for byte, from that
  unit alone
- no time of day, timezone, host name, address, or account id lands in a tracked file, as
  `rule.forbid.dox-in-public-repo` already holds

## .landed

- `howdoes.a-grove-backs-up-and-restores` — the brief
- `1.vision.yield.md` — the design
- `src/grove.provision/5.devtools/5.27.backup/` and `grove.backup.restore` — the build

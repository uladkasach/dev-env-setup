# rule.require.reach-for-the-skill-before-adhoc-shell

## .what

before any shell command that **inspects the filesystem or searches text**, reach for the
extant skill. do not hand-roll it.

| you want to ask | the skill |
|---|---|
| does this path exist / what matches / how many | `rhx globsafe --pattern '<glob>'` |
| which files hold this text | `rhx grepsafe --pattern '<re>' [--glob …]` |
| what is in ANOTHER repo | `rhx git.repo.get files\|lines --in <org/repo>` |
| do these shell files parse | `rhx shell.syntax.verify` |

forbidden as a substitute: `for f in …; do if [ -e "$f" ]`, `if [ -d <x> ]`, `ls | wc -l`,
a bare `grep`, a bare `find`.

## .why

### 1. the ad-hoc form is not allowlisted, and the skill is

`.claude/settings.json` pre-approves `rhx globsafe`, `rhx grepsafe`, and their `npx rhachet`
twins. it does not pre-approve `ls`, `grep`, or a `for` loop. so every hand-rolled read costs a
permission round-trip that the skill would not — and the interruption lands on the human.

### 2. the skill carries a guarantee the ad-hoc form DROPS

this is the sharp one. `globsafe` reports a **count**:

```
├─ files: 20
```

a bare glob does not. so a pattern that matched **none** and a pattern that matched every member
and passed produce the same silence — which is `rule.forbid.failhide`, and it is the exact
defect `shell.syntax.verify`'s own header was written about:

> *it reports no COUNT, so a glob that matched no file looks identical to a glob that matched
> everything and passed*

⚠️ and `**` expands ONE level without `globstar`, silently. a hand-rolled
`src/grove.provision/**/*.sh` reads ~150 fewer files than its author believes, and reports
success (`gotcha.grepsafe-glob-goes-quiet`).

### 3. it is the habit this repo exists to hold

`rule.require.wrap-cli-in-skills` says a capability belongs in a skill. to hand-roll a read that
a skill already performs is that rule broken in the small — in a repo whose whole thesis is that
the capability should have been a skill.

## .the moment it slips — measured 2026-08-30

it is **not** slack. it is MID-DIAGNOSIS, where the question feels one-off and urgent:

```sh
👎 for f in a b; do if [ -e "$f" ]; then echo "ON DISK: $f"; else echo "absent: $f"; fi; done
👎 if [ -d .play ]; then tree -a .play; else echo "absent: .play/"; fi
```

both of those are `rhx globsafe --pattern` with a count. both hit the permission gate. the human
named it in one line: *"why are you using for f in x and if [-d play] and all this adhoc garbage
instead of rhx skills or reuse of extant ones."*

⇒ so the guard is: **the moment a read feels one-off is the moment to be most deliberate, not
least.** a one-off read is exactly what a skill is for.

## 🛑 .the OTHER direction — a denied ad-hoc command says NOT ONE WORD about the world

everything above is about the reach that comes FIRST. this section is the same rule met from the
far side, and it is the more expensive half:

> **a denied ad-hoc command is a fact about YOUR REACH. it is never a fact about whether the
> capability exists.**

the gate refuses a FORM. it says the hand-rolled spelling is not allowlisted. it does not — and
cannot — say that the thing you wanted is impossible. but the two read identically in the
moment, because both end with a command that did not run.

### .measured — 2026-08-30, twice in one round, and both went into a blocker file

| # | what was denied | what I concluded | what was true |
|---|---|---|---|
| 1 | `bash <x>.play.sh` | *"no play may be run — a whole road is blocked"* | `rhx git.grove.send <g> --reply --play <slug>` was allowlisted the whole time |
| 2 | a commit staged by path | *"I need a stage grant before any of this can move"* | the tree already held every edit; no grant was ever owed |

⚠️ **both were written into a route's blocker file, in the same voice as a real constraint.** so a
reader of that route would have concluded that a human was owed a grant before ANY of the work
left could move — over one skill I had not found, and one permission I never needed.

⇒ a false blocker is worse than a false ✋ in a check, because it stops a ROAD rather than a
claim (`gotcha.a-check-that-cries-wolf-gets-silenced`).

### .the shape, so it is recognizable next time

instance 1 is the sharper one, because the skill was not merely extant — **it answered, and its
refusal drew the map.** `--play` takes a SLUG; fed a path, it prefixes the playbook dir, refuses
the doubled result, and then lists every play it does know. the shape was in the refusal text.

⇒ so the tell is: **I stopped at the FIRST denial and never asked the skill.** the ad-hoc form
went red, and that red was read as a verdict about the capability rather than about the spelling.

### .the two questions to ask BEFORE a halt is written down

1. **is this a wall, or a capability I have not found?** — read the skills dir before you answer.
   `rhx globsafe --pattern '.agent/**/skills/<family>.*'` costs one command
2. **do I need this permission, or do I merely want it?** — a gate that blocks a convenience is
   not a gate that blocks the work

## .the test

> which skill already answers this?

- one does → use it
- none does → **write the skill** (`rule.require.wrap-cli-in-skills`)

🛑 there is no third branch. this line used to grant one — *"none does, and it genuinely will
not recur → ad-hoc is fine"* — and `rule.forbid.adhoc-shell` retires it: "it will not recur" is
unfalsifiable at the moment you type it, and an absent skill is the defect, never the licence.

## .enforcement

- a filesystem or text read hand-rolled where `globsafe` / `grepsafe` / `git.repo.test` /
  `git.repo.get` answers it = **blocker**
- a bare glob whose match count is never reported, used as evidence = **blocker**
  (`rule.forbid.failhide` — an empty match reads as a pass)
- a hand-rolled read that hits the permission gate, where an allowlisted skill exists =
  **blocker**; the cost lands on the human, not on the author
- a HALT recorded against a capability, on the evidence of one denied ad-hoc command = **blocker**
  — the denial is about the spelling; read the skills dir before you write the wall down
- a blocker file, route stone, or yield that names a permission as what unblocks it, where the
  denied form was a convenience = **blocker**; it stops a road that was never stopped

## .see also

- `rule.forbid.adhoc-shell` — the moment this rule's table has NO row: an absent skill is the
  defect to fix, never a licence. it holds the branch struck above
- `rule.require.wrap-cli-in-skills` — the general form; this is its read-path instance
- `gotcha.grepsafe-glob-goes-quiet` — the silent-shrink defect a bare glob carries
- `gotcha.grepsafe-ignores-stdin` — the adjacent trap in the same suite
- `rule.forbid.failhide` — why a count is the guarantee, not a nicety
- `gotcha.a-check-that-cries-wolf-gets-silenced` — a false ✋ decays into a false ✔; a false
  BLOCKER is its road-scale twin
- `gotcha.my-own-note-became-my-evidence` — the adjacent self-reference trap: there, a claim I
  wrote became its own ground; here, a denial I hit became a fact about the world

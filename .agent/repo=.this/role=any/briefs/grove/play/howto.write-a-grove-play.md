# howto.write-a-grove-play

## 🛑 .before you write one line — the ONE question

> **does this touch the machine?**

- **yes** → 🛑 STOP. it is a **bundle**, not a play. go to `src/grove.provision/`.
- **no, it only looks and reports** → read on.

there is no third answer. `rule.forbid.repair-plays` is the whole law here — it is booted
say-level, so you have already read it. this howto covers only the plays that remain
legitimate: the ones that **read**.

⚠️ and before you write a READ play, ask a second question: **would a `--mode plan` have
answered this?** a plan runs every verify and writes no state. it already answers what is
absent on this box for the whole tree. a play earns its file only when it asks what the
tree's own verifies do not.

## .what a play IS

a shell file in one of **exactly two** dirs, sent to a grove by `git.grove.send --play`,
which rsyncs it over, chmods it, and runs it in the duct.

| dir | tracked? | what belongs |
|---|---|---|
| `.play/temporary/` | ✋ gitignored | a scratch probe, a `rollback.*` — almost always this one |
| `.play/permanent/` | ✔ tracked | a discrimination probe, under `rule.forbid.repair-plays` exception 2 |

🛑 there is no third dir, and `.agent/playbooks/` is forbidden by name. it sat outside both
runners' reach and outside `shell.syntax.verify`'s walk, so a play there was unparsed,
unreachable by slug, and silent when absent.

⚠️ a play is named by **slug**, never by path. the send resolves it across both dirs and
halts if both hold the name — a path would hide that collision behind whichever one you
typed.

```sh
rhx git.grove.send <grove> --play diagnose.grove-github-credential
```

you do **not** `chmod +x` it locally. a play is written mode `644`; the `--play`
transport sets the bit on the remote. a local `+x` is pure noise.

## .the three verbs, and the one that writes

| verb | what it does | asserts a verdict? |
|---|---|---|
| `diagnose.*` | reads the box and reports rows | **no** — and that is the point |
| `verify.*` | reads the box and judges a claim | yes |
| `prove.*` | DRIVES something, then judges what it observes | yes |
| `rollback.*` | ⚠️ un-converges a TEST box during development | no — it is scaffolding |

the verb leads the filename, and the filename ends `.play.sh`:

```
<verb>.<subject>.play.sh
```

## 🛑 .the SECOND question — does this play earn a commit?

almost certainly not. **the default is `.play/temporary/`**, which is gitignored on
purpose: a play is scratch — a `rollback.*`, or a probe written to answer one question
today — and what a play PROVED belongs in a **brief**, never in the file that measured it.

`.play/permanent/` is the narrow exception, with one trigger: the play is a
**discrimination probe** — it breaks a subject on purpose, confirms the check reddens, and
restores. that one must reach every box; its absence must never be silent. every other play
is scratch.

```sh
rhx git.grove.send <grove> --play <name>     # slug, not path — either dir
rhx play.run --play <name>                   # a tracked play, on THIS box
```

### the test

> **will a reader want this answer again in six months?**

- yes, as a tool or a clamp → write what it measured into a **brief**; the file stays scratch
- no — it answers one question, once → let the scratch file go

### ⚠️ why the scratch dir is an ENFORCEMENT, not a convenience

`rule.forbid.repair-plays` grants a `rollback.*` on four conditions, the fourth of which
reads *"DELETED when the bundle it served is proven."* memory alone enforced that deletion —
and memory is what let the tracked play dir grow past twice the size its own readme claimed.

**a play that is never committed cannot rot into an exhibit.** the scratch dir does
structurally what the fourth condition asked a human to remember.

### ⚠️ and the third kind — the EXHIBIT, which belongs in neither

an **exhibit** is a play that measured one argument once, whose lesson then landed in a
brief. it reads as coverage and guards no claim — *"a liability that reads as coverage"*,
as the play family's own readme put it, for exactly that reason.

⇒ if the lesson is in a brief, the play is spent. **delete it** — and remember that a
delete is TWO edits: the file goes, and every line that named it says what became of it.

### which verb do I want?

- the answer is **rows a human reads** — a verdict hides which branch decided
  → `diagnose`. this is the verb that caught the ec2 detection defect, precisely because
  it collapsed no branches into one answer.
- the answer is **a claim that is true or false right now**, and a read settles it
  → `verify`.
- the claim is **about what a run DOES** — idempotency, a chain that must break, an
  interaction between two bundles — so a read cannot settle it → `prove`.

> a property about what a run DOES cannot be settled by a look at what a box IS.

### ⚠️ the `prove` caveat — its write must be a call into `grove.provision`, or a suite

a `prove` may drive. it may **not** invent its own convergence. the write it causes is
either `rhx grove.provision …` or a test suite — never a hand-rolled install. the moment a
`MODE=plan` / `MODE=apply` split appears inside a play, `bundle.upgrade` has been
re-implemented badly — that play is a repair play with a new hat.

## .the header — what every play states before its first command

```sh
#!/usr/bin/env bash
######################################################################
# <verb>.<subject> — one line, in the imperative
#
# .what = what it reads, and what it prints
# .why  = the question it exists to answer, and why the tree's own
#         verifies do not already answer it
#
# ⚠️ .what it does NOT prove
#         name the direction you have NOT seen it discriminate in.
#         a check seen green but never red is half proven
#
# guarantee:
#   - it writes no state   (or, for a prove: exactly what it drives, and why)
#   - it prints no secret  — byte counts and prefixes, never values
#
# usage:
#   rhx git.grove.send <grove> --play <verb>.<subject>
######################################################################
set -uo pipefail
```

`set -uo pipefail` and **not** `set -e`: a play reads many things and most reads are
allowed to fail. an `-e` turns the first `·` row into a silent exit — every row below it
is lost, which is the whole output.

## .the rules a play must obey

### 1. bound every probe

a play runs in a duct. a probe that hangs holds the pane — the pane is how a human reaches
the box.

```sh
out="$(timeout 45 rhx keyrack list --owner ehmpath 2>&1 < /dev/null)" && rc=0 || rc=$?
```

`timeout` on every remote or credential call, and `< /dev/null` on every one that might
prompt — **a duct is tmux**, so a prompt sits on the pane and eats the next command sent
down it (`rule.require.bounded-probes-in-verifies`).

### 2. print the evidence beside the verdict

the single habit that has caught the most defects in this repo. a reader who can see the
rows can overrule a wrong verdict; a reader given only `✋` cannot.

```sh
echo "   ├─ fstab says: $(awk '$3 == "swap" {print $1}' /etc/fstab | tr '\n' ' ')"
echo "   └─ ✋ /swapfile is armed at every boot"
```

### 3. judge the DECLARATION, not the live state

`/etc/fstab`, a unit file, a manifest — not `swapon --show`, not `ps`. live state is
rebuilt at every boot, so it goes quiet exactly when it matters
(`rule.require.judge-declared-state-not-live-state`).

> the test: *"if I reboot this box right now, does my verdict still hold?"*

### 4. a probe that cannot ASK must not ANSWER

a crashed tool reported as a negative answer is the nastiest failure this repo has measured.
`command -v rhx` proves a FILE is on PATH; it does not prove the file runs. a stale shim's
crash was announced as `rack does NOT answer`, with a fix that repaired no part of it.

```sh
# 👎 conflates "no" with "could not ask"
if ! rhx keyrack get …; then echo "   · absent"; fi

# 👍 three outcomes, not two
out="$(timeout 45 rhx keyrack get … 2>&1)" && rc=0 || rc=$?
if printf '%s' "$out" | grep -q 'Cannot find module'; then
  echo "   💥 the TOOL is broken — this row asked no question"
elif [[ "$rc" -ne 0 ]]; then
  echo "   · absent"
else
  echo "   ✔ present"
fi
```

### 5. consult the exemption, not only the general rule

a `·` earns trust when the row can name what would have made it a `✔` **and** confirms
that thing is absent. a box-wide restriction with per-binary exemptions read without its
exemptions produced three false `·` rows in one file on 2026-08-09, and a whole repair was
designed for a precondition that was already met
(`gotcha.a-check-that-cries-wolf-gets-silenced`, measurement 3).

### 6. never print a secret, and never leave litter

report byte counts and a 4-char prefix. and a play that stores anything must take it back
on **every** exit path — use a trap, not a last line:

```sh
trap _restore EXIT
```

a diagnose that wrote a probe key and never removed it is why one of the eight deleted
repair plays existed at all.

### 7. this repo is PUBLIC

no account id, arn, instance id, private host, or real principal name — in the code, in a
comment, or in an example of output. placeholder them (`rule.forbid.dox-in-public-repo`).

## .the exit code

| code | meaning |
|---|---|
| `0` | the claim holds (`verify`/`prove`), or the rows printed (`diagnose`) |
| `1` | the claim does NOT hold, or the play could not ask its question |

⚠️ a `diagnose` exits `0` even when every row is `·`. it asserts no verdict — that is the
definition of the verb, and a diagnose that exits non-zero on a `·` has become a verify.

## ⚠️ .the duct returns the SEND's verdict, never the play's

`git.grove.send --what '<cmd>'` returns `0` whenever the text landed, whatever the command
then did. so a check built on `--what` reports `✔` on a box that answered no part of it.

🛑 **the fix is `--reply`.** it rides the DUCT and returns the command's own stdout and
exit code:

```sh
rhx git.grove.send <grove> --reply --what '<cmd>'
```

⚠️ **`--reply` reserves exit code 97 for "no verdict exists"** — the send was refused, the
box went quiet, `--within` elapsed. a caller that branches on truthiness alone reads a
refused send as a fact about a box that never spoke:

```sh
local out rc=0
out="$(rhx git.grove.send "$g" --reply --what "$cmd")" || rc=$?
[[ "$rc" -eq 97 ]] && halt_naming_the_duct     # never judge the box
```

`|| rc=$?`, never `|| true` — a `true` discards the code and leaves 1 indistinguishable
from 97 again.

⇒ `--bare` keeps exactly TWO triggers, and both name a duct that **cannot carry** the
command: `--why 'no tmux yet'` and `--why 'duct is broken'`. a third survives in
`gotcha.a-tool-found-by-path-answers-only-a-human` — a probe that needs a NON-INTERACTIVE
shell, since a duct pane runs an interactive zsh and would reproduce a human's PATH.

`--play` is the normal path and it is fine — a human reads the pane. the hazard is only
when a CALLER judges the result (`gotcha.the-duct-returns-the-send-not-the-answer`, which
records this resolution under its 🛑 RESOLVED heading).

## .prove the play discriminates, before you trust it

a check earns its authority when it is **seen to do both**:

1. run it against a box you know is **good** → it must go green
2. break the subject on purpose → it must go red
3. restore → green again

a check proven in one direction only is half proven, and its header must say so — the same
bar `rule.require.clamp-edge-cases` sets for a regression test. ⚠️ a probe that asks its
questions only AFTER the fix passes every one, and proves no more than that it ran
(`prove.keyrack-peer-probe-bites`).

## .where a play lands on the remote

```
$HOME/.local/state/grove.play/<name>.play.sh
```

⚠️ **not `/tmp`.** `/tmp` is shared across seats and carries the sticky bit, so the first
seat to send a play owns the path and every other seat gets `permission denied` — which
reads exactly like a broken tunnel. and `/tmp` never auto-cleans, so a stale play outlives
its session.

## .the checklist

- [ ] it does not touch the machine (or, for a `prove`, it drives only `grove.provision` or a suite)
- [ ] the verb leads the name, and the name ends `.play.sh`
- [ ] mode `644` — no local `chmod +x`
- [ ] `set -uo pipefail`, never `set -e`
- [ ] every remote probe has a `timeout` and a `< /dev/null`
- [ ] the evidence prints beside the verdict
- [ ] it judges a declaration, not live state
- [ ] a broken tool is distinguished from a negative answer
- [ ] no secret, no dox, no litter (trap the cleanup)
- [ ] seen RED on a real break and GREEN on a real pass — or the header says which is untested

## .see also

- `rule.forbid.repair-plays` — **a play may never write.** the law this howto serves
- `term=play.verify` / `term=play.prove` / `term=play.await` — why each verb exists
- `rule.require.bounded-probes-in-verifies` — the timeout discipline
- `rule.require.judge-declared-state-not-live-state` — read the declaration
- `gotcha.a-check-that-cries-wolf-gets-silenced` — the false `✋`, and how it decays
- `gotcha.the-duct-returns-the-send-not-the-answer` — when to reach for `--bare`
- `rule.forbid.dox-in-public-repo` — this repo is public

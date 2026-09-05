# gotcha.pipefail-grep-q

## .what

under `set -o pipefail`, the shape

```sh
some_command | grep -q PATTERN
```

reports **failure when the pattern MATCHES**. the `if` reads that as "no match",
so the check answers the exact opposite of the truth.

## 🛑 .`grep -q` IS NOT THE ONLY CULPRIT — the class is EARLY EXIT

this file is named for `grep -q` because that is where it was first measured,
and the name has since cost a whole audit its completeness. the actual rule has
no `grep` in it:

> **any reader that stops before EOF can SIGPIPE its producer, and pipefail then
> reports that producer's 141 as the pipeline's status.**

the readers that stop early:

| reader | stops when | in this repo |
|---|---|---|
| `grep -q` | the first match | the original measurement |
| `head -N` | the Nth line | **swept only on 2026-08-13** — see below |
| `grep -m<N>` | the Nth match | **named by no audit until 2026-08-14** |
| a bare `read` off a pipe | one line | rare here |

⚠️ **early exit only bites when the early-exiter is the CONSUMER.** the SIGPIPE
travels backward, so a reader with no producer behind it kills nobody:

```sh
cmd | grep -m1 X          # 👎 grep can SIGPIPE cmd
grep -m1 X file | sed …   # 👍 grep is the FIRST stage — no producer to kill
```

that distinction is why a reader for this class must parse the PIPELINE and not
merely the word.

and the readers that do NOT, so are always safe:

| reader | why |
|---|---|
| `tail -N` | must read to EOF to know which lines are last |
| `sort` | must read all input before it can order it |
| `wc` | counts to EOF |
| `awk 'NR<=N'` | **the fix** — caps the OUTPUT, reads to EOF anyway |

⇒ so `awk 'NR<=N'` is to `head -N` exactly what `grep PATTERN >/dev/null` is to
`grep -q`: the same result, with no early exit to kill anybody.

⚠️ **`head` is the harder of the two to spot**, for a reason that is easy to
miss: `grep -q` at least sits where a status is read by construction — it is
written for an `if` to consume. `head` is usually mid-pipeline, so its 141
propagates through stages nobody looks at, and surfaces only when the
pipeline's status happens to matter.

## .why

`grep -q` exits the instant it finds its first match — that is the whole point of
`-q`. its exit closes the read end of the pipe. the producer, still mid-write,
gets **SIGPIPE** and dies with status **141** (128 + 13).

`pipefail` sets a pipeline's status to the **rightmost non-zero** status of any
stage. so:

| stage | status |
|---|---|
| `some_command` | 141 — killed by SIGPIPE |
| `grep -q` | 0 — it matched |
| **pipeline, under pipefail** | **141 — failure** |

with no `pipefail` the pipeline takes only grep's 0, and the shape works. this is
why the trap is invisible until a repo turns pipefail on.

## .the measurement

taken on the laptop, 2026-07-30, on a box where the font IS installed:

```
$ bash -c 'set -uo pipefail; fc-list | grep -qi "hack nerd font mono"; echo $?'
141          ← matched, and reports FAILURE

$ bash -c 'set -uo pipefail; fc-list | grep -i "hack nerd font mono" >/dev/null; echo $?'
0            ← matched, and reports SUCCESS
```

## ⚠️ .why it is worse than a plain bug — it is SIZE-dependent

SIGPIPE only fires if the producer is **still writing** when grep quits. so the
outcome turns on how much output there is and how early the match lands:

| producer | output | what happens |
|---|---|---|
| `fc-list` | thousands of lines | producer still writes → SIGPIPE → **false failure** |
| `flatpak list` | a few lines | fits the 64KB pipe buffer, producer already done → **works** |
| `echo "$var"` | one line, builtin | no separate process → **works** |

so the same broken shape passes in most places and fails in one. the file that
exposed it (`4.1.fonts`) sat beside four other files with the identical shape
that all reported ✔ — which is precisely why a reader would trust the shape.

## ⚠️ .it can fail in the UNSAFE direction too

whether a false 141 is safe depends on the polarity of the test:

```sh
# fail-CLOSED (safe by luck) — a good signature reads as bad, and we refuse
if ! gpg --verify ... | grep -q "Good signature"; then abort; fi

# fail-OPEN (dangerous) — vim-tiny reads as a full build, and we report ✔
if vim --version | grep -q 'Small version'; then report_defect; fi
```

the second is the one to fear: the check silently stops reporting the very defect
it exists to catch. **a security or safety gate must never rest on this shape**,
even when its accidental polarity is the safe one — a verdict that depends on
whether a producer finished its output before its reader stopped is not a verdict.

## ⚠️⚠️ .the bias — a MATCH makes the false answer MORE likely

this is the part that turns a coin-flip into a trap.

`grep -q` exits **as soon as it matches**. so the earlier the match, the more the
producer still has left to write, and the more certain the SIGPIPE. run it out:

| the truth | grep exits | producer state | pipeline | reported |
|---|---|---|---|---|
| pattern present, early | at once | far from done | 141 | **"absent"** ← wrong |
| pattern present, late | near the end | nearly done | maybe 0 | "present" |
| pattern absent | at EOF | done | 0 | "absent" ← right |

so the shape is **least reliable exactly when what it hunts for is there**. it is
not a check that is right half the time; it is a check biased toward "I found no
match".

measured 2026-07-30 in `4.3.2.emulator.configure.verify`, which reads
`kitty --debug-config` — a dump of the whole config, far past a 64KB buffer:

```sh
if echo "$out" | grep -qiE 'error|unknown ...'; then
  report_complaints        # never reached for a big config
else
  echo "kitty.conf parses clean ✔"   # a 141 lands HERE
fi
```

a config error made grep match early, which made SIGPIPE likely, which sent the
`if` to its else branch, which printed **"parses clean ✔"**. the presence of the
defect is what produced the all-clear.

> a `grep -q` under `pipefail` does not merely risk the wrong answer — it leans
> toward a silence about what it was written to find.

## .the fix

drop `-q`, redirect to `/dev/null`:

```sh
# 👎 bad
if fc-list | grep -qi 'hack nerd font mono'; then

# 👍 good
if fc-list | grep -i 'hack nerd font mono' >/dev/null; then
```

without `-q`, grep drains the whole stream, so the producer finishes normally and
its status is a true 0. the cost is that grep reads to the end rather than stops
early — negligible for anything a config check inspects.

### the alternatives, and why they are worse

| form | verdict |
|---|---|
| `grep PATTERN >/dev/null` | ✅ the fix. one edit, no scope change |
| `if out="$(cmd)"; grep -q <<<"$out"` | works, but buffers the whole output into a variable for no gain |
| `set +o pipefail` around the line | ❌ turns off a safety net repo-wide-in-spirit to paper over one line |
| `\|\| true` on the pipeline | ❌ `rule.forbid.failhide` — it hides the real failures too |

## 🛑 .how to find it — NO RUN CAN, so the sweep is a hand audit

a provision cannot surface this one, and that is the sharpest fact in the brief:

> a `grep -q` truncated by SIGPIPE reports **success**. so the check passes, the phase
> passes, the provision passes, and the box is green over a read that saw part of its
> subject. a run cannot surface a defect whose whole signature is that no step fails.

⇒ so the sweep is a **hand audit**, and the section below is emphatic that four hand audits
ran and each was wrong differently. treat every pattern here as a RECORD of what one audit
looked at, never as a method that finds them all.

the shape a sweep needs: static — no network, no privilege, the same answer on every box —
and it **derives its scope from the tree**, so a family nobody named is in scope the day it
lands. prove its reader in both directions before you trust a row it prints.

⚠️ **every hand-written pattern below is a RECORD, not a method.** four hand audits
ran; each reported completeness; each was wrong differently. §the FOURTH audit names how.

the questions the play asks, so you can read its rows:

1. **is this file reached under `pipefail`?** measured 2026-08-13, the files that
   set it are:

   | file | sets | note |
   |---|---|---|
   | `src/grove.provision._.sh` | `-uo` | the driver — every bundle phase inherits it |
   | `src/git-credential-keyrack.sh` | `-uo` | git invokes it on every fetch |
   | `src/backup_env.sh` | `-uo` | human-run |
   | `src/machine/kitty.snapshot.terminals.sh` | `-uo` | **unattended, systemd timer** |
   | `src/machine/machine_usage_snapshot` | `-euo` | **unattended, systemd timer** |
   | `src/util.yubikey.ssh.sh` | `-euo` | human-run, two functions |

   a hit in `bash_aliases.sh`, `zshrc.sh`, or `ductwork.sh` is sourced into an
   interactive shell that does NOT set it, so the pipeline takes grep's status
   alone and the shape is sound there.

   > 🛑 **do not read this table to answer step 1.** it is a hand-list of `src` only,
   > silent about the 133 plays and skills, several of which set `-uo pipefail` in
   > their own first line. the play reads each file's own first lines
   > (`_under_pipefail`), plus the one inherit rule no grep can see: **every file
   > under `src/grove.provision/` inherits `-uo` from the driver**, whatever its own
   > header says.
   >
   > ⚠️ a hand-named checklist goes stale silently, and it fails toward "sound"
   > (`rule.forbid.failhide`) — a reader answers step 1 "no", stops, and records the
   > shape as sound in a file that does set `pipefail`.
   >
   > ⚠️ the two rows marked **unattended** are the worst placed. they run from a
   > systemd timer with output redirected away, so a SIGPIPE there is the one failure
   > no human ever sees. `machine_usage_snapshot` sets `-euo`, so it aborts at the
   > first stage rather than merely misreport.
2. **can the producer emit more than 64KB?** an external command can; a builtin
   `echo "$var"` can too, once `$var` is large — `echo` is not exempt, it is only
   exempt for *small* strings, which is the same size-dependence in disguise.
3. **does anything READ this pipeline's status?** a false 141 is only a defect
   where somebody consumes it, and this question does most of the work — on
   2026-08-13 it took 45 candidate `head` hits down to 2.

   | the pipeline sits… | status read? | verdict |
   |---|---|---|
   | as a function's LAST command | yes — it is the return value | **judge it** |
   | directly in an `if`, `&&`, `\|\|`, `while` | yes | **judge it** |
   | in a file that also sets `-e` | yes — a 141 ABORTS the run | **judge it, first** |
   | as `foo="$(cmd \| head -1)"`, status unchecked | no | sound; the VALUE is right |
   | as `echo "$out" \| head -3 \| sed …` for display | no | sound |

   ⚠️ but read question 3 as a NARROWER, never as an exemption. the bundle tree
   inherits `-uo` and deliberately not `-e`, so most of its hits are genuinely
   sound — and the two that were not were both **gates**, where the wrong answer
   costs a phase that asks for root over work already done.

### the sites the earlier audits settled

**2026-07-30** — `4.1.fonts`, `4.4.vim`, `4.3.2` gpg, `1.5.swap`,
`4.3.2.emulator/configure.verify` (was fail-OPEN), `2.6.starship/configure.verify`: all
fixed. hits in `bash_aliases.sh`, `ductwork.sh`, and `zshrc.sh` set no pipefail, so they
are sound as written.

> ⚠️ `4.2.ptyxis` carried two more and was DELETED on 2026-08-13 — this box is 100% kitty.
> do not go look for the bundle.

**2026-08-13** — five hits in bundles written after the first sweep, so never in its scope:

| site | producer | the direction it fails |
|---|---|---|
| `5.13.reach/configure.upsert` ×2 | `$reachlog`, a captured log — unbounded | the most precise cause would be the one silently skipped |
| `5.12.rack/configure.upsert` ×2 | `rhx keyrack list` — **external**, unbounded | a wired rack reads as unwired, so every apply re-wires and never prints "no work" |
| `5.6.aws/configure.verify` | `$out`, small | a **false ✋** — live credentials reported as `NO access key` |

all five fixed `-q` → `>/dev/null`, each with its direction noted inline. every one was a
`grep -q`, because the sweep's pattern named one reader.

⇒ **a `grep -q` audit is not a pipefail audit.** §.the FOURTH audit holds what each sweep
left wrong, and why the repair is a play.

⚠️ **the two lines below are a RECORD, not a method.** they still carry `--path src`, so
they are the very pair the fourth audit found wrong — and they miss `grep -m<N>` besides.
run `prove.early-exit-readers-are-safe` instead.

```sh
rhx grepsafe --pattern '\|\s*grep\s+-[a-zA-Z]*q' --path src   # one reader
rhx grepsafe --pattern '\|\s*head\s+-'            --path src   # the other
```

### the `head` sweep of 2026-08-13 — 51 hits, 8 that could bite, 6 fixed

first, the two questions from `.how to find it` narrow it hard:

| set | count | verdict |
|---|---|---|
| every `\| head -` in `src` | 51 | — |
| …in a file that sets `pipefail` (incl. the whole bundle tree, which inherits it) | 45 | candidates |
| …whose **status is read** — a function's last command, an `if`, a `&&` | 2 | the real hunt |
| …in a file that also sets **`-e`**, where a 141 ABORTS rather than misreports | 6 | the severe half |

⚠️ the 45→2 collapse is the useful part: in the bundle tree the driver sets `-uo` and
**deliberately not `-e`** (`grove.provision._.sh:79`), so a false 141 there is only read
where somebody reads it. a `foo="$(cmd | head -1)"` discards the status entirely, and
its VALUE is always right — head got its line. those are sound as written.

**the severe half — `src/machine/machine_usage_snapshot`, which sets `-euo` and runs
unattended from a systemd timer with its output redirected away:**

| site | the producer | what a 141 did |
|---|---|---|
| top-cpu block | `ps aux` | **aborted the snapshot** past ~412 processes |
| top-mem block | `ps aux` | same |
| d-state block | `awk` over `ps aux` | aborted at >10 blocked processes |
| zombie block | `awk` over `ps aux` | aborted at >10 zombies |
| iostat block | `tail -n +4` | `\|\| true` caught it; fixed for consistency |
| sensors block | `grep -E` | **two** aborts — see below |
| open-files block ×2 | `ps -eo pid`, `sort` | bounded today; fixed anyway |

the threshold was measured on a grove, 2026-08-13:

```
$ ps aux | wc -lc
188   29812        ← ~159 bytes a line
```

a pipe buffer holds 64KB, so `ps aux` outruns it at **~412 processes** — and this box
has hit **641** during a keyrack daemon leak. so the tool that exists to capture a
runaway-process event aborted at precisely the process count that event produces.

⚠️ **the sensors block held a second abort, unrelated to early exit:**
`sensors | grep -E '(Core|temp|…)' | head -10`. `grep` exits **1** when it matches no
line at all, pipefail propagates that, and `-e` aborts. so a box with `sensors`
installed and no matching label killed the snapshot at its last section. `awk` fixed
both at once — it caps without an early exit AND exits 0 on an empty match.

**the gate — `src/grove.provision/4.terminal/4.5.nvim/provision.upsert.sh`:**

```sh
grove_provision_4_5_nvim_pinned() {
  …
  /usr/local/bin/nvim --version 2>/dev/null | head -1 | grep -qF "v${version}"
}   # 👎 the pipeline's status IS the function's return value
```

two early exits in one line, and the function is a **read-before-privilege gate**: a
false 141 reads as "not pinned", so the upsert drops into its root half over a binary
already at the pin — a ✋ on a seat with no sudo, for work already done. it has never
misfired, because `nvim --version` writes ~1.5KB into a 64KB buffer. that is luck about
a size. fixed by a capture plus a bash pattern match, which reads no pipeline status at
all.

**the one deliberate KEEP** — `5.1.node/_.sh:135`, `sed -n '…/p' "$manifest" | head -1`,
also a function's last command. its producer is `sed` in print-matched-lines mode over
`package.json`, so its output is at most one short line by construction — bounded by
content, not by luck about a box. sound as written, and recorded here so the next audit
does not re-litigate it.

## 🛑 .the FOURTH audit, 2026-08-14 — all three prior ones swept `--path src`

every pattern this brief records carries `--path src`. audits 1-3 each fixed the reader and
left the **scope** where the one before it sat.

measured 2026-08-14: `src/` holds **203** tracked `.sh`. the two families outside it hold
**101** more — 60 in the play family, 41 in `.agent/**/skills/` — and the clamp's
derived scope, which also picks up the untracked, reads **339**. so a third of the surface
sat outside every audit's reach. a sweep of those two families found **66 hits**, one of
them measured mid-bite in the same hour.

⚠️ the defect is three-deep, and each layer was found by the layer before it as it
announced that it was done:

| audit | fixed | left wrong | reported |
|---|---|---|---|
| 1 (2026-07-30) | the sites | the DATE — a table with no date reads as permanent | "settled every hit in this repo" |
| 2 (2026-08-13) | the date, the pipefail list | the READER — hunted `grep -q` only | completeness |
| 3 (2026-08-13) | the reader — added `head` | the SCOPE — `--path src`, as 1 and 2 had | completeness |
| **4 (2026-08-14)** | the scope — **and retired the hand-sweep for a play** | *see below* | 54 sites, **and no completeness** |

🛑 **audit 4 claims no completeness, and the empty cell it is tempting to write there is
the whole defect.** each row above was authored by somebody who believed their column
was empty. what audit 4 has instead of a belief is a clamp that re-derives its own scope
on every run — so the next gap is reported by a play rather than by a fifth author.

what audit 4 is known to leave open, named rather than assumed away:

- **`grep -m<N>` is REPORTED, not refused.** its sites are judged by nobody today.
- **the play's four globs are themselves a hand-list.** they are checked by direction 0
  and a <100-file floor, so a shrink turns red — but a family added in a *fifth* place
  is in no glob, and no floor can see that.
- **only pipelines are read.** a `read` off a process substitution, or a coprocess, is
  the same class and is in no direction.

⇒ **an audit bounded by hand is a claim about a set the author held in mind.** three
authors in a row held `src/` in mind, because `src/` is where the tree is. no one held
the plays — which are the artifacts that JUDGE the tree, so a false verdict there is a
false verdict about everything else.

### how it bit — the play that condemned itself

`prove.apt-is-never-interactive` direction 0 printed this:

```
   ✋ devenv.bootstrap.sh is NOT in scope (206 file(s) read)
── direction 1: every apt write routes through the boundary
   ✔ …
      · devenv.bootstrap.sh:128           ← two lines below its own ✋
```

the row read `_scope_list … | grep -q '/devenv\.bootstrap\.sh'`. 206 paths is well past
a 64KB buffer and the match lands mid-list, so the SIGPIPE was near-certain — the bias of
`.the bias` section, at full strength, in a play whose whole job is a verdict.

### the 54 sites, and the four worth their own row

| site | a false 141 means | why it is the sharp one |
|---|---|---|
| `git.grove.wake.sh:329,366` | a **live** tunnel reads as mute | the branch then `pkill`s a healthy session-manager-plugin and rebuilds. `ssh-keyscan` writes a comment line, then one key per algorithm **as each arrives** — so this is a TIMING race, not merely a size one, and it is the first command of every grove op |
| `verify.grove-safe-to-wipe.play.sh:207` | a credential in a REPLICA vault reads as absent | the play gates a **disk wipe**. the presence of the irreplaceable secret is what produces "safe to wipe" |
| `prove.bundles.plan-apply-apply.play.sh:320` | a MUTATED plan reads as clean | fail-OPEN on `rule.require.one-command-provision`'s own evidence. a clean plan reads right by luck of a short stream; a dirty one makes the `grep -v` match early |
| `5.8.docker/provision.verify.sh:59,60` | a seat ON the docker roster reads as off it | the **only bundle-tree sites**, and three `--path src` audits walked past them. line 60 is the function's last command, so it IS the return value |

plus `nvim.test.headless.sh` ×3 (fail-OPEN — a match means the human's test FAILED, and
an nvim traceback is exactly the large output that triggers it) and
`git.grove.trust.gen.sh` ×3 (a match means the key is trusted; the false answer lands in
the `else`, which raises a host-key-CHANGED alarm *because* the key matched).

all 54 fixed `-q` → `>/dev/null`. the 5 `head` rows whose status is read became
`awk 'NR<=N'`. `rhx shell.syntax.verify` → **345 files parse ✔**.

⚠️ **the line numbers above are already a decay hazard** — every one shifted while this
section was written, because the fixes added an inline ⚠️ above each site. so each site
carries its own reason at the code, and the durable way to find them is the comment text,
never the digit. re-derive before you act on a row (`rule.require.trust-but-verify`).

### the repair is a play, not a fifth pattern

`prove.early-exit-readers-are-safe` — and the two properties that make it a clamp rather
than a fourth audit:

- **its scope is DERIVED** — four globs reach five families (the bundle tree and the
  shared runtime both sit under `src/`, plus the exempt `devenv.bootstrap.sh`, the plays,
  and the skills), and it **refuses to run on <100 files** (`:257`). direction 0 asserts
  each family BY NAME, because a plausible simplification of the glob list drops one and
  the play then goes green about a directory it never opened.

  ⇒ a scope that silently shrinks is the failure all four audits had. the floor turns it
  red, and the per-family assertions say WHICH shrank.
- **it tokenizes shell rather than greps it** — a quote mask (so `echo "… | grep -q …"`
  in a fix-text is prose) and a heredoc skip (so its own fixture may CONTAIN the shape it
  refuses). without both, the play condemns its own error messages.

it REFUSES `grep -q` under pipefail and merely REPORTS `head` / `grep -m<N>`, since those
are sound wherever no one reads the status. an exemption needs a reason:

```sh
… | grep -q X   # early-exit-on-purpose: <why the status is not read here>
```

a marker with an empty reason is refused — arm `g_marked_bare` proves it.

⚠️ and the reader was **too narrow on its first draft**: `grep[ \t]+-[a-zA-Z]*q` demands
the `q` in the FIRST flag group, so `grep -E -q` and `grep --quiet` were invisible to it.
a pattern written from the shapes on hand reaches a subset of its own claim. broadened —
**with three fixture arms added in the same edit**, per
`gotcha.a-check-that-cries-wolf-gets-silenced` m.6.

## .the deeper lesson

`-q` is an optimization — "stop as soon as you know". `pipefail` is a safety net —
"tell me if any stage failed". the two disagree about whether an early, deliberate
exit is a failure, and the shell resolves that disagreement in favor of the net.

when a flag makes a command stop early, ask what the thing upstream of it is doing
at that moment.

## .see also

- `rule.forbid.failhide` — the false-✔ direction of this trap is a pure instance
- `gotcha.a-check-that-cries-wolf-gets-silenced` — the false-✋ direction, and the
  m.6 habit this brief's own reader needed: when you change what a reader
  classifies, add a fixture arm for that shape in the SAME edit
- `rule.require.clamp-edge-cases` — why the fourth audit ends in a play rather than
  a fifth table
- `rule.require.upgrade-entries-verify-themselves` — a verify that lies is worse
  than no verify, because it is trusted
- `rule.require.judge-declared-state-not-live-state`


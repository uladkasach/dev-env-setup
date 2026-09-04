# define.cry-wolf-measurements

## .what

the measurements behind `gotcha.a-check-that-cries-wolf-gets-silenced` — each in full, with the
output it printed, the cause it turned out to have, and the repair that closed it.

that gotcha is booted at say level and holds the QUESTIONS these measurements yield, one per
entry. **this file is what each question was learned from.** reach for a measurement when its
question just went red on you, and you want the case it was cut from.

⚠️ **m.13 is not here — it lives in the gotcha itself**, because it names no defect in a
reader's logic and so yields no question. it is the one measurement about a check that is never
RUN, and it is why every m.N below states its evidence inline rather than by a pointer at a file
that can rot.

⚠️ the measurements are numbered in the order they were RECORDED, so m.3 sits after m.4 and
m.13 is absent between m.12 and m.14. the number is a stable citation, not a sequence.

⚠️ **`q1`..`q13`, anywhere below, name the questions of that gotcha's `.the test`.** each
measurement names which of them could NOT have caught it — that is what earns it an entry rather
than a footnote under an extant question.

## .see also

- `gotcha.a-check-that-cries-wolf-gets-silenced` — the thirteen questions, m.13, and the corollary
- `rule.forbid.failhide` — the false-✔ half of the pair
- `term=bite._.choice._.md` — the word for a check seen to fire on a real break

---

## .measurement 1 — a glyph counted twice, 2026-07-30

`prove.phase-chain-breaks.play.sh` asks: when a bundle's phase fails, do the rest of
that bundle's phases stand down instead of restate the same root cause?

it counted ✋ lines per leaf and demanded exactly one. it reported:

```
  5.4.gh
     ✋ claims  = 2
     ⏭  skipped = 1
     ✋ 2 claims for one leaf — the chain did NOT break
```

and then, in the very output it printed as evidence:

```
   ├─ 5.4.gh.configure.verify — skipped; an earlier phase of 5.4.gh failed
```

the chain **had** broken. the second ✋ was the run's own sign-off line —

```
✋ grove.provision finished with failures — each is named above, with its fix
```

— which is a **summary**, and says so. the count swept it in with the claims.

so the play condemned a correct fix, on a page that showed the fix at work. a
reader who trusted the verdict over the evidence would have reverted it.

## .what makes a line countable

the trap is that ✋ marks two different kinds of line:

| line | what it is | countable? |
|---|---|---|
| `✋ gh is unauthed, and no human is confirmed present…` | a **claim** — a phase found a fact | yes |
| `✋ grove.provision finished with failures` | a **summary** — the runner totals up | no |

a count keyed on the glyph alone cannot tell them apart. subtract the summary by
name:

```sh
# 👎 counts the runner's sign-off as if a phase had spoken
claims="$(printf '%s\n' "$out" | grep -c '✋' || true)"

# 👍 claims only — the summary is excluded by name
claims="$(printf '%s\n' "$out" \
  | grep '✋' \
  | grep -vc 'grove.provision finished' || true)"
```

## .measurement 2 — a filter that never saw its line, 2026-07-31

the first measurement is a check whose LOGIC was wrong. this one is worse to find,
because the logic was right the whole time.

`prove.bundles.plan-apply-apply.play.sh` diffs two settled applies and excuses the
lines a tool is allowed to vary on — apt's mirror order, pnpm's resolved counter.
both were excused, by name, and had been for a day:

```sh
| grep -vE '^(Hit|Ign|Err):[0-9]+ ' \
| grep -vE '^Progress: resolved [0-9]+' \
```

then `bundle.upgrade` grew an output pad, so a phase's output is indented to its
depth in the tree. apt still printed `Hit:4 …`; the runtime handed on `      Hit:4 …`;
and `^(Hit|…)` stopped matching. the play reported `1.1.keybinds` and `5.3.brains`
**not-idempotent** on evidence that was entirely those two excused patterns.

no part of the check changed. no part of the bundles changed. a third file changed
the SHAPE of the text between them.

> a check that reads another component's output has a dependency on that output's
> FORMAT, and that dependency is invisible — it appears in no import, no argument,
> no declaration. it breaks silently when the format moves.

the repair belongs at the head of the pipeline, not on each pattern:

```sh
# 👎 the strip runs LAST, so every `^`-anchored pattern above it is disarmed
#    the day its subject gains an indent
… | sed -E 's/^\s+//'

# 👍 the strip runs FIRST, so a pattern may anchor at `^` without a thought
#    about how deep in the tree its bundle sat
sed -E 's/^[[:space:]]+//' "$1" | …
```

to relax each `^` to `^\s*` instead repairs the extant patterns and leaves the
next one added to fall into the same hole.

## .measurement 4 — the verdict was right and named the WRONG MACHINE, 2026-08-13

m.1-m.3 are checks whose *verdict* was wrong. this one's verdict and evidence were both
**correct**, and it still misdirected — a generalization printed underneath named the wrong
subject.

`git.grove.provision test` step 0 climbs `git.grove.ready.verify`, and on a halt it dumps that
ladder's own `why:` and `fix:` — which are precise, per-rung, and were exactly right:

```
      ├─ 0. box
      │  └─ ✋ the ladder halted — its own reason is below

  why: the grove did not wake — see …/wake.log for the aws error
  fix:
    rhx keyrack unlock --owner ehmpath --env camp
    rhx git.grove.wake grove-ahbode-v20260811
```

and then, unconditionally, one line further down:

```
  ⇒ that is a fact about the BOX, so fix it there and run this again.
```

**it was not a fact about the box.** the wake failed because THIS machine's camp
credential had lapsed — `keyrack unlock` reports `expires in: 55m`, so any session
longer than an hour hits it. the grove was healthy throughout: the very next wake
reported `[KEEP]` on every rung and changed no box state at all.

### why it is worth its own measurement

"read the evidence, not the verdict" cannot reach it: the two agree perfectly — the ladder
DID halt, and said so. what was wrong is a **scope claim layered on a correct message**, the
kind a reader has no cause to doubt, because the precise part above it just earned trust.

⚠️ and it degrades a message that was already right. the halt's `fix:` names the
credential unlock as its FIRST line — so the output contained its own refutation, two
lines apart, and the later, vaguer sentence is the one a hurried reader acts on.

### the cause: rungs that do not share a subject

```
1 registry  — an entry on THIS machine
2 reach     — EITHER: this machine's aws credential, or the box
3 duct      — EITHER: this machine's tunnel, or the box's tmux
4 devenv    — the box
5 creds     — the box
```

no single sentence can name the subject of a halt that could come from any of five
rungs. the sentence was written when the box was the likely case, and it has been
wrong for rungs 1-3 ever since.

⇒ **a summary line that generalizes over a set does not get to skip the set.** where
the members disagree, either say which member spoke, or say none and point at the
precise text you already printed.

## .measurement 3 — a DIAGNOSE cries wolf, three times in one file, 2026-08-09

m.1 and m.2 are both a `prove` — a play that asserts a verdict. this one is a `diagnose`,
which **asserts none**, so q1 and q2 cannot reach it.

`diagnose.rootless-docker-viability.play.sh` reports seven preconditions for a rootless
docker daemon, each row marked `✔` met or `·` unmet. it printed three `·` rows that were
all already met:

| row | what it read | why it was wrong |
|---|---|---|
| apparmor userns | `· RESTRICTED → needs a sysctl or an apparmor profile` | read only the box-wide sysctl, never the per-binary profile that **exempts** rootlesskit — and ubuntu ships that profile, loaded |
| linger | printed `linger=no means the daemon DIES…` under `linger: yes` | the note sat outside the branch, so it fired unconditionally |
| vpnkit | `· vpnkit absent` | vpnkit is an **either-or alternative** to slirp4netns, not a companion; on linux its absence is correct |

the first cost real work: a repair step was designed, argued (it explicitly refused the
box-wide sysctl in favor of a narrow profile), written, reviewed, and sent to a grove —
to install a profile that was **already there and already loaded**. the box was never
blocked.

### why q1 and q2 miss it

q1 needs a verdict; a diagnose asserts none, by design (`term=play.diagnose`). q2 needs a
diff; each row is a direct read of the subject, and each read was correct —
`apparmor_restrict_unprivileged_userns` really was `1`.

every individual fact was true. the defect was **which facts were consulted**: a general
restriction read without its exemption, a note read without its condition, an either-or
read as an and-both.

> a `prove` cries wolf by mis-JUDGING true evidence.
> a `diagnose` cries wolf by gathering true evidence that is INCOMPLETE — and having no
> verdict, it offers no claim for a reader to contradict.

### the shape to watch for

each of the three is the same move: **a rule consulted without its escape hatch.**

- a box-wide restriction has per-binary exemptions → read both
- a `.note` that explains a bad state belongs INSIDE the bad-state branch
- an either-or pair listed in an and-both loop marks the correct member absent

⚠️ and a `·` is expensive precisely because a diagnose is trusted to be neutral. a reader
who distrusts a `prove`'s verdict will go read the evidence. a reader who sees `· absent`
from a diagnose has no verdict to distrust, so they build a repair for it.

## .measurement 5 — the probe measured a world it FAILED TO BUILD, 2026-08-13

m.1-m.4 are checks whose READING of the subject was wrong. this one read its subject
perfectly. **the subject was never the one the probe thought it had set up.**

`prove.trust-gen-drift-bites` proves `trust.gen`'s alias-drift check discriminates. to do
that it must supply BOTH sides of the comparison that check makes:

| side | `trust.gen` reads it from |
|---|---|
| registry | `$HOME/.git.forest/groves/<name>.json` |
| alias | `ssh -G <alias>` |

so the first cut set `HOME` to a temp dir and wrote both — a registry entry AND a
`$HOME/.ssh/config` — and expected each side to follow. it printed:

```
── direction 1: registry and alias AGREE
   ✋ it cried DRIFT over an endpoint that MATCHES the registry
      | registry declares: localhost:65099       ← the temp-dir registry: FOLLOWED
      | alias '…' dials:   grove-probe-…:22      ← ssh's DEFAULTS: did NOT follow
✋ 2 check(s) failed — the drift guard does not bite as declared
```

**only one side followed.** `ssh` never read the config in the throwaway `HOME`, so the
"matched" arm was drifted by construction — and the play condemned a guard that had just
fired correctly, three times, in its own printout, on the same screen.

### why q1-q4 miss it

the evidence agreed with the verdict (q1) — two arms genuinely disagreed. the difference sat
in the subject, not a tool (q2): the two endpoints really were different. no rule with an
exemption was in play (q3). the rows supported the summary exactly (q4).

the defect sits one layer earlier than any of them look: **the FIXTURE did not take.**

### the shape to watch for

> a probe that BUILDS a world before it measures one has a second way to be wrong, and
> that way is invisible to every question about the measurement.

it hides best when the setup is **partly** effective. had `HOME` redirected neither side,
the play would have failed loudly at its own first step. because it redirected one, the
play ran end to end and produced a confident, false verdict.

⚠️ the near cause deserves its own line, because it will recur: **`$HOME` is not a
sandbox.** it redirects the readers that consult the variable, and not the ones that
consult the passwd database. here the shell functions followed it and `ssh` did not.

### the repair, and why it beats the fix

the FIX would force ssh onto the fake config. the REPAIR deletes the fixture: an alias in no
config at all makes `ssh -G` answer from its own defaults, deterministically, on every box.
only the registry moves, the play writes no ssh config anywhere, and the human's
`~/.ssh/config` stays out of it. one side supplied instead of two; one fixture that can fail
to take instead of two.

⚠️ that also retired an exemption the play no longer needed. the first cut claimed
`rule.forbid.repair-plays` EXCEPTION 2 for its write, correctly — and an exception taken
where none is needed is exactly the habit `rule.forbid.exemption-as-habit` names.

⇒ and the measurement it cost is now **direction 0** of that play: it reads what `ssh -G`
answers for an unconfigured alias, and halts when that answer is not the one every later
arm is built on. the assumption that broke it is now a checked precondition.

## .measurement 6 — the check cited a TRUE sentence about a DIFFERENT claim, 2026-08-13

m.1-m.5 are checks wrong about their FACTS, their SCOPE, or their FIXTURE. this one had
every fact right, and was wrong about **which question it asks**.

`prove.sudo-is-gated-or-nonintera` asks: can a bare `sudo` in an upsert reach a password
prompt? its first cut ran green. an audit of the reader then found it counted
`pkg_assert_sudo` as a gate — and `bundle.upgrade.sh` says this, plainly:

> "on a seat with no root, a `pkg_assert_sudo` in an upsert is ALWAYS a decline wearing a
>  ✋, and its fix-text is always wrong"

so the reader was changed to refuse it. it went red on **nine** sites across four bundles:

```
   ✋ src/grove.provision/6.apps/6.3.dropbox/provision.upsert.sh:112
   ✋ src/grove.provision/6.apps/6.5.onepassword/provision.upsert.sh:139
   ✋ src/grove.provision/6.apps/6.2.codium/provision.upsert.sh:69
   …
   ⇒ 9 ungated bare sudo call(s)
```

**not one of them can prompt on any box.** two independent reads settle it:

| read | what it showed |
|---|---|
| `devenv.pkg.sh:260` | `pkg_assert_sudo() { pkg_can_sudo && return 0; … return 1; }`, and `pkg_can_sudo` is `sudo -n true`. so either root is password-less, or the phase returns 1 BEFORE any bare sudo below it runs |
| each bundle, ~60 lines above its assert | `[[ "$GROVE_ENV_SERVER" != local@* ]] && return 0` — all four are laptop-only, so a grove never reaches the assert at all |

### why q1-q5 all miss it

the nine sites really do hold a bare `sudo` with no decline-gate above them, so evidence and
verdict agree perfectly (q1). the difference sits in the subject — real code (q2). no
exemption is in play; an assert is a different GATE, not a carve-out (q3). nine found, nine
flagged (q4). all three arms behaved as written (q5).

the defect sits at the level none of them reach: **the CLAIM the check believes it tests.**
one call answers two questions differently, and the citation settled the wrong one:

| claim | `pkg_assert_sudo` |
|---|---|
| can a prompt reach the pane? | **no** — it is `sudo -n true`; a prompt is unreachable either way |
| is the refusal legible? | **no** — it fails the phase and names hand steps, where a gate would 🌙 and name an owner |

`bundle.upgrade.sh` speaks to the second row. the play asks the first.

### the shape to watch for

> **a citation is not a verdict about your claim unless it is about your claim.** the more
> authoritative and true the quoted sentence, the less likely anyone re-reads it against
> what the check actually asks.

this is the most persuasive way to break a check that works, because every ingredient is
sound: a real rule, a real file, a correct quotation, an honest audit. the audit was even
right that the reader was sloppy — it just prescribed a repair for a different defect.

⚠️ and the SECOND half is the more actionable one. the fixture held three arms — gated,
`sudo -n`, ungated — and **none for the shape it had just reclassified.** so when the rule
changed, no arm could contradict it, and direction 2 reported `✔ it discriminates` about a
reader that had just learned to condemn correct code.

⇒ **when you change what a reader CLASSIFIES, add a fixture arm for that shape in the same
edit.** the play now carries `_asserted` (must read as asserted) and
`_gated_then_asserted` (a gate outranks a belt-and-braces assert), and either would have
caught this before it reached a bundle.

## .measurement 7 — one PATTERN, two claims, and the correct value is OPPOSITE, 2026-08-14

measurement 6 is a check that cited a true rule about the wrong claim. this one is a check
whose **pattern** spans two claims at once — so a single verdict cannot be right for both,
and it was written for the one that happened to be on the author's mind.

`prove.registry-bounds-agree` clamps a copied bound: every literal must equal
`WEB_REGISTRY_TOTAL_SECONDS` (900s), the total that keeps a stalled install from holding a
shell. its reader was `timeout[[:space:]]+[0-9]+[[:space:]]+(npm|pnpm|corepack|flatpak)`.

first run, three ✋, and **all three were false**:

| row | it read | why it was wrong |
|---|---|---|
| `5.1.node/_.sh:152` | `timeout 60 pnpm` → "should be 900" | the line is `CI=1 timeout 60 pnpm bin -g </dev/null` — a **local read** of the global shim dir. no registry, no wire |
| `bash_aliases.sh:504` | `pnpm exec "$@"` unbounded | `pnpm exec` runs a binary already in `node_modules/.bin`. `pnpm dlx` fetches; `exec` cannot |
| `bash_aliases.sh:1544` | `pnpm install` unbounded | it is a **message**: `lines+=("tip: use --init to run pnpm install …")`. prose about a call |

### .why row 1 is the one worth the entry

rows 2 and 3 are ordinary reader sloppiness — a verb set too wide, and a quoted body read as
code. row 1 is different in kind: the text `timeout <n> pnpm` is **correct in both places**,
and the correct `<n>` is *opposite*:

| the call is a… | the right bound is… | because |
|---|---|---|
| registry install | **900s**, generous | a thin link that still moves bytes must not be killed |
| local read in a verify | **60s**, tight | `rule.require.bounded-probes-in-verifies` — a verify may not linger |

so the reader's ✋ came with a `fix:` line that named a real regression: to widen
`timeout 60 pnpm bin -g` to 900 would have loosened a bound in the one place this repo's own
rule is sharpest. a check that prints a **plausible, specific, wrong fix** is worse than one
that prints a bare complaint, because the fix is what a hurried reader applies.

### .why q1-q6 all miss it

evidence matched verdict (q1); the difference sat in the subject (q2); no exemption applied
(q3); the summary matched its rows (q4); the fixture took (q5); and the rule cited — *"a
literal bound must equal the canonical total"* — is about this reader's exact claim (q6).

the defect sits in the **pattern's reach**: it matched a superset of the claim's subjects.

⇒ **a reader's pattern is a claim about which sites it governs, and a pattern is easy to
write wider than the claim.** the tell is not in the output — it is the question *"is there
a site this pattern matches where the correct value is DIFFERENT?"* if yes, the pattern must
carry the discriminator into itself. here that is the **verb**: the canonical pair governs
`install|add|remote-add|update|upgrade|dlx|view|outdated`, and says no word about
`bin|root|list|exec|why|prefix|config|run`.

⚠️ and the fixture is what makes it stay fixed. the play now carries `_local_bounded.sh`
(`timeout 60 pnpm bin -g` — a tight bound that MUST be spared) and `_message.sh` (prose that
quotes a call). without those two arms, the next author who widens the pattern back gets a
green run.

## .measurement 8 — the reader TORE PROSE IN HALF, and its prose-arm passed, 2026-08-14

measurement 7 is a pattern too wide. this one is a reader whose pattern was fine and whose
**tokenizer** was wrong — and it earns its own entry because the play already held an arm for
exactly this shape, and that arm went green while the shape was broken.

`prove.offbox-reads-are-bounded` splits a line at every place a new command may begin — `$(`,
`&&`, `|`, `;` — then judges each segment by its first word. it reported:

```
   ✋ 5.devtools/5.1.node/provision.upsert.sh:438
      | corepack install -g pnpm@$pnpm_want"
```

**line 438 is an `echo`.** the whole line reads:

```sh
echo "      read why: fnm use <version> && corepack install -g pnpm@$pnpm_want"
```

the split cut at the `&&` **inside the quotes**, so the tail became a segment whose first
word was `corepack` — and `echo` was no longer in front of it to mark it prose. the real
calls sit twelve lines above, and both already route through `web_corepack` / `web_npm`.

⇒ so the play condemned the most carefully bounded loop in the whole tree, and named a
`fix:` — *"wrap each in `timeout <n>`"* — for a call that is wrapped, on a line that is not a
call.

### .why the arm that existed did not catch it

the fixture carried `_fix_text` from the start:

```sh
_fix_text() {
  echo "      fix: gh auth login" >&2
}
```

it passes, and it always did — but **for the wrong reason**. that line holds no separator, so
the splitter leaves it whole, its first word is `echo`, and `echo` is in no tool set. it was
spared *incidentally*. the reader had no notion of prose at all, so the arm proved a property
the reader never had.

⇒ **an arm that passes incidentally is indistinguishable from an arm that passes on purpose**
— and this one stood as the stated guarantee of the play (*"a tool named inside an echo is
prose, not a call"*) for as long as the play existed.

### .the shape to watch for

> a reader that TOKENIZES a language must honor how that language quotes, or it will read
> data as code — and the failure appears only when a separator lands inside a string.

within double quotes, `&&`, `|`, and `;` are literal text; `$(` is the one construct that
still begins a command. the repair is a mask that neutralizes the first three within quotes
and leaves `$(` alone — nine lines of awk, and it moved direction 1 from one false ✋ to
`✔ no phase reaches off this box unbounded`.

⚠️ and the repair needs **both** arms, in the same edit. `_fix_text_chain` alone (an `&&`
within prose, which must be spared) is satisfied by a reader that spares every line with an
`&&` in it — a reader that would go blind to real chained calls. `_chained_real`
(`command -v git && git ls-remote …`, which must still be REFUSED) is what keeps the repair
honest, and it is the arm that must stay red-capable.

## .measurement 9 — the SWEEP was right, and the AUDIT beside it over-reported 5×, 2026-08-14

every measurement above is a check that got its VERDICT wrong. this one's verdict was right,
its tokenizer was right, and its twelve arms were all green — and the list printed two lines
below it was wrong, because that list was cut by a **different reader**.

`prove.timeouts-kill-what-they-cut` splits one set in two:

| half | the line holds | the play calls it |
|---|---|---|
| violation | a bare `timeout` call, unmarked | `_read_timeouts` — flagged |
| exemption | a bare `timeout` call, marked with a reason | `_read_exempt` — printed for audit |

the first was quote-aware and heredoc-aware. the second was a plain
`grep -rHn 'bare-timeout-on-purpose:…'`. so the sweep found **0 violations**, correctly, and
the audit announced **5 exemptions** where the repo holds **1**:

```
   · exempt: deaf.sh")  # bare-timeout-on-purpose: this IS the control; …   ← the real one
   · exempt: …play.sh:316:    | grep -vE 'bare-timeout-on-purpose:…' \      ← its own filter
   · exempt: …play.sh:348:  grep -rHnE 'bare-timeout-on-purpose:…' \        ← the AUDIT's filter
   · exempt: …echo 'i_marked() { timeout 30 … } # bare-timeout-on-purpose:… ← fixture text
   · exempt: …echo 'j_marked_bare() { … } # bare-timeout-on-purpose:'       ← fixture text
```

two rows are the play's **own filter patterns** — a reader that greps for its own regex
finds itself, always. two more are direction 5's fixture echoes. **not one of the four holds
a `timeout` call at all**; each merely quotes the word.

### .why this is a defect and not cosmetic

the list exists for exactly one purpose: so a second exemption **cannot appear unnoticed**
(`rule.forbid.exemption-as-habit`). four extra rows destroy that purpose outright — a human
who reads five near-identical lines cannot spot the day a sixth is real. so the exemption
goes quiet **inside the device built to keep it loud**.

⚠️ and one padded row carried **no reason after its colon** — the exact shape direction 5
proves must be refused. the audit advertised as an exemption a mark the sweep had already
flagged as a violation. the two halves of one set disagreed, in print, on one screen.

### .why q1-q8 all miss it

the sweep says 0, and 0 is right (q1), read correctly off the subject (q2). this IS the
exemption reader, so q3 turns on itself. the summary was faithful to its rows (q4); all
twelve arms behaved (q5); no citation is in play (q6); the *sweep's* pattern and tokenizer
are both exactly right (q7, q8).

every one of them interrogates **a** reader. the defect is that there were **two**, and the
questions have no way to ask which one you just examined.

### .the shape to watch for

> when one set is cut into complementary halves, both halves must come from **one**
> tokenizer — and both halves need an arm.

`violation = bare && !marked` and `exemption = bare && marked` differ by one term. written
as two independent readers they can disagree, and the disagreement is invisible because each
looks correct alone. the repair is a shared `_scan_bare`, with the marker applied as the last
filter in each direction:

```sh
# 👎 two readers, one set. the second cannot tell a CALL from the WORD
_read_timeouts() { <tokenizer> | grep -vE "$MARKED"; }
_read_exempt()   { grep -rHnE "$MARKED" --include='*.sh' "$1"; }

# 👍 one tokenizer, cut two ways
_scan_bare()     { <tokenizer>; }
_read_timeouts() { _scan_bare "$1" | grep -vE "$MARKED"; }
_read_exempt()   { _scan_bare "$1" | grep -E  "$MARKED"; }
```

⚠️ **a false `·` in an AUDIT is as corrosive as a false ✋ in a check.** an audit claims no
verdict, so a reader has none to distrust — the same reason measurement 3 is expensive. the
difference is direction: m.3's rows were true and INCOMPLETE, and these rows are true about
a word and are not members of the set they name.

### .the second defect, in the same device, found by the same read

the audit shortened each row with `sed 's|.*/||'` — cut at the LAST slash **anywhere on the
line**, not merely in the path. the one genuine exemption's body holds `"$tmp/deaf.sh"`, so
it printed as:

```
   · exempt: deaf.sh")  # bare-timeout-on-purpose: this IS the control; …
```

its file, its line number, and its call all eaten. **an audit row that cannot name its own
site audits no site** — and the mangle only ever fires on a row whose call is rich enough to
hold a path. the repair strips the repo prefix and no more.

## .measurement 10 — the CORRECTION re-created the defect it recorded, 2026-08-14

every measurement above is a defect in a reader. this one is a defect in the **fix**, and it
earns its own entry because the fix was written by an author who had just read this brief and
applied it on purpose.

`prove.see-alsos-point-somewhere` reads every path a brief cites under `.see also` / `.refs`
and demands the file exist. it found one in a term file that named a SHIPPED brief of another
role at a path under this repo:

```
| …/term=probe._.choice.example=…:137   .agent/…/briefs/rule.require.trust-but-verify.md
```

the correction did the right move — cite a shipped brief by NAME — and then, to show a reader
what had been wrong, it QUOTED the bad path in backticks. the next run flagged the identical
row, two lines lower.

**the record and the pointer are the same bytes.** a backticked path under a pointer heading
is indistinguishable from a live pointer, so the sentence that documented the dead link WAS a
dead link.

### .why it is not merely a typo

it is the general shape of every timelessness record in this repo:

> a correction that QUOTES the artifact it corrects re-creates that artifact, inside the
> exact section a reader is told to trust.

the same move is safe in prose — the play's `c_history.md` arm proves the reader ignores a
dead path mentioned outside a pointer heading — and unsafe under `.see also`, because that
heading's contract is *go here*. so the SAME sentence is correct in one section and a defect
in another. that is m.7 seen from the author's side rather than the reader's: not a pattern
too wide, but a **record placed where it reads as a claim**.

⇒ and it hides itself in the ordinary way: the author reads their own correction as prose,
because they know it is prose. only the machine reads it as what it is.

### .the repair

state the wrongness without reproduction of it — name the SHAPE of the bad path, not the path:

```md
👎 this line spelled a full `…/role=any/briefs/<shipped-brief>.md` path
👍 this line gave one under this repo's own briefs dir
```

⚠️ **and the 👎 line above was itself an instance, until 2026-09-02.** it spelled the dead
path in full — inside the repair block of the measurement that names the trap. a reader
built for this shape found it on its first run. the line now names the SHAPE; the reader
carries a second belt, and skips any line that holds a 👎.

⚠️ **an exemption is the wrong answer here.** the fix that tempts is a marker that spares a
quoted path inside a correction block — and that would spare a REAL dead pointer the day
someone writes a ⚠️ above one (`rule.forbid.exemption-as-habit`). the record belongs outside
the section, or written without the artifact in it.

## .measurement 11 — the FIXTURE was obeyed exactly, and what it said was FALSE, 2026-08-14

m.8 is an arm that passed for the wrong reason. this one is the mirror, and it is the harder
of the two: the arm passed for exactly the RIGHT reason, and the claim it encoded was wrong
about the domain.

`prove.apt-sources-serve` gained a direction 0 over its own source readers. one arm read:

```
✔ a_echoed — a source line quoted inside an echo is a read-why, not a declaration
```

that sentence is true of `prove.offbox-reads-are-bounded`'s subject, which is where it was
borrowed from. **it is false of this tree**, where an echo piped to `tee` is the ONLY way a
bundle declares an apt source:

```sh
echo "deb [signed-by=$keyfile] https://… vscodium main" \
  | sudo tee /etc/apt/sources.list.d/vscodium.list >/dev/null
```

so the reader obeyed the arm precisely, all 15 arms went green — and the rows below reported
**three false ✋**, on codium, dropbox, and onepassword, each a bundle that is correct.

### .why every question below misses it

q1 asks whether the evidence agrees with the verdict. it does: the reader found no live `deb`
line, and by its own rule there was none. q5 asks whether the fixture took — it took
completely. q7 asks whether the pattern's reach exceeds the claim — it does not; the pattern
matches exactly the claim the arm states. **the claim itself is what is wrong**, and a
fixture cannot see that, because a fixture's whole job is to hold the reader to the claim.

### .the shape to watch for

> a fixture proves the reader does what you SAID. it cannot prove that what you said is true
> of the tree.

⚠️ and the two rows that stayed green did so by **luck**: `gh` and `docker` guard the write
with `if ! echo …`, so their first word was `if` rather than `echo`. a page of 4 ✔ and 3 ✋
sat one line of shell away from a page of 7 ✋ — so the partial survival made the defect read
as three rotted vendors rather than as one broken eye (m.2's degradation, from the other
side).

⇒ **what caught it was the LIVE half of the same run.** so the three devices are a set, and a
play that discovers its own subjects owes all three:

| device | answers |
|---|---|
| **floor** | did the set shrink? |
| **fixture** | does the reader obey its stated claim? |
| **live rows** | is that claim true of the tree? |

⇒ and the repair is a PAIR of arms rather than one, so neither direction can be asserted
alone: `a_echo_decl` (an echo piped to `tee` IS a declaration) beside `b_echo_prose` (a line
sent to `>&2` is a read-why). a third, `b2_guarded_decl`, plants the `if ! echo` shape whose
luck hid half of it.

## .measurement 12 — the pattern matched a SUBSET, and the total was true of the subset, 2026-08-14

m.7 is a pattern whose reach EXCEEDS its claim, and it goes red. this is the mirror, and it
goes **green**: a pattern whose reach falls SHORT of its claim reads part of its subject,
counts what it read, and reports that count as though it were the whole.

`prove.see-alsos-point-somewhere` reads every path a brief cites under `.see also` / `.refs`
and demands the file exist. its tokenizer emitted **backticked** tokens only:

```awk
while (match(line, /`[A-Za-z0-9._-]+\/[A-Za-z0-9._=\/*<>$-]+`/))
```

and `template.domain-term.md` — this repo's own declaration of how a `.refs` list is written —
declares the **bare** shape:

```md
## .refs
- src/domain.objects/Stone.ts            # the domain object
```

so the whole `domain.terms/` corpus writes bare paths: **312 rows across 66 files**, against
the 170 backticked ones elsewhere. the play read the 170, and printed:

```
   ├─ paths cited:       170
   ✔ all 170 cited paths exist
```

**four genuinely dead pointers sat in the unread two thirds** — three that name files deleted
in the 2026-07-30 hard cut, and one that names a SHIPPED brief of another role at a path under
this repo (m.10's shape, in a row m.10's own repair could not reach, because nobody could read
it).

### .why every question above misses it

- **q1** — 170 read, 170 exist. they agree exactly.
- **q4** — the sign-off is *literally true of its rows*: all 170 cited paths exist. it never
  claims 170 is the corpus; the reader infers that.
- **q5** — all 11 arms behaved.
- **q7** — no matched site holds a different correct value. the defect sits entirely in sites
  it does **not** match, and no question about matched sites reaches an unmatched one.
- **q8** — the tokenizer handed the pattern exactly what the file says.
- **q10** — every arm's sentence is true of this tree.

### 🛑 .the two devices that ALSO miss it

this is the sharpest part, because both are the devices this brief prescribes:

| device | why it is blind here |
|---|---|
| **fixture** | all 11 arms were written backticked — the author's own habit. an arm can only plant a shape its author can SEE, so a fixture written by whoever wrote the reader inherits that reader's blind spot verbatim |
| **floor** | a floor is calibrated against the reader's own first read. set at 170 while the reader was already blind, it enshrines the blindness as the baseline — and then reports ✔ forever, on 170 |

⇒ **a floor calibrated against a blind reader does not detect the blindness; it ratifies it.**
that is the one case `term=floor`'s promise (*did the set shrink?*) cannot keep, because the
set never shrank — it was never that size.

### .what DID catch it

a **dead pointer planted into a real brief**, in the live corpus, followed by a run:

```md
- .play/temporary/prove.this-path-is-not-real.play.sh   # PROBE — must be flagged, then removed
```

the play stayed green **and the count did not move**. that is unambiguous: a row the reader
cannot see is a row that changes no number.

⇒ so the discrimination probe belongs on the **live corpus**, not only on the fixture. a
fixture arm asks *"does the reader obey me?"*; a planted row in the real subject asks *"does the
reader SEE the shape my subject is actually written in?"* — and only the second can find a
shape the author never thought to write.

⚠️ it is a round trip with net zero effect, so it is legitimate under `rule.forbid.repair-plays`
EXCEPTION 2 — but the planted row must be removed in the same session, and the arm that replaces
it must be permanent (`m_bare_dead`, here).

### ⚠️ .the repaired reader then went red against THIS RECORD — and it was right to

the paragraph above quotes the bare `.refs` convention verbatim, in a fence, so a reader can see
the shape that went unread. the newly-sighted reader took that illustration for a live pointer
and reported a dead path — against an example that was never about a file.

that is **m.10 from a new direction**. there, a correction that QUOTED a dead path re-created it;
here, an illustration of the POINTER SHAPE re-created a pointer. one cause both times: a record
and the artifact it records are the same bytes.

⇒ but the repair is the OPPOSITE one, and that is the lesson. m.10's fix was at the author —
name the shape, do not reproduce it — because a path is nameable without reproduction. a
CONVENTION is not: a brief that teaches how a `.refs` list is written must be able to show one,
and always will. so the durable fix is at the **reader**: a fenced block is DATA, and the toggle
runs before the heading rule, so a fenced `## .refs` can neither open a section nor close one.

⚠️ and the arm must plant the shape that just bit, in the same edit (`o_fenced`) — and the row
AFTER the fence closes too, since a toggle that never flips back would silently swallow the rest
of the file.

## .measurement 14 — the count consulted the INDEX, and the TREE disagreed, 2026-08-30

m.9 is one set cut by two readers in one file. this is one set held by **three stores** — the
index, the worktree, and whatever record a reader keeps — and a delete that reaches two of the
three reads as done from whichever store you ask.

a census of a play dir was re-counted, and two reports disagreed on the DENOMINATOR:

```
git ls-files '<dir>/*.play.sh' | wc -l   → 109      ← the INDEX
tree -a <dir>                            → 108      ← the TREE
```

one path held the delta:

```
git status --short -- <dir>/verify.shell.syntax.play.sh
AD <dir>/verify.shell.syntax.play.sh
```

`AD` = staged as **added**, deleted in the **worktree**, deletion **never staged**. so
`git ls-files` counted a file that no longer exists, and a readme's two questions were put to a
play nobody could open.

### .why q1-q12 all miss it

every question above interrogates a READER — its logic, its pattern, its tokenizer, its fixture,
its citation, its reach. this reader was correct: `git ls-files` reports the index exactly, and
`tree` reports the disk exactly. **each answer was right about the store it asked.** the defect
is that the subject has more than one store, and the count named neither.

### .the shape to watch for

> **a count is a claim about a SET, and a set with more than one store has more than one true
> answer.** name the store, or read both and demand they agree.

⇒ the repair is not a better count. it is to read the two stores SEPARATELY and assert
agreement, which turns a silent disagreement into a row:

```
tree -a <dir> | tail -3          → 1 directory, 112 files     ← the TREE
git ls-files '<dir>/' | wc -l    → 112                        ← the INDEX
```

⚠️ and the third store is the one no command reads: **the record a reader keeps.** a note that
says *"this was deleted"* is a third answer, free to drift from both — m.9's shape with one more
holder. `rule.require.one-command-provision` records the same trap at a remote boundary, where a
local record keyed on a name outlived the box that name pointed at.
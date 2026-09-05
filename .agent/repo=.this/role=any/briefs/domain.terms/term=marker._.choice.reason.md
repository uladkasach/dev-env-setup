# domain.term.choice.reason: marker

## .etymology

a **marker** is what you leave so you can find a place again. it carries no cargo
and does no work — its whole value is that it stays FINDABLE and does not move.
both properties are load-bear here: a marker must be greppable, and it must
survive every edit to the code beneath it.

## .why it is not `guard` — the split worth the record

these two sit one line apart, and authors conflate them constantly — the code that
got this wrong among them:

```sh
local marker="# grove: keynav autostart at login"   # the MARKER — a fact
if grep -qF "$marker" "$profile"; then               # the GUARD — a decision
```

| | the guard | the marker |
|---|---|---|
| what it is | the `grep` + the branch it drives | the line the grep looks for |
| what it does | DECIDES whether to append | ASSERTS that the append happened |
| how it fails | it appends twice, or never | it drifts, and the guard fails with it |

`guard` is already this repo's word for the half that decides —
`kitty_snap_lowbatt` is "the low-battery guard", and the bhrain route vocabulary
uses it for a gate. to call the greppable line a guard puts one word on both
halves of a mechanism whose whole defect is that the two halves get confused.

## .why not `sentinel`

`sentinel` is the closest near-miss, and the one a hurried author reaches for. it
says *watches for a condition* — a sentinel value stands guard at the end of an
array, a sentinel file signals a state that may change. a marker watches for no
condition. it is inert. it asserts one fact about the past ("this block landed")
and it never changes.

that difference matters because a reader who calls it a sentinel eventually tries
to make it CONDITIONAL — derive it from the block, stamp a version into it, key it
on a hostname — and every one of those breaks the fixedness the term exists to
protect.

## .the evidence — two guards that could never match, found 2026-07-31

`~/.profile` has three appenders. only one had a real marker.

```sh
grep -qF '(keynav && echo "keynav started"' ~/.profile   # 1.1.keybinds
grep -qF 'system76-power profile battery'   ~/.profile   # 1.2.power
grep -F  "# grove: fnm + pnpm on PATH…"    ~/.profile   # 5.1.node  ← the only marker
```

the first two grep a **fragment of the very line they write**. that couples the
guard to the COMMAND, so the guard survives only while the command stays frozen:
reword the echo, add a redirect, swap an `&&` for an `||`, and the grep can never
match a healthy file again. every later run appends another copy.

the sharp part: this stays invisible until someone edits the command. the guard
looks like idempotence and delivers it right up until the day the code changes —
then delivers the opposite, silently, on every box.

⚠️ `1.2.power`'s own file header already documented this defect class, in words:

> *"a non-idempotent append guarded by a check that cannot ever match: the guard
> looks like idempotence and delivers the opposite."*

it wrote that about the ORIGINAL pop-os line it came from — then shipped a milder
version of the same shape three lines below. **a file that names a trap in prose
gets no protection from it.** only a term protects, because a term lets the
reviewer ask "is that a marker?" and get a yes-or-no.

## .why the words, and not the slug

`# grove: 1.1.keybinds` lost. a slug names a POSITION in the bundle tree, and
positions move — `4.3.kitty` gained a child this same week, `1.4.performance`
retired, `install_env.pt*` became bundles entirely. a marker keyed on a slug is a
marker a rename silently breaks, on every box, for the same reason a code-fragment
guard breaks.

the CLAIM does not move. "keynav autostart at login" is true of the block whoever
owns it, wherever the bundle tree puts that owner next.

## .the migration hazard, which is the term's sharpest edge

the repair itself is an append hazard, and it inverts the usual instinct:

> a marker rename with no legacy grep beside it appends a SECOND block to every
> box already provisioned.

so the run that FIXES idempotence is the run that breaks it — once, everywhere,
at the same time. that is why both repaired appenders carry two greps:

```sh
if   grep -qF "$marker" "$profile"; then :          # the new marker
elif grep -qF "$legacy" "$profile"; then :          # the pre-marker block
else <append>
fi
```

the legacy grep is the migration. drop it only when no box predates the marker —
which, for a personal machine with one laptop and disposable groves, arrives sooner
than it sounds, and is still a fact about the world rather than about the repo.

### ⚠️ the branch is enough only where the marker drives ONE decision

the `if/elif` above serves an appender that asks one question: append, or do not.
where the same marker also drives a **strip**, a branch is not enough. the strip
would still name the CURRENT fence, match no block, and the append would land a
second one regardless — so the branch reads as handled and delivers the very defect
it was written to prevent.

⇒ repoint the VARIABLE instead, and every later reader inherits it:

```sh
if ! grep -F "$marker" "$profile" && grep -F "$marker_was" "$profile"; then
  marker="$marker_was"   # the guard, the strip, and the skip all follow it
  ender="$ender_was"
fi
```

`5.1.node`'s appender is the worked case: its guard greps `$marker`, its `awk`
strips from `$marker` to `$ender`, and its heredoc always writes the CURRENT fence.
so a legacy box strips its legacy block and re-emits a current one, and a box whose
content is already right keeps its legacy fence untouched. one block, either way.

### .measured on a box converged before the fence moved — 2026-09-02

`~/.profile:29` held `# devenv: fnm + pnpm on PATH for login shells`, and the
current fence matched **0** lines. the two halves, read separately:

| the reader | on that box |
|---|---|
| a verify keyed on the current fence alone | ✋ — a false claim, whose re-apply fix-text could never clear it |
| the same verify, reading both fences | ✔ |
| the upsert, marker repointed | `already current; skipped` — and line 29 stayed the only block |

⇒ two lessons, and the second is the one a reader would miss. the legacy grep is
load-bear TODAY, so the drop-it clause above has not come due for this fence. and a
marker rename costs a reader on BOTH halves — the verify's miss is the louder one,
since it argues against a correct box on every run
(`gotcha.a-check-that-cries-wolf-gets-silenced`).

## .the overload it nearly took — a LOCAL file that remembers a REMOTE fact, 2026-08-30

`sentinel` above is the near-miss on the WORD. this is the near-miss on the CONCEPT, and it
came from an author who had just read this cluster.

`git.grove.provision` kept a per-seat file at
`$XDG_STATE_HOME/git.grove.provision/<name>/applied.<seat>` so a re-run could say which applies
it had already driven. the skill's header, its comments, and the brief that recorded its defect
all called it a marker.

**it is not one, on every property this term names:**

| | a marker | that file |
|---|---|---|
| where it sits | INSIDE a file this repo does not own | in its own state dir, owned outright |
| what it buys | an APPEND becomes idempotent | memory across runs |
| who reads it | a `grep`, in the same phase that writes it | a later, separate invocation |
| what it asserts | *my block is already here* | *an operation ran on some OTHER machine* |

⇒ that last row is the whole difference. a marker asserts a fact about **the file it sits in**,
so it cannot outlive its subject — remove the block and the marker goes with it. that file
asserted a fact about a **remote box**, and a claim held apart from its subject is free to
outlive it. it did: keyed on the grove NAME, it survived a rebuild and reported an apply on an
instance terminated half an hour earlier.

⚠️ so the overload would cost more than tidiness. it would lend this term's central guarantee —
*a marker cannot drift from what it asserts* — to the one shape that can.

that concept is spelled **`record`** instead: a plain word, no cluster owed, since it composes
no declared dobj or dop (`rule.require.domain-term-itemization`).

⚠️ and `record` does NOT belong in this term's `synonyms.forbidden`. that list holds other words
for the SAME concept — words a hurried author reaches for in place of `marker`. this is the
opposite error: the right word for a DIFFERENT concept, mis-spelled as this one. so it earns a
`.what` line in the say file ("what a marker is not"), never a synonyms row — the two mistakes
take different repairs, and a list that mixes them teaches neither.

## .disputes

no dispute is open.

## .see also
- `rule.forbid.two-writers-on-one-artifact` — the rule this noun serves, and its
  `.the marker must be a SLUG, never the code` section
- `rule.require.idempotent-install-procedures` — what a marker buys
- `term=asset._.choice._.md` — the other answer to "who owns this file": an asset
  is byte-owned by one bundle, where a marked file has several appenders and no owner
- `term=claim._.choice._.md` — what the marker's words name

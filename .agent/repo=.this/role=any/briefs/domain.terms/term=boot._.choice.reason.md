# domain.term.choice.reason: boot

## .etymology

`boot` is the clipped form of `bootstrap`, from *"to pull oneself up by one's bootstraps"* — a
19th-century figure for an impossible self-start, borrowed by computer science for the possible
one: a small act that brings a larger system to life.

the field kept **both** forms and split them, which is exactly the split this repo needs:

| form | its sense in the field |
|---|---|
| **bootstrap** | the small program that makes a start possible at all |
| **boot** | the whole sequence from power-on to a usable system |

⇒ so the pair is not our coinage. we adopt a distinction the field already draws, and the reader
who knows one domain knows the other. that is the strongest ground a term can have.

## .why NOT reuse `bootstrap` for both

it is the obvious move and it is wrong twice over.

**1. the two acts differ in every axis that matters.** the `.choice._.` table lists five, and no
two rows agree. a word that spans them says none of them.

**2. `grove.bootstrap` already carries a singularity claim.** its own file states the reason it
is not called `entrypoint`: `grove.provision._.sh` is **THE** entrypoint, and that singularity is
load-bear. to now put `bootstrap` on two concepts would commit the identical defect one rung
down — and in the very cluster that names it (`ubiqlang.ambiguous-from-overload`).

⇒ **the argument that protects `bootstrap` from `entrypoint` protects `boot` from `bootstrap`.**

## .why NOT `provision`

this is the near miss, and it earns a statement because a boot's whole body is provision calls.

`grove.provision` is the DRIVER — it converges one `$HOME` on one box
(`term=grove.provision._.choice._.md`). a boot calls it once per seat and does three things the
driver cannot:

1. it reaches the box at all (wake, trust)
2. it orders the seats — ground before camper, which is load-bear
3. it runs the gate with no command in the gap

⇒ **a boot is the sequence AROUND the driver, never the driver.** to name them alike would make
"which provision?" a permanent question, and would hide that the seat order has an owner.

## 📜 .the two measurements — 2026-09-06

### m.1 — the hand-rolled sequence cannot work, and fails late

a mechanic read the four steps out of `rule.require.one-command-provision` and typed them:

```sh
rhx git.grove.send <g>.ground --reply --what 'rhx grove.provision --mode apply'
#   → exit 127:  Command 'rhx' not found
```

`rhx` sits on PATH from `~/.zshrc`, which a ground seat's non-interactive shell never reads
(`gotcha.a-tool-found-by-path-answers-only-a-human`). the boot skill names the driver by path —
the carve-out `rule.forbid.the-driver-by-path` grants a SKILL and denies a human at a keyboard.

⇒ so the hand-rolled twin is **unreachable**, not merely discouraged. the word `boot` names the
one act with a path to succeed, and that is why the rule's own step list opens with 🛑 *do NOT
hand these lines to a human as the procedure.*

### m.2 — the fix-text dropped the verb

on the same run, `boot` halted and printed its own resume command:

```
then run again from here —
  rhx git.grove.provision grove-… --mode apply --from 2 --trust keep
                                  ↑ the verb is absent
```

copied verbatim, that yields `✋ git.grove.provision needs a verb`, whose own fix-text then names
`boot` and `test` — the word the line above had just dropped.

⇒ this is `gotcha.a-check-that-cries-wolf-gets-silenced` m.4 in miniature: **the halt was
correct and the command it handed back was wrong.** it cost one wasted invocation, and it is
evidence the verb had not yet hardened as a term. that is the gap this cluster closes.

## .disputes

none open.

⚠️ one dispute worth a note before it is raised: *"the skill is `git.grove.provision`, so the
verb is redundant — drop it and infer from `--mode`."* that argues for a THIRD name for one act,
and it would put the read verb (`test`) and the write verb on one name discriminated by a flag.
the two differ in whether they WRITE, which is the one axis a flag must never carry silently
(`rule.forbid.repair-plays` draws the same line for plays).

## .evidence

- `git.grove.provision --help` declares exactly two verbs, and names the gap they exist to close:
  *"boot runs test as its last step, with no command in between — that gap is the bar
  rule.require.one-command-provision exists to hold."*
- `rule.require.one-command-provision` — its `.the test` section, where the four steps are
  recorded as a record and explicitly refused as a procedure
- `rule.forbid.the-driver-by-path` — carve-out 1, `git.grove.provision.boot.sh`'s `UPGRADE` string

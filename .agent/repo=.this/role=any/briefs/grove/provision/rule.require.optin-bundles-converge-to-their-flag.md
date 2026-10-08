# rule.require.optin-bundles-converge-to-their-flag

## 🛑 .the rule, in one line

# **AN OPT-IN BUNDLE SHIPS TO EVERY BOX. ITS BODY READS THE FLAG AND CONVERGES TO IT — SET MEANS INSTALL, ABSENT MEANS TEAR DOWN.**

the flag decides **what the bundle converges to**. it never decides **whether the bundle runs**.

## .what

some subjects are not facts about a box but **elections** by a human — a courtesy fence around
their hours, a monitor they want on this seat and not that one. such a bundle is opt-in, and
opt-in is written as a flag the bundle's own body reads:

```sh
if [[ "$(<the bundle>_optin_state)" != "in" ]]; then
  # tear down what this bundle installed, and report
  return 0
fi
# ... install, as normal
```

both legs are real work. the opt-out leg is not a skip.

## 🛑 .why this is NOT a per-machine bundle subset

`rule.require.identical-bundle-composition` forbids a per-machine subset — *"installed on each
machine, or on no machine. there is no third answer."* an opt-in bundle does not breach it, and
the distinction is the whole reason this rule exists:

| | a DECLINE (governed by that rule) | an OPT-IN FLAG (governed by this one) |
|---|---|---|
| does the bundle run? | no — early return before any work | **yes, always. every phase** |
| what the claim is about | this box **cannot hold** the subject | this seat **has not elected** it |
| what varies per box | the composition — which bundles ran | the converged **state**, which every bundle has |
| who may write it | only a physical reason (`rule.forbid.divergence-without-a-physical-reason`) | the human, per box |

⇒ that rule governs **which bundles run**. it says no word about what a bundle converges to —
and every bundle in this tree already converges to a declared value. `1.2.power` sets logind to
`IdleAction=ignore`; a bundle that converges to *"no timer"* is the same shape, not a decline.

⚠️ **so an opt-in bundle still declines nowhere, and its phases still all run.** a reader who
sees a per-box difference in OUTCOME must not read it as a per-box difference in COMPOSITION.

## .how to write one

### 1. ONE reader, shared by every phase

the upsert and the verify must not each test the flag their own way — that is how an upsert
installs while its verify calls the box opted out
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9). declare the reader in the bundle's `_.sh`
beside the flag, and have both halves call it.

### 2. the bundle READS the flag and never writes it

🛑 a bundle that creates its own opt-in marker **grants the election it was sent to ask about**.
the first apply would enroll every box, and the default would be off in name alone.

⇒ the human places the flag, and the bundle's report names **the skill that places it**.

### 2b. ⚠️ a box-side flag OWES a skill family — `get`, `set`, `del`

the flag's path is the half nobody recalls, so the ad-hoc form is a `mkdir -p` plus a redirect
into an exact path — and a redirect one character off writes a flag the bundle never reads. that
fails **silently** in the worst direction: the next apply tears the subject down and reports
success, because by its own reader the box asked for none.

⇒ so wrap it (`rule.require.wrap-cli-in-skills`: *an absent skill is the defect to fix*), and let
the family source the BUNDLE for the path so the two can never disagree.

| verb | owes |
|---|---|
| `get` | the election AND the converge, as **two rows** — they drift by one apply |
| `set` | idempotent, `--mode plan` default, and it prints a prior note before it replaces it |
| `del` | idempotent, **human only on apply**, and it reads whatever state the teardown may **strand** (see step 4) |

🛑 **the revoke is human only.** an agent fenced by the subject could otherwise opt its own box out
of it. `del --mode apply` holds the same tty guard `git.commit.uses allow --global` holds; plan
stays open, since it writes naught.

🛑 **a skill may write the flag where the bundle may not.** the bundle runs on every box,
unattended; a human types the skill once, at the box they mean. that asymmetry is the whole
reason the write belongs in the family and the bundle stays a pure reader.

⚠️ and the family **never drives the converge itself**. it sets the election and names the one
command — else there are two paths to the installed state
(`rule.forbid.repair-plays`, `rule.require.install-via-procedures`).

### 3. opt-out TEARS DOWN — it does not merely skip

`grove_optin`'s *never uninstalls* is right for an app in `6.apps`: a forgotten `--include` must
not be destructive. it is wrong for a subject whose unit stays live once installed. a box opted
in once and out later would carry a timer that no declaration holds.

### 4. ⚠️ the teardown reverts the MECHANISM, never the human's state

a torn-down gate must not be an OPEN gate. a human may have closed one by hand, and the safe
direction on an unreconciled subject is the closed one. **opt-out means stop converge, never
revert.**

and the teardown must not delete the flag itself — check the paths it removes. a marker stored
beside the bundle's rendered files is deleted by the very opt-out it should survive.

### 5. the verify's claim INVERTS with the flag

an opted-out box is **converged, not broken**, so it reports `•  … ✔` and returns 0. what the
verify then hunts is **residue**: a live unit on a box that elected none is the defect, and it is
invisible to a verify that only ever checks the installed case.

## .where the flag lives — and the test that sorts it

| the fact | owner | why |
|---|---|---|
| the subject's SHAPE — hours, zone, pins, unit text | the **tree** | one fact for every box; a fresh box must inherit it |
| the ELECTION — does THIS seat want it | the **box** | differs per box, so no tree value can carry it |

⚠️ a box-side flag looks like a breach of `rule.require.repo-as-source-of-truth`. check its two
stated harms before you accept that verdict:

1. *"lost at the next apply"* — it cannot be, if the bundle only ever reads it (step 2)
2. *"the next machine never gets it"* — for an opt-in-only subject this is **the point**, not a
   loss. a fresh box that correctly carries no gate is the default honored

⇒ if either harm DOES land, the flag belongs in the tree instead.

⚠️ and a box-side flag is **config, not state**: xdg splits those by owner, so it belongs under
`${XDG_CONFIG_HOME:-$HOME/.config}` with the files a human writes — never beside the files the
bundle renders.

## .PRESENCE beats a parsed value

a parsed flag needs a grammar, and a grammar can be typo'd. `OPTIN=ture` is neither true nor
false, which leaves the bundle two bad moves: guess, and tear down a gate the human asked for;
or fail, and redden a run over one stray character.

⇒ prefer **presence of a path**. it has no grammar to get wrong, and it frees the file's body to
hold the human's own reason.

## .it is not the `--include` opt-in

this repo has two opt-in mechanisms, and they are not interchangeable:

| | `--include` (`6.apps`) | a converged flag (this rule) |
|---|---|---|
| where the ask lives | the command line | a declared flag the bundle reads |
| lifespan | that ONE run | until a human changes it |
| a bare `grove.provision` | installs no app | converges the subject |
| opt-out | skips; **never uninstalls** | **tears down** |

`--include` is per-run, so a subject wired that way needs its flag on every apply or the next
bare run removes it — and a fence a human must re-request forever is a fence they lose
(`rule.require.one-command-provision`).

## .enforcement

- an opt-in bundle that **declines** (returns before its phases) rather than converges = **blocker**;
  that is a composition subset, and `rule.require.identical-bundle-composition` forbids it
- an opt-in flag read in **two places** with two tests = **blocker**
- a bundle that **writes or creates** its own opt-in flag = **blocker**; it grants its own election
- an opt-out leg that **skips** rather than tears down a subject whose unit stays live = **blocker**
- a teardown that **reverts the human's state** (opens a gate, clears a meter) = **blocker**
- a teardown that **deletes the flag** = **blocker**; the next apply then cannot tell opted-out
  from never-asked
- a verify with **no residue check** for the opted-out case = **blocker**; it is the only reader
  that sees a unit no declaration holds
- a box-side flag with **no skill family** to get/set/del it = **blocker**; the hand-rolled
  redirect it leaves behind fails silently (step 2b)
- a family that **restates** the flag's path rather than source the bundle's declaration =
  **blocker**; the drift tears down the very subject a human just elected
- a family verb that **drives the converge** itself = **blocker**; two paths to one state
- a `del` whose apply an agent can run unprompted = **blocker**; the fenced party revokes its own fence

## .the reference

`5.18.openhours` is the worked case: the marker is presence-only under `~/.config/grove/`, the
schedule stays in the tree, one reader serves both phases, and the teardown stops the converge
and opens neither gate.

## .see also

- `rule.require.identical-bundle-composition` — which bundles run; the rule this one reconciles with
- `rule.forbid.divergence-without-a-physical-reason` — the bar a real decline must clear
- `rule.require.repo-as-source-of-truth` — its two harms, and when a box-side flag escapes them
- `rule.require.upgrade-entries-verify-themselves` — why the opted-out case owes a verify too
- `howto.opt-into-openhours` — the per-seat recipe for the reference case
- `term=opt-in._.choice._.md` — the `--include` mechanism, which this is not

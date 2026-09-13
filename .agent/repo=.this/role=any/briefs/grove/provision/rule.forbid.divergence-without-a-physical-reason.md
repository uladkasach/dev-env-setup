# rule.forbid.divergence-without-a-physical-reason

## 🛑 .the rule, in one line

# **PARITY IS THE DEFAULT. A GROVE DIVERGES ONLY WHERE THE TWO KINDS ARE FUNDAMENTALLY DIFFERENT — AND THE DIFFERENCE IS PHYSICAL.**

a cloud grove has no screen, so it has no terminal emulator. that is a fundamental
difference, and `4.3.2.emulator`'s decline is earned by it.

every other divergence is forbidden. a tool, a version, a config, a unit — if both kinds can
hold it, both kinds get it.

## .what counts as FUNDAMENTAL

the box physically cannot use the subject. the full set this repo has earned:

| the fact | what it declines |
|---|---|
| no screen, no compositor | a GUI app, a font render, a theme, a launcher |
| no microphone | an audio capture |
| no notification bus | an alert a human reads |
| no kitty windows | a capture of those windows |
| no hand at the keyboard | a yubikey tap |
| no keystroke for zle to read | an inline completion widget |

⇒ each names a **physical absence**. a traveler can point at the box and say *"that is not
here, and no command makes it appear."*

## 🛑 .what does NOT count — and each has bitten

| the excuse | why it is not fundamental |
|---|---|
| *"a grove would not need it"* | a guess about use, never a fact about the box. this is how `yq` was missed |
| *"it is a dev convenience"* | a cloud grove does the same work; convenience is no hardware fact |
| *"the binary is absent there"* | that is the DEFECT, stated as its own justification |
| *"a human is not at this box"* | ⚠️ a **capability** claim, and the subtlest. a binary needs no human. gate the PROMPT, never the tool |
| *"it has always been that way"* | an unexamined divergence is the one most apt to be a miss |

## .the test, before you write a decline

> **1. name the physical subject. can a command make it appear on the other kind?**
> **2. if yes, there is no decline to write. ship it to both.**

a screen cannot be installed. a binary can. that one question sorts every case.

## ⚠️ .gate the PROMPT, never the TOOL

the most common correct-seeming mistake. `gh` and a git identity reach a cloud grove; only
their interactive login does not.

```sh
# 👍 the tool installs everywhere; only the prompt is gated
grove_provision_5_4_gh_provision_upsert    # no gate — gh reaches both kinds
grove_provision_5_4_gh_configure_upsert    # gates the LOGIN on local@unix
```

⇒ a decline placed on the bundle rather than the prompt costs the far box the whole tool.
that is the `5.7.terraform` and `5.17.yq` shape, and it is what this rule exists to catch.

## .why parity is the default, and no mere preference

- **the same work runs on both kinds.** a grove clones the same repos and runs the same gates,
  so a tool absent from one box is a gate that reddens there and nowhere else
- **a divergence is invisible until it bites.** a plan reports what RAN; a bundle that declines
  reports a tidy `🌙` and every reader reads it as correct
- **the cost lands on the far box.** the author works on a laptop, so a laptop-only tool feels
  complete. the cloud grove finds out later, alone, with no human at it
- ⇒ `rule.require.identical-bundle-composition` already demands one declaration for both. this
  rule is the same claim at the DECLINE: one declaration, and a decline that is argued rather
  than assumed

## 🛑 .a decline states its subject INLINE, at the bundle

```sh
# 👍 the subject is physical, and named where a reader meets the gate
if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
  echo "   🌙 declined — the snap captures kitty WINDOWS, and $GROVE_ENV_SERVER has none"
  return 0
fi

# 👎 a capability, and a guess
if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
  echo "   🌙 declined — a grove would not use this"
  return 0
fi
```

⚠️ **`local@*` is coarser than most reasons it carries.** `local@cicd` is a local tier with no
screen and no human (`grove.env.sh`), so a gate whose reason says *human* or *screen* wants
`local@unix`. inert while the detected set is two values; a live defect the day cicd detection
lands.

## .enforcement

- a bundle that declines on a kind with **no physical subject named** = **blocker**
- a decline whose subject is a capability, a convenience, or a guess about use = **blocker**
- a decline placed on a TOOL where only its PROMPT is interactive = **blocker**; it costs the
  far box the whole tool
- a tool absent from one kind with **no decline at all** = **blocker**; that is a miss, and the
  bundle that owes it is the repair
- a new divergence added with no row in `inventory.approved-divergences` = **nitpick**; the
  inventory is what spares the next traveler a re-argument

## .see also

- `inventory.approved-divergences` — the settled cases, and the two measured misses
- `rule.require.identical-bundle-composition` — one declaration serves both kinds
- `rule.forbid.tty-as-a-proxy-for-a-human` — the capability-for-presence defect, one layer down
- `rule.require.one-command-provision` — the bar a silent divergence breaks
- `repo.overview.md` — the two kinds, and why a claim true of one is a defect

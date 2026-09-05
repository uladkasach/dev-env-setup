# rule.require.identical-bundle-composition

## .what

**cloud and local get the IDENTICAL set of bundles.** every bundle applies to every machine,
unless that bundle's own header articulates why this machine genuinely cannot hold it.

it is installed on **each** machine, or on **no** machine. there is no third answer, and there is
no per-machine subset.

a decline is written as an **early return in the bundle's own body**, guarded by a direct read of
`$server`:

```sh
grove_provision_9_9_example() {
  # <the articulated reason THIS box cannot hold it>
  [[ "$GROVE_ENV_SERVER" == local@* ]] || return 0
  ...
}
```

there is **no** `grove_env_has_*` predicate, **no** `--applies <fn>` argument, and **no**
`any|local|cloud` tag. those are all forbidden — see `.the three shapes this replaces`.

## .why

### two lists drift — and applicability was the last surviving list

this repo's oldest and most repeated defect is two answers to one question:

| date | the two |
|---|---|
| 2026-07-26 | `install_env.sh` and `install_env.grove.sh` — two lists of steps |
| 2026-07-27 | `grove.provision.grove` — a second wrapper, which had already dropped `brains` |
| 2026-07-29 | `grove.env.sh` + `grove.for.sh` — two readings of one machine |

each was killed by collapse to one. **applicability is the same defect behind a predicate**: a
`local`-gated bundle means the cloud box runs a different composition, so there are two trees
again, derived rather than written down. a derived divergence is worse — no file shows it, so
you must run both to find out.

### the mistake is always the same: EFFECT confused for HOLD

every gate this repo ever wrote was wrong, and wrong the same way. it read *"this has no effect on
a headless box"* as *"this cannot be held by a headless box"*. those are different claims:

| bundle | the gate's claim | what is actually true |
|---|---|---|
| `1.1.keybinds` | a grove has no keyboard | keyd installs from apt and runs on `/dev/uinput`, which the kernel provides with no display. it just has no keyboard to remap |
| `1.2.power` | a grove has no lid | logind is present; `IdleAction=ignore` is exactly as wanted — an idle ec2 box that locks drops every duct |
| `1.3.browser` | a grove has no display | the flatpak installs; the profile and prefs are plain files. only `xdg-settings` needs a desktop — ONE line |
| `4.3.2.emulator` | kitty needs a screen for its window | the tarball extracts anywhere, and it ships `kitten` — which every termwork skill in this repo drives |

a keyboard remap with no keyboard is a **harmless declaration**. the gate that avoided it cost a
grove a real capacity to save a config file it would have ignored.

### the inverted-intuition case, which is the proof

`4.3.1.terminfo` settled this before the rule was written. the box that needs the `xterm-kitty`
entry is the box a kitty client **connects to** — the headless one. the package is named
`kitty-terminfo`, so every intuition says "local only", and every intuition is wrong.

on 2026-07-29 that entry's absence on a grove surfaced as three complaints that each read as its own
bug: tmux refused to start ("unsuitable terminal"), ncurses tools garbled, backspace drawn as a
space. **one absent entry, three symptoms, and no run reported a defect** — because the entry was
installed by a step only a machine WITH a screen ever ran.

that is the cost of a wrong gate, and it is the reason the default must be "everywhere".

## .the three shapes this replaces — all forbidden

### 1. `grove_env_has_*` predicates — REMOVED 2026-07-29

`grove_env_has_screen` and `grove_env_has_human` were declared in `src/grove.env.sh`. three
independent reasons they were wrong:

1. **they were synonyms.** both bodies were the identical text
   `[[ "$GROVE_ENV_SERVER" == "local@unix" ]]`. two names, one test — precisely
   `rule.forbid.domain-term-synonyms`.

2. **each name asserted a fact it could not check.** `has_screen` reads a string; it cannot see a
   display. on a `local@cicd` runner — local tier, no display — it answered **yes**. and that exact
   case was cited *in the same file* as the reason the predicate existed. a predicate whose name
   claims more than its body tests is worse than no predicate, because a reader trusts the name.

3. **they existed only to be PASSED** to an `--applies <fn>` dispatch. an early return needs no
   argument, so a named predicate has no caller left.

### 2. `--applies <fn>` / `--holds` dispatch flags — REMOVED

applicability passed to a dispatcher puts the condition somewhere other than beside the reason for
it. an early return in the body keeps the two together, which is the only place a reader will find
them both.

### 3. the `any|local|cloud` tag — REMOVED

a two-valued tag cannot express the fact a step depends on, and it gets `local@cicd` wrong: local
tier, no screen, no human. worse, a tag is a **claim held by the caller**, so a step's applicability
lived in a file that knew no fact about the step.

## .how to write a legitimate decline

the bar is an **articulated reason THIS MACHINE cannot hold the bundle** — not that it would be
unused there.

```sh
grove_provision_5_9_yubikey() {
  ####################################################################
  # a yubikey is a usb device physically inserted by a hand. a cloud box has no
  # usb bus a human can reach, so the agent would hold a socket no key can ever
  # answer on — and its verify would fail on every run, forever
  ####################################################################
  [[ "$GROVE_ENV_SERVER" == local@* ]] || return 0
  ...
}
```

the test to apply, in order:

1. **can the machine HOLD it?** (does the install succeed, does the file land?) → if yes, no decline
2. **would a decline cost a capacity?** (`kitten` on a grove, terminfo on a grove) → if yes, no decline
3. **is the constraint one LINE, not the bundle?** (`xdg-settings` needs a desktop) → then that line
   tolerates its own failure and says why; the bundle still applies
4. only if all three fail: decline, with the reason written above the early return

## .the one-line exception, spelled out

a bundle often has a single step that a machine cannot complete. that does **not** license a
decline. the line handles itself:

```sh
# a headless box has no desktop to register a default with, so this line cannot
# take there — and that is not a failure of the bundle
xdg-settings set default-web-browser org.mozilla.firefox.desktop \
  || echo "   🌙 no desktop to register a default browser with" >&2
```

the report is a `🌙` (unproven / not applicable here), never a `✋`. a bundle that failed loudly on
every grove run would teach a reader to ignore its output, which is `rule.forbid.failhide` read from
the other side: **a false alarm is its own dishonesty.**

## .how a verify must handle it

a verify runs on both machines too, so a claim that only holds on one must be stated, not failed:

- the claim holds → `•  ... ✔`
- the claim is disproven → `✋`, with the fix (`rule.require.errors-name-the-fix`)
- the claim **cannot be observed here** → `🌙`, and return 0

`1.1.keybinds/configure.verify.sh` is the reference: it asserts the conf's declared lines on every
box, and reports with a `🌙` that whether the kernel DELIVERS ctrl needs a key event, so it needs an
interactive tty and a human hand.

## .the test

> could this machine HOLD this bundle — install its packages, land its files?

- yes → it applies. no gate, no exception, no matter how unused it would be there
- no, and the reason is written above the early return → a legitimate decline
- no, but the reason is only "it would be unused here" → **blocker**

## .enforcement

- a bundle that declines with no articulated reason in its header = **blocker**
- a decline whose reason is "unused here" / "no effect here" rather than "cannot be held here" = **blocker**
- a `grove_env_has_*` predicate, an `--applies <fn>` argument, or an `any|local|cloud` tag,
  anywhere = **blocker**
- an applicability decision in a PARENT bundle or in the root dispatch = **blocker** (only the
  bundle that owns the claim may decline; `rule.require.grove-provision-bundles`)
- an applicability decision smuggled into the package boundary — an `install_env.pkg.sh` name map
  that translates a package to `""` on one machine — = **blocker**. that is a claim about a screen,
  hidden in a file whose whole job is to translate package names
- a bundle that fails (`✋`) rather than reports (`🌙`) for a step this machine cannot complete = **blocker**

## .see also

- `rule.require.grove-provision-bundles` — the tree, and why a claim belongs to its own bundle
- `rule.require.bundle-as-sole-declaration` — one declaration per concern, in its own dir
- `rule.forbid.domain-term-synonyms` — the rule the two `has_*` predicates broke
- `rule.forbid.failhide` — why a decline reports rather than passes silently, and why a false
  alarm is the same defect mirrored
- `rule.require.errors-name-the-fix` — what a real failure must carry
- `rule.require.conform-to-sdk-environment` — `$server` is the one derived reading a decline may test

# rule.forbid.tty-as-a-proxy-for-a-human

## .what

never test for a tty to decide whether a human is present. a tty answers *is there a terminal
attached*, which is a different question, and the two part company exactly where it costs most.

test the **declared intent** instead — in this repo, `--for cloud|local`
(`term=grove.provision.for`), which exists precisely to say whether a human is present.

## .why

a tty probe (`[[ ! -t 0 ]]`, `[[ -t 1 ]]`, `test -t 0`) reads as a human-presence check and is
not one. several things attach a tty with no human behind it:

| carrier | has a tty | has a human |
|---------|-----------|-------------|
| a duct (tmux pane, headless) | **yes** | no |
| `ssh -t host cmd` | **yes** | no |
| a ci runner with a pty allocator | **yes** | no |
| an expect/pty test harness | **yes** | no |
| a plain `ssh host cmd` | no | no |
| a human at a laptop | yes | **yes** |

the probe is right only in the last two rows. every row between is a false positive, and each
one is a headless machine that the probe declares humanned.

## .the general shape

this is one instance of a wider defect: **inferred state, where declared state was available.**

- a tty infers a human → `--for` declares one
- a hostname infers an environment → an env flag declares one
- a file's presence infers a mode → a mode flag declares one

an inference is a guess with a plausible reason, which makes it durable and dangerous: it
holds on the machine you test and fails on the one you do not. where a contract already
carries the answer, to infer it is to build a second, worse source of truth.

**the test:** does a flag, env var, or config already state this? then read it. only infer what
nobody declared.

## .the conjunction, not either half

a gate before a prompt needs BOTH the tier (`GROVE_ENV_SERVER`, which says a human COULD be
here) and the tty (which says one IS here right now):

```sh
[[ "${GROVE_ENV_SERVER:-}" == "local@unix" && -t 0 ]]   # may a prompt open?
```

six measured incidents shaped this rule — a tty with no tier, a tier with no tty, a rationale
offered as an exemption, a background run that removed the human whether it timed out or
succeeded, and a third-party tool (`git`) that opens `/dev/tty` directly and answers to nobody
but its own opt-out flag. full write-ups: `.refs = rule.forbid.tty-as-a-proxy-for-a-human.demo=incidents, m1-m6`.

## .the narrow, legitimate use of a tty probe

a tty probe is correct for questions genuinely ABOUT the terminal, because that is what it
measures:

- should output carry color / ansi escapes?
- should a progress spinner animate, or print one line per step?
- is the output width knowable (`tput cols`)?

these are presentation questions. use it there, and never to decide whether a human can answer.

## .enforcement

- a tty probe used to decide whether an interactive prompt may run = **blocker**
- a tty probe used to infer a human, environment, or machine kind where a flag declares it =
  **blocker**
- a command that can prompt, run in the background = **blocker** — the human is removed by
  construction, so the timeout is likely and proves no fact about the subject. ⚠️ this is a
  blocker on the ACT, so a background run that SUCCEEDS is a blocker too: it succeeded
  because a human chanced to be at the browser, which is luck rather than design
- a timeout on such a command, reported as a fact about the rack/box/credential = **blocker**
  (`rule.forbid.failhide`)
- a tty probe for presentation (color, spinner, width) = fine
- an exemption from this rule that offers a rationale rather than a testable trigger =
  **blocker** — write the probe instead (`rule.require.exemptions-name-their-trigger`)
- a gate before an interactive prompt that reads the TIER and not the tty = **blocker** —
  the tier says a human COULD be here, never that one IS. both conjuncts, always

## .see also

- `rule.forbid.tty-as-a-proxy-for-a-human.demo=incidents.md` — the six measurements this rule
  was cut from
- `term=grove.provision.for._.choice.reason.md` — the axis, and the boundary of what it answers
- `rule.require.errors-name-the-fix` — why the guard names `GH_TOKEN` rather than a bare refusal
- `howto.bootstrap-a-grove-from-scratch.md` — the trap as it appears in operation
- `plan.grove-credentials.md` — how a grove gets a token with no human

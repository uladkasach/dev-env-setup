# demo: tty-as-a-proxy-for-a-human — the incidents behind the rule

## .what

`rule.forbid.tty-as-a-proxy-for-a-human` states the rule in one line: read declared intent,
never a tty, to decide whether a human is present. this file holds every dated incident that
shaped it — each one a distinct way a tty probe (or its absence) let a prompt open with nobody
there to answer it.

## m1 — `gh auth login` opens on a duct with no human, the first incident

`install_gh_cli` guarded an interactive `gh auth login` on `[[ ! -t 0 ]]`:

```sh
if [[ ! -t 0 ]]; then   # 👎 the defect
  echo "no tty for an interactive login" >&2
  return 1
fi
gh auth login
```

it was tested over plain ssh, where it worked. then the grove image changed to ship tmux, so a
duct became the transport — and a tmux pane has a tty. the probe read `false`, the guard
passed, and `gh auth login` opened its prompt on a machine with no human.

the damage went past a hang: the prompt sat on the duct's stdin, so the next command sent to
that duct was consumed as the prompt's answer:

```
? Where do you use GitHub? tail -20 $HOME/grove.provision.2.log  [Use arrows to move, type to filter]
```

⇒ the fix reads the axis that already declares intent, `--for cloud|local`, not a tty guess at
presence:

```sh
if [[ "${FOR:-}" == "cloud" ]]; then   # 👍 intent, not inference
  echo "   ✋ gh is unauthed, and a --for cloud run has no human to answer a login" >&2
  echo "      fix: export GH_TOKEN=<a token that may read the orgs>" >&2
  return 1
fi
gh auth login
```

## m2 — a backgrounded prompt removes the human, from the CALLER's side, 2026-08-10

the same principle from the other end: an invoker that takes a human away.

`rhx keyrack unlock --owner ehmpath --env camp` opens an aws sso prompt in a browser. run with
`run_in_background`, no human ever saw it, so it burned its timeout and exited 2:

```
✋ keyrack unlock
   └─ aws sso login timed out
      ├─ status: blocked 🚫
      │  └─ human did not respond to browser sso prompt
      └─ robot: halt and escalate
         ├─ do not proceed
         ├─ do not find workarounds
         └─ do not skip credentials
```

the skill was correct in every particular. the defect was the transport chosen, unrelated to
the rack, the flags, or the box.

⇒ a command that needs a human is answerable only where a human can see it. to background it
is to guarantee the timeout, then read that timeout as a fact about the subject. never
`run_in_background` a command that can prompt — run it in the foreground, or hand it to the
human.

## m3 — the near-miss is worse than the timeout, 2026-08-13

the m2 run failed, so it taught at once. this one succeeded, which is more corrosive: the same
command was backgrounded again — in the very session the rule was under edit — and came back
green:

```
🔓 keyrack unlock ahbode.camp.AWS_PROFILE
   ├─ with sso prior?
   │  └─ ✗ clear, no prior session
   └─ ✓ authenticated as vlad
```

there was no warm session — it opened a fresh sso prompt, in a browser, on a machine where the
human happened to be sat at that moment. it did not work because the transport was sound; it
worked because a human was there to answer a prompt nobody had told them to expect.

⇒ a rule broken with no consequence is a rule half-unlearned. so the enforcement is on the ACT,
never the outcome: `run_in_background` on a promptable command is a blocker whether it times
out or succeeds — success is simply a cost that has not billed you yet.

### the read-trap that rode along

the same failed run also printed a different credential slug than this repo's consumers read
(`ahbode.camp.GITHUB_TOKEN` vs. the canonical `@all.camp.GITHUB_TOKEN`), so its "absent" tip
was inapt — a robot that acts on it would spend a real pat to fix a credential that was never
broken.

## m4 — an exemption that argued a rationale instead of a trigger, 2026-08-12

worse than a probe written in ignorance: `pkg_can_sudo` cited this rule, by name, then argued
its way to an exemption.

```sh
pkg_can_sudo() {
  sudo -n true 2>/dev/null && return 0
  [[ -t 0 ]] && return 0        # 👎 the defect
  return 1
}
```

its header block ran: *"a tty test is correct HERE… `can sudo read a password?` is answered by
a tty because a tty is the literal mechanism sudo uses… so a false read is impossible rather
than merely unlikely"* — well made, cites the right rule, and wrong on one word. a tty says
whether sudo can ASK. the fact worth a read is whether anyone will REPLY. those are two
questions.

on `grove-ahbode-v20260811`'s camper seat, reached by this repo's own transport, the probe
answered yes. every box-wide upsert would have reached for root, sudo would have prompted onto
the pane, and the prompt would have eaten the next command sent — the `gh auth login` incident
(m1), reproduced exactly, by the function written to prevent it.

no argument found it. a probe did, on its first run:

```
🔭 prove.root-decline-bites
   ├─ seat: camper
   ├─ sudo: this seat holds none without a password
   ├─ bundle.root.owns → rc=0        ← waved through
```

⚠️ a full apply could not have found it either: on a converged box every upsert reads its fact
first, finds it true, and returns before privilege is consulted — so the camper's apply was
clean, twice, with this defect live the whole time.

⇒ an exemption that offers a RATIONALE cannot be tested. an exemption that states a TRIGGER
can. the moment you reach for *"this rule does not apply here because…"*, write the probe
instead — a real exemption goes green; a false one gives you evidence.

the repair reads the tier, which DECLARES the human:

```sh
[[ "${GROVE_ENV_SERVER:-}" == "local@unix" && -t 0 ]] && return 0
```

`local@unix` is the one tier with a human at a keyboard; `local@cicd` has a runner and
`cloud@aws.ec2` has a duct — the same move as `--for cloud` in m1: read the declared axis, let
the tty narrow it rather than decide it.

## m5 — the mirror: a gate with the tier and NO tty, 2026-08-13

the exact mirror of every instance above, found in the sweep that followed m4's repair:

```sh
# 5.15.identity/configure.upsert.sh — the gate before a `read -rp`
if [[ "$GROVE_ENV_SERVER" != "local@unix" ]]; then   # 👎 tier, and no tty
  … decline …
fi
read -rp "   git user.email …" email
```

its header argues carefully, and correctly, for why the tier must be read and the test must
fail closed — and stops one conjunct short: the tier says *this is the kind of box a human
sits at*. it does not say a human sits at it right now. a laptop is `local@unix` whether the
run came from a keyboard, a cron, a systemd unit, or a detached job.

what it costs turns on stdin: `/dev/null` (a systemd unit) returns empty at once, so the ✋
below catches it with the wrong named cause; a pipe held open makes `read -rp` block forever,
in a background run nobody watches; a real terminal works, which is the case anyone tests.

three more sites carried the same shape the same day:

| site | read the tier | read the tty | fails |
|---|---|---|---|
| `pkg_can_sudo` (m4, 2026-08-12) | no | yes | **open** on a duct — a tmux pane has a tty |
| `5.15.identity` (2026-08-13) | yes | no | **open** on a laptop cron — the tier is right and no one is there |
| `5.4.gh` (2026-08-13) | yes | no | **open** — `gh auth login` blocks; this rule's own first incident, on a laptop |
| `2.3.ssh` (2026-08-13) | yes | no | **open** — `ssh-keygen` leaves the passphrase question deliberately unanswered |

⇒ neither half is the answer; the conjunction is. the tier is load-bear because a tty proves
no human. the tty is load-bear because a tier proves no presence. a gate that carries one and
argues well for it reads as considered, and is half a gate:

```sh
# the shape every site now holds
[[ "${GROVE_ENV_SERVER:-}" == "local@unix" && -t 0 ]]   # may a prompt open?
```

### the third case is a THIRD answer, not the headless branch

`2.3.ssh` shows why the tty conjunct is not a mechanical edit. its gate already had two arms,
and the obvious repair — let a no-tty laptop fall into the headless arm — is wrong:

| box | tty | right answer |
|---|---|---|
| a grove | — | generate a passphrase-less key; the box is the identity, revoked at the remote |
| a laptop | yes | prompt, so the human sets a passphrase |
| a laptop | **no** | **✋ halt** — neither of the above |

the headless arm makes an unprotected key. on a grove that is the design; on a laptop it is a
security downgrade the human never chose, applied silently by a background run on a machine
that also holds their own keys.

⚠️ note where the mirrors were found: in a sweep for the FIRST defect's shape. a search for
`-t 0` finds a site that has one; a site with a tier and no tty matches no such grep. every
later instance is invisible to the search the first one motivates — sweep for the DECISION
(*"what opens a prompt here?"*), never for the symptom.

## m6 — a third party makes the tty judgment for you: git, 2026-08-15

every instance above is a decision this repo makes. git makes this one on your behalf, and
cannot be talked out of it: **git opens `/dev/tty` directly for a credential prompt.** it does
not read stdin, so none of the shapes that look like a fix are one:

| shape | stops the ask? | why |
|---|---|---|
| `GIT_TERMINAL_PROMPT=0` | **YES** | git's own contract — dies with `terminal prompts disabled` |
| `</dev/null` | NO | git never consults stdin for a credential |
| a pipe into the command | NO | same |
| `[[ -t 0 ]]` around the call | NO | this rule's whole subject: a pane HAS a tty |

so on a duct, `git fetch` with an unanswerable credential is a hang, not a failure — the ask
sits on the pane and eats every command sent after it. measured on
`grove-ahbode-v20260811`: the credential helper declined (its normal, designed outcome), and

```
camper@…:~$ { zsh -ic git -C $HOME/git/ahbode/svc-chat fetch origin main }
Username for 'https://github.com/ahbode/svc-chat.git':
```

the duct held there until it was rebooted; `git.grove.provision test` step 1 never returned.

⇒ a tty probe of your own is a decision you can fix. a third-party tool that probes the tty
itself is a decision you can only pre-empt — with the opt-out that tool publishes, on the
call, every time. three now live in this repo:

| tool | it asks by | the opt-out |
|---|---|---|
| `sudo` | `/dev/tty` | `sudo -n`, or a decline-gate above it |
| apt / needrestart | a menu on stdout | `DEBIAN_FRONTEND`, `NEEDRESTART_MODE` (`PKG_APT_ENV`) |
| git | `/dev/tty` | `GIT_TERMINAL_PROMPT=0` |

clamped by `prove.git-never-prompts`, whose fixture holds an arm for the `</dev/null` shape
specifically — a reader that spared it would go green over the exact wedge.

## .see also

- `rule.forbid.tty-as-a-proxy-for-a-human.md` — the rule these incidents shaped
- `rule.require.exemptions-name-their-trigger` — m4's shape: a rationale cannot be tested
- `rule.forbid.failhide` — m2/m3: a timeout or a lucky success, reported as a fact about the
  subject, is a failhide either way

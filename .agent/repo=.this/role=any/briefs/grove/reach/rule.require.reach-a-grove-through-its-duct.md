# rule.require.reach-a-grove-through-its-duct

## .what

every command you send to a grove goes through a `git.grove.*` skill. never a raw
`ssh <grove> "<cmd>"` at the prompt.

| you want to | use |
|-------------|-----|
| run a command there | `rhx git.grove.send <grove> --what '<cmd>'` |
| run several commands there | `rhx git.grove.send <grove> --play <name>` |
| see what it holds | `rhx git.grove.read <grove> --lines N` |
| move content there | `rhx git.grove.push <grove> --from … --into …` |
| move content back | `rhx git.grove.pull <grove> --from … --into …` |
| make it reachable | `rhx git.grove.wake <grove>` |
| take it down | `rhx git.grove.stop <grove> --how hibernate\|halt` |

this is the grove-shaped case of `rule.require.wrap-cli-in-skills`, and it is stated
separately because that rule's examples are all `aws` — a reader looked straight past it
while they typed `ssh`.

## .why

`term=duct._.choice._.md` already carries the core of it:

> an ad-hoc `ssh <host> "<cmd>"` does the same work once and keeps none of it: no
> scrollback, no survival across disconnect, no `--play` review of what was sent.
> **a duct is not a fallback for when a local tool is unavailable — it is the verification
> surface this repo is built to have.**

concretely, a raw ssh forfeits five guarantees the skills hold:

1. **scrollback** — a duct keeps what it was sent. an ssh one-shot leaves no trace to read
   back, so a later question has to re-run the work
2. **survival** — close the laptop, the duct lives on. an ssh dies with its socket
3. **the busy guard** — `duct.send` refuses a duct that a non-shell holds, so a command
   cannot be typed into a live `apt` or an `rm -i` prompt (`term=duct.idle`)
4. **review before it lands** — `--play` is a reviewed file; a chained one-liner is not
   (`git.grove.send` refuses `;`/`&&`/`||` in `--what` for exactly this)
5. **an error that names its fix** — a skill reports the cure; ssh reports
   `Connection refused` and stops

## .the trap — CLOSED 2026-07-30

`ssh grove-1` used to sit in the pre-approved Bash allowlist as a **prefix** match. a raw
`ssh grove-1 "<cmd>"` sailed through the permission hook with no prompt at all.

it is now **denied**. `.claude/settings.json` carries `Bash(ssh:*)` in its `deny` list; the
`Bash(ssh grove-1:*)` allow was removed from `settings.local.json`. deny outranks allow, so a
raw ssh is refused at the hook rather than merely discouraged in prose.

**.why the ban is safe for the skills** — the hook evaluates only the **outer** command
string (`rule.require.wrap-cli-in-skills`). `git.grove.send` is invoked as
`rhx git.grove.send …`; its inner ssh rides inside ductwork where the hook never looks. the
skills are unaffected — only a human-typed ssh is stopped.

**.why the ban is safe to make total** (`ssh:*`, not just `ssh grove-1`) — this rule already
states it: *"there is no case that calls for raw ssh at the prompt."* the one exemption is
`git.grove.send --bare --why '…'`, which is still a skill.

### the lesson that outlived the trap

**an allowlist is a floor under danger, not a limit on practice.** when the two disagree,
the rule wins — and where a rule and an allowlist can disagree, the allowlist should be
amended so they cannot. prose alone did not hold: see the two occurrences below.

## .the one exemption, and it is still a skill

a fresh grove has no tmux, so it cannot hold a duct yet. that case is
`rhx git.grove.send <grove> --bare --why '<reason>'` — which is still the skill, and which
*demands* the `--why` so the bypass is on the record.

there is no case that calls for raw ssh at the prompt.

## .examples

### 👎 bad — raw, unlogged, and mute on failure

```sh
ssh grove-1 "gh auth status"
# → ssh: connect to host localhost port 36901: Connection refused
# which port? whose tunnel? is the box down or the forward dead? no hint given.
```

### 👍 good — through the duct

```sh
rhx git.grove.send grove-1 --what 'gh auth status' --await 60
rhx git.grove.read grove-1 --lines 14
# 🔭 duct://grove-1:main (cloud)
# camper@ip-<private-ip>:~$ gh auth status
# You are not logged into any GitHub hosts. To log in, run: gh auth login
```

the second form leaves the answer in the duct, so the next reader finds it without a
re-run.

## .what a raw ssh has cost

⚠️ **a rule that lives only in prose competes with convenience, and convenience wins.** that
is why the ban is now a `deny` entry rather than another paragraph.

**the lesson**: a bypass is never a single bypass. it takes with it every guard downstream of
the surface it skipped.

.refs = rule.require.reach-a-grove-through-its-duct.demo=raw-ssh-cost-twice, m1, m2

## .enforcement

- a raw `ssh <grove> "<cmd>"` at the prompt where a `git.grove.*` skill applies = **blocker**
- a chained one-liner smuggled past `--what` by way of raw ssh = **blocker**
- a `--bare` send with no `--why` = **blocker** (the skill already refuses it)

## .see also

- `rule.require.reach-a-grove-through-its-duct.demo=raw-ssh-cost-twice` — the two dated
  incidents that moved this ban from prose to a `deny` entry
- `term=duct._.choice._.md` — why the word is `duct`, not `ssh`
- `term=duct.idle._.choice.reason.md` — the busy guard a raw ssh has no version of
- `rule.require.wrap-cli-in-skills` — the general rule this specializes
- `rule.require.wake-the-grove-freely` — the prior authorization to run `grove.wake`
- `howto.headless-terminal-streams.md` — how a duct is built

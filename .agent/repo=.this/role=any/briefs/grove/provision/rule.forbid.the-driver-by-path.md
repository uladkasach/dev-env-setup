# rule.forbid.the-driver-by-path

## 🛑 .the rule, in one line

# **NEVER `bash …/grove.provision._.sh`. THE DRIVER IS REACHED THROUGH `rhx`, ALWAYS.**

| you want to converge… | you type |
|---|---|
| the box you are standing on | `rhx grove.provision [--from tree\|main] [--what <slug>] --mode apply` |
| a grove you reach over a duct | `rhx git.grove.provision boot <name> --mode apply` |

no `bash <path>`. no `sh <path>`. no `source <path> && <fn>`. no `cd src && ./…`.
whatever the flags, the invocation begins with `rhx`.

## .why the PATH form is a defect, and not merely a style

`rule.require.grove-provision-as-the-only-entrypoint` says `grove.provision._.sh` is the one
DRIVER, and that is still true — this rule changes none of it. it bans the **invocation
surface**, which is a different axis:

| axis | the answer |
|---|---|
| what DRIVES the inventory | `src/grove.provision._.sh` — one driver, unchanged |
| how a human or agent REACHES it | `rhx`, and no other way |

four costs, in order of how often each has bitten:

1. **it reads from whatever dir you happen to stand in.** `bash src/…` is relative, so it
   silently drives the checkout your shell is cwd'd into. `rhx grove.provision` names the
   checkout with `--from tree|main` and prints which one it took. a converge against the
   wrong checkout looks identical to one against the right one.
2. **it bypasses the `--from` axis entirely**, which is the whole reason a branch is testable
   before it merges. the path form can only ever drive the tree it is typed inside.
3. **it is un-gateable.** a permission rule, a hook, or an audit can key on `rhx <slug>`; it
   cannot key on an arbitrary `bash <some path>`, because that is the shape of every shell
   invocation in existence. one surface is one thing to allow, deny, or count.
4. **it teaches by example.** every fix-text, howto, and worked example a reader copies is the
   form they will use next time. the path form was written into ~140 files, so it was the form
   the repo taught — and `rule.require.install-via-procedures` names exactly this: an example
   contradicting its own rule teaches the opposite, with the rule's authority behind it.

⚠️ **and this rule's own parent modeled the violation.** `rule.require.grove-provision-as-the-only-entrypoint`
carried a row reading *"upgrade this machine → `bash …/grove.provision._.sh`"* in its `.the rule`
table. the rule that declares the one door named the wrong handle.

⚠️ **and that quote carries an ellipsis on purpose.** to cite the dead form verbatim is to
re-create it — a reader copies the headline and gets the banned command, with this rule's own
authority behind it. so the convention is: **a path that carries `…` is prose; a path a reader
could paste is a call.** `prove.the-driver-is-never-named-by-path` reads that difference, and it
reddened THIS file on 2026-09-07 for the very sentence above.

## ⚠️ .the FOUR carve-outs, and why each is real

| # | site | why the path form survives |
|---|---|---|
| 1 | `git.grove.provision.boot.sh` — its `UPGRADE` string | it is sent to a **bare** box. on a first apply the repo is present and `rhx` is not installed at all; there is no skill to call |
| 2 | `git.grove.auth.github.set.sh` — its `PROVE_ONE_BUNDLE` string | the send is a `bash -lc`, which reads no `.zshrc`, so `rhx` is not on PATH on the far side (`gotcha.a-tool-found-by-path-answers-only-a-human`, rung 4) |
| 3 | a **ONE-BUNDLE apply on a grove**, sent over a duct | a grove's `rhx` runs and resolves **no repo skill**. this is the routine way a change reaches a grove |
| 4 | `git.grove.auth.keys.set.sh` — the fix-text under its `rhx does not run` rung | the rung ahead of it PROVED `rhx` does not run on that box, so `rhx grove.provision` is the very surface reported broken. the send re-applies `5.1.node`, which is what puts `rhx` there |

🛑 **carve-out 4 is measured, not assumed, and that is what makes it the tightest of the four.**
1 and 2 assert their far side's reach from the shape of the send; 4 reaches its line ONLY on the
false branch of a probe that asked. ⇒ where a carve-out CAN be earned by a probe rather than
claimed by a comment, that is the form to prefer — a claimed trigger goes stale in silence, and a
probed one cannot.

⇒ the discriminator is **which BOX the command lands on**:

> on a box where `rhx` resolves the skill, the path form is a blocker — no exception.
> on a box where it does not, the path form is the only form there is.

⚠️ **that sentence replaced *"a skill may; a human never may"*, and the swap is the point.**
carve-outs 1 and 2 are both skills, so the typist looked like the discriminator. the
discriminator is whether the FAR SIDE's `rhx` resolves the skill — and carve-out 3 is a human
at a keyboard against a far side that cannot.

⚠️ each carve-out must state its trigger inline, beside the string
(`rule.require.exemptions-name-their-trigger`). a fifth site that copies the shape without the
reason is a violation, not a carve-out — and it will look identical.

### 🛑 carve-out 3, measured 2026-09-07

a `4.5.nvim` change was owed to two groves. the sanctioned form was sent over the duct and
answered:

```
BadRequestError: no skill "grove.provision" found in any linked role
tip: did you `npx rhachet roles link` the --role this skill comes from?
```

`rhx` itself RAN, so this is **not** `gotcha.a-tool-found-by-path-answers-only-a-human` — that
one is about PATH. this is the rhachet ROLE LINK, a different link entirely, and **no bundle
links roles on a grove**:

```sh
rhx grepsafe --pattern 'roles link' --glob 'src/**/*.sh'   # → 0 matches
```

⇒ so a grove is DESIGNED with its repo skills out of reach, rather than drifted into it. the
path form is not a shortcut there; it is the only door — and carve-outs 1 and 2 already lean on
exactly that fact.

⚠️ **what the over-tight draft cost, before this carve-out was written.** the rule read as a
flat ban, so the next move looked like `rule.forbid.adhoc-shell`'s *"an absent skill is the
defect to fix"* — and a whole `git.grove.provision drive` verb was half-written for an operation
the human does routinely. the human stopped it: *"why do you need to drive one on the grove?
just apply the bundle against the grove. its done all the time."*

⇒ **an over-tight rule buys a build, never a fix.** where a rule seems to forbid a routine
operation, the likelier read is that the rule's SCOPE is wrong.

### the routine form

```sh
rhx git.grove.push <seat> --from . --into git/more/dev-env-setup --mode apply
rhx git.grove.send <seat> --reply --within 900 \
  --what 'bash $HOME/git/more/dev-env-setup/src/grove.provision._.sh --what <slug> --mode apply'
```

ground first, then the camper (`rule.require.one-command-provision`). `--reply` carries the
driver's own exit code, and 97 means the duct gave no answer at all
(`gotcha.the-duct-returns-the-send-not-the-answer`).

⚠️ this converges ONE bundle and gates no box. a grove is RAISED by
`rhx git.grove.provision boot <name> --mode apply`, which still holds every clause above.

## .the forwarder is not a third entrypoint

`rhx grove.provision` holds no bundle of its own. it adds exactly one axis (`--from`), forwards
every other flag unenumerated, and `bash`es the driver. that is what
`rule.require.grove-provision-as-the-only-entrypoint` calls a legitimate forwarder, and it is
the ONE forwarder this repo has. so the ban costs no capability: every flag the driver grows
works through the skill on the day it lands.

## .the test

> **does this line start with `rhx`?**

- yes → correct
- no, and it lands on a box whose `rhx` resolves no repo skill, with the trigger stated
  inline → a carve-out
- no, otherwise → a blocker, and the fix is a one-for-one substitution

⚠️ the second arm asks whether the FAR SIDE's `rhx` resolves the skill, never who typed the
line. a grove qualifies; this machine never does.

## .enforcement

- `bash|sh|source <any path that ends in grove.provision._.sh>` aimed at a box whose `rhx`
  resolves the skill — a howto, a brief, a fix-text, a readme, a comment, or a command a human
  is handed = **blocker**
- the same, typed by an agent at a shell against THIS machine = **blocker**
- a fifth carve-out added with no trigger stated inline = **blocker**
- a NEW SKILL written to wrap a carve-out 3 send = **blocker**; the human does this routinely,
  and a wrapper adds a component while the far side still resolves no skill
- a carve-out whose trigger no longer holds — `rhx` IS reachable on that far side — kept anyway
  = **blocker** (`rule.forbid.exemption-as-habit`)
- a NEW forwarder beside `rhx grove.provision` = **blocker**, under the parent rule; this rule
  forbids the path, that one forbids the second door

## .see also

- `rule.require.grove-provision-as-the-only-entrypoint` — the one DRIVER; this rule is the one SURFACE
- `rule.require.invoke-rhx-by-its-bare-name` — how the `rhx` call itself is written
- `rule.require.install-via-procedures` — never hand a human a one-off command
- `rule.require.one-command-provision` — what the one command must achieve
- `gotcha.a-tool-found-by-path-answers-only-a-human` — why carve-out 2 exists. ⚠️ it is about
  PATH; carve-out 3 is about the rhachet ROLE LINK, which is a different link
- `rule.forbid.adhoc-shell` — its *"entool it"* mandate, and the one case where that mandate
  misfires: an operation the human already does routinely (carve-out 3)

# rule.forbid.the-driver-by-path

## 🛑 .the rule, in one line

# **NEVER `bash src/grove.provision._.sh`. THE DRIVER IS REACHED THROUGH `rhx`, ALWAYS.**

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
carried a row reading *"upgrade this machine → `bash src/grove.provision._.sh`"* in its `.the rule`
table. the rule that declares the one door named the wrong handle.

## ⚠️ .the TWO carve-outs, and why each is real

both are a **skill that owns the drive**, sending the command to a box where `rhx` cannot be
reached. neither is ever a line a human types.

| # | site | why the path form survives |
|---|---|---|
| 1 | `git.grove.provision.boot.sh` — its `UPGRADE` string | it is sent to a **bare** box. on a first apply the repo is present and `rhx` is not installed at all; there is no skill to call |
| 2 | `git.grove.auth.github.set.sh` — its `PROVE_ONE_BUNDLE` string | the send is a `bash -lc`, which reads no `.zshrc`, so `rhx` is not on PATH on the far side (`gotcha.a-tool-found-by-path-answers-only-a-human`, rung 4) |

⇒ the discriminator is **who types it**, never how it looks:

> a **skill** that owns the drive may name the driver by path, when the far side cannot find
> `rhx`. a **human or an agent at a keyboard** never may.

⚠️ each carve-out must state its trigger inline, beside the string
(`rule.require.exemptions-name-their-trigger`). a third site that copies the shape without the
reason is a violation, not a carve-out — and it will look identical.

## .the forwarder is not a third entrypoint

`rhx grove.provision` holds no bundle of its own. it adds exactly one axis (`--from`), forwards
every other flag unenumerated, and `bash`es the driver. that is what
`rule.require.grove-provision-as-the-only-entrypoint` calls a legitimate forwarder, and it is
the ONE forwarder this repo has. so the ban costs no capability: every flag the driver grows
works through the skill on the day it lands.

## .the test

> **does this line start with `rhx`?**

- yes → correct
- no, and it is a skill that sends to a box where `rhx` is unreachable, with the trigger stated
  inline → a carve-out
- no, otherwise → a blocker, and the fix is a one-for-one substitution

## .enforcement

- `bash|sh|source <any path ending in grove.provision._.sh>` in a howto, a brief, a fix-text,
  a readme, a comment, or a command a human is handed = **blocker**
- the same, typed by an agent at a shell = **blocker**
- a third carve-out added with no trigger stated inline = **blocker**
- a carve-out whose trigger no longer holds — `rhx` IS reachable on that far side — kept anyway
  = **blocker** (`rule.forbid.exemption-as-habit`)
- a NEW forwarder beside `rhx grove.provision` = **blocker**, under the parent rule; this rule
  forbids the path, that one forbids the second door

## .see also

- `rule.require.grove-provision-as-the-only-entrypoint` — the one DRIVER; this rule is the one SURFACE
- `rule.require.invoke-rhx-by-its-bare-name` — how the `rhx` call itself is written
- `rule.require.install-via-procedures` — never hand a human a one-off command
- `rule.require.one-command-provision` — what the one command must achieve
- `gotcha.a-tool-found-by-path-answers-only-a-human` — why carve-out 2 exists

# rule.require.brain-config-has-one-home

> was `rule.require.brain-configs-via-repo`. that name covered ONE of the two axes below, and
> every command in its body had been deleted.

## 🛑 .the rule, in one line

# **EVERY ROBOT-BRAIN CONFIG KNOB IS DECLARED IN `5.3.brains`, AND NOWHERE ELSE.**

one bundle. one artifact per knob. no shell export in `2.5.zsh`, no export in `2.7.aliases`, no
hand-edit on the box.

## .the two axes, and each needs the other

| axis | the claim | the rule it instances |
|---|---|---|
| **repo, not machine** | the repo declares it; a hand-edit on the box is lost | `rule.require.repo-as-source-of-truth` |
| **one bundle, not three** | `5.3.brains` declares it; a peer bundle may not | `rule.forbid.two-writers-on-one-artifact` |

⚠️ axis 1 alone is what the prior rule carried, and it is **satisfiable by a mess**: four bundles
can each declare a knob, every one of them in the repo, every one reproducible — and the set still
drifts. a knob in the repo twice is a knob with two answers.

## .what counts as a brain-config knob

- a key in `~/.claude/settings.json` — `model`, `effortLevel`, `permissions`, `env.*`
- an env var claude, codex, or rhachet reads for its own behavior
- codex and rhachet global config, by the same argument

**not** a brain-config knob: a shell FUNCTION that wraps a brain (`claude()`, `brains.auth.sh`).
a function is a shell surface and belongs to the shell bundle — see the carve-out below.

## 🛑 .the shelf is `settings.json` unless a READ SITE forbids it

the seductive split is *"settings keys in `5.3.brains`, env vars in the shell."* it is wrong, and
the source says so:

```js
function zd(){ Object.assign(process.env, Nh6(j8().env)),
               Object.assign(process.env, Nh6(J7()?.env)), … }
```

`zd()` applies the settings `env` block into `process.env` **unfiltered**, at startup. so any flag
read after startup — which is nearly all of them — is reachable from `settings.json`.

⇒ 🔴 **and claude's own migration agrees.** `RtK()` writes `env.DISABLE_AUTOUPDATER` **into**
userSettings. anthropic put that flag on the settings shelf themselves; a shell export beside it is
a second writer this repo added.

### the ONE test that earns a shell export

> **find the READ SITE. does it run before `zd()`?**

- after → `settings.json`, in `5.3.brains`. no exception
- before → a shell export is physically required, and it **still belongs to `5.3.brains`**, which
  writes its own rc fragment. it does not belong to `2.5.zsh`
- 🔴 **no read site at all** → the flag is DEAD. delete it; do not rehome it

⚠️ *"the settings env block is read too late"* is a **claim, not a measurement.** it sat in
`zshrc.sh` on two exports, with no read site cited, and the source contradicted both.

## 🛑 .a knob with NO writer is the defect a tidy page hides

`~/.claude/settings.json` has **three** writers: this repo, a human, and **claude itself**. the
upsert deep-merges, so a key a human placed by hand survives every apply and **reaches no other
box** — green here, absent on a fresh grove, and no verify can see it, because a verify reads only
the rows the repo DECLARES.

⇒ when you touch this file, diff the LIVE keys against the DECLARED set. a key the box holds and
the repo does not is owed a decision: adopt it, or remove it.

## .the carve-out — a FUNCTION is a shell surface

`claude()` stays in `2.7.aliases`. it is a shell function: it looks up a binary, wraps a cgroup
scope, and is meaningful only to an interactive shell. no settings key can express it.

the line: **a VALUE the brain reads is config, and `5.3.brains` owns it. a FUNCTION a human types
is a shell surface, and the shell bundle owns it.**

## .how to change a knob

1. edit the `patch` in `5.3.brains/configure.upsert.sh`
2. edit the paired row in `configure.verify.sh`, or the verify reddens
3. `rhx grove.provision --what 5.3.brains --mode apply`

## .enforcement

- a brain-config knob declared outside `5.3.brains` = **blocker**
- one knob declared in two bundles = **blocker**, even where both agree today
- a shell export for a flag whose read site runs AFTER `zd()` = **blocker**
- a flag with **no read site** in the pinned cli, kept = **blocker**; it is dead, and a verify on it
  is a false ✔ — true of the file, false of the effect
- a *"read too late"* justification with no read site cited = **blocker**
- a live settings key the repo declares not at all, left unowned = **blocker**; a fresh box gets none
- a hand-edit of `~/.claude/settings.json` with no matched repo change = **blocker**

## .see also

- `define.claude-code-config` — the keys, the resolution order, and what `gk6` really gates
- `rule.forbid.two-writers-on-one-artifact` — axis 2's parent
- `rule.require.repo-as-source-of-truth` — axis 1's parent
- `rule.require.bundle-as-sole-declaration` — why ONE bundle, stated for the tree at large
- `hazard.claude-shadowed-by-npm-global` — which `claude` binary a shell actually reaches

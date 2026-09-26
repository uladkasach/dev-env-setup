# define.claude-code-config

## .what

claude code's model + behavior config for this machine lives in the repo, and `5.3.brains`
converges it into `~/.claude/settings.json`. that file is the SOLE writer of every key below.

## .where

`src/grove.provision/5.devtools/5.3.brains/configure.upsert.sh` renders the patch;
`configure.verify.sh` asserts each key back, pair by pair.

| key | effect |
|-----|--------|
| `model` | the default model the `/model` panel shows |
| `env.ANTHROPIC_MODEL` | the default model the cli actually boots with |
| `effortLevel` | the default effort level (`low` \| `medium` \| `high`) |
| `env.CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` | the prompt-suggestion nag |
| `env.DISABLE_AUTOUPDATER` / `env.DISABLE_UPDATES` | pin the cli version |
| `cleanupPeriodDays` | transcript retention |

## 🛑 .the model is declared TWICE, and the two are not redundant

the cli picks a model from THREE places, in this order (`Ih()`, v2.1.87):

1. the session override — `/model`, or `--model` on the command line
2. `env.ANTHROPIC_MODEL`
3. `model`

⇒ **`ANTHROPIC_MODEL` outranks `model`.** a box that declares only the second runs whatever a
stale env var says, quietly. so both are declared, at one value.

⚠️ the env var does NOT pin the session — rung 1 still wins, so `/model` switches live exactly
as before. this sets the DEFAULT, never an upper bound.

## 🛑 .settings `env` OVERRIDES an inherited shell export

measured 2026-09-25: a shell that exported `ANTHROPIC_MODEL=claude-opus-5[1m]` produced a
session on `claude-opus-5-5[1m]`, because the settings `env` block is applied at startup
(`zd()`) **before** the model is picked.

⇒ so a shell export is not a second lever; it is a **silent loser**. `bash_aliases.sh` used to
carry one, and it had drifted a full version behind with no signal
(`rule.forbid.two-writers-on-one-artifact`).

## 🛑 .`gk6` is a TRUST list, NOT a permission list — the `env` block is applied UNFILTERED

this brief read *"`gk6` is the allowlist of env names a settings file may set"*. **that is false**, and
it is the more dangerous direction of wrong: it implies four keys this repo declares are inert, so a
reader who trusts it deletes config that works.

read `zd()`, the startup applier (v2.1.87):

```js
function zd(){ Object.assign(process.env, Nh6(j8().env)),
               Object.assign(process.env, Nh6(J7()?.env)), … }
```

**no filter.** every `env` key a settings file declares lands in `process.env`, on the list or off it.

`gk6` is consulted in exactly two shapes, and **both test for ABSENCE**:

| site | what it does |
|---|---|
| `Uk6()` | collects the env names **`!gk6.has(…)`** — i.e. the UNUSUAL ones |
| `LoK()` / `xoK()` | reports which settings files hold an unusual name, to feed the **`TrustDialog`** |

⇒ `gk6` is the set of env names that raise **no trust prompt**. an off-list name still applies; it
just marks the file as one a human should be asked about.

⚠️ measured 2026-09-25 against the 82-name set: `ANTHROPIC_MODEL`, `DISABLE_AUTOUPDATER`, and
`CLAUDE_CODE_SUBAGENT_MODEL` are **on**; `DISABLE_UPDATES`, `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION`,
and `CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK` are **off** — and all six are live.

📜 the false line was written here on 2026-09-25 from one session's read, and was cited the next day
as though the repo attested it (`gotcha.my-own-note-became-my-evidence`). a read of the two call
sites disproved it in one pass.

## ⚠️ .an unnamed settings key is stored and read by NOBODY

`~/.claude/settings.json` is zod-validated, and a key absent from the schema is kept in the
file and consulted by no caller. so a key that *looks* declared can be inert.

`effortLevel` IS in the schema — `enum(["low","medium","high"]).optional()` — which is why it
is safe to declare. ⚠️ `CLAUDE_CODE_EFFORT_LEVEL` overrules it for a whole session.

## .the model id format

the `[1m]` suffix is a context-window selector (1 million token context), appended to the base
model id. base id follows the `claude-opus-N-M` pattern.

## .how to change the default model

1. edit the `patch` line in `5.3.brains/configure.upsert.sh` — **both** `model` and
   `env.ANTHROPIC_MODEL`, at one value
2. edit the paired rows in `configure.verify.sh`, or the verify reddens
3. apply it:

```sh
rhx grove.provision --what 5.3.brains --mode apply
```

⚠️ a live session keeps the model it booted with. the change reaches the NEXT session.

## .why repo, not a hand-edit

per `rule.require.repo-as-source-of-truth`: the repo drives the config so a fresh machine
reproduces the same setup. a value hand-set in `~/.claude/settings.json` is overwritten by the
next apply and never reaches the next box.

## .gotcha

- a typo'd model id boots a dead default. confirm the id string is one the cli accepts before
  you apply.
- `CLAUDE_CODE_SUBAGENT_MODEL` is still a shell export in `bash_aliases.sh`, and is the sole
  writer of that name — it is NOT in this settings patch.

## .see also

- `hazard.claude-shadowed-by-npm-global` — which `claude` binary a shell actually reaches
- `rule.forbid.two-writers-on-one-artifact` — why the shell export was retired

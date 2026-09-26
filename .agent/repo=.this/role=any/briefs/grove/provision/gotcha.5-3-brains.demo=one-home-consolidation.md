# gotcha.5-3-brains.demo=one-home-consolidation

every measurement behind `rule.require.brain-config-has-one-home` and the reap in
`5.3.brains/configure.upsert.sh`. all taken 2026-09-25 against `cli.js` @ 2.1.87.

## m1 — the split: ONE brain's config, spread across THREE bundles

| flag | `2.5.zsh` | `2.7.aliases` | `5.3.brains` | refs in cli |
|---|---|---|---|---|
| `ANTHROPIC_MODEL` | — | ✔ export | ✔ settings | live |
| `DISABLE_AUTOUPDATER` | ✔ export | — | ✔ settings | 6 |
| `DISABLE_UPDATES` | ✔ export | — | ✔ settings | **0** |
| `DISABLE_INSTALLATION_CHECKS` | ✔ export | — | — | 3 |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | ✔ export | — | — | 1 |
| `CLAUDE_CODE_SUBAGENT_MODEL` | — | ✔ export | — | 1 |
| `CLAUDE_CODE_SKIP_UPDATE_CHECK` | — | ✔ export | — | **0** |
| `skipAutoPermissionPrompt` · `tui` · `CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK` | — | — | — | live |

three rows are the defects: **two writers** on rows 1-3, **no writer at all** on the last, and
**two flags with no read site** in the pinned cli.

⚠️ every one of these was in the repo. so `rule.require.repo-as-source-of-truth` was satisfied the
whole time — which is why the prior rule (`brain-configs-via-repo`) could not see this at all.

## m2 — `ANTHROPIC_MODEL`'s two writers had DRIFTED, and the drift was silent

`bash_aliases.sh` exported `claude-opus-5[1m]`; the settings patch declared `claude-opus-5-5[1m]`.
a live session ran on **`claude-opus-5-5[1m]`** — the settings value.

```js
function zd(){ Object.assign(process.env, Nh6(j8().env)),
               Object.assign(process.env, Nh6(J7()?.env)), … }
```

`zd()` runs at startup, before the model is picked, so the settings `env` block **overwrote** the
inherited shell export. ⇒ the stale copy was a **silent loser**: no error, no caution, and the wrong
value would have surfaced only if the settings copy were ever removed.

## m3 — 🔴 `gk6` is a TRUST list, and this repo recorded it as a PERMISSION list

`define.claude-code-config` and `configure.upsert.sh` both read *"`gk6` is the allowlist of env
names a settings file may set."* **false.** `zd()` above applies the block with **no filter**.

`gk6` is read in exactly two shapes, and both test for **absence**:

```js
Uk6(q): … for (let [z,A] of Object.entries(q.env)) … { if (!gk6.has(z.toUpperCase())) _[z]=A }
LoK(q): return Object.keys(q.env).some((K)=>!gk6.has(K.toUpperCase()))
```

`LoK` feeds `xoK`, which builds the file list for the **`TrustDialog`**. ⇒ `gk6` is the set of env
names that raise **no trust prompt**; an off-list name still applies.

of the 82 names: `ANTHROPIC_MODEL`, `DISABLE_AUTOUPDATER`, `CLAUDE_CODE_SUBAGENT_MODEL` are **on**.
`DISABLE_UPDATES`, `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION`,
`CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK` are **off** — and all six are live.

🛑 **the wrong direction is the expensive one.** the false claim implies three declared keys are
inert, so a reader who trusts it **deletes config that works**. it was written on 2026-09-25 from
one session's read, and cited the next day as though the repo attested it
(`gotcha.my-own-note-became-my-evidence`). two call sites disproved it in one pass.

## m4 — *"the settings env block is read too late"* was a guess, stated twice, and false

`zshrc.sh` carried `note: must be exported in shell — the settings.json env block is read too late`
on two exports. `configure.upsert.sh` carried the same claim about the installer nag, twice over.
**no site cited a read site.** the read sites:

| flag | read at | when |
|---|---|---|
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `et6()` | per turn |
| `DISABLE_AUTOUPDATER` | `j96()` | on the update check |
| `DISABLE_INSTALLATION_CHECKS` | `$w6()`, `kFz()` | behind a react effect |
| `CLAUDE_CODE_SUBAGENT_MODEL` | `Ik6()` | on subagent spawn |

every one is after `zd()`. ⇒ all four are reachable from `settings.json`.

🔴 **and claude's own migration settles the shelf question outright:**

```js
function RtK(){ … H7("userSettings",{...K, env:{...K.env, DISABLE_AUTOUPDATER:"1"}}),
                d("tengu_migrate_autoupdates_to_settings", …)
```

the cli **writes that key into userSettings itself**. so `settings.json` is anthropic's own choice of
shelf, and the shell export beside it was a second writer this repo added.

⇒ the shelf rule (*"match the shelf to WHEN the flag is read"*) was right; only its application was
wrong. **find the read site.** a *"read too late"* comment with no read site beside it is a guess,
and these two guesses bought a three-bundle split.

## m5 — 🔴 the REAP: a rule authored at 15:40 fired on the 15:52 apply

the consolidation dropped `DISABLE_UPDATES` from the patch. the live file held it afterward anyway:

```
"env": { "DISABLE_AUTOUPDATER": "1",
         "DISABLE_UPDATES": "1",          ← declared by NOBODY
         … }
```

`jq '. * $patch'` is a deep **merge**, so it only ever ADDS. a key retired from the patch is never
removed — the box converges to every key the repo has **ever** declared, never the set it declares
today. **provision defect shape 11**, and invisible by construction: a verify reads the DECLARED
rows, so an undeclared key has no row to redden.

⚠️ `rule.require.brain-config-has-one-home` names that exact state a blocker, and had been written
**twelve minutes earlier**. it is the cue `rule.always.catch-dreams-for-followups` calls the
sharpest — *a rule you just wrote fires on your very next action* — so it was fixed, not dreamt.

### why the reap names keys EXPLICITLY rather than reap every undeclared one

a blanket reap is the obvious shape and it is wrong here: the merge's **preserve** guarantee is
load-bear — it is what lets the repo adopt a value a human set by hand rather than revert it
(`configure.upsert.sh` states it twice). a blanket reap inverts that and destroys a human's own env
key.

⇒ so a key enters the reap list only once it is **proven dead** — zero read sites in the pinned cli
— which is precisely why a delete of it can harm no caller. a key that is live but merely **moved**
is retired by a change of value, never by a delete.

⚠️ and the filter is **one** `del(a, b)`, never a loop that builds it: an empty list would render
`del() | …`, a jq syntax error, so the shape must not depend on the count.

## m6 — the proof

| run | result |
|---|---|
| plan, before | ✋ `.effortLevel` reads null, want `"medium"` — declared the prior session, never applied |
| apply #1 | 11/11 → **16/16** green; every new key lands |
| apply #2 (reap's first) | `DISABLE_UPDATES` removed; live file == declared set exactly |
| apply #3 | idempotent — 16/16, `del` on an absent path is a no-op |
| `2.5.zsh` apply | `~/.zshrc` matches the checkout ✔, parses ✔ |
| `2.7.aliases` apply | alias suite present, current, parses (4 files) ✔ |
| live rc sweep | zero `CLAUDE*` / `ANTHROPIC*` / `DISABLE_*` exports across five rc files — every hit a comment |

## m7 — 🔴 *"disable_updates should be true"* — the INTENT holds; the KEY is not a knob

the ask came back a second time, and it deserves the enumeration rather than a grep, because a
zero-match is the one result whose cause is ambiguous (`gotcha.a-check-that-cries-wolf-gets-silenced`,
q11: a pattern reaches only the forms its author could see).

⇒ **every** ALLCAPS token that holds `UPDAT` in the 12.9 MB bundle, plus every `process.env.X` and
`process.env['X']` read: the only update-related env names that exist are `DISABLE_AUTOUPDATER`
(6 refs) and `FORCE_AUTOUPDATE_PLUGINS` (1). **`DISABLE_UPDATES` is absent in every form.**

the gate is `j96()`, and it has exactly three sources:

```js
function j96(){
  if (n6(process.env.DISABLE_AUTOUPDATER)) return {type:"env",envVar:"DISABLE_AUTOUPDATER"};
  let q = XX7(); if (q) return {type:"env",envVar:q};      // CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
  let K = j8();
  if (K.autoUpdates===!1 && (K.installMethod!=="native" || K.autoUpdatesProtectedForNative!==!0))
    return {type:"config"};
  return null }
```

| source | status |
|---|---|
| `DISABLE_AUTOUPDATER` | ✔ declared by `5.3.brains`, live in `~/.claude/settings.json` |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | a different concern; not reached for here |
| `j8().autoUpdates === false` | 🛑 **do not declare it** — `RtK()` strips both fields off config and writes the env var instead, so a repo that declared it would lose that writer fight every session |

⇒ so the ask is **already satisfied, and by a wider margin than it names**: `ED6()` is
`iB() && !FORCE_AUTOUPDATE_PLUGINS`, and `iB()` is `j96()!==null`, so the one key also suppresses
**plugin** auto-updates. `DISABLE_INSTALLATION_CHECKS=1` covers the native-installer nag beside it.

🔴 **and to add the key anyway would be the defect this brief's own rule names.** a declared key
with no read site gets a verify row, that row goes green, and the green means *"the string is in the
file"* — never *"updates are off"*. it is a **false ✔** manufactured on purpose, and it would mask
the day `DISABLE_AUTOUPDATER` is renamed, because the row that comforts a reader stays green.

⚠️ the honest counter: this is measured against **2.1.87**, and a later release could coin the name.
that is an argument for a re-read on upgrade, never for a key held on speculation
(`rule.forbid.exemption-as-habit`: a placeholder whose justification is a future that has not arrived).

## .see also

- `rule.require.brain-config-has-one-home` — the rule these measurements bought
- `define.claude-code-config` — the keys, the resolution order, and what `gk6` really gates
- `rule.require.one-command-provision` — shape 11, the add-only bundle
- `gotcha.my-own-note-became-my-evidence` — m3's mechanism

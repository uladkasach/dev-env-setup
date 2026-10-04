# howto: silence claude-code cli noise

## .what

kill the repeat claude-code cli noise — startup banners **and** in-prompt suggestions — while we
stay on the **pnpm global** install (do NOT migrate to the native installer).

## .why

claude-code is managed via `pnpm install -g @anthropic-ai/claude-code` (binary at
`~/.local/share/pnpm/claude`), for version pin and rollback control. 🛑 the native-installer
migration is refused. so the nags get suppressed rather than obeyed.

## .the four noises

| noise | fix | where |
|-------|-----|-------|
| `✗ Auto-update failed · Try claude doctor …` | `DISABLE_AUTOUPDATER=1` + `DISABLE_UPDATES=1` | settings.json `env` (`5.3.brains`) |
| `Claude Code has switched from npm to native installer. Run claude install …` | `DISABLE_INSTALLATION_CHECKS=1` | settings.json `env` (`5.3.brains`) |
| `N claude.ai connectors need auth · /mcp` | disconnect in claude.ai web UI (settings key needs ≥2.1.182) | claude.ai account |
| grey ghost text in the prompt box (**prompt suggestions**) | `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false` | settings.json `env` (`5.3.brains`) |

every flag lives on ONE shelf, settings.json `env`, merged by `5.3.brains`. see below for why
the shell-export shelf was retired.

## .prompt suggestions — the one that is not a startup nag

the grey text claude proposes **inside its own input box** (tab accepts it). the canonical term
is **prompt suggestion**, never "autocomplete"
(`domain.terms/term=prompt-suggestion._.choice._.md`).

**it does NOT touch the `/`-command menu or `@`-file completion.** those are separate features
and they survive.

```jsonc
// ~/.claude/settings.json — merged by 5.3.brains's configure.upsert
{ "env": { "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "false" } }
```

### ⚠️ the polarity trap

this is the repo's **first `ENABLE_*` flag**. every other one is `DISABLE_*="1"`, so the convention
inverts and does **not** transfer:

- `"false"` is a non-empty string, hence *truthy* under a naive read
- claude passes it through a coerce helper rather than a direct compare, so it should parse right
- but **verify by behavior, never by the file** — a presence check in `settings.json` passes even
  if the feature is still on

if grey text survives a restart: try `"0"`, then unset-and-invert.

### version

opt-out shipped in claude **2.0.71** (anthropics/claude-code#13878). we run 2.1.87, so no upgrade
is needed.

## .key gotcha: the shell-export shelf was a GUESS, retired 2026-09-25

this brief once split the flags across two shelves — boot-time checks as shell exports in
`~/.zshrc`, mid-session reads in settings.json — on the claim that *"the settings.json env block
is read too late"*. that claim cited no READ SITE, and it was false: claude's `zd()` assigns the
settings `env` block into `process.env` at startup, unfiltered, before any of these reads:

| flag | read site (cli 2.1.87) |
|---|---|
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `et6()`, per turn |
| `DISABLE_AUTOUPDATER` | `j96()` off `process.env` — claude's own `RtK()` writes it INTO settings |
| `DISABLE_UPDATES` | 🔴 0 refs in 2.1.87 — kept for a later cli |
| `DISABLE_INSTALLATION_CHECKS` | `$w6()`/`kFz()`, behind a react effect |

⇒ every claude flag now has ONE home, `5.3.brains`'s settings patch, and `~/.zshrc` exports
none. the guess bought a two-writers split across three bundles. a shelf claim with no read site
beside it is a guess — when you add a flag, find its read site first.

⚠️ the 2026-09-25 move removed the zshrc exports and left two flags in NO home —
`DISABLE_INSTALLATION_CHECKS` and `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` reached the patch on
2026-10-01. a move is a delete AND an add, and only the delete was checked.

the connectors patch (`disableClaudeAiConnectors: true`) lives in `settings.json`, merged by
`5.3.brains`'s configure.upsert. ⚠️ it needs claude **≥2.1.182**; at 2.1.87 it is inert, so
kill that nag via the claude.ai web UI instead.

## .DISABLE_INSTALLATION_CHECKS is undocumented

not in the official docs. found in the minified `cli.js` source (via anthropics/claude-code#23683):

```js
if (K.current || v9() || w1(process.env.DISABLE_INSTALLATION_CHECKS)) return;
```

**always verify undocumented flags against the installed bundle before you trust them.**

⚠️ `rhx grepsafe` will **not** do this — it refuses any path outside the git repo, and the bundle
lives in the pnpm store. use the Grep tool (or plain `grep`) against the resolved store path:

```
~/.local/share/pnpm/global/5/.pnpm/@anthropic-ai+claude-code@<version>/node_modules/@anthropic-ai/claude-code/cli.js
```

a useful side effect: the `grepsafe` refusal message prints the fully resolved store path,
version included — which is a quick way to confirm which build is actually installed.

**prefer `files_with_matches` over a count.** count mode can render ambiguously on this bundle
(a count line followed by `Found 0 total occurrences`), and presence is what the decision rests on
anyway.

two probes worth knowing:

```
process\.env\.<FLAG>              # confirms it is read from the environment
<FLAG>\s*[!=]==                   # zero matches = it goes through a coerce helper, not a compare
```

both `DISABLE_INSTALLATION_CHECKS` and `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` are confirmed present
in the 2.1.87 bundle, so both work without an upgrade.

## .the other keys `5.3.brains` declares, and why

### 🛑 `cleanupPeriodDays` governs the TRANSCRIPTS, and its default DELETES them

- claude keeps a session's transcript for N days past its last activity, then removes it.
  the default N is 30, and it applies whether or not the key appears — so an ABSENT key is
  not "no prune", it IS the 30-day prune, chosen by default and never stated
- ⇒ every `/resume`, every post-compaction re-read of a session `.jsonl`, and every
  archaeology run against a prior session dies on its 31st day
- ⚠️ the loss is UNRECOVERABLE and UNREPORTED — a human learns of it from a `/resume` that
  finds naught. a failhide in the tool, so the key is declared (`rule.forbid.failhide`)
- ⇒ 36500 days is a hundred years: `never`, said in the one unit the option accepts. claude
  declares no sentinel for never, so a grep for that word finds none — not a gap

### `permissions.deny=["Agent"]` bans SUBAGENTS outright

- a BARE tool name (no parens, no args) removes the tool from claude's own context, so it
  never sees it — not a prompt-at-call-time gate. it takes effect on the next tool call,
  mid-session, with no restart
- the cost is real and chosen: research a subagent would hold in its own context lands in
  the main one, and `/batch` (which fans out across worktree agents) no longer runs

### `permissions.defaultMode=acceptEdits`

every session starts with file edits applied without a prompt; shift+tab still cycles modes.

### 🛑 `jq '. * $patch'` merges objects and REPLACES arrays

- the merge, never an overwrite: `~/.claude/settings.json` is a file a HUMAN also edits —
  hooks, model, permissions — and the deep merge leaves every undeclared key as found
- ⇒ but a `deny` list a human adds to the live file by hand is DESTROYED by the next apply,
  silently, since the patch declares that same key. a deny entry belongs in the patch
- (the live file held no `deny` array when this landed, so the first apply destroyed no
  entry — a fact about that day, never a guarantee)
- an absent jq is a hard STOP: the only ways forward are overwrite (destroys hooks) or skip
  (a failhide). the fix names `5.3.brains` itself, since jq is that bundle's own declared
  dependency (`rule.require.bundles-own-their-dependencies`)

## .apply

```sh
grove.provision --what 5.3.brains  --mode apply   # the settings.json patch — every flag
```

then **fully restart the claude cli**, since settings load at startup.

verify:

- the patch → `jq .env ~/.claude/settings.json` holds every flag above
- prompt suggestions → **check the behavior, not the file**: type a partial prompt and confirm no
  grey ghost text appears. a key present in `settings.json` proves nothing about how it parsed

## .refs

- suppress installer nag: https://github.com/anthropics/claude-code/issues/23683
- opt-out for auto-synced connectors: https://github.com/anthropics/claude-code/issues/56773
- suppress "N need auth" counter: https://github.com/anthropics/claude-code/issues/62518
- disable prompt suggestions: https://github.com/anthropics/claude-code/issues/13878
- prompt-suggestion toggle persistence bug: https://github.com/anthropics/claude-code/issues/14629

## .see also

- `domain.terms/term=prompt-suggestion._.choice._.md` — why "prompt suggestion" and not
  "autocomplete"
- `define.claude-code-config` — the model + shell-export side of claude config
# howto: silence claude-code cli noise

## .what

kill the repeat claude-code cli noise — startup banners **and** in-prompt suggestions — while we
stay on the **pnpm global** install (do NOT migrate to the native installer).

## .why

vlad manages claude-code via `pnpm install -g @anthropic-ai/claude-code` (binary at `~/.local/share/pnpm/claude`) for version pin + rollback control. he explicitly refuses the native-installer migration. so we suppress the nags rather than migrate.

## .the four noises

| noise | fix | where |
|-------|-----|-------|
| `✗ Auto-update failed · Try claude doctor …` | `DISABLE_AUTOUPDATER=1` + `DISABLE_UPDATES=1` | shell export (`src/zshrc.sh`) |
| `Claude Code has switched from npm to native installer. Run claude install …` | `DISABLE_INSTALLATION_CHECKS=1` | shell export (`src/zshrc.sh`) |
| `N claude.ai connectors need auth · /mcp` | disconnect in claude.ai web UI (settings key needs ≥2.1.182) | claude.ai account |
| grey ghost text in the prompt box (**prompt suggestions**) | `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false` | settings.json `env` (`configure_robot_brains`) |

note the last one is not a *startup* nag — it renders mid-session, which is why it takes a
different shelf. see below.

## .prompt suggestions — the one that is not a startup nag

the grey text claude proposes **inside its own input box** (tab accepts it). the canonical term is
**prompt suggestion**, never "autocomplete" — see
`domain.terms/term=prompt-suggestion._.choice._.md` for why that distinction carries weight.

**it does NOT touch the `/`-command menu or `@`-file completion.** those are separate features and
they survive. anyone who reads this and fears the loss of those two can stop here.

```jsonc
// ~/.claude/settings.json — written by configure_robot_brains
{ "env": { "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "false" } }
```

### why the settings.json shelf, not a shell export

the other three flags are shell exports because their checks run at **boot**, before settings load.
this one is read as `process.env.CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` **mid-session**, long after
settings load — so the `env` block reaches it fine. verified present in the 2.1.87 bundle.

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

## .key gotcha: which shelf does a flag belong on?

**the rule is about WHEN the flag is read, not about the flag's shape.**

| when claude reads it | shelf | examples |
|----------------------|-------|----------|
| at **boot**, before settings load | shell export (`src/zshrc.sh`) | `DISABLE_AUTOUPDATER`, `DISABLE_UPDATES`, `DISABLE_INSTALLATION_CHECKS`, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` |
| **mid-session**, after settings load | settings.json `env` | `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` |

the update/install checks fire before the `settings.json` `env` block is applied, so a value there
is ignored — they must be real shell exports in `~/.zshrc`.

⚠️ **do not over-generalize that into "claude env flags always need a shell export."** the
prompt-suggestion flag is read mid-session and works fine from the `env` block. when you add a new
flag, ask *when* it is read before you pick the shelf.

the connectors patch (`disableClaudeAiConnectors: true`) DOES live in `settings.json` and is written by `configure_robot_brains`, but it only works on claude **≥2.1.182**. we run 2.1.87, so it is inert — kill that nag via the claude.ai web UI instead.

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

## .apply

```sh
sync.devenv.zshrc    # copy src/zshrc.sh → ~/.zshrc, re-source
sync.devenv.brains   # run configure_robot_brains (writes settings.json patch)
```

then **fully restart the claude cli** from a fresh shell (so it inherits the exports).

verify:

- exports → `echo $DISABLE_INSTALLATION_CHECKS` → `1`
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

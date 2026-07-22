# howto: silence claude-code cli startup nags

## .what

kill the repeat claude-code cli startup banners while we stay on the **pnpm global** install (do NOT migrate to the native installer).

## .why

vlad manages claude-code via `pnpm install -g @anthropic-ai/claude-code` (binary at `~/.local/share/pnpm/claude`) for version pin + rollback control. he explicitly refuses the native-installer migration. so we suppress the nags rather than migrate.

## .the three nags

| nag | fix | where |
|-----|-----|-------|
| `✗ Auto-update failed · Try claude doctor …` | `DISABLE_AUTOUPDATER=1` + `DISABLE_UPDATES=1` | shell export (`src/zshrc.sh`) |
| `Claude Code has switched from npm to native installer. Run claude install …` | `DISABLE_INSTALLATION_CHECKS=1` | shell export (`src/zshrc.sh`) |
| `N claude.ai connectors need auth · /mcp` | disconnect in claude.ai web UI (settings key needs ≥2.1.182) | claude.ai account |

## .key gotcha: shell export, not settings.json

these update/install checks run **before** the `settings.json` `env` block is applied, so a value there is ignored. they must be real shell exports in `~/.zshrc`. (same reason as `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`.)

the connectors patch (`disableClaudeAiConnectors: true`) DOES live in `settings.json` and is written by `configure_robot_brains`, but it only works on claude **≥2.1.182**. we run 2.1.87, so it is inert — kill that nag via the claude.ai web UI instead.

## .DISABLE_INSTALLATION_CHECKS is undocumented

not in the official docs. found in the minified `cli.js` source (via anthropics/claude-code#23683):

```js
if (K.current || v9() || w1(process.env.DISABLE_INSTALLATION_CHECKS)) return;
```

**always verify undocumented flags against the installed bundle before you trust them:**

```sh
rhx grepsafe --pattern 'DISABLE_INSTALLATION_CHECKS' \
  --path ~/.local/share/pnpm/global/5/node_modules/@anthropic-ai/claude-code/cli.js
```

confirmed present in the 2.1.87 bundle (2 hits), so it works without an upgrade.

## .apply

```sh
sync.devenv.zshrc    # copy src/zshrc.sh → ~/.zshrc, re-source
sync.devenv.brains   # run configure_robot_brains (writes settings.json patch)
```

then **fully restart the claude cli** from a fresh shell (so it inherits the exports). verify: `echo $DISABLE_INSTALLATION_CHECKS` → `1`.

## .refs

- suppress installer nag: https://github.com/anthropics/claude-code/issues/23683
- opt-out for auto-synced connectors: https://github.com/anthropics/claude-code/issues/56773
- suppress "N need auth" counter: https://github.com/anthropics/claude-code/issues/62518

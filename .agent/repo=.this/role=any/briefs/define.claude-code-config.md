# define.claude-code-config

## .what

claude code's model + behavior config for this machine lives in the repo, not in `~/.claude`. the shell exports drive it.

## .where

`src/bash_aliases.sh` (copied to `~/.bash_aliases` on sync):

```sh
# claude code config (expected: v2.1.87, beyond which hooks are truncated)
export ANTHROPIC_MODEL='claude-opus-5[1m]'
export CLAUDE_CODE_SKIP_UPDATE_CHECK=1
```

| var | effect |
|-----|--------|
| `ANTHROPIC_MODEL` | global default model claude code boots with |
| `CLAUDE_CODE_SKIP_UPDATE_CHECK` | skip the cli update nag on start |

## .the model id format

the `[1m]` suffix is a context-window selector (1 million token context), appended to the base model id. base id follows the `claude-opus-N-M` pattern.

## .how to change the default model

1. edit the `ANTHROPIC_MODEL` line in `src/bash_aliases.sh`
2. `sync.devenv.bashaliases` to copy into `~/.bash_aliases`
3. re-source (`source ~/.bash_aliases`) or open a new shell — the export only reaches claude code sessions started after the shell picks it up

## .why repo, not ~/.claude

per `rule.require.repo-as-source-of-truth`: the repo drives all env config so a fresh machine reproduces the exact same claude setup. a value hand-set in `~/.claude/settings.json` would be lost on the next machine build.

## .gotcha

- the live shell holds whatever value it was sourced with. after an edit, an open terminal keeps the OLD model until re-sourced — so "what the repo says" and "what my current session uses" can differ.
- a typo'd model id boots a dead default. confirm the id string is one the cli accepts before you sync.

## .see also

- `rule.require.repo-as-source-of-truth`
- `howto.silence-claude-cli-nags`

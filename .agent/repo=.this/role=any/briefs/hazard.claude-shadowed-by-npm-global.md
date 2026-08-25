# hazard.claude-shadowed-by-npm-global

## .what

an `npm install -g @anthropic-ai/claude-code` under any fnm node version silently
outranks the pinned pnpm-global copy, so `claude` runs a version the repo never
chose — with no error raised.

## .why it is silent

three things combine, and each one alone looks harmless:

1. **no binding exists.** `src/bash_aliases.sh` sets `ANTHROPIC_MODEL` and
   `CLAUDE_CODE_SKIP_UPDATE_CHECK`, but declares no `alias claude=`. the "pin" was
   only ever "the pnpm copy happens to be first on PATH".
2. **fnm always wins the PATH race.** `eval "$(fnm env --use-on-cd)"`
   (`src/zshrc.sh`) puts `/run/user/$UID/fnm_multishells/*/bin` near the front on
   every shell.
3. **the PNPM_HOME prepend is skipped.** `src/zshrc.sh` guards it:

   ```sh
   case ":$PATH:" in
     *":$PNPM_HOME:"*) ;;                        # already present -> do nada
     *) export PATH="$PNPM_HOME:$PATH" ;;
   esac
   ```

   when `~/.local/share/pnpm` is already inherited somewhere in PATH, the prepend
   is a no-op, so it stays *behind* fnm's bin forever.

the `DISABLE_AUTOUPDATER` / `DISABLE_INSTALLATION_CHECKS` exports still work — they
just protect the pnpm install that is no longer the one running.

## .why it recurs

the shadow is installed per node version, so it accumulates. one audit found
claude-code npm-global under **five** fnm node versions (v20.12.2, v20.18.1,
v22.14.0, v22.21.0, v24.14.0) while the repo believed a single pnpm copy was in
use. `fnm use` to any of them surfaces a different claude.

claude's own native-installer migration is a common source: it installs the
`bin/claude.exe` native variant under the active node, not via pnpm.

## .the trap when you fix it by hand

```sh
npm uninstall -g @anthropic-ai/claude-code   # 👎 removes the WRONG one
```

`src/bash_aliases.sh` defines an `npm` **function** that routes to `pnpm` whenever
the cwd has no `package-lock.json`. from most directories that command uninstalls
the pnpm copy you meant to keep, and leaves the shadow in place.

reach for the absolute path instead, so the function cannot intercept:

```sh
nodedir=~/.local/share/fnm/node-versions/v22.21.0/installation
"$nodedir/bin/node" "$nodedir/bin/npm" uninstall -g @anthropic-ai/claude-code
```

## .the guard

`configure_robot_brains()` in `src/install_env.pt5.devtools.sh` — reached via
`sync.devenv.brains` (and the full `sync.devenv`) — converges all three:

| step | what it does |
|------|--------------|
| prune | uninstalls claude-code from **every** fnm node version |
| converge | `pnpm install -g @anthropic-ai/claude-code@$CLAUDE_CODE_VERSION_PINNED` |
| verify | asserts the resolved `claude` is the pinned version, else fails loud |

the verify step is what makes recurrence detectable: a shadow reintroduced later
turns the next `sync.devenv.brains` red with the fix named, rather than passing
quietly (`rule.forbid.failhide`).

## .the tell

if claude behaves oddly around hooks, check resolution first:

```sh
which -a claude   # more than one hit = a shadow is present
claude --version  # must match CLAUDE_CODE_VERSION_PINNED
```

## .see also

- `rule.require.brain-configs-via-repo` — brain config belongs in the repo, applied via sync
- `rule.require.repo-as-source-of-truth`
- `rule.require.install-via-procedures`

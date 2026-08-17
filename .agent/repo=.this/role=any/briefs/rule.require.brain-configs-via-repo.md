# rule.require.brain-configs-via-repo

## .what

all global robot-brain configs (claude-code, codex, rhachet) must be driven
from this repo and applied via `sync.devenv.*` — never hand-edit
`~/.claude/settings.json` (or peer brain configs) directly on the machine.

## .why

- **reproducibility** — fresh machines get the same brain config from scratch
- **version control** — changes are tracked, reviewable, revertible
- **idempotency** — `sync.devenv.brains` can be re-run safely to reconverge
- **no drift** — a direct edit is silently overwritten on the next sync, or
  worse, silently absent on the next machine

## .scope

applies to every global brain config knob, e.g.:

- claude-code `~/.claude/settings.json` (env, permissions.defaultMode, connectors)
- codex + rhachet global config
- any other brain tool config that lives outside the repo tree

## .how

1. edit the source in `src/install_env.pt5.devtools.sh` → `configure_robot_brains()`
   - the `patch` JSON is deep-merged into `~/.claude/settings.json` via `jq`
2. apply with `sync.devenv.brains` (or the full `sync.devenv`)
3. commit the change to the repo

## .examples

### 👍 good — config via repo patch

```sh
# add permissions.defaultMode to the patch in configure_robot_brains()
vim src/install_env.pt5.devtools.sh

# apply
sync.devenv.brains
```

### 👎 bad — direct edit

```sh
# lost on next sync or fresh machine
vim ~/.claude/settings.json
```

## .see also

- rule.require.repo-as-source-of-truth
- rule.require.install-via-procedures

## .enforcement

direct brain-config edits without a matched change in
`configure_robot_brains()` = lost on next sync or machine setup

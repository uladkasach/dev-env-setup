# domain.term.choice.reason: alias

## .etymology
ssh's own word — a `Host` block in `~/.ssh/config` defines an alias, and `ssh <alias>` reaches
the machine through it. the repo already speaks it for git (`configure_git_aliases`) and shell
aliases, so it reads consistently.

chosen over:
- `handle` / `nickname` — informal, and each suggests a display label rather than a
  functional address ssh actually reads
- `shortcut` — implies mere convenience; an alias may carry the port, user, identity file,
  and ProxyCommand, without which the grove is unreachable

## .disputes
### dispute: name  —  raised 2026-07-25  —  status: RESOLVED (split into two terms)
- raised.by  = <traveler>
- claim      = the grove's `name` could serve as its ssh alias; one word, one concept, and
               `git grove set <name> --at ...` already wrote a Host block named for the grove
- counter    = they are genuinely distinct. an ssh alias often pre-exists, written by
               infra/declastruct with keys, ProxyCommand, or an SSM tunnel. to force the grove
               name onto it would clobber or duplicate that config. and the reverse: a grove
               name should stay semantic in the registry, free of ssh's address concerns.
- resolution = split. `name` = the registry key; `alias` = the ssh Host that reaches it. they
               default to the same string, and `--alias` names an extant one. `del` strips
               only a Host block we wrote ourselves, so an infra-managed alias is never
               clobbered. dispute closed.

## .evidence
- the split carries weight in code: the registry records `sshAlias`, and
  `_git_grove_ssh_alias` is what send/read/push/pull ride — never the raw name
- narrative: infra wakes a grove and writes its ssh alias with an SSM ProxyCommand; the
  developer then registers `git grove set one --alias abc`, and grove touches no ssh config
- the narrative above was CONFIRMED 2026-07-25 against real infra: ahbode/infrastructure's
  `git.grove.wake` skill applies a `DeclaredUnixSshAlias` that writes the `grove-1` Host block
  itself (over an SSM tunnel on :36901). so the ssh alias genuinely pre-exists, infra-owned —
  the split was not hypothetical, and `--alias` is the only registration mode that does not
  clobber it

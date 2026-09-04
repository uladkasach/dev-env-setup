# domain.term: alias

term.chosen   = grove.alias
term.kind     = noun
term.synonyms.forbidden:
- handle
- shortcut
- nickname

## .what
the ssh Host name that reaches a grove — distinct from the grove's own name.

## .note
a grove has a **name** (the registry key, semantic: `grove-box`) and an **alias** (the ssh
Host that reaches it). they may match, but they are two concepts:
- `git grove set <name> --at <user@host:port>` — we own the alias, so we write the Host block
- `git grove set <name> --alias <ssh-alias>` — ssh owns it (infra wrote keys/ProxyCommand/SSM),
  so we point at it and touch no ssh config

## ⚠️ .a two-seat grove has TWO aliases, and only ONE carries a suffix
a grove with a `ground` / `camper` split (`term=ground`) writes two Host blocks, and they are
deliberately **asymmetric**:

| alias | seat | user |
|---|---|---|
| `<exid>.ground` | ground | `ground` |
| `<exid>` — **bare, no suffix** | camper | `camper` |

so `<exid>.camper` matches no Host block and is tried as a literal hostname:

```
$ rhx git.grove.push <exid>.camper --from src …
ssh: Could not resolve hostname <exid>.camper: Name or service not known
```

measured 2026-08-12 — a push aimed at the symmetric-looking name, which does not exist.

⇒ the asymmetry is intended: the camper is the **default** seat, the one the agent works as, so
the plain grove name reaches it and every unsuffixed command in every brief stays correct. the
suffix marks the exception, the way a default branch or default profile needs no qualifier.

⚠️ it is still a footgun, because `rule.prefer.symmetric-term-pairs` is the habit a reader
brings: having seen `.ground`, they infer `.camper`. the saving grace is that the failure is
LOUD — ssh names the host it could not look up — so it costs a command, never a wrong write.

## .refs
where the term is declared / used:
- src/bash_aliases.sh                  # _git_grove_ssh_alias, sshAlias registry field
- src/grove.provision/2.shell/2.2.git/configure.upsert.sh  # git alias precedent
- .agent/repo=.this/role=any/skills/git.grove.wake.sh     # writes/repairs the Host block ([SET]/[KEEP]/[REPLACE])

## .reason
see the ref-level cluster beside this choice:
- `term=grove.alias._.choice.reason.md` — etymology, disputes, evidence

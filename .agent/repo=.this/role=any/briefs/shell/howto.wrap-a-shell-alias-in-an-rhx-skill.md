# howto: wrap a shell alias in an rhx skill

## .what

this repo's real behavior lives in shell functions — `duct.list`, `git_alias_grove`,
`_git_tree_set` — loaded from `~/.bash_aliases`. an **rhx skill** is a thin forwarder that
hands its args to one of them:

```
rhx duct.list --on duct://grove-1   →   duct.list --on duct://grove-1
```

the skill adds no logic. it exists so the function can be **reached and tested** by an
agent.

## .why — a fresh shell per run

an agent cannot test a shell function by a `source` into its own shell.

a long-lived shell binds function definitions when it reads a file. a later `source` of a
newer file does **not** replace the definitions already bound in that process — so every
check re-runs the OLD code and passes, while the installed code stays broken.

four defects hid that way, each for a full round of "verified":

| defect | why the check passed anyway |
|--------|------------------------------|
| `${!a[@]}` — bash-only array keys | the agent's shell was bash; the human's is zsh |
| `${~want}` — unquoted RHS globs in bash, is literal in zsh | same split, re-made ten lines later |
| `local status` — zsh reserves `status` read-only | bash has no such reservation |
| a tab delimiter — `read` eats an empty first field | the row shape only broke for LOCAL ducts |

an `rhx` skill spawns a **new** `bash` per invocation, which reads the installed file every
time. so a check finally speaks about the code the human runs. that is the whole point —
the allowlist surface is a bonus.

> if you cannot run it fresh, you did not test it. you tested your memory of it.

## .why — one allowlistable surface

`rhx duct.list` is one stable string an agent's permissions can name. the alternative —
`source ~/.bash_aliases; duct.list …` — is unallowlistable, since the `source` half is a
blanket grant.

## .the pattern

### 1. the shared setup, once per verb family

a family of verbs (`duct.open|send|read|stop|list`) repeats three moves. put them in
`<family>.operations.sh` so a fix lands in one place:

```bash
# .what = load the installed functions, or fail with the fix
__duct_skill_load() {
  # shellcheck source=/dev/null
  source ~/.bash_aliases 2>/dev/null || true

  local verb="$1"
  if ! command -v "$verb" &>/dev/null; then
    echo "✋ $verb not found — the installed aliases lack ductwork" >&2
    echo "   └─ fix: install this tree's version —" >&2
    echo "        rhx grove.provision --from tree --mode apply" >&2
    return 2
  fi
}

# .what = drop rhachet's own flags, keep the caller's
# .how  = sets the global array DUCT_SKILL_ARGS
__duct_skill_args() {
  DUCT_SKILL_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift; DUCT_SKILL_ARGS+=("$@"); break ;;
      --skill|--repo|--role) shift 2 ;;
      *) DUCT_SKILL_ARGS+=("$1"); shift ;;
    esac
  done
}
```

### 2. the forwarder, one per verb

```bash
#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `duct.list` bash function
# .why  = a FRESH shell per run, so a check reads the installed code
#
# usage:
#   rhx duct.list --on duct://grove-1
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/duct.operations.sh"

__duct_skill_load duct.list || exit 2
__duct_skill_args "$@"

duct.list "${DUCT_SKILL_ARGS[@]}"
```

that is the whole skill. no logic, so there is no second copy to drift.

### 3. set the exec bit

**rhachet runs the file directly** — with no exec bit it dies with
`Permission denied` and exit `126`, which names no cure:

```bash
chmod +x .agent/repo=.this/role=any/skills/duct.list.sh
```

do it as you create the file. it is the one step with a bad error message.

## .the rules the pattern obeys

- **file name == command name.** `duct.list.sh` → `rhx duct.list`. a reader infers one
  from the other with no lookup
- **strip `--skill|--repo|--role`.** rhachet forwards its own flags into your argv; the
  wrapped verb would reject them as unknown args
- **honor a bare `--`.** every arg after it is literal, so a value that looks like a flag
  (a grove named `--repo`) still reaches through
- **forward the exit code.** the last line is the call, so `$?` propagates untouched.
  keep the wrapped verb's codes: `0` ok, `1` malfunction, `2` constraint
  (`rule.require.exit-code-semantics`)
- **add no behavior.** the moment a skill decides anything, there are two implementations
  of one verb, and the shell one is the one the human runs

## .the trap this pattern does NOT excuse

a wrapper makes a verb reachable; it does not make it correct. verify against the
**installed** file, never the tree:

```bash
rhx grove.provision --from tree --mode apply   # install first
rhx duct.list --on duct://grove-1             # then check
```

a check that runs before the install reports on the prior version and is worth less than
no check at all, because it reads as evidence.

## .see also

- `rule.require.wrap-cli-in-skills` — why a raw CLI call is a defect
- `rule.require.reach-a-grove-through-its-duct` — the same argument, for groves
- `rule.require.exit-code-semantics` — the codes a forwarder must not swallow
- `.agent/repo=.this/role=any/skills/duct.operations.sh` — the live implementation

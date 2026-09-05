# rule.forbid.bare-globs-in-dual-shell-files

## .what

in a file that BOTH bash and zsh source — `src/bash_aliases.sh`, `src/ductwork.sh`,
`src/termwork.sh` — never write `for f in <dir>/*.ext`. use `find` fed into a `while read`.

## .why

the two shells disagree about a glob that matches no file:

| shell | `for f in /nope/*.json` |
|-------|-------------------------|
| bash | leaves it as LITERAL text, so `[[ -f "$f" ]] \|\| continue` skips it |
| zsh | `no matches found` — a HARD ERROR that **aborts the whole function** |

so the `[[ -f ]]` guard everyone writes reads as defensive and defends none of it under
zsh. the loop never runs, and neither does any line after it.

this is not theoretical. `duct.list --refresh` walked `hosts/*.json` to refresh remote
hosts. a **grove holds zero remote hosts**, so on a grove under zsh the whole function died
before it emitted a single duct — local or remote. the same command passed on the laptop,
which has one host file, and passed on the grove under bash. it failed only where the two
conditions met: an empty dir AND a zsh.

> the glob fails exactly when the directory is empty — which for most of these paths is the
> NORMAL state of a fresh machine, not an edge case.

## .the test

> "if this directory were empty, would zsh abort here?"

if the pattern can match zero files — and nearly all of them can — it is a defect.

## .how

### 👎 bad — the guard cannot fire

```bash
for f in "$DIR"/hosts/*.json; do
  [[ -f "$f" ]] || continue     # zsh never reaches this line
  ...
done
```

### 👍 good — `find` emits no line for no match, in every shell

```bash
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  ...
done < <(find "$DIR/hosts" -type f -name '*.json' 2>/dev/null)
```

`find` needs no shell option, no dialect branch, and no guard that only half works. it also
survives a dir that does not exist at all, which the glob form does not.

## .why not `setopt nullglob`

it is the obvious fix and it is wrong here for two reasons:

1. **it is dialect-specific** — the file is read by bash too, where `setopt` is not a
   command. so it needs a shell test, which is the branch this rule exists to avoid.
2. **it mutates the human's shell** — these files are sourced into an INTERACTIVE session.
   a `setopt` there silently changes how every later command in that terminal globs. a
   config file may not reach out and re-tune the shell that read it.

## .the family this belongs to

the same defect shape has now landed five times in these files, each time green in the
agent's bash and broken in the human's zsh:

| syntax | bash | zsh |
|--------|------|-----|
| `${!arr[@]}` | array keys | `bad substitution` |
| `[[ "$x" == $var ]]` | pattern match | literal compare |
| `local status` | fine | `read-only variable` |
| `IFS=$'\t' read -r a b` | eats an empty first field | same, but only bit LOCAL ducts |
| `for f in dir/*.ext` | literal on no match | `no matches found`, aborts |

the through-line is never zsh. it is that **the shell a check ran in was not the shell the
human runs in**. the durable fix is `howto.wrap-a-shell-alias-in-an-rhx-skill.md` — a test
surface that spawns a fresh shell — plus rules like this one for the syntax that splits.

## .where to look

`src/bash_aliases.sh` still holds glob-form loops — worktree walks, `*.json`, `*.patch`. a
`_worktrees` or `.patch` dir is routinely empty, so each is a live instance. a pattern that
is near-certain to match (`/proc/[0-9]*`) is the low-risk end of the same defect.

## .enforcement

- a bare `for … in <path>/*` in a file both shells source = **blocker**
- a `[[ -f "$f" ]] || continue` guard presented as the defense for one = **blocker** (it
  cannot fire; it makes the defect look handled)
- `setopt nullglob` inside a sourced config = **blocker**

## .see also

- `howto.wrap-a-shell-alias-in-an-rhx-skill.md` — the test surface that catches this class

# gotcha: shell snapshotter drops functions and variables

## .what

the shell snapshotter that writes the `~/.bash_aliases.*` files has two behaviors that break
sourced shell scripts:

1. **filters out single-underscore functions** (`_foo`) but keeps double-underscore ones (`__foo`)
2. **drops file-level variable assignments** — only functions are captured

## .why the single-underscore filter exists

shell completion systems name their internals `_git`, `_docker`. the filter keeps completion
internals out of the snapshot.

## .gotcha 1: absent internal functions

a public function (`term.open`) that calls a single-underscore internal (`_term_register`)
finds that internal absent from the installed file.

### symptom

```
term.open:54: command not found: _term_find_by_duct
```

it works in an interactive zsh, which sources the file directly, and fails in a bash
procedure or a fresh shell, which read the snapshot.

### fix

use double-underscore prefix for internal functions:

| bad | good |
|-----|------|
| `_term_register` | `__term_register` |
| `_term_find_by_duct` | `__term_find_by_duct` |

## .gotcha 2: absent file-level variables

the snapshotter captures no file-level variable assignment, so a function that depends on one
reads an empty value.

### symptom

```
mkdir: cannot create directory '': No such file or directory
__term_register:7: permission denied: /1828394.json
```

`TERMWORK_DIR` is empty: the snapshotter captured no
`TERMWORK_DIR="$HOME/.termwork"` at file level.

### fix

set a variable inside the function, with a fallback default:

```bash
# bad: file-level assignment (not captured)
TERMWORK_DIR="$HOME/.termwork"

__term_ensure_dir() {
  mkdir -p "$TERMWORK_DIR"
}

# good: set inside function with default
__term_ensure_dir() {
  TERMWORK_DIR="${TERMWORK_DIR:-$HOME/.termwork}"
  mkdir -p "$TERMWORK_DIR"
}
```

## .rules

1. all internal functions in ductwork.sh and termwork.sh must use `__` prefix
2. all file-level variables must be set inside functions with `${VAR:-default}` pattern

## .note

this is a known Claude Code bug (issues #40602, #55816, #60397). the workarounds above are user-side until the snapshotter logic is fixed.

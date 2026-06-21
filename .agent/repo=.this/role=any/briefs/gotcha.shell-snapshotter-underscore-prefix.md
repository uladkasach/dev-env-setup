# gotcha: shell snapshotter drops functions and variables

## .what

the shell snapshotter (used by `install_zsh` to create `~/.bash_aliases.*` files) has two behaviors that break sourced shell scripts:

1. **filters out single-underscore functions** (`_foo`) but keeps double-underscore ones (`__foo`)
2. **drops file-level variable assignments** — only functions are captured

## .why single-underscore filter exists

single-underscore functions are common in shell completion systems (e.g., `_git`, `_docker`). the filter prevents snapshot bloat from completion internals.

## .gotcha 1: absent internal functions

if a public function (e.g., `term.open`) calls an internal function with single underscore (e.g., `_term_register`), the internal function will be absent from the installed file.

### symptom

```
term.open:54: command not found: _term_find_by_duct
```

works in interactive zsh (sourced directly), fails in bash scripts or fresh shells (uses snapshot).

### fix

use double-underscore prefix for internal functions:

| bad | good |
|-----|------|
| `_term_register` | `__term_register` |
| `_term_find_by_duct` | `__term_find_by_duct` |

## .gotcha 2: absent file-level variables

file-level variable assignments are not captured by the snapshotter. functions that depend on them will see empty values.

### symptom

```
mkdir: cannot create directory '': No such file or directory
__term_register:7: permission denied: /1828394.json
```

the `TERMWORK_DIR` variable was empty because the file-level assignment `TERMWORK_DIR="$HOME/.termwork"` was not captured.

### fix

set variables inside functions with fallback defaults:

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

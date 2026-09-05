# hazard: a test for a HANG defect must carry a timeout, or it hangs instead of fails

## .what

`rule.require.clamp-edge-cases` says a defect fix needs a test that goes red under the un-fixed
defect. for most defects, red means a failed assertion. for a **hang** defect it does not — the
un-fixed code never returns, so the test never reaches its assertion at all.

a clamp with no timeout does not fail. it stops. and a suite that stops reports no verdict:

```sh
# 👎 under the un-fixed defect this line never returns. the suite hangs, CI times out at the
#    job level, and the output names no case at all.
_brains_auth_usage --reach          # the arg parser spins forever
_code 'guard.reach-without-value' 2 "$?"
```

```sh
# 👍 the timeout converts the hang into an exit code, so the case reports as a failure
timeout 5 bash -c "source '$ALIASES'; _brains_auth_usage --reach" >/dev/null 2>&1
_code 'guard.reach-without-value' 2 "$?"     # regression -> got 124, not a hang
```

exit **124** is `timeout`'s signal that it killed the child. it is the tell that the defect is
back, and it is legible in the same one-line report as every other case.

## .the defect this came from

`shift 2` with exactly one positional left is a **no-op** in bash. it does not error, does not
shift, and its non-zero return is unread inside a `case`. so a `--flag` handed no value leaves
`$#` unchanged and the `while [[ $# -gt 0 ]]` loop spins forever, in silence.

```sh
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reach) reach="$2"; shift 2 ;;    # 👎 `--reach` as the LAST arg -> infinite loop
  esac
done
```

the guard is one line, and it must be repeated at every parser:

```sh
--reach) [[ $# -ge 2 ]] || { echo "✋ $1 needs a value" >&2; return 2; }
         reach="$2"; shift 2 ;;
```

## .why the timeout is what makes it a clamp

the clamp was dogfooded both ways (`rule.require.clamp-edge-cases`):

| the guard | without `timeout` | with `timeout 5` |
|-----------|-------------------|------------------|
| present | ✓ exit 2 | ✓ exit 2 |
| removed | **suite hangs** — no case named | 💥 `expected exit 2, got 124` |

the row that matters is the bottom-left. a clamp that turns a silent hang into a *different*
silent hang has bought no protection at all — it merely moved where the run dies.

## .the general shape

> whenever the defect you clamp is "it never returns", the assertion cannot be the clamp. the
> **bound** is the clamp; the assertion only reads what the bound produced.

the same holds for a poll that never converges, a read on a pipe no one writes, and a lock
never released. bound the wait, then assert on the bounded result.

## .pick the bound generously

the timeout is a **hang detector**, not a performance budget. set it well above the slowest
honest run, so a loaded machine never turns a green case red — 5s for a pure-shell parser that
should return in milliseconds. a flaky clamp gets deleted, and a deleted clamp guards no defect.

## .see also

- `rule.require.clamp-edge-cases` (mechanic) — the rule this sharpens: prove the clamp bites
- `rule.forbid.failhide` (code.test) — a suite that stops verifies on no path
- `hazard.bash-aliases-parse-silently.md` — the other silent-failure trap in this same file
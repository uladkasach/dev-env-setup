# hazard: a test fixture leaks to a real dotfile

## .what

a test redirects a production path variable to a temp dir, then writes fixtures through it. if
the redirect is **missed for one variable**, or **placed below a case that writes**, the fixture
lands on the human's real file instead.

## .the incident — 2026-08-31

`brains.auth.test.sh` reads two live-file paths from variables that `bash_aliases.sh` defaults
to real dotfiles:

```sh
_BRAINS_AUTH_LIVE_CREDS="${HOME}/.claude/.credentials.json"
_BRAINS_AUTH_LIVE_PROFILE="${HOME}/.claude.json"
```

the test redirected **one** of them at the top, and the other **270 lines lower**, beside the
first case that read it:

```sh
:236   _BRAINS_AUTH_LIVE_CREDS="$_SWAPDIR/.credentials.json"   # redirected
...
:416   > "$_BRAINS_AUTH_LIVE_PROFILE"   # ⚠️ still $HOME — wrote a fixture to the real file
:436   printf 'not json at all' > "$_BRAINS_AUTH_LIVE_PROFILE"  # ⚠️ and corrupted it
...
:504   _BRAINS_AUTH_LIVE_PROFILE="$_SWAPDIR/.claude.json"      # redirected, too late
```

every `rhx brains.auth.test` run overwrote the human's real `~/.claude.json` — a 400 KB config —
first with a ~90-byte fixture, then with the literal string `not json at all`.

## .why nobody caught it

- **it was silent.** claude code holds that config in memory and rewrites the whole file on its
  next change, so a running session repaired the damage within seconds. the corruption existed
  only in the window between the test write and the next rewrite.
- **the suite stayed green.** the cases asserted on the fixture they had just written, so they
  passed whether the target was a temp file or the real one. a green run was evidence of none of it.
- **the comment claimed the guarantee.** a `⚠️ the override MUST be in place before any of these
  run` note sat above the redirect — it described an invariant no code enforced.
- **three peer-review rounds and 96 cases missed it.** the reviewers read what the cases
  asserted, never where they wrote.

it was found by the human, who asked whether some defect wrote `not a json` into their settings.

## .the two causes

1. **a redirect parted from its twin.** one variable was redirected at the top, the other beside
   its first reader. that made the second redirect a *position-dependent* guarantee — and a later
   section (added above it, for profile-sync coverage) silently fell outside its protection.
2. **the guarantee was a comment.** a comment cannot fail a run. the invariant "these paths point
   into the temp dir" was asserted in prose and checked by no code.

## .the fix

co-locate every redirect, then **verify** it before any case runs:

```sh
_SWAPDIR="$(mktemp -d)"
_BRAINS_AUTH_LIVE_CREDS="$_SWAPDIR/.credentials.json"
_BRAINS_AUTH_LIVE_PROFILE="$_SWAPDIR/.claude.json"

for _p in "$_BRAINS_AUTH_LIVE_CREDS" "$_BRAINS_AUTH_LIVE_PROFILE"; do
  case "$_p" in
    "$_SWAPDIR"/*) ;;
    *) echo "💥 halt: '$_p' is not inside the temp dir" >&2; exit 1 ;;
  esac
done
```

the loop turns the comment into a clamp: point either path back at `$HOME` and the run halts
before the first write.

## .the rule this generalizes to

> when a test writes through a variable that has a **production default**, the redirect is a
> safety mechanism — so it needs the same discipline as any other: co-located, and **verified**,
> never merely written.

and the test that would have caught it costs one line:

> stamp the real file before the suite and compare after. `wc -c ~/.claude.json` either side of
> a run is a complete leak detector, and it needs no knowledge of what the cases do.

## .the tell to look for

a suite is exposed to this whenever **all three** hold:

- a path comes from a variable with a real-file default
- the test redirects that variable rather than injects a path
- a case writes (not merely reads) through it

grep for every such variable and confirm each is redirected in one block, above every case.

## .see also

- `rule.require.hermetic-tests` (mechanic) — the rule this violated
- `hazard.claude-oauth-one-holder-per-token.md` — the other live-file hazard in this namespace
- `rule.require.clamp-edge-cases` (mechanic) — a fix needs a clamp proven to bite

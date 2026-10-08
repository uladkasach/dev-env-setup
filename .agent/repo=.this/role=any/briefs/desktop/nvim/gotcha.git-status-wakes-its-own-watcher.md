# gotcha: a `git status` wakes the `.git/` watcher that ran it

## .what

a plugin that watches `.git/` and runs `git status` on each event can feed itself. `git status` takes the optional `.git/index.lock` to refresh its stat cache, and that lock is a `.git/` event.

```
watcher fires → git status → index.lock created + removed → watcher fires → …
```

⇒ the fix is `GIT_OPTIONAL_LOCKS=0` in nvim's environment (`4.5.nvim/init.lua`, near the top).

## .measured — codediff, 1000 changed files, 20s with no input, 2026-10-07

| | refreshes | render time |
|---|---|---|
| lock on | 36 | 9.5s |
| `GIT_OPTIONAL_LOCKS=0` | 0 | 0.6s |

each refresh rebuilt and redrew the whole tree, so the editor's main thread was busy half of every idle second.

## .why it hides

- **the index timestamp does not move.** the lock file is created and removed; `.git/index` itself is untouched, so a check on the index mtime reads "no change"
- **each refresh is async and debounced (500ms).** no single call is slow; the cost is the rate
- **it scales with the repo.** at 100 files a refresh is cheap and the loop is invisible

## .why the env var is safe

- git documents it for this caller: a background process that runs status for the user
- it skips only the stat-cache refresh. commit, stage, and checkout still take every lock they need
- a `:terminal` inside nvim inherits it, so its `git status` re-stats rather than reads the cache: slower on a huge tree, never wrong

## .enforcement

- an nvim plugin that watches `.git/` and runs git, with optional locks on = **blocker**
- clamp: `prove.codediff-refresh-stays-quiet`, arm `old-locks` must show the loop

## .see also

- `howto.tune-nvim-at-scale` — the method that found it

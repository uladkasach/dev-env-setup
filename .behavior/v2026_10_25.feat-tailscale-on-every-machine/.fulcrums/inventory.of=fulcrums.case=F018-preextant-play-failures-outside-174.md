# F018 — four pre-extant play failures outside #174's surface

- **fork:** fix all four in this pr, as the 5.3 stone asks · or fix the one that sat inside this pr's
  reach, and defer the four that open untouched domains
- **taken, why:** the split
  - fixed here: `prove.declared-assets-are-tracked`. its path charset dropped `@`, so it
    misread `user@.revive.conf` as an untracked `…/user`. this is a clamp this pr leans on
  - deferred:
    - the header weight of 8 files
    - the codediff red-control that no longer bites
    - earlyoom absent on this laptop
    - two stale allow entries in the actor's tracked `settings.local.json`: permission grants, a
      human's edit
  - each deferral opens a domain #174 never touched (wifi, keybinds, openhours, nvim) or needs a
    human's root
- **rework:** dirty — to pull them in means rewrites across 9+ unrelated files in a tailscale pr
- **confidence 70%, why not higher:** the 5.3 stone says no failure is "prior". a reviewer may hold that
  over the scope rule
- **verdict — the director, 2026-10-30:** the four are a red main, not a reason. each is its own
  dream, with its cause and the shape of its fix, for a separate tree; this tree edits none of them
- **verdict superseded — the director, 2026-11-01:** out-of-pr is no reason
  (`rule.forbid.accept-a-red-main-as-a-reason`). no tree or pr was live for #176–#179, so all four
  are fixed in this tree:
  - #176 `brief-pointers-reach`: the two allow rows in `settings.local.json` name the live paths. a
    `.radio/` record now reads as a dated route record
  - #177 `codediff-single-pane-keeps-the-view`: the installed codediff (2.43.15) keeps the view
    with no local wrapper, so the 2.41.1 wrapper is retired. the red arm forces the teardown it
    must see. 3 of 3 runs green
  - #178 `earlyoom-spares-the-session`: an absent earlyoom declines (exit 2). the new
    `prove.earlyoom-play-declines-when-absent` clamps both branches
  - #179 `headers-carry-their-weight`: 8 headers cut to an outline, with their narratives rehomed
    to the briefs that own them. `2.7.aliases/configure.verify.sh` moves its two verify functions
    and its SSH_AUTH_SOCK row into the bundle's `_.sh`
- **rework:** clean
- **confidence 75%, why not higher:** #177's root cause is inferred. no commit shows when the box
  moved from 2.41.1 to the lock. the retired wrapper rests on the probe's reads of the installed
  plugin

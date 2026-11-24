# F7 — shell-shape refactors held: the decline banner copy, positional args, a collector/fold split, play verdict branches

## .the fork
- **refactor now**
  - lift the 🌙 platform decline (banner + pad) into a runtime operation `bundle.platform.declines`
  - give `bump`, `unreadable`, `walk` named args (`key=value`)
  - flatten each play's `if … else … fi` verdict into guard + early return
- **hold** — keep the three as written; the pair parse, the dirname, the row split, and the pad
  each got a named transformer in this round

## .taken — hold
- **the banner** has three copies of its pad (`src/bundle.upgrade.sh`, `2.9.emoji/_.sh`, this
  bundle) and two of its decline. a runtime operation is the right home, and it reaches the runtime
  and a bundle this wish does not own — caught as a dream, never smuggled in. this bundle names its
  pad in `grove_provision_1_15_hibernate_pad`
- **the positional args** sit on three-line functions inside one file, each called with fixed
  literals of one kind per slot (`bump <epoch> <kind> <source>`). bash has no named args; a
  `key=value` parse adds more decode than it removes, and the clamp asserts every verdict line, so
  a swapped slot reads red
- **the check as collectors, a fold, and an actuator** — each reader emits rows, one fold picks the
  newest and counts. the readers are named and in narrative order, each truncates `$ERRS` on its
  own redirect (`2>"$ERRS"`), and the per-source counts landed. a fold would replace shared
  globals with rows and change no verdict; the sed path stays either way for the legacy bytes
- **the play verdicts** are two-way: pass prints ✔, fail prints ✋ and sets `FAILED`. a guard +
  `return` form needs a function per arm for no gain in a reader's pass; the check itself (prodcode)
  has no `else` left

## .the i009 asks, held on the same grounds
- **a ledger file in place of the globals** (the fold above, again). the hazard named is a future
  edit that wraps `unreadable` or `bump` in `$(…)` and loses the hold. the clamp sees exactly that:
  every `holdsloud` arm asserts the box HOLDS and exits 1 on an unread source, so a lost `UNREAD`
  sleeps the box and reads red on every `holdsloud` arm at once. the state fails open only past a red clamp
- **the bound sum as three declared names** (`READ_WINDOW`, `WORST_RUN`). the sum is read once in
  the drift play, through the bundle's one reader (`bound_of` → `declared`), and asserted under
  `TimeoutStartSec=`; `act_hibernate`'s `late` names the same three constants. a retune that edits
  one literal and not the sum reads red on `bounds`
- **the verify-only readers moved out of `_.sh`** into `configure.verify.sh`. the runtime sources a
  bundle's `_.sh` for every phase, and the drift play sources `_.sh` alone to reach `health`; the
  move re-wires both for a rule the upsert already keeps (it calls none of them — measured, 0)
- **a declared `PTS_TYPE`** so the clamp rewrites one head line rather than `-type c` in the body,
  and **a `stub <name> <body>` helper** for the clamp's printf stubs. both are play shape; the
  leak guard already fails on a `-type c` the rewrite missed

## .rework — clean
each is a local edit with its plays already in place to catch a slip.

## .confidence — 85%, and why it is not higher
`rule.forbid.positional-args` names bash outright, and a reviewer reads it as binding there.

## .where
`src/grove.provision/1.system/1.15.hibernate/_.sh`, `idle-hibernate.sh`, the five plays

## .verdict
open — best-guessed at 5.1

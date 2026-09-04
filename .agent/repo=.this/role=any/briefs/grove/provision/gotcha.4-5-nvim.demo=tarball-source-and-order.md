# demo: 4.5.nvim — why the tarball, and the order that avoids a lost apply

## .what

`4.5.nvim/provision.upsert.sh` installs from the official tarball, never a ppa, and checks
the pin BEFORE it asserts root. two measurements back both choices.

## m1 — the two neovim ppas, read directly

- `neovim-ppa/unstable` ships dev snapshots that double-emit `<CR>`/`<BS>` under kitty
- `neovim-ppa/stable` publishes NO neovim binary for ubuntu noble at all, deps only
- ⇒ the official tarball is the only source here that is self-contained and pinnable

## m2 — a sudo-first assert breaks the phase chain on an already-pinned box, grove-ahbode-v20260810, 2026-08-10

- the camper seat was already at the pinned v0.12.3. a `pkg_assert_sudo` as the FIRST
  statement still returned 1 — that seat holds no sudo by design
- `bundle.upgrade` reads a phase's non-zero return as a chain break. it skips every phase
  after it:

  ```
  ├─ 4.5.nvim.provision.upsert
  ✋ sudo needs a password, and no terminal is attached for it to ask on
  ├─ 4.5.nvim.provision.verify  — skipped; an earlier phase failed
  ├─ 4.5.nvim.configure.upsert  — skipped; an earlier phase failed
  ├─ 4.5.nvim.configure.verify  — skipped; an earlier phase failed
  ```

- `~/.config/nvim/init.lua` was never written, over work already done. the ✋ named the
  wrong cause: the camper never holds sudo by design, and "no terminal is attached"
  points a reader at a tty instead of the seat
- ⇒ an upsert whose goal already holds must ask what already holds BEFORE it asks for the
  privilege to change it. a goal that already holds needs no privilege at all

## .see also

- `4.5.nvim/provision.upsert.sh` — the header these measurements back
- `gotcha.4-5-nvim.demo=configure-verify-measurements` — the neighbor demo, the configure
  half rather than the install source
- `rule.require.errors-name-the-fix`

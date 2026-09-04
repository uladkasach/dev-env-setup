# demo: 5.2.rust — the sourced pin, and a two-writer collision it dodges

## .what

`5.2.rust` installs rustup's binary directly, never through `sh.rustup.rs`. it also
suppresses rustup's own rc edits. four measurements back both choices.

## m1 — a fresh ubuntu 24.04 grove ships no C compiler at all

- a fresh ubuntu 24.04 grove ships no compiler, where both prior images did
- cargo shells out to `cc`; with no compiler, every build dies at the link. rustup only
  WARNS about this, and a warn is easy to scroll past
- ⇒ the gap surfaces later as a build failure in an unrelated step

## m2 — `sh.rustup.rs` answers no hash at all, read 2026-08-13

- `sh.rustup.rs.sha256` answers no http code at all. an unversioned url names no fixed
  artifact, so no hash is expressible against it
- ⇒ the fix is a different ROUTE (the versioned binary), never a new check bolted onto
  the old one. the swap costs no capability — that installer fetches the same binary
  this bundle fetches directly

## m3 — the pin is SOURCED, and what that does and does not buy

- rust publishes a `.sha256` beside every archived artifact; this value was read
  from the `1.29.0` archive sidecar on 2026-08-13
- the sidecar shares a host with the binary, so one attacker could swap both — what
  makes it bite regardless is that the value now lives HERE, in git
- rust publishes no `.asc`/`.sig` for rustup-init, both 404, so the stronger check
  `5.6.aws` uses is unavailable here

## m4 — rustup's own rc-append collided with `2.5.zsh`'s byte ownership, 2026-08-14

- a grove built from scratch, one apply, then a plan:

  ```
  ✋ ~/.zshenv DIFFERS from the checkout
  262a263
  > . "$HOME/.cargo/env"
  ```

- the box read as converged. the red line named the INNOCENT bundle
  (`rule.forbid.two-writers-on-one-artifact`)
- the append was redundant the whole time: `src/zshenv.sh:101` already puts
  `~/.cargo/bin` on PATH, guarded. `~/.cargo/env` was sourced from `~/.zshrc` alone,
  which no program reads (`gotcha.a-tool-found-by-path-answers-only-a-human`)
- ⇒ `--no-modify-path` suppresses the rc edits. rustup still WRITES `~/.cargo/env`
  itself — the flag governs only rc files

## .see also

- `5.2.rust/provision.upsert.sh` — the header these measurements back
- `rule.require.verify-binary-downloads`
- `rule.forbid.two-writers-on-one-artifact`
- `gotcha.a-tool-found-by-path-answers-only-a-human`

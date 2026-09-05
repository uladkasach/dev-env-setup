# howdoes: `5.14.treesitter`'s pin, and what it does not bound

## .what

`5.14.treesitter/_.sh` pins `tree-sitter-cli` for one declared reason and carries
one known gap in what that pin covers. this brief holds both.

## why it is a bundle of its own, not a phase of `4.5.nvim`

inside `4.5.nvim`, `cargo install tree-sitter-cli` needs cargo, cargo arrives with
`5.2.rust`, and section 5 runs after section 4 — so a first apply could never
build it there. as its own bundle it sits right after `5.2.rust` instead, per
`howdoes.5-devtools-dispatch-order.md`.

## why a third-party build tool gets pinned

`cargo install tree-sitter-cli` with no version takes whatever crates.io serves
at apply time — a third-party registry account, and the crate it serves is
compiled and then RUN on this box, so an unreviewed publish is arbitrary code, as
this human, on the next apply. the criterion is who can publish, never what the
tool does (`5.3.brains/_.sh` carries the same split).

## what the pin does not bound

`cargo install` ignores the crate's own `Cargo.lock` unless `--locked` is passed,
so every transitive dependency still resolves fresh. a pin on the top-level crate
leaves that graph open.

`--locked` is the control that closes it, and it is not shipped here: it fails
the install outright when a crate publishes no lockfile or an out-of-sync one,
and this repo spends no unproven flag on the provision path
(`rule.require.one-command-provision`). prove it on a fresh grove first —

```sh
cargo install tree-sitter-cli --version 0.26.10 --locked
```

green there ⇒ add `--locked` to the upsert and delete this residue.

## how to bump

read what the box runs, decide, put it in `_.sh`, apply the bundle:

```sh
tree-sitter --version
```

## .see also

- `5.14.treesitter/_.sh` — the pin declaration this brief explains
- `howdoes.5-devtools-dispatch-order.md` — why this bundle sits at `5.14`
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9/m.13, why the pin lives in `_.sh`

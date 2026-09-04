# demo: emoji cli — the hazards found during the index and widget build

## .what

`define.emoji-cli-contract.md` states the contract. this brief holds the four
hazards found during the build of `src/emoji.index.build.sh` and
`src/emoji.zsh` — kept here so the contract stays a contract.

## m1 — the FE0F trap, cost ~40% of the set — ❤️ and ⚠️ among them

- CLDR keys `❤` as `2764`. emoji-test.txt lists the fully-qualified `2764
  FE0F`. U+FE0F is the variation selector that promotes a legacy dingbat to a
  color emoji — invisible, and absent from the CLDR key
- a byte-equality intersect drops every such pair. the first build kept 933
  by a naive byte match, against the full set once FE0F was stripped on both
  sides
- ⇒ match on the stripped form, emit the qualified form. the bare `U+2764`
  renders monochrome text-style, which is not what anyone means by the heart
  emoji. `❤️` and `⚠️` are canaries in the verify set — if they vanish, this
  regressed

## m2 — `trap '' PIPE` causes the error it means to prevent

- `trap '' PIPE` → signal **ignored**, so `write()` returns EPIPE and printf
  prints `write error: Broken pipe`
- no trap → default action, exit 141, which the rhx harness flags
- `trap 'exit 0' PIPE` → **handled**, quiet
- ⇒ ignore is not the same as handle

## m3 — `rhx` is not a measurement or pipe surface

- `rhx emoji.get --query rocket | wc -l` returns **4** for a one-emoji
  output — the banner is on stdout
- ⇒ never pipe rhx output, never benchmark through it

## m4 — a backtick inside double quotes is command substitution

- ``so `latest` is unpinnable`` prints as `so  is unpinnable`, plus a
  `latest: command not found` on stderr
- ⇒ in a message that names a moving ref, quote with single quotes or drop
  the backticks. this bit twice in one bundle

## .see also

- `define.emoji-cli-contract.md` — the contract these hazards back
- `src/emoji.index.build.sh` — the transform that carries the FE0F fix

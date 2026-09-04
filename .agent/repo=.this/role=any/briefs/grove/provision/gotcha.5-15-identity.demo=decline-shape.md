# demo: the "wrong-bundle decline" shape, three instances

## .what

a bundle's SECTION NUMBER asserts a dependency on a subject; the real dependency is a
tool or credential that a LATER section provides. each instance was found the same way:
a phase declined with "that comes later" instead of a relocation into the section that
owns it.

## the three instances

| # | bundle pair | the real dependency | lands in |
|---|---|---|---|
| 1 | `2.2.git` → `5.4.gh` | a github credential | section 5 |
| 2 | `4.5.nvim` → `5.14.treesitter` | cargo | section 5 |
| 3 | `2.2.git` → `5.4.gh` (identity) | the same credential as #1 | section 5 |

## .why "no human step is owed" reads as harmless and is not

- a decline that says *"the next apply completes it; no human step is owed"* is right
  that no human is needed and wrong that no defect exists
- two applies to converge one box IS the defect `rule.require.one-command-provision`
  names as a blocker, whether or not a human types anything
- see `term=decline._.choice.reason.md` for why a correct half of a decline hides the
  incorrect half

## .see also

- `5.15.identity/_.sh` — the third instance, now its own bundle
- `rule.require.one-command-provision`
- `term=decline._.choice.reason.md`

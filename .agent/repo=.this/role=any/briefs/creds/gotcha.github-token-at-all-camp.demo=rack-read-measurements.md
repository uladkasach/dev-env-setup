# demo: github-token-at-all-camp — the rack-read measurements

## .what

`rule.require.github-token-at-all-camp.md` states the one slug every github consumer reads.
these are the dated measurements behind its read-path and proof-of-work claims.

## m1 — the exit code cannot separate locked from absent, corrected 2026-08-25

- this rule used to claim a locked read "returns an empty string and exit 0". wrong — the
  rack's real answer, measured directly:

  | state | stdout | stderr | rc |
  |---|---|---|---|
  | present | the value | — | 0 |
  | locked 🔒 | empty | `status: locked 🔒` + an unlock tip | **2** |
  | absent 🫧 | empty | `status: absent 🫧` + a set tip | **2** |

- the CONCLUSION survived (a locked read does read as "no credential") and the cited
  MECHANISM did not (there is no zero exit)

⇒ locked and absent are both rc=2, so a caller that keeps only the exit code cannot tell them
apart — and they want opposite repairs, one of which (`keyrack set`) has no entry-only mode
and overwrites a live value. only the rack's own stderr tells them apart, which is why five
skills in this repo no longer drop that stream on 2026-08-25.

## m2 — proven end to end, 2026-08-05, rhachet@1.45.1

- both consumers draw from `@all.camp.GITHUB_TOKEN` on grove-1, measured separately since they
  read the rack by different routes: `gh repo list` ehmpathy/ahbode ✔ listed (ahbode incl.
  private repos); `git clone` ehmpathy/…, ahbode/… (private) ✔ both over plain https
- the read itself, cold, from `~`: 40 bytes, a classic pat, byte-exact
- the pat needs BOTH scopes: `repo` serves the clone, `read:org` serves discovery
- a scope change does not reach `gh` on its own: when the pat was re-scoped, `git` picked it
  up at once (it asks the rack on every fetch) and `gh` stayed refused (it holds a stored
  login taken once at apply time) — `rhx grove.provision --what 5.4.gh --mode apply` re-authed
  it

⇒ one slug, two consumers, two different staleness windows — the rack can be current while one
consumer's copy of it is not. that is the `entry`/`slug` split in a third costume.

## .see also

- `rule.require.github-token-at-all-camp.md` — the rule these measurements back
- `define.github-auth-two-paths.md` — the repo/discovery scope split m2 draws on

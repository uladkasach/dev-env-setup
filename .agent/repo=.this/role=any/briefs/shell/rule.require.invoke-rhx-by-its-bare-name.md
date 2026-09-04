# rule.require.invoke-rhx-by-its-bare-name

## .what

call a rhachet skill as `rhx <skill> …`. never `./node_modules/.bin/rhx`, and never
`npx rhachet run --skill <x>` where a bare `rhx <x>` reaches the same skill.

```sh
rhx git.grove.wake grove-1                      # 👍
./node_modules/.bin/rhx git.grove.wake grove-1  # 👎
npx rhachet run --skill git.grove.wake grove-1  # 👎
```

## .why

- **the bare name is the only spelling that travels.** `./node_modules/.bin/` is a
  fact about one checkout's layout. it is wrong on a grove, wrong in a worktree
  whose deps live elsewhere, and wrong the moment the package manager changes —
  so a command a reader copies from a doc or a comment fails for a reason that has
  no relation to the skill itself
- **the bare name is what every brief and every human types.** two spellings for
  one invocation is the synonym drift this repo kills everywhere else
  (`rule.forbid.domain-term-synonyms`)
- **`npx rhachet run --skill x` is the same skill under a longer name.** it is not
  a fallback for when `rhx` is absent; if `rhx` is absent, the devenv is unraised
  and the fix is `grove.provision`, not a second spelling

## .the one exemption

a **pretooluse hook line** in `.claude/settings.json` runs before any shell profile
is sourced, so it has no PATH to find `rhx` on. those lines name the binary by path
out of necessity. that is a hook-config concern, not a command a human or an agent
types (`rule.require.exemptions-name-their-trigger`).

## .if `rhx` is not found

that is a devenv defect, not a reason to reach for the path:

```sh
grove.provision --what 5.1.node --mode apply   # the bundle that puts rhx on PATH
```

## .enforcement

- a `./node_modules/.bin/rhx` invocation in a command, doc, comment, or play = **blocker**
- an `npx rhachet run --skill <x>` where `rhx <x>` reaches the same skill = **blocker**
- a hook line in `.claude/settings.json` that names the path = **exempt**, per above

## .see also

- `rule.require.wrap-cli-in-skills` — why the skill exists to be called at all
- `howto.wrap-a-shell-alias-in-an-rhx-skill.md` — how a new one is added
- `rule.require.install-via-procedures` — the same instinct: hand a human the
  reproducible command, never the local-layout one

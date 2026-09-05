# rule.require.bundle-slug-matches-its-path

## .what

a bundle's **numeric path** must equal its **directory path**. the number is not a label — it IS the
node's position in the tree, so it must agree with where the directory sits.

```
src/grove.provision/1.system/1.4.sysctl/          ✔  1.4 sits under 1
src/grove.provision/1.system/1.4.performance/
                   1.system/1.4.1.kernel/        ✋  1.4.1 claims to be under 1.4,
                                                     but it is a SIBLING of it
```

three things must agree for every node:

| the thing | must equal |
|---|---|
| the dir's numeric prefix (`1.4.1`) | its ancestors' numbers, plus its own segment |
| the function name (`grove_provision_1_4_1_kernel`) | the slug, with `.` → `_` |
| the `bundle.upgrade <slug>` line in the parent | the child dir's actual name |

## .why

### the framework's ONE claim is that the tree IS the directory tree

`grove.provision` holds no list of work. the root reads top-level DIRECTORIES; each body dispatches
its children by slug. that is the whole reason there is no second list to drift
(`rule.require.bundle-as-sole-declaration`).

a slug whose number disagrees with its path breaks exactly that claim. now the tree has **two
shapes**: the one the directories describe and the one the numbers describe. and a reader who trusts
either one is misled about the other — which is the two-lists defect this repo has killed four times,
smuggled back in as a naming inconsistency.

### it still WORKS, which is what makes it rot

📜 2026-07-29: `1.4.1.kernel` was created as a peer of `1.4.performance` under `1.system/`. the
run was unaffected — the recursive glob sources every `*.sh` at any depth, and bash does not care
where a function was defined. no error, no alarm, no failed verify. the only symptom was a
`1.4.1` beside a `1.4` in an `ls`.

⚠️ **a defect that costs no run today and misleads every reader tomorrow is the most expensive
kind**, because there is no failure to motivate the fix.

### `--what` reads the NUMBER, so a wrong number scopes wrongly

the `--what` filter matches on the numeric path (`bundle.num.of`), because a slug is
`<number>.<name>` and the name segment breaks a string prefix — `4.3.1.terminfo` is not
string-prefixed by `4.3.kitty`. so the number is load-bear machinery, not decoration:

- `--what 1.4` must reach `1.4.sysctl` and everything below it
- a node numbered `1.4.1` that actually sits elsewhere will be pulled in by `--what 1.4` from
  wherever it is, and excluded by `--what` for its real parent

that is a filter that silently selects the wrong set — the exact class of defect the numeric match
was written to fix.

## .the test

for each bundle dir, read its numeric prefix and walk UP:

> does every segment of my number, except the last, appear as the number of a directory above me?

- yes → the position is honest
- no → either move the dir, or renumber it. one of the two is wrong

and then, for the function:

> is my function name my slug with `.` replaced by `_`, and does my parent's `bundle.upgrade` line
> name my dir exactly?

## .the two fixes, and how to choose

when a number and a path disagree, decide which one states the truth:

| the intended relation | fix |
|---|---|
| it really IS a child of that parent | **move the dir** into the parent |
| it is really a peer | **renumber it** to a peer number |

in the `1.4.1.kernel` case neither answer was obvious — and that ambiguity was itself the signal. the
parent (`1.4.performance`) was named for a quality, so it could not answer whether `kernel` belonged
inside it. the real fix was to delete the parent and promote the child to `1.4.sysctl`
(`rule.require.bundle-names-name-their-subject`).

> when you cannot tell whether a node is a child or a peer, suspect the PARENT's name.

## .examples

### 👎 bad — number claims a parent it does not have

```
1.system/
├── 1.4.performance/     ← _.sh dispatches `bundle.upgrade 1.4.1.kernel`
└── 1.4.1.kernel/        ← but it lives HERE, as a sibling. it runs anyway.
```

### 👎 bad — function name does not match the dir

```
1.system/1.4.sysctl/_.sh
  grove_provision_1_4_1_kernel() { ... }     ← left over from a rename
```

this one DOES fail, loudly: `bundle.upgrade 1.4.sysctl` reports
`✋ 1.4.sysctl — undeclared; its bundle dir did not source`. that message is honest but points at the
wrong cause (it reads as an absent file), so the rename must be complete in one pass.

### 👍 good

```
1.system/
├── 1.3.browser/
│   └── 1.3.1.firefox/       1.3.1 sits under 1.3, which sits under 1
├── 1.4.sysctl/
└── 1.5.swap/

4.terminal/
└── 4.3.kitty/
    ├── 4.3.1.terminfo/
    └── 4.3.2.emulator/
```

## .enforcement

- a bundle dir whose numeric prefix does not match its directory ancestry = **blocker**
- a function name that is not its slug with `.` → `_` = **blocker**
- a `bundle.upgrade <slug>` line that names a dir which is not that bundle's child = **blocker**
- a renumber or a move applied to the dir but not to its function names, or the reverse = **blocker**
  (the rename must be complete in one pass, or the failure names the wrong cause)

## .see also

- `rule.require.bundle-names-name-their-subject` — the naming half of the same integrity, and the
  rule that usually explains WHY a position went ambiguous
- `rule.require.bundle-as-sole-declaration` — one declaration, in one dir
- `rule.require.grove-provision-bundles` — the tree, and `bundle.num.of`, which reads these numbers

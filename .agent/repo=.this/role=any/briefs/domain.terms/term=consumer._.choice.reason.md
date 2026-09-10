# domain.term.choice.reason: consumer

## .etymology

latin *consumere* — to take up entirely. software already carries the word in the
producer/consumer pair: one party writes, another reads and acts on what it read. that pair is
exactly the relation this repo has with the machine — the repo **produces**
`src/bash_aliases.sh`, and a shell **consumes** it.

the pair is what earns the word. `reader` names only half of it (a process opened the bytes) and
carries no obligation. a consumer *acts on* what it read, so it can refuse — and the refusal is
the whole reason the term exists here.

## .the case that pinned it

2026-09-05. an nvim leak fix had landed, and the sync aliases had been rewritten to honor
`DEV_ENV_SETUP_DIR`. before a `sync.devenv.bashaliases` could put that file on the live machine,
one check was owed: does it parse?

the obvious check is `bash -n src/bash_aliases.sh`. the filename says bash. the extension says
bash. the alias that syncs it is named `bashaliases`.

but the file's actual consumers are declared elsewhere:

```sh
# src/zshrc.sh
source ~/.bash_aliases            # line 119 — zsh reads it
export BASH_ENV=~/.bash_aliases   # line 124 — bash reads it
```

zsh sources it directly at login. bash inherits it through `BASH_ENV`. **two consumers, one
filename.** and `ductwork.sh` / `termwork.sh` inherit the same duality, because
`bash_aliases.sh` sources them — so they land in whichever shell read their parent.

had a bash-only construct entered that file, `bash -n` would have returned clean, the sync would
have printed success, and the next terminal would have failed to open — with a green check on
record.

## ⚠️ .a filename is a claim about one consumer, never the set

this is the durable lesson:

> **the consumer set is a property of who sources a file, and that is declared in a different
> file than the one under test.** the name cannot carry it, because the name was chosen before
> the second consumer arrived.

which makes the set *discoverable but not local*. `src/bash_aliases.sh` holds no evidence that
zsh reads it; the evidence is two lines in `src/zshrc.sh`. a check that reads only the file under
test can never derive its own scope.

this is a `proxy` in the exact sense the repo already names: a value measured (bash parses)
substituted for the value claimed (safe to source), with the condition (bash is the only
consumer) left unstated. by `rule.require.name-what-you-measured` the condition had to be named —
so `shell.test.syntax` prints the consumer set beside every result:

```
├─ ✔ src/bash_aliases.sh    bash, zsh
├─ ✔ src/zshrc.sh           zsh
```

the claim is now exactly as wide as the measurement.

## .why the set is declared, not derived

`consumers_of()` reads a hardcoded `DUAL_CONSUMED` list rather than a parse of `src/zshrc.sh`.
that is a **second copy**, and it can drift from the truth it mirrors — the same hazard `sync`
records.

held deliberately, for two reasons:

1. a parse of `source` lines is itself a proxy — a shell can source a path built at runtime, so a
   static scan would report a confident, incomplete set. a wrong set that looks derived is worse
   than a short list that looks like a list.
2. the report prints the set per file. so a drift surfaces as a consumer column that reads wrong
   to a human who knows the repo — a visible defect, rather than a silent gap.

the tradeoff is named rather than hidden, which is the most the `sync` lesson asks.

## .the neighbours

- **`proxy`** — the direct parent. "bash parses it" stood in for "safe to source"; the unstated
  condition was the consumer set. this term is the name of that condition.
- **`sync`** — the operation that would have delivered the unchecked file. a sync reports on a
  copy, not a delivery; a consumer set is what makes the delivered file *usable*. the two
  failures compose: a correct source path that delivers a file the target cannot parse.
- **`concern`** — `shell.test.syntax` emits its failures as `says` + `fix`, and the fix names the
  shell, because "it does not parse" without the consumer is not actionable.
- **`class`** — a consumer set is a set of runtimes charged with one file, much as a class is a
  set of processes charged as one cost. both exist because the singular reading misleads.

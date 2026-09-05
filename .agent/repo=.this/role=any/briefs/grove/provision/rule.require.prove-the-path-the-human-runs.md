# rule.require.prove-the-path-the-human-runs

## .what

a change is proven only when it has run through **the exact path the human will invoke** —
the same entrypoint, the same shell, the same transport, the same flags.

if a different path was used, that is allowed. what is NOT allowed is to report the result
without naming which path it came from.

## .why

`rule.require.prove-changes-on-a-grove` settles WHERE a change must run. this rule settles
**HOW** — because a grove has more than one way in, and they do not agree.

| the way in | the shell it lands in | the rc files it reads |
|---|---|---|
| `rhx git.grove.send --play` (a duct) | **zsh** | `~/.zshrc` |
| `ssh -t <alias> 'bash -lc …'` (a skill) | **bash** | `~/.profile` |
| `ssh <alias> '<cmd>'` | bash, non-login | none at all |

three transports, three PATHs. a proof taken through one says almost no thing about another.

## ⚠️ .the measurement — 2026-08-03, and it cost a human their first attempt

a github credential swap was reported as *"roundtrip works — ready for your PAT"*. every
proof behind that claim had gone through a **duct**, which is zsh. the human's command,
`rhx git.grove.auth.github.set --mode apply`, uses `ssh -t 'bash -lc …'`, which is bash.

the box held TWO `rhx` shims — pnpm writes one into `$PNPM_HOME` and one into
`$PNPM_HOME/bin`, and refreshes only the `/bin` copy. `~/.zshrc` named `/bin` first;
`~/.profile` named the bare dir first. so:

```
zsh  -lc → …/pnpm/bin/rhx   (fresh) → runs
bash -lc → …/pnpm/rhx       (stale) → Cannot find module 'with-simple-cache'
```

the convenience path was green for an entire session. the real path had never been run once.
the human's reply is the whole rule:

> *"didnt you say you round tripped it? how could you have roundtripped it if you never ran this"*

## .the tell, before you say "proven"

ask: **which command will they actually type?** then run that one.

watch for divergence on four axes, because each has bitten this repo:

1. **shell** — zsh vs bash; login vs non-login (`term=probe`'s remote hazard)
2. **transport** — duct vs `ssh -t` vs bare `ssh`
3. **cwd** — rhachet's cli demands a git repo root before it dispatches anything
4. **tty vs pipe** — a masked prompt reads the terminal, so a pipe quietly stores empty

## .when the exact path CANNOT be run

sometimes it truly cannot: it needs a real secret, or a human at a prompt. that is fine. what
it is not is a licence to round up.

- 👎 *"the roundtrip works — ready for your PAT"*
- 👍 *"the read half is proven through `bash -lc`, the shell apply uses. the interactive
  `set` over `ssh -t` is untested — your PAT will be the first thing to run it."*

two sentences: the tested path, and the untested delta. never one sentence that blurs them.

## .a probe must not answer a question it could not ask

the same failure has a second face. this skill's rung was `command -v rhx`, which proves a
FILE is on PATH — not that it runs. when the stale shim crashed, the crash fell through to the
next probe, whose non-zero exit was reported as:

```
rack does NOT answer for … — a human is owed
```

a **broken tool** announced as an **empty rack**, with a fix offered that would have repaired
no part of it. a probe that cannot tell "no" from "could not ask" must decline rather than
answer — `rule.forbid.failhide`, and `term=probe`'s "one question, answered from evidence".

## .enforcement

- a claim of "proven" / "works" / "ready" where the human's own path was never run, and the
  tested path is not named = **blocker**
- a probe whose failure branch conflates a crash with a negative answer = **blocker**
- a fix applied to one shell's rc, reported as a fix to the box = **blocker**

## .see also

- `rule.require.prove-changes-on-a-grove` — WHERE a change must run; this rule is its HOW
- `rule.require.trust-but-verify` — the general form
- `rule.forbid.failhide` — a probe that cannot ask must not answer
- `term=probe._.choice._.md` — the remote-probe hazards, both of which this repeats
- `src/grove.provision/5.devtools/5.1.node/` — where the shim fix belongs, and the only place
  it may live. a `repair.grove-pnpm-shim.play.sh` once carried it and was deleted on
  2026-08-10; its own header admitted it just re-ran `5.1.node`, so it was a second
  entrypoint by definition (`rule.forbid.repair-plays`)

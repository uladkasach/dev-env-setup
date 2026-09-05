# domain.term: bound

term.chosen   = bound
term.kind     = noun
term.synonyms.forbidden:
- timeout      (names ONE mechanism — the `timeout` binary. a bound may also come from the
                tool itself, `curl --max-time`. and a `--connect-timeout` is spelled the same
                way while it is NOT a bound, so the word cannot discriminate)
- deadline     (implies a wall-clock instant. a bound is a DURATION, applied per call)
- limit        (unqualified; this repo already spells rate, size, and depth limits)
- cap          (same, and it reads as a maximum VALUE rather than a maximum WAIT)
- guard        (a guard decides whether work runs; a bound decides how long it may take)
- retry budget (a retry policy bounds ATTEMPTS, and an unbounded attempt makes it infinite
                anyway — so it is a neighbour, never a synonym)

## .what
a **bound** is a TOTAL cutoff on how long a call may wait before it is treated as answered
"no".

⚠️ the word **total** is the whole term. a cutoff on one PHASE of a call is not a bound:

| what it caps | is it a bound? |
|---|---|
| `timeout 20 ssh …` — the whole call | **yes** |
| `curl --max-time 3` — the whole transfer | **yes** |
| `ssh -o ConnectTimeout=5` — the HANDSHAKE only | **no** |
| `curl --connect-timeout 5` — the connect only | **no** |

⇒ and the reason a partial cutoff is worse than none is that it inverts which case fails:
the **dead host** — which would have failed anyway — is cut short, while the **live host
that goes quiet mid-transfer** waits forever. so the benign case is bounded and the bad case
is not, which is exactly backwards, and it reads as diligence.

## .why the distinction is load-bear
a call with no bound does not fail — it HANGS. and a hang is worse than a failure on the one
path this repo cares most about: a failure ends a run and prints its reason, where a hang
holds the pane, and on a grove the pane IS the duct
(`rule.require.one-command-provision`, non-interactive).

## .a bound has an owner, and it is not always `timeout`
| source | example | this repo's read |
|---|---|---|
| the wrapper | `timeout 10 docker info` | always sound |
| the tool | `curl --max-time 3`, `aws --cli-read-timeout` | sound where the tool sets a TOTAL |
| the tool's DEFAULT | `aws`, 60s | sound, and it must be MEASURED, never assumed |

⚠️ that last row is the one that decides whether a check cries wolf. to demand a wrapper on
a tool that already bounds itself is to condemn `aws` on the strength of what `curl` does
(`gotcha.a-check-that-cries-wolf-gets-silenced`, measurement 6).

## .the neighbour it is most often confused with
a **guarantee** prevents a bad state; a **bound** converts an unbounded wait into a
reportable fact. so a bound does not make the far end answer — it makes its silence
legible, on a schedule.

## .refs
- .agent/repo=.this/role=any/briefs/evidence/rule.require.bounded-probes-in-verifies.md
- src/grove.web.sh                                              # `web_fetch --within`
- src/grove.provision/2.shell/2.8.tmux/_.sh                       # `timeout 5` on the ask
- src/grove.provision/5.devtools/5.10.repos/configure.upsert.sh   # the ConnectTimeout record

## .reason
see the ref-level cluster beside this choice:
- `term=bound._.choice.reason.md` — the dispute that settled `ConnectTimeout`, and why
  `timeout` was refused as the word

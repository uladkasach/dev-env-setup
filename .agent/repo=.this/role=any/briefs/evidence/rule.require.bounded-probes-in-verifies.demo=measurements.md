# demo: bounded-probes-in-verifies — the measurements behind the boundary

## .what

`rule.require.bounded-probes-in-verifies` states the current rule: every call that leaves the
process, in any phase, must be bounded and fed `</dev/null`. this file holds the measurements
that grew the rule from "verify only" to "every phase", and that built + hardened
`src/devenv.web.sh` as the one boundary every network call routes through.

## m1 — the scope was `*-verifies`, and the cost sat in `*-upserts`, 2026-08-13

for the rule's whole life its name, its clauses, and its examples all spoke of `*.verify`. a
sweep of the tree found **twenty-one unbounded network calls, every one in an UPSERT** —
eighteen bare `curl`, two bare `git clone`, and the bootstrap's own clone of this repo. every
one had sat there for the rule's whole life, in a repo whose reviewers had it loaded.

they were invisible for a reason unrelated to care: the rule's own name told a reader they were
out of scope. a grep for `verify` does not reach an upsert, and a human who reads a filename
does not re-derive the hazard.

⇒ an upsert is the WORSE half, not the lesser one: a hang in a verify costs the run's OUTPUT (no
map). a hang in an upsert costs the run's WORK — the provision itself never returns, on a box
with no human to notice, no terminal to interrupt, and a duct now wedged. and every one of the
twenty-one sites was guarded on "is this already here?", so a clean apply is evidence about the
SKIP path and says no word about the call.

⇒ the scope below is corrected to every phase, and this file's own name is the fossil that
proves why: a check keyed on a filename is a check keyed on last year's scope.

## m2 — the founding hang, 2026-07-30

`5.1.node.configure.verify` ran `bash -lc 'pnpm --version'` bare. `--what 5.devtools --mode
plan` hung on it and never returned.

this repo had already documented the same shape once: corepack's shim prints `Do you want to
continue? [Y/n]` on stdout and reads stdin, and `pnpm --version` was measured sitting in
`ep_poll` for 57 minutes on `grove-1` that way (`gotcha.5-1-node.demo=fnm-pnpm-install-measurements`,
m1). the second occurrence was written by somebody who knew about the first — evidence that a
rule, not a memory, is what this needs.

⇒ `bash -lc` sources whatever rc files the box holds, and any one of them may prompt, wait on
a lock, or reach the network. a verify cannot read those files ahead of time to rule the hazard
out, so it must assume its probe may block and convert the unbounded wait into a reportable
fact: `timeout N` plus `</dev/null`.

## m3 — a login shell CHATTERS, 2026-07-30

a bound stops the hang. it does not clean the answer. `bash -lc 'node --version'` printed
**two** lines on this laptop — a hello from an rc file, then `v22.21.0`. the phase reported the
whole capture, so the version it named was the hello.

⇒ same root as m2: arbitrary rc code prints. keep only the ANSWER, the last line, because the
command the probe asked for runs last:

```sh
timeout 10 bash -lc "$1" </dev/null 2>/dev/null | tail -1
```

## m4 — a bare `ConnectTimeout` cited THIS rule, and bounded the wrong half, 2026-08-13

nine sites were bounded this day — four `tmux` calls, one `tmux show-environment`, three
`docker info`, and `5.10.repos/configure.upsert`'s `ssh -o ConnectTimeout=5`. the last is the
one worth remembering: its comment cited this rule by name, two lines above a call that
violates the rule's own enforcement clause — *"a bare `ConnectTimeout` offered AS the bound =
blocker"*. the citation was true, the rule was real, and the reading was inverted:
`ConnectTimeout` caps the DEAD network, which fails anyway, and says no word about a live host
that completes the handshake and goes quiet — the ordinary failure through a NAT, which is the
topology every grove sits behind.

⇒ a rule cited beside its own violation is harder to catch than an uncited one, because the
citation is what a reader checks for (`gotcha.my-own-note-became-my-evidence`).

⚠️ `5.6.aws/configure.verify` was the sharpest of the nine: it runs on every `--mode plan`, and
asks the duct's OWN tmux server — the socket a wedged pane hangs on.

## m5 — the `aws` "60s" claim named the wrong quantity, 2026-08-14

a table of tool defaults (curl, git/http, ssh: none; aws: 60s) had read "60s" as a bound since
it was written. 60s is what one ATTEMPT may wait; the cli then retries, and a stalled endpoint
measured **182s over 3 attempts** (`prove.tool-defaults-are-bounded`).

⇒ a documented timeout is a bound only where the tool makes ONE attempt. multiplied by a retry
policy it is a phase cutoff that reads as a total — the table now records the attempt count
beside the number, for every tool.

## m6 — four tools measured, and one was invisible to the sweep, 2026-08-14

`prove.tool-defaults-are-bounded` points each tool at a listener that accepts a connection and
stays silent, with a 240s cap, and counts the listener's ACCEPTS so a tool that failed before
the wire reads `🌙 inconclusive` rather than a false ✔:

| tool | it returned | attempts | verdict |
|---|---|---|---|
| `gh` | rc=1 at 10s | 1 | `·` bounded, tightly |
| `aws` | rc=255 at ~183s | 3 | `·` bounded — the 60s claim was per-attempt (m5) |
| `cargo` | rc=101 at 30s | 1 | `·` bounded |
| `fnm` | rc=1 at 30s | 1 | `·` bounded |
| `npm` | never, cut at 240s | 2 | ✋ |
| `pnpm` | never, cut at 240s | 5 | ✋ |
| `corepack` | never, cut at 240s | 1 | ✋ |
| `flatpak` | never, cut at 240s | 1-10 | ✋ |

`cargo` and `fnm` were added to the play only after they were found invisible to it — the same
defect `corepack` had, the day before. both sit on a fresh grove's first-apply path, and `fnm
install --lts` is the head of the cascade `5.1.node` names: no node ⇒ no pnpm ⇒ no rhx ⇒ no
keyrack ⇒ no gh token ⇒ no org clone.

⇒ `corepack` was in NEITHER set before this run — not condemned, not reported, invisible. it is
the preferred half of `5.1.node`'s pnpm install, so the tree's most load-bear registry read was
the one no reader could see. a tool list hand-written inside a reader is a claim about what
reaches off the box, and unlike a discovered set it goes stale in silence.

⚠️ two of the four ✋ rows only surfaced because the probe itself was repaired: the first cut
scored `pnpm` and `flatpak` `🌙 inconclusive` — `npm_config_registry` did not redirect a
corepack-shimmed pnpm, and `flatpak remote-ls` takes a remote NAME rather than a uri, so each
measured its own argument parse in about a second. the accept-count is what caught both.

## m7 — the boundary grew a second cutoff: `src/devenv.web.sh`

the repair for m6's four ✋ rows is NOT a `timeout` at each site — that is the regression m1
already refused, and this measurement does not overturn it: a flat total kills a thin-link
install along with a stall. so the boundary layers two cutoffs that cap different halves,
exactly as `timeout 20 ssh -o ConnectTimeout=5` does:

```sh
web_npm      install -g <pkg>     # timeout -k 30 900  +  --fetch-timeout 60000
web_pnpm     install -g <pkg>     # timeout -k 30 900  +  --fetch-timeout 60000
web_corepack install -g <pkg>     # timeout -k 30 900          (no per-request knob)
web_flatpak  install …            # timeout -k 30 900          (no per-request knob)
```

the per-request half is what makes the total safe to set: a wholly dead registry fails on its
FIRST request, so an honest install never approaches 900s. the total is only the backstop that
makes the call RETURN.

## m8 — a bare `timeout` is a REQUEST, not a bound, 2026-08-14

`web_flatpak` carried a bare `timeout 900` with no `-k`, and a bare `timeout` sends only
SIGTERM at N — a child that catches, blocks, or ignores it outlives the call, and `timeout`
itself then WAITS for that child without end. one process's hang becomes two.

`flatpak` is the tool that refuses SIGTERM, measured rather than supposed: `web_flatpak` at a
20s total returned `rc=137` at **50s = total + grace** — direct evidence a real tool in this
tree refuses TERM. before the `-k`, that same wrapper held a grove's duct for ~60 minutes with
the play's verdict one line away.

⇒ `rc=137` at total+grace is the bound SUCCEEDING, and it is the stronger evidence — it is the
only outcome that proves the `-k` was load-bear rather than decorative.

⇒ 45 sites across the tree carried the bare form. `prove.timeouts-kill-what-they-cut` measures
the mechanism on a TERM-deaf child both directions — bare `timeout 3` still ran at 15s, `timeout
-k 2 3` ended at 5s with rc=137 — then refuses any bare `timeout` anywhere in the tree, with no
exemption list: `-k` is never the wrong choice, since on a well-behaved child the SIGKILL never
fires.

## m9 — the boundary's own flag had to be PROVEN to parse, 2026-08-14

`web_npm` / `web_pnpm` append `--fetch-timeout` to every registry call a fresh box makes. if
this box's npm rejected that flag, npm would exit before it reached the wire, and every install
would fail — on a first apply, and no other run. no converged box can see it, because no
converged box installs.

⇒ point each wrapper at a live stall with a 20s total: a cut at ~20s with rc=124 means the
flags PARSED and the total BIT; a fast exit with `unknown option` means the flag is rejected.
measured on a grove: `web_npm`, `web_pnpm`, and `web_corepack` each parsed and were cut at 20s —
the eight call sites that route through the boundary are proven to reach the wire, not merely
spelled correctly.

## m10 — the two copies that cannot route through the boundary

two sites reach a registry from outside the bundle tree, and neither can source
`src/devenv.web.sh` — an installed shell artifact has to work on a box with no checkout:

| site | what it does | why it is the sharper one |
|---|---|---|
| `src/zshrc.sh:236` | `npm install -g pnpm`, when pnpm is absent after an fnm switch | runs on shell START and after every `cd`. a duct pane IS a shell |
| `src/bash_aliases.sh:1575` | `pnpm install` after `git tree set --init` | backgrounded and disowned, so it leaks an orphan rather than wedge a shell |

the first is the sharpest unbounded call this repo has held: a stall there does not fail one
phase, it holds the PANE, and every command sent down that duct afterward queues behind it.
both now carry the two-layer pair as literals, clamped by `prove.registry-bounds-agree` — a
third declaration of two numbers is trusted only when a clamp refuses their disagreement.

## m11 — a `wait` with no operand joined a listener nobody meant to wait on, 2026-08-14

`prove.tool-defaults-are-bounded` — the play that produced m6's table — carried a `timeout`
inside every probe AND a watchdog above every probe, and still hung for 40 minutes, holding a
grove's duct until a human read the pane. the cause was one line, in neither place:

```sh
lpid="$(_listen "$port" "$tmp/$s.accepts")"   # `while True: accept()` — never exits
pids+=("$lpid")                                # …into the SAME array as the probes
…
wait                                           # 👎 waits on the listeners, forever
```

every probe returned. every number was measured. the verdict was one line away.

⇒ a bare `wait` is an unbounded probe with no subject. it asserts that every background job of
the shell is one you meant to join, and that assertion appears in no argument — it breaks
silently the day a second `&` lands anywhere above it. name the operand instead:

```sh
wait                      # 👎 every background job of this shell
wait "${ppids[@]}"        # 👍 the ones this play means to join
```

`prove.plays-name-what-they-join` is the clamp, static, over every play AND every skill, keyed
on the join rather than on whether some child terminates.

## .see also

- `rule.require.bounded-probes-in-verifies.md` — the current rule and boundary these
  measurements built
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.6 (a tool condemned only on a measured
  default), m.7 (the verb-blind reader that condemned two correct tight bounds)
- `gotcha.5-1-node.demo=fnm-pnpm-install-measurements` — m1, the earlier corepack hang this
  rule's founding measurement (m2) repeated
- `src/devenv.web.sh` — the boundary itself

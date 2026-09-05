# rule.require.bounded-probes-in-verifies

## .what

every call **any phase** makes against a shell, a network, or a package manager MUST be
bounded — wrapped in `timeout` (or its tool's own equivalent), and fed `</dev/null` so no
prompt can wait on stdin.

```sh
timeout 10 bash -lc 'node --version' </dev/null 2>/dev/null
```

🛑 **the filename says `-verifies`; the scope is every phase.** the name is a fossil of the
rule's first cut, kept for a human to rename — `rule.require.bounded-calls-that-can-block`
states the actual subject. do not trust the filename over this section.

## .why a hang is WORSE than a wrong answer

a wrong fact costs a reader one minute — run the command by hand and see the truth.

a **hang** costs the entire run. `--mode plan` never returns, so the reader gets no output at
all, not even the phases that already passed. a wrong answer is a bad map; a hang is no map.

an unbounded call in an UPSERT is the worse half: it hangs the provision's own WORK, on the
FIRST apply, on a box with no human to notice and a duct now wedged — the one run that a
converged box can never re-test. so the bar is never "is it likely to return" — it is "**can**
it fail to return". if yes, bound it.

## .why a login shell in particular

`bash -lc` is arbitrary code. it sources whatever rc files THIS box happens to hold —
`/etc/profile`, `~/.profile`, `~/.bash_profile`, and whatever those source in turn. any one of
them may prompt, may wait on a lock, may reach the network.

a verify cannot read those files ahead of time and rule the hazard out. so it must assume its
probe may block, and convert that unbounded wait into a reportable fact.

## .the two halves

| half | what it buys |
|---|---|
| `timeout N` | converts an unbounded wait into a bounded failure the phase can report |
| `</dev/null` | a prompt that reads stdin fails INSTANTLY, rather than cost the whole N |

both, or neither works well. with only `timeout`, every prompt costs the full N seconds. with
only `</dev/null`, a probe that blocks on a lock or a socket still hangs forever.

## .a login shell CHATTERS — keep only the answer

a bound stops the hang; it does not clean the answer. arbitrary rc code prints, so a probe must
keep only the last line — the command the probe asked for runs last:

```sh
timeout 10 bash -lc "$1" </dev/null 2>/dev/null | tail -1
```

## .what the failure message owes the reader

a bounded probe has two failure modes that look identical from outside — "absent" and "timed
out". the message must name both, because their fixes differ:

```sh
echo "   ✋ a non-interactive login shell canNOT find pnpm (or it timed out)" >&2
echo "      ⇒ a TIMEOUT here means corepack's shim asked a question and" >&2
echo "        waited on stdin — export CI=1 so it never prompts" >&2
echo "      read what a login shell gets: timeout 10 bash -lc 'pnpm --version'" >&2
```

## .scope

applies to any call, **in any phase** — `provision.upsert`, `provision.verify`,
`configure.upsert`, `configure.verify`, a play, or `devenv.bootstrap.sh` — that leaves the
current process:

- a login or interactive shell — `bash -lc`, `zsh -ic`, `ssh host cmd`
- a package manager — `pnpm`, `npm`, `corepack`, `apt`, `flatpak`
- any call that reaches the network — `curl`, `wget`, `git clone`, `git ls-remote`, `aws`
- any call that takes a lock — `apt`, `dpkg`, `flatpak`

it does NOT apply to a read that cannot block: `[[ -f ... ]]`, `grep` on a local file,
`command -v`, a `/proc` read.

### `timeout` is the general answer, and it is not the only one

a tool that bounds itself does not need an external wrapper — it needs its own bound SET,
because the defaults are the hazard. its own connect-timeout flag is not enough on its own: it
bounds the DEAD network (which fails anyway) and says no word about a live host that completes
the handshake and then goes quiet — the ordinary failure through a NAT, which is the topology
every grove sits behind.

| tool | its own bound | its default (attempts) |
|---|---|---|
| `curl` | `--max-time`, `--speed-limit`+`--speed-time` | connect 300s; **total: none** |
| `git` (http) | `http.lowSpeedLimit` / `http.lowSpeedTime` | **none** — its transport IS libcurl |
| `ssh` | `ConnectTimeout` | none |
| `aws` | `--cli-read-timeout` | 60s **per attempt**, 3 attempts (≈182s total) |
| `gh` | — | 10s, bounded |
| `cargo` | — | 30s, bounded |
| `fnm` | — | 30s, bounded |

### for the network, the answer is not a flag at all

a flag at each call site is twenty-one copies of one decision, and a drifted timeout is the
worst kind of drift: the copy that lost its bound looks identical to the copy that kept it,
right up until it waits forever.

⇒ every network call in this repo goes through **one boundary**, `src/devenv.web.sh`:

```sh
web_fetch <url> [--into <path>] [--within <seconds>]   # http
git_clone <url> <dir> [--within <seconds>]             # git
```

`prove.wire-fetches-are-bounded` stages a real stall against a listener that accepts and then
stays silent, confirms the bound cuts it at ~60s, and sweeps every phase for a call that still
goes bare.

### the OTHER road off the box — a tool that is not a fetch

`web_fetch` and `git_clone` cover the calls this repo makes to pull BYTES, not the calls it
makes to ask a QUESTION — `tmux show-environment`, `docker info`, `ssh -T git@github.com`,
`gh auth status`, `aws sts …`, `flatpak install`. `prove.offbox-reads-are-bounded` is the
second clamp: static, no network, no privilege, same answer on every box — it reads every
`*.upsert.sh` and `*.verify.sh` for a command position that reaches a party outside this
process.

it condemns a tool only where that tool's own default is MEASURED — never on the strength of
what a stricter tool does. the verdict, sourced:

| verdict | tools | source |
|---|---|---|
| ✋ | `curl`, `git`/http, `ssh` | table above: default none |
| ✋ | `tmux` | this repo — `2.8.tmux/_.sh` already wraps its ask; a wedged server never replies |
| ✋ | `docker` | dials a daemon socket; the cli sets no client-side cutoff |
| ✋ | `npm` `pnpm` `corepack` `flatpak` | measured — each held a silent endpoint past a 240s cap |
| `·` | `gh` `aws` `cargo` `fnm` | measured — each bounded, per the table above |

⚠️ the `·` set is reported and failed by nobody, on purpose: a `timeout 60` around `pnpm
install -g` fails a fresh box on a slow link that would otherwise have converged, so a guessed
bound trades a hazard nobody has seen for a regression on the one run this repo cannot re-test.
to promote a `·` to a ✋, measure that tool's default first.

`src/devenv.web.sh` layers two cutoffs for the four ✋ package managers, so a total that makes
the call RETURN never bites an honest install that fails fast on its first request:

```sh
web_npm      install -g <pkg>     # timeout -k 30 900  +  --fetch-timeout 60000
web_pnpm     install -g <pkg>     # timeout -k 30 900  +  --fetch-timeout 60000
web_corepack install -g <pkg>     # timeout -k 30 900          (no per-request knob)
web_flatpak  install …            # timeout -k 30 900          (no per-request knob)
```

### a bare `timeout` is a REQUEST, not a bound

| form | what it sends at N | what a child may do |
|---|---|---|
| `timeout N cmd` | **SIGTERM** | catch it, block it, ignore it — and outlive the call |
| `timeout -k <grace> N cmd` | SIGTERM at N, **SIGKILL** at N+grace | no escape — SIGKILL cannot be caught, blocked, or ignored |

a bare `timeout` around a TERM-deaf tool does not merely fail to cut the call — `timeout`
itself then waits for that child, without end, so it adds a second process to the same hang.
`prove.timeouts-kill-what-they-cut` refuses any bare `timeout` anywhere in the tree, with no
exemption list: `-k` is never the wrong choice, since on a well-behaved child the grace costs
zero.

### two copies cannot route through the boundary

`src/zshrc.sh` (an `npm install -g pnpm` fallback, run on shell start and after every `cd`) and
`src/bash_aliases.sh` (a backgrounded `pnpm install`) reach a registry from outside the bundle
tree, where `src/devenv.web.sh` cannot be sourced — an installed shell artifact must work on a
box with no checkout. both carry the two-layer pair as literals, and
`prove.registry-bounds-agree` clamps every literal against the boundary's own numbers: a third
declaration of one bound is trusted only when a clamp refuses its disagreement.

### a bound inside a probe is not a bound on a JOIN

a `wait` with no operand joins every background job of the shell, not merely the ones a play
means to join. that assertion appears in no argument, so it breaks silently the day a second
`&` lands anywhere above it:

```sh
wait                      # 👎 every background job of this shell
wait "${ppids[@]}"        # 👍 the ones this play means to join
```

`prove.plays-name-what-they-join` clamps every play and skill on this, keyed on the join rather
than on whether some child terminates — which is undecidable.

## .eleven measurements built this rule

📜 the rule above did not arrive whole — it grew from "verify only" to "every phase", and
`src/devenv.web.sh` grew its second cutoff, across eleven measured incidents.
`.refs = rule.require.bounded-probes-in-verifies.demo=measurements, m1-m11`.

## .the paved form

declare one bounded probe helper per bundle and route every probe through it, so the bound is
declared once rather than repeated at each call site:

```sh
# .what = run one command in a login shell, bounded, with no stdin to block on
grove_provision_5_1_node_login_probe() {
  timeout 10 bash -lc "$1" </dev/null 2>/dev/null
}
```

## .enforcement

- an unbounded call that leaves the process, in **any** phase = **blocker**
- an unbounded call in an `*.upsert` = **blocker**, and the more expensive one — it hangs the
  provision itself, on the FIRST apply, which no converged box can re-test
- a network call that does not go through `web_fetch` / `git_clone` = **blocker**, even where
  it carries its own correct bound — one boundary, or twenty-one copies that drift
- a `--connect-timeout` (or a bare `ConnectTimeout`) offered AS the bound = **blocker**; it
  bounds the benign case and leaves the stall unbounded
- a bounded call with no `</dev/null` = **blocker** (a prompt costs the full timeout)
- a `wait` with no operand, in a play or a skill = **blocker** — it joins every background
  job of the shell, so one never-exit child anywhere above it is a hang, and on a grove that
  hang holds the duct rather than one check
- a registry call in an installed shell artifact (`zshrc.sh`, `bash_aliases.sh`) with no
  total bound = **blocker**; the RC copy runs on every shell start and after every `cd`
- a literal bound that disagrees with `WEB_REGISTRY_*_SECONDS` = **blocker**, and a
  disagreement in the other direction too: a **tight** bound on a LOCAL read
  (`timeout 60 pnpm bin -g`) is correct, and to widen it to the registry total is a
  regression
- a failure message that names only "absent" and not "or it timed out" = **nitpick**

## .see also

- `rule.require.bounded-probes-in-verifies.demo=measurements.md` — the eleven measurements
  that grew this rule and its boundary
- `rule.require.one-command-provision` — the bar an unbounded upsert defeats outright
- `rule.require.upgrade-entries-verify-themselves` — why a verify exists at all
- `gotcha.pipefail-grep-q.md` — the other class of defect that hides inside a verify
- `gotcha.a-check-that-cries-wolf-gets-silenced` — why a converged box cannot test this; m.6
  is why the play condemns a tool only on a measured default, m.7 the verb-blind reader that
  condemned two correct tight bounds
- `rule.forbid.tty-as-a-proxy-for-a-human` — the adjacent lesson about what a shell can assume
- `src/devenv.web.sh` — the one boundary every network call goes through

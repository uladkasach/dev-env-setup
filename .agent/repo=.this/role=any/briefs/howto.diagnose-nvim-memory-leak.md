# howto.diagnose-nvim-memory-leak

## .what

the path from "nvim keeps dying" to a named plugin and a one-line fix. four steps, each a skill,
each answering a question the prior one could not.

worked once, 2026-09-03: 63 watchdog trips over six weeks → `neominimap` makes minimaps of its
own minimaps.

## .the ladder

| step | skill | the question it answers |
|------|-------|-------------------------|
| 1 | `rhx machine.usage.diagnose` | is nvim even the problem? |
| 2 | `rhx nvim.diagnose.watchdog` | is it a leak, and in which dimension? |
| 3 | `rhx nvim.diagnose.watchdog --history` | which sessions, and how bad? |
| 4 | `rhx nvim.diagnose.watchdog --bufs` | **what are they** — the culprit |

do not skip. each step narrows the next, and step 4 needs a live core, which is the one thing you
cannot get after the fact.

---

## step 1 — is it nvim?

```sh
rhx machine.usage.diagnose
```

read the `nvim:` row and the `census`. the row quotes the watchdog's own verdict rather than a
re-derivation, because the watchdog sees inside the process and no external tool can.

```
├─ 🌕 nvim:   2 watchdog trips in 24h, watchdog STAMPEDE, 90 bufs
```

a trip means a core crossed 1.2G. more than one trip in a day means it is not an accident.

## step 2 — which dimension grows?

```sh
rhx nvim.diagnose.watchdog
```

this is the step that decides everything after it. the watchdog logs rss beside four other
dimensions, and **the one that moves with rss is the leak**:

| what moved | verdict | the fix |
|------------|---------|---------|
| `bufs` | a buffer leak | find what opens them (step 3-4) |
| `ts` | treesitter | the breaker handles it |
| `marks` | an extmark leak | `--marks` names the namespace |
| `chans` | a job/channel leak | a shell-out whose close is missed |
| `lua_kb` | a lua-side leak | a retained table/closure — reachable, findable |
| **none of them** | a **native** leak | lua gc has no lever; suspect image data or parser state |

⚠️ if the report says the fields are absent, the machine runs an older instrument than the repo.
sync first, or every verdict below is blind.

## step 3 — which sessions, and how bad?

```sh
rhx nvim.diagnose.watchdog --history
```

groups every climb by **cwd**, because "which repo makes nvim explode?" is the question a human
actually holds — a pid answers nothing once the process is gone.

```
2877M peak   805M floor   10708 bufs   sql-dao-generator...
1498M peak   800M floor   34354 bufs   rhachet-briefs-ahbode...
```

read the `bufs` column. a human opens tens of buffers. **34,354 is a leak, and its presence in
every row makes it systematic rather than one bad session.**

## step 4 — what ARE they?

```sh
rhx nvim.diagnose.watchdog --bufs
```

steps 1-3 read the log, which holds counts and no identities. this queries a **live core** and
groups its buffers by filetype + buftype + named + loaded. the filetype is the plugin's signature.

```
1367  neominimap  nofile  scratch  loaded
1342  -           nofile  scratch  loaded
   5  everything else
```

there is the culprit. and the **ratio** is the second finding: 1367 artifacts against 5 real
source buffers is 273:1, far past the ~1:1 a correct per-buffer plugin would show. that ratio is
what separates a bounded leak from an `amplifier`.

⚠️ this step needs a live nvim with an rpc socket. a plain `nvim` does not listen. start one with
`nvim --listen /run/user/$(id -u)/nvim.diag.0`, or pass `--sock <path>`.

---

## .the two lessons this hunt paid for

### a repeated trip is evidence the remedy misses

63 trips is not 63 problems. it is **one problem, unaddressed, 63 times**. the breaker ran
`Neominimap off`, which hides minimap *windows* and deletes no buffers — so it reported a remedy
each time and freed nothing.

> a breaker that fires once worked. a breaker that fires weekly has its lever attached to the
> wrong thing. check `reclaimed_mb` on the trip line.

### a default is a guard someone else wrote

`exclude_buftypes` held `nofile` by default, which kept minimaps off scratch buffers. this repo
emptied it for a good and stated reason — codediff's panes are `nofile` and must be mapped.

the removal was correct. the defect was that the default carried **two** jobs and only one was
known:

- the job we knew: keep minimaps off scratch buffers
- the job we did not: keep minimaps off **minimaps**

> to remove a default for a reason is fine; to remove it with no enumeration of what it held is
> to inherit an unknown liability.

the fix restores the guard at the intended width — `neominimap` in `exclude_filetypes` — rather
than undo the codediff support.

## .the tells of an amplifier

this leak was an `amplifier`: its own output re-entered its own input. the tells, in the order
they appear:

1. a class grows while no member is large → `machine.diagnose.class`
2. the count is a near-multiple of another count → `--bufs` ratio
3. a kill helps, then it returns on a schedule → the trip record
4. the rate rises with the load → **no skill covers this yet**

## .see also

- `domain.terms/term=amplifier._.choice._.md` — the structure this leak had
- `domain.terms/term=watchdog._.choice._.md` — why the log is the evidence, never the existence
- `domain.terms/term=stampede._.choice._.md` — why 40 log lines can share one timestamp
- `rule.require.name-what-you-measured` — the rule that caught three defects in these very tools
- `howto.diagnose-machine-slowness` — the tier above: is it nvim, or the box?

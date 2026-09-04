# rule.require.judge-declared-state-not-live-state

## .what

when you check whether a machine is configured correctly, read the **declared**
state — `/etc/fstab`, a systemd unit, a config file, a repo manifest — not the
**live** state, like `swapon --show`, `ps`, or `ss`.

live state may be reported as context. it must never carry the verdict.

## .why

live state is a *consequence* of declared state, rebuilt at every boot. so it
fails as evidence in both directions:

- **it goes quiet exactly when it matters.** right after a boot or a resume, the
  live signal can be entirely absent while the declared state stands ready to
  re-arm the very problem you checked for. the checker reports clean, and the
  next boot brings the defect back.
- **a live fix does not hold.** `swapoff`, `kill`, `ip link down` all look like
  repairs and are not — the declaration reinstates them. a repair that skips the
  declaration is a pause, not a fix.

a checker that misreports is worse than no checker, because its verdict is
trusted (`rule.forbid.failhide`, and the same lesson `verify.devenv.parity`
already earned).

## .the incident that earned this

`configure_swapfile` added `/swapfile`, swapped it on, and wrote it into
`/etc/fstab` — on a grove whose kernel resumes from a *different* target that
`ec2-hibinit-agent` had registered. hibernate refused.

two checkers were written to catch it, and the first draft of each read the live
state:

| checker | read | outcome |
|---------|------|---------|
| the guard in `configure_swapfile` | `swapon --show` | quiet on a poisoned box |
| `verify.swap.hibernate-safe` | active swap | reported **SAFE** on a poisoned box |

both were run on a freshly resumed grove-1, which had **no active swap at all**
— while `/etc/fstab` still named the bad file. the live read said clean; the
declaration said broken. the declaration was right.

the live "repair" was equally hollow: `sudo swapoff /swapfile` fixed that boot
and only that boot, because the fstab line swapped it back on at the next one.

## .how

1. name the declaration that owns the state (`/etc/fstab`, a unit file, a manifest)
2. judge on that
3. report live state alongside, labelled as transient
4. repair the declaration **first**, then reconcile the live state to match

## .examples

### 👎 bad — the verdict rests on a transient signal

```sh
if swapon --show=NAME --noheadings | grep -qx /swapfile; then
  echo "conflict"   # silent right after a resume, when no swap is active yet
fi
```

### 👍 good — the verdict rests on the declaration

```sh
if awk '$3 == "swap" && $1 !~ /^#/ {print $1}' /etc/fstab | grep -qx /swapfile; then
  echo "conflict — armed at every boot"   # true whatever this boot happens to hold
fi
```

### 👍 good — repair the declaration before the live state

```sh
sudo sed -i '\|^/swapfile |d' /etc/fstab   # the durable damage, removed first
sudo swapoff /swapfile                      # then reconcile this boot
```

## .the test

> "if i reboot this box right now, does my verdict still hold?"

- yes → you read the declaration
- no → you read a shadow of it

## .enforcement

- a config check whose verdict rests on live state where a declaration exists = **blocker**
- a repair that mutates live state without the declaration that reinstates it = **blocker**
- live state reported as context, clearly labelled transient = fine

## .see also

- `rule.forbid.failhide` — why a checker that misreports outranks no checker
- `rule.require.solve-at-cause` — the declaration is the cause; live state is the symptom
- `src/grove.provision/1.system/1.5.swap/configure.upsert.sh` — the declaration is written
  HERE and nowhere else. a `repair.swap.hibernate-conflict.play.sh` once healed old boxes and
  was deleted on 2026-08-10 (`rule.forbid.repair-plays`); a guard that defers on new boxes but
  heals no old one is an incomplete UPSERT, not a reason for a play

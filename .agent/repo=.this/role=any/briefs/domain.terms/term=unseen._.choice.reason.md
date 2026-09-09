# domain.term.choice.reason: unseen

## .etymology

plain english, and chosen for exactly that. *un-* + *seen* — the past participle of an act of
perception. the word's grammar puts an **observer** in the sentence: something is unseen *by
someone*. every rejected candidate drops that observer and speaks about the resource instead.

that grammatical difference is the whole term. `missing` says the resource is at fault. `unseen`
says the looker could not see. only one of those is a claim the tool is entitled to make.

## .the case that pinned it

2026-09-06. `machine_resource_procs_find_orphan` listed nine strays and offered a single
`kill -9`. six were chromium:

```
🪲 1426679 (chrome): /proc/1426682/fdinfo
🪲 1426683 (chrome): /proc/1426682/fdinfo
🪲 1426742 (chrome): /proc/1426682/fdinfo
```

they were **live playwright browser processes**, and their parents were alive too — 1426683's
ppid is 1426679, which is itself in the process table. a kill would have taken down a running
browser automation session.

the predicate:

```sh
if [[ "$cwd" == *"(deleted)"* ]] || [[ ! -d "$cwd" ]]; then
```

two clauses, joined by `||`, and they ask **different questions**:

- **clause one** reads a suffix the kernel writes. when a directory is unlinked, the kernel
  appends a literal ` (deleted)` to `/proc/<pid>/cwd`. that is testimony about the *target*, and
  it holds no matter who reads it.
- **clause two** asks whether the path is visible **in the observer's namespace, with the
  observer's permissions**. that is testimony about the *reader*.

chrome's zygote chdir's to `/proc/<crashpad-pid>/fdinfo` as sandbox hardening. that pid had since
exited, so the path was gone from every namespace — while the processes that chdir'd there were
healthy. clause two fired on a fact about a *third* process, and charged it to these.

## ⚠️ .an absence has an author, and the author decides whether you may act

this is the durable lesson:

> **an absence is never self-attesting.** something is absent *according to someone*, and the
> license to act comes from **who** — never from the absence itself.

the kernel is the only party whose testimony about a process's cwd is universal. every other
reader speaks from a namespace, a uid, a mount table. a test that does not name its attester has
silently promoted the observer's viewpoint to a fact about the world.

this is the `proxy` shape again — the **eleventh** instance in these tools: the observer's view of
a path substituted for the target's cwd state, with the condition (same namespace, same
permissions) left unstated (`rule.require.name-what-you-measured`).

## .why the fix reports rather than drops

the unseen set could have been discarded. it is kept, printed as `🫥` beneath the strays, because
it carries real information — just not the information the orphan hunt sought:

```
·  🫥 1426679 (chrome): /proc/1426682/fdinfo
·     ↳ cwd unreadable FROM HERE (a sandbox namespace, or a /proc path
·       whose pid exited). not a stray — the kernel did not say deleted
```

a human who sees a `/proc/<pid>/` cwd learns how chrome sandboxes itself. a human who sees the row
vanish learns none of that, and may re-derive the whole investigation later. so the row stays,
with its epistemic status printed beside it.

the `🫥` glyph does the same work the `host` marker does in the churn report: it says *this is real
and it is not yours to cut*.

## .why the kill moved behind a probe

the fix also changed what happens to the **genuine** strays. they were offered as a bare
`kill -9 <all>`; they are now offered behind a probe:

```
├─🪄 read the family before you cut:  ps -o pid=,ppid=,etimes=,args= -p ...
└─🪄 then, if idle:  kill -9 ...
```

because a deleted cwd says a process outlived its directory — it does **not** say the process is
idle. the three real strays on this box were `bwrap`, `bwrap`, `xdg-dbus-proxy`: firefox's sandbox
wrappers, adjacent pids to a live browser. a kill on the wrapper set risks the browser.

that is the `host` lesson applied one term over: a report may name what it found, and must not
convert a finding into an irreversible act it cannot justify.

## .the neighbours

- **`orphan`** — the term this one guards. an orphan is attested (the parent exited, the kernel
  reparents); an unseen cwd is not attested at all. the two were fused in one `||` predicate.
- **`proxy`** — the parent form, eleventh instance. observer visibility proxied for target state.
- **`host`** — the sibling lesson from the day before, same shape: a report ranked a container as
  a culprit and offered a kill. both fixes are "hold the un-actionable finding apart, and mark it".
- **`concern`** — sharpened again: a fix must be runnable, justified by what was measured, **and**
  attested by a party entitled to say it.

## .disputes

### note on the OPEN `adrift` dispute  —  2026-09-06
this round edited the exact predicate the `adrift` dispute concerns (see
`term=orphan._.choice.reason.md`). the dispute proposes that the cwd-deleted sense be renamed
`adrift`, keeping `orphan` for the unix sense (a live process whose parent exited).

this round **strengthens the case and does not settle it.** the split performed here is
attested-vs-unseen, which is orthogonal to the orphan-vs-adrift naming question — after the fix
the hunt still calls a cwd-deleted process an `orphan`, which is still the second sense.

left OPEN, unchanged: the rename edits a label a human reads daily, and per
`rule.always.defer-fulcrums-to-last` the rework is clean, so it waits on a human verdict rather
than a unilateral change to their vocabulary.

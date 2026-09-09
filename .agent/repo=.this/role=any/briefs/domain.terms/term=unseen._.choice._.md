# domain.term: unseen

term.chosen   = unseen
term.kind     = adj
term.synonyms.forbidden:
- missing
- deleted
- gone
- invisible
- inaccessible

## .what

a resource the **observer cannot read, where the target can** — so its absence is a fact about
*who looked*, never about the resource.

the word marks a **finding that must not be acted on**. an unseen path is not a defect; it is the
boundary of the instrument. to report it as a defect is to charge a process for the observer's own
blindness.

the two states it separates:

| | attested | unseen |
|---|---|---|
| who says so | the kernel, about the target | the observer, about itself |
| holds for | every reader | this reader only |
| is it actionable | yes | **no** |

## ⚠️ .the hazard the word must carry

**an unseen resource and an absent one are indistinguishable at the point of the test.** both make
`[[ ! -d "$cwd" ]]` true.

they diverge for every sandboxed process on a desktop — chrome zygotes, bwrap/flatpak,
xdg-dbus-proxy — because those live in a different mount namespace than the tool that inspects
them. and for any path under `/proc/<pid>/`, where the pid may have exited while the process that
chdir'd there stays healthy.

measured 2026-09-06: six **live** playwright chromium zygotes were listed as strays and offered to
`kill -9`. their cwd was `/proc/1426682/fdinfo` — chrome's sandbox-hardening chdir — and pid
1426682 had exited. the path was gone from the observer's view; the processes had live parents and
were perfectly healthy.

so a test for absence must ask **who attests it**, and only a kernel-attested absence licenses an
action.

## .refs

**the contracts:**

- `src/install_env.pt1.system.performance.sh` — `machine_resource_procs_find_orphan` splits
  `ORPHAN_INFO` (kernel-attested ` (deleted)` suffix) from `UNSEEN_INFO`; the unseen set prints as
  `🫥` below the strays and is never offered for kill

**the origin:**

- 2026-09-06 — the orphan hunt offered `kill -9` on six live chromium zygotes whose cwd was
  unreadable from the observer's namespace

## .the boundary

| word | what it implies | fits? |
|------|-----------------|-------|
| **unseen** | this observer could not read it | ✅ locates the fact in the observer, where it belongs |
| `missing` | it ought to be there and is not | ✗ asserts about the resource; that is the claim we cannot make |
| `deleted` | the kernel unlinked it | ✗ the canonical opposite — an attested fact, and the one that IS actionable |
| `gone` | it ceased to exist | ✗ same overreach as `missing`, in fewer letters |
| `invisible` | it is hidden by design | ✗ implies intent; a namespace boundary hides by accident of structure |
| `inaccessible` | permission was refused | ✗ names one cause of many — a namespace split is not a permission denial |

`missing` loses on the sharpest point: it is the word a reader reaches for by habit, and it makes
exactly the claim the observer is not entitled to.

## .reason

see the ref-level file beside this choice:

- `term=unseen._.choice.reason.md` — etymology, the chromium zygote case in full, and why an
  observer-relative test can never license an irreversible act

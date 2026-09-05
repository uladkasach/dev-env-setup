# rule.require.bundle-names-name-their-subject

## .what

a bundle's name must name **the thing it declares** — a package, a file, an interface, a device, a
service. it must NOT name:

- a **quality or outcome** — `performance`, `reliability`, `security`, `optimization`, `hardening`
- a **layer** — `kernel`, `system`, `userland`, when used as a container for unrelated concerns
- a **concern**, when the bundle's own files implement one specific thing under it

and the name must hold at **every level of the path**. if `1.3.browser/` holds firefox's phases
directly, the name is wrong at that level: the dir says concern, the files say implementation.

## .why

### a name for a quality has no boundary, so it becomes a junk drawer

you cannot install `performance`. so no bundle can OWN it — and every bundle can *claim* to serve
it. that means a dir named for a quality has no test for what belongs inside, so it accumulates
whatever a writer felt was related. six months on, `1.4.performance` holds sysctl, swap, three
diagnostic commands, and a systemd timer, and its `_.sh` header cannot say what unites them because
the only thing that does is a vibe.

a name for a **subject** has a boundary built in. `1.4.sysctl` writes `/etc/sysctl.conf`. a reader
knows what belongs and, more importantly, what does not — and the next concern is forced to declare
its own bundle rather than drift into this one.

### the tell: two unrelated bodies in one phase file

📜 2026-07-29: `1.4.performance/1.4.1.kernel/configure.upsert.sh` held BOTH `sysctl` keys and
the whole swapfile procedure — a two-line config append beside a
`fallocate`/`mkswap`/`swapon`/`fstab` sequence with a hibernation-conflict guard.

that is not one concern, and the reason they landed together is the whole lesson: **the category
above them was too vague to separate them.** a subject-name would have refused the merge, because
"a swapfile" is plainly not "a sysctl key".

> when one phase file holds two bodies that fail differently and prove differently, look UP. the
> parent's name is usually the defect.

### a layer is not a parent

the same draft nested `1.4.1.kernel` under `1.4.performance`, which asserts that the kernel is a
subset of performance. it is not — it is a layer that many concerns touch. a layer name as a
container invites everything that touches that layer, which is the junk-drawer failure again with a
technical-sounding name on it.

### the concern/implementation mismatch leaks

`1.3.browser/` with firefox's four phases directly inside reads fine until the second
browser-adjacent concern arrives — another browser, a shared mime default, an enterprise policy
file. it has nowhere to go but INTO the firefox files, and then `1.3.browser` silently means
"firefox plus whatever else showed up".

the fix is to name each level for what it holds:

```
1.3.browser/          the concern     — which browser, and how the box reaches one
└── 1.3.1.firefox/    this browser    — its build, its profile, its extensions
```

a node with a single child earns its line when the two levels answer **different questions**. "which
browser does this box use?" is not "is firefox installed and configured?" — the first has an answer
that could change; the second is about one artifact.

## .the test

three questions, all of which must pass:

1. **can you point at it?** a package, a file, a socket, a device, a binary. if the answer is a
   feeling ("responsiveness") or a category ("system"), the name is wrong.
2. **does the name refuse things?** a reader must be able to say "no, that does not belong in here".
   if any plausible concern could be argued in, there is no boundary.
3. **does the name match the files at THIS level?** a dir named for a concern must hold children, not
   an implementation's phases.

## .examples

### 👎 bad

```
1.4.performance/            a quality — cannot be installed, refuses no concern
└── 1.4.1.kernel/           a layer as a container
    └── configure.upsert.sh  ← holds BOTH sysctl keys AND the swapfile. the tell.
```

```
1.3.browser/                a concern
├── provision.upsert.sh     ← but these install FIREFOX specifically
└── configure.upsert.sh
```

### 👍 good

```
1.4.sysctl/                 names the interface it writes
1.5.swap/                   names the resource it allocates
1.3.browser/                the concern
└── 1.3.1.firefox/          the implementation, one level down
```

```
4.3.kitty/                  names the program
├── 4.3.1.terminfo/         names the entry it installs
└── 4.3.2.emulator/         names the artifact — the terminal binary itself
```

## .the one legitimate use of a broad noun

a **section** at the top level may name a domain area (`1.system`, `2.shell`, `4.terminal`,
`5.devtools`) because its job is to group and order, and its number is the namespace. that license
stops at depth one: a section's CHILDREN must each name a subject.

`1.system` is fine. `1.system/1.4.performance` is not.

## .enforcement

- a bundle named for a quality or outcome (`performance`, `security`, `reliability`, `hardening`,
  `optimization`) = **blocker**
- a bundle named for a layer, used as a container for unrelated concerns = **blocker**
- a bundle dir named for a concern whose own phase files implement one specific thing = **blocker**
  (nest the implementation)
- one phase file that holds two bodies which fail and prove differently = **blocker**, and the fix
  is usually a rename of the PARENT
- a section (depth one) named for a domain area = **allowed**; its children must still name subjects

## .see also

- `rule.require.grove-provision-bundles` — the tree these names live in
- `rule.require.bundle-slug-matches-its-path` — the position half of the same integrity
- `rule.require.bundle-as-sole-declaration` — one concern, one dir, no second home
- `rule.require.ubiqlang` (mechanic) — one canonical word per concept
- `rule.forbid.term=helpers` (mechanic) — the same defect in a different costume: a name that
  refuses no candidate carries no information

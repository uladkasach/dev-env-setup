# demo: zshrc.sh — the OSC sink, the cwd hooks, and every measurement behind them

## .what

`2.5.zsh/zshrc.sh` installs as `~/.zshrc`, the INTERACTIVE half of the shell (the program half
is `~/.zshenv` — `gotcha.2-5-zsh.demo=zshenv-reaches-every-zsh`). its hooks fire on every `cd`,
so most of what is measured here is a hook that ran where nobody expected it.

## m1 — the OSC SINK is settled OUTSIDE the `[[ -t 1 ]]` block

every writer to `$_osc_sink` is a `chpwd` hook, and a `chpwd` hook fires on every `cd` — a `cd`
inside a `$( )` among them, where fd 1 is a PIPE and `[[ -t 1 ]]` is FALSE. a sink declared
inside that block is UNSET at the one moment it is most needed, and `>$_osc_sink` redirects to
an EMPTY filename.

📜 2026-09-14, after the sink was first placed inside the block:

```
$ zsh -ic true | wc -c
_grove_fnm_use_on_cd:2: no such file or directory:
0
```

the byte count went green and the shell still spoke — on stderr, where the count could not see
it. a clamp that reads one stream is half a clamp. `_grove_fnm_use_on_cd` proved it: it sits in
the `command -v fnm` block, which has NO tty gate, so it runs under a pipe.

- the assignment is DUPLICATED inside the tty block on purpose — idempotent, so the pair cannot
  disagree, and a reader at the emitters finds the sink beside them
- `; }`, never `{ … }`: zsh accepts the bare form, and bash reads the `}` as an argument to `:`,
  leaves the group open, and reports it a hundred lines later at an innocent `fi`. the file is
  read by `prove.dual-shell-files-hold-no-bash-only-syntax`
- `-w /dev/tty` is NOT the probe: `access(2)` reads the node's mode bits, `crw-rw-rw-` on a box
  with no ctty as readily as on one with. only an OPEN answers

## m2 — the sink is the TERMINAL, never stdout

📜 2026-09-14: both OSC emitters `printf`ed to STDOUT, and both are `chpwd` hooks, so ANY `cd`
inside a command substitution poured their bytes into the capture:

```
eval "$( cd "$HOME"; pnpm completion zsh )"
  ✋ (eval):1: command not found: ^[]7
  ✋ (eval):1: no such file or directory: file://pop-os/home/vlad^G^[]2
  ✋ (eval):1: command not found: ~^G#compdef
```

the OSC 7 body is `$HOME`, the OSC 2 title is `~`, and `#compdef` is the first line of `pnpm
completion zsh` — three producers glued into one string and RUN in the human's shell. an OSC
sequence addresses the TERMINAL, and a capture is not one, so the sink is `/dev/tty`, which stays
the terminal where fd 1 is a pipe — for every future `cd` in a `$( )`, not one call site at a
time. the sink is settled ONCE, not per `cd`, since these run on every directory change.

## m3 — `stty erase '^?'` is DECLARED in the rc, never appended by `4.3.1.terminfo`

`2.5.zsh` owns `~/.zshrc` by BYTE — its upsert `cp`s the file, its verify demands `cmp -s`. any
other bundle that appends to it breaks that verify on the next run.

📜 grove-1, 2026-07-31, with `4.3.1.terminfo` appended: a full-tree run left `2.5.zsh`'s plan at
`✋ ~/.zshrc DIFFERS from the checkout` PERMANENTLY — apply it and terminfo re-appends on the next
pass. terminfo itself never went red, since its verify accepts the marker in EITHER rc and
`~/.bashrc` still carried it. one bundle quietly broke another's claim and paid no price.

the marker comment `# grove.provision:4.3.1.terminfo` is kept VERBATIM: terminfo's verify greps
both rc files for it. terminfo keeps `~/.bashrc`, which no bundle byte-owns.

## m4 — a DIRECTORY NAME is untrusted input inside an OSC string

- a linux dir name may hold any byte but `/` and NUL — BEL among them, and BEL ENDS an OSC 7.
  a dir named `x<BEL><ESC>]52;c;<b64><BEL>` closes the cwd report and hands the terminal a
  fresh OSC 52, which with `set-clipboard on` WRITES THE HUMAN'S CLIPBOARD
- it is REACHABLE: `git.grove.pull` writes a tree the GROVE named, and the human `cd`s in
- a `// /%20` alone encodes SPACES only — the control bytes are the whole hazard (m.12)
- a PARAMETER EXPANSION, never `__duct_strip_escapes`: this runs on every `cd`, the sink is three
  processes, and `${x//[[:cntrl:]]/}` is none. it cuts every byte that can END the string
- the same strip rides the OSC 2 title and the two tmux pane options — a second path to the same
  terminal. one rule, every emitter (m.9)

### 🛑 the BOUND of `[[:cntrl:]]`, measured 2026-08-31 — it does NOT reach C1

one payload (`x\a\e]52;c;ZXZpbA==\a\177\302\233Y\233Z`), one utf-8 locale, `//`:

```
zsh 5.9   left a bare `9b`             (it DID cut the encoded `c2 9b`)
bash 5.2  left `c2 9b` AND bare `9b`   (it cut neither form)
```

- the residue HERE is one raw `9b`, which a utf-8 terminal draws as U+FFFD — it drives no
  sequence, and kitty is utf-8 only. the guard is sufficient for ITS OWN subject, and a claim of
  "covers C0, DEL and C1" is wider than its reach (m.4)
- 🛑 the bash row is why the bound is written down: `bash_aliases.sh` is sourced by BOTH shells,
  so this primitive is WRONG there, and that file uses the sink instead (`term=holder`)

## m5 — the fnm cwd hook is OURS, and it cannot prompt

fnm's generated hook calls `fnm use --silent-if-unchanged`, not `--install-if-missing`. when a
`.nvmrc` pins a version the box lacks, fnm ASKS, on stdin, in whatever shell did the `cd`:

```
Can't find an installed Node version matching v22.21.0.
Do you want to install it? answer [y/N]:
```

📜 grove-1, 2026-08-03, on a plain `cd` into a checkout: the call sat 4m16s. a duct IS tmux, so the
question holds the pane and consumes the NEXT command sent as its answer — a corrupted command
stream, not a slow shell (`rule.forbid.tty-as-a-proxy-for-a-human`). `5.1.node`'s baseline narrows
the odds; the hook closes the hole, since every cloned repo brings its own `.nvmrc`.

- our OWN function name, never an override of `_fnm_autoload_hook` — an upstream rename would
  silently unhook the override, on a box nobody watches
- the guard tests fnm's own three files (`.node-version`, `.nvmrc`, `package.json` via
  `engines.node`, which `FNM_RESOLVE_ENGINES` enables by default)
- `eval "$(fnm env)"` is NOT here: it moved to `~/.zshenv` (#140), and a copy here would fork a
  second time and mint a SECOND per-shell dir over a var that already holds one
- ⚠️ do NOT wrap `fnm use` in a timeout: its fetch was measured BOUNDED on 2026-08-14, so a
  wrapper is a second bound — a false ✋ with a plausible fix (q7)

### 🛑 the RESIDUE — a grove picks which node the laptop fetches and runs

the three guard files are DATA, and `GROVE_BOUNDARY_EXCLUDES` (`.git node_modules .log .temp
.agent/.cache`) lets all three ride `git.grove.pull` untouched. one `cd` into a landed tree and
`--install-if-missing` acquires the pinned build — an old release with published CVEs is a legal
pin, and `{"engines":{"node":"12.0.0"}}` suffices.

- the REACH is the SHELL SESSION: the hook has no revert arm, and `fnm use` re-points the
  per-shell symlink. a `cd` OUT runs none of this, so the pin holds in the human's own repos
- 🛑 do NOT add a revert arm: it would fire on every `cd` out of every CORRECT checkout —
  hundreds a day — and argue with correct behavior far more than with the residue (q7)
- the bound that holds: fnm fetches from nodejs.org's feed, and the mirror is an ENV var
  (`FNM_NODE_DIST_MIRROR`) a pulled FILE cannot set. a grove picks the VERSION, never the SOURCE

## m6 — `fnm use`'s stdout goes to the sink, the THIRD writer of the 2026-09-14 repair

```
$ zsh -ic true | wc -c
20
$ zsh -ic true | cat -A
Using Node v22.21.0$
```

`fnm use` prints that to STDOUT whenever the version changes; `--silent-if-unchanged` quiets only
the no-op. it was a BOOT PRINT a human is asked to act on none of, and — as a `chpwd` hook — it
poured into any `$( )` that landed in a pinned tree. so it goes to the sink, like the OSC
emitters. STDOUT only: an absent version, a failed fetch, and a refused install report on stderr,
and to sink those would be a failhide.

## m7 — `_ensure_pnpm_after_fnm`: rooted, bounded, pinned, and `cd -q`

### 🛑 ROOTED AT `$HOME` — a package manager reads CONFIG from the cwd

this is a `chpwd` hook, so the cwd is whatever dir the human just entered — routinely a tree a
grove wrote. the cwd reaches the call as CONFIGURATION:

- a project `.npmrc` names the REGISTRY this fetch asks, and `_authToken` for it
- a `packageManager` field names a version a corepack shim FETCHES and EXECUTES
- `CI=1` removes the consent prompt — so the grant that ends the stall also makes the fetch silent

it must be a SUBSHELL: a bare `cd` would move the human's own dir out from under them.

### 🛑 `cd -q`, never a bare `cd`

this function IS a `chpwd` hook, so a bare `cd` re-fires every hook, THIS ONE INCLUDED. a subshell
bounds the blast and does not stop the re-entry. `-q` suppresses `chpwd` and `chpwd_functions`,
which is right on its own terms: this cwd is CONTAINMENT, never a place a human went.

📜 2026-09-14, one counter, one hook:

```
bare cd  -> fired=1
cd -q    -> fired=1      ← the hook did not run
```

`prove.rc-hooks-never-reach-a-capture` re-proves it on every box.

### ⚠️ BOUNDED — the sharpest bound in the repo

📜 2026-08-14: `npm install` against a listener that accepts and stays silent NEVER returned, cut
at 240s over 2 attempts. this line sits in a shell RC, so it runs on every shell start and after
every `cd` — a stall here does not fail one phase, it WEDGES THE PANE, and every command sent down
that duct queues behind it.

- the two-layer bound from `src/grove.web.sh`: `--fetch-timeout` (per request) and `timeout -k`
  (the total backstop). `--version` is bounded too: a corepack shim may FETCH there (m.9)
- 🛑 the `-k 30` is what makes 900 a BOUND: a package manager mid-transaction may ignore TERM, and
  a bare `timeout` did NOT end a TERM-deaf child at five times its limit (2026-08-14,
  `prove.timeouts-kill-what-they-cut`)
- the numbers are a COPY of `WEB_REGISTRY_*_SECONDS`: an RC must work on a box with no checkout,
  so it cannot source the boundary. the copy is CLAMPED by `prove.registry-bounds-agree`

### 🛑 PINNED, and `--ignore-scripts`

a bare `npm install -g pnpm` is `pnpm@latest`, in the one repo whose own bundle refuses that by
name (`5.1.node/provision.upsert.sh`: *"an undeclared pin is a HARD stop rather than a fall back
to `@latest`"*). and npm is NOT pnpm 10: pnpm denies lifecycle scripts by default, npm RUNS them —
so whoever publishes `pnpm` had code execution here, on every shell start.

- the floor is a COPY of this repo's `packageManager`, for the RC reason above. `5.1.node` still
  installs the per-repo version, which governs a converged box
- 🛑 the clamp for THIS copy is OWED: `prove.registry-bounds-agree` reads the two second-counts
  and not this. the absence of a ✋ is not agreement

## m8 — pnpm completions: the call that pipes into `eval`, and needed the root MOST

📜 2026-09-01: the THIRD `pnpm` call in the block got NONE of the containment the other two
carry, eight lines below the header that spells out why. and it is the one whose BYTES `eval`
runs in the human's shell — a `packageManager` field names the version corepack fetches, and
that program's stdout is what `eval` executes.

- the cwd here is the SHELL'S START cwd: any launcher that roots a new shell at an inherited dir
  reaches it — `tmux.conf`'s `respawn-pane -c '#{pane_current_path}'`, kitty's `launch
  --cwd=current`, its `boss.launch(--cwd=…)`, and `duct.reboot`. a `cd` into a pulled tree and a
  new pane is the whole trigger
- 🛑 `[[ -t 1 ]]` makes it WORSE, not safer: a duct pane IS a tty, where a consent prompt wedges
  the pane. `CI=1` removes the prompt
- the `eval` stays OUTSIDE the subshell: functions defined in `( … )` die with it
- `cd -q` is the second half of the 2026-09-14 repair: four hooks are registered by then, and the
  sink already keeps their bytes out — but `_grove_fnm_use_on_cd` would switch this shell's node
  mid-capture, from a `.nvmrc` the cwd chose, and `pnpm` is a node program

## m9 — the pnpm PATH pair lives in `~/.zshenv`, and its cause is the CWD

the pair and its order are measured in `gotcha.2-5-zsh.demo=zshenv-reaches-every-zsh`, m7. two
facts belong here:

- 📜 grove-1, 2026-08-02: with only `$PNPM_HOME` named in the rc, `pnpm install -g rhachet`
  refused in a duct — `The configured global bin directory "…/pnpm/bin" is not in PATH` — while
  the same install ran clean in a bundle. it read as "pnpm is broken", not "this PATH is short"
- 📜 2026-08-06 (`diagnose.pnpm-bin-dir-per-cwd`): the order is a TIEBREAK, never the fix:

  ```
  cwd = a repo   packageManager pnpm@10.24.0 → 10.24.0 → $PNPM_HOME
  cwd = $HOME    no package.json above it    → 11.20.0 → $PNPM_HOME/bin
  ```

  corepack's `pnpm` is a DISPATCHER, so two pnpms write global shims to two dirs at once. the fix
  is at the source: `5.1.node` pins corepack's default to the declared version and prunes fossils
- ⚠️ do NOT re-declare `PNPM_HOME` here: `.zshenv` is read by every zsh, interactive ones too, and a
  second copy is the two-writers defect this repo has paid for three times

## m10 — `~/.cargo/env` stays here as the HUMAN's copy

it exports more than PATH (the rustup shims a human's `rustc`/`rustup` want). the PATH half is
ALSO in `~/.zshenv`, since nvim-treesitter execs `tree-sitter` (zshenv demo, m3).

## m11 — the emoji widget is zsh-only, ordered, and guarded

- it loads AFTER compinit (it wraps a completion widget) and AFTER fzf (so its TAB bind wins)
- zsh only: it calls `zle` and `bindkey`, so it cannot live in `~/.bash_aliases`, which
  `BASH_ENV` makes every bash source
- the `-f` guard is load-bear: `2.9.emoji` DECLINES on a box with no human, so a grove holds no
  such file, and the guard keeps every duct pane silent

## m12 — no claude flag is exported here

every claude flag lives in `5.3.brains`'s settings patch, since claude copies the `env` block into
`process.env` at startup. the "must be a shell export" notes cited no read site and were false —
`howto.silence-claude-cli-nags`, *the shell-export shelf was a GUESS*.

## .see also

- `2.5.zsh/zshrc.sh` — the file these measurements back
- `gotcha.2-5-zsh.demo=zshenv-reaches-every-zsh` — the program half
- `prove.rc-hooks-never-reach-a-capture` · `prove.rc-is-quiet-on-boot` ·
  `prove.dual-shell-files-hold-no-bash-only-syntax` · `prove.registry-bounds-agree`

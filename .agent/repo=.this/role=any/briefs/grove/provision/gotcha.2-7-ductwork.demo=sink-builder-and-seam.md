# demo: ductwork.sh — the escape sink, the registry builder, and the one ssh seam

## .what

`2.7.aliases/ductwork.sh` holds three security seams. its headers keep the outline; this
file keeps the measurements and the long arguments behind them. the VERIFY's own claims
about those seams live in `gotcha.2-7-aliases.demo=duct-security-seams.md`.

## m1 — a remote-chosen name became a laptop path (`__duct_as_registry_file`)

- four readers joined a name to a path inline — `register_host`, `register_duct`,
  `unregister_duct`, `get_duct_host`. the grammar had four holders and no reader
  (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
- the `ducts/` pair was the expensive one: `duct.list --refresh` asks a grove's tmux for
  its session names and writes one file per answer. a grove is assumed compromised, so
  those are remote-chosen bytes that became a LAPTOP PATH — an arbitrary `mkdir -p`, and a
  write over any `*.json` this human can write
- ⇒ a session named `../../.claude/settings` lands on `~/.claude/settings.json` and
  replaces it with a two-key object: no `hooks` block, no `permissions` block — every
  pretooluse gate in this repo, removed by a `duct.list` (`rule.require.security-paramount`)

### 👎 a `..` deny-list, refused

it names one shape of the attack rather than the property the path needs — a character
deny-list by another name (`rule.require.solve-at-cause`). `mkdir -p` plus a `.json` suffix
leaves plenty of shapes a list must then grow to hold, and the day it misses one it is
silent.

### 👍 the ALLOWED grammar, the one the URI already advertises

a name is one or more segments of `[A-Za-z0-9._-]`, and no segment may be `.` or `..`.
`..` fails because it is no legal SEGMENT, never because it was enumerated.

the refusal is a hard return. to write the row anyway under a scrubbed name would be a
false ✔ — the registry would hold a duct whose real name it lost.

### the reach of the verify's join count, and the bound it cannot cross

`2.7.aliases`'s configure.verify counts joins that name the registry dir LITERALLY, on one
line, and demands one. it holds the additive regression — a fifth reader that writes
`"$DUCTWORK_DIR/ducts/$name.json"` inline takes the count to 2. it does NOT hold an alias:

```
local base="$DUCTWORK_DIR/ducts"     # counts 1
printf '%s\n' "$base/$name.json"     # counts 0 — the total stays 1, green
```

- ⇒ read the row as *"no NEW literal join was added"*, never *"every join goes through
  here"*. the second is true of the tree today and only a human re-read can renew it (q11)
- 🛑 do NOT widen the pattern to `"$<var>/$<var>"`. it would flag `bash_aliases.sh`'s
  worktree paths, `git-credential-keyrack.sh`, `zshenv.sh`, and every `$GROVE_SRC/…` in the
  bundle phases — well over 200 correct lines in `src/`. that is round 15's deleted reader
  rebuilt: a false ✋ at scale, which decays into a silenced check

## m2 — the refusal path is the ONLY place a grove-chosen name is printed

the builder's refusals relay a grove-chosen value, so they use `printf` with the values as
ARGUMENTS — never `echo`, and never in the format.

- the guard fires BECAUSE the segment holds a byte outside `[A-Za-z0-9._-]`, and `\` is such
  a byte. so the escape-shaped name is exactly the one that reaches the refusal
- the byte sink has no work to do on it: `\`,`0`,`3`,`3`,`]`,`5`,`2` are all PRINTABLE, so it
  correctly passes them (`term=relay._.choice._.md`, property 2)
- zsh's builtin `echo` then EXPANDS `\033` and authors a real OSC 52 clipboard write
- and a `%` in a grove-chosen name would be a printf directive if it sat in the format

📜 measured 2026-09-01, both dialects, over a payload with NO 0x1b in it — just the
printable characters `\`, `0`, `3`, `3`:

```
bash  echo "$said"  → four printable characters. inert ✔
zsh   echo "$said"  → 1b 5d 35 32 …  an OSC 52 CLIPBOARD WRITE
```

`2.5.zsh/zshrc.sh` sources this file into an interactive zsh, and the duct verbs are
functions there with no `bash -c` wrapper — so the unsafe half is the half a human types.
the same verb rule holds at `__duct_say_unreachable`'s replay and `duct.send`'s BUSY
refusal: one cause, several effects.

## m3 — a terminal OBEYS a grove's bytes (`__duct_strip_escapes`)

- a terminal is an ingress boundary, and the one nobody guards. a grove's stdout is
  remote-chosen bytes, and a terminal does not merely DISPLAY those — it OBEYS them. so
  `cat` of a grove file is `eval` at the emulator
- this repo's kitty config sets `set-clipboard on`: OSC 52 lets the far side WRITE THIS
  HUMAN'S CLIPBOARD. the next paste into any shell is text a grove chose, and a paste is a
  command a human vouched for — a reach with no ssh, no credential, and no prompt
- strip by CLASS: every C0 but TAB and LF, plus ESC and the C1 range. an allow-list of
  harmless sequences is the same mistake as a deny-list — OSC 52 is one payload of many
  (OSC 8 hyperlinks, DCS, the title set-and-report pair), and a list must grow forever
- it is a FILTER, never a check: a caller that compares output to a hash compares the RAW
  bytes, and pipes only the copy a human reads

### 📜 2026-08-31 — one `tr` over `\177-\237` DESTROYED utf-8

that range is 0x7F-0x9F, and 0x80-0x9F is a subrange of utf-8's CONTINUATION bytes:

```
in    ├─ tag=<ESC>[31mred<ESC>[0m 🐢
out   342 342  tag=[31mred[0m  360 242
```

- `├` is E2 94 9C; both 0x94 and 0x9C fall in that range, so only E2 survived. 🐢
  (F0 9F 90 A2) came out as F0 A2. every box glyph and every emoji the duct relays was
  corrupted, on every read, from the day the sink was written
- ⇒ not cosmetic: `git.grove.pull` prints the member at fault to justify a refusal, and
  `git.grove.push` prints the paths a `--delete` would take. the sink ate the very evidence
  its callers exist to show
- ⚠️ the probe the file PRESCRIBED could never have caught it — `printf
  'a\033]52;c;ZXZpbA==\007b\tc\n'` is pure ASCII, and a fixture of ASCII cannot see a
  defect whose subject is non-ASCII (m.12). the probe now carries a box glyph AND an emoji,
  and lives in `2.7.aliases`'s configure.verify, since a check nobody runs decays (m.13)

### the THREE stages, and why one `tr` cannot be all of them

1. `tr` — the C0 block and DEL, by byte. these are single-byte characters in valid utf-8,
   so they never sit INSIDE a multi-byte sequence and a byte-wise cut is exact. TAB and LF
   are kept on purpose: they are the only control bytes ordinary output carries
2. `iconv -c` — DROP every byte that is not valid utf-8. this retires a RAW C1 byte (a bare
   `\233` is CSI to an 8-bit terminal and invalid utf-8 everywhere else), and it makes
   stage 3 a FIXED POINT: afterward every `\302` is followed by `\200-\277`
3. `sed` — cut U+0080..U+009F as CHARACTERS, spelled `\xC2\x80..\xC2\x9F`. iconv keeps
   these since they are valid utf-8, and a terminal still obeys U+009B as CSI

⚠️ the ORDER is load-bear: a `\302`, a C0 byte, then `\233` is invalid utf-8. cut the C0
byte first and it becomes `\302\233` — a legitimately encoded CSI the sink itself
synthesized, which stage 2 or 3 then retires. reverse stages 1 and 2 and it walks out.

⚠️ `iconv` is glibc, so its absence is a broken box, not a supported one.

### 📜 2026-09-01 — the sink owns its own `pipefail`

*"`set -o pipefail` turns an absent stage into a non-zero exit"* was a claim about the
CALLER's shell state, which a function cannot know. measured with `iconv` hidden behind a
crafted PATH:

| tree     | caller   | rc    | bytes out | raw ESC |
|----------|----------|-------|-----------|---------|
| healthy  | pipefail | 0     | 16        | none    |
| healthy  | bare     | 0     | 16        | none    |
| crippled | pipefail | 127   | 0         | none    |
| crippled | bare     | **0** | 0         | none    |

- row 4 is the falsification: a caller with default options was told the strip succeeded
- ✔ and the SAFETY half was true all along: every crippled row emitted ZERO bytes, so no
  unstripped byte ever reached a terminal. the defect was purely in the SIGNAL
- ⚠️ that is why it survived. a claim whose dangerous half is true reads as verified at
  every spot check, and the false half is the half no test looks at
- ⇒ the subshell carries `set -o pipefail`, so the exit code holds at every caller. a
  subshell rather than `local -`, since this file is sourced by bash AND zsh

### 📜 2026-08-31 — measured in BOTH directions

```
printf 'a\033]52;c;ZXZpbA==\007\302\233X\233Y\tb \342\224\234 \360\237\220\242 z\n' \
  | __duct_strip_escapes | od -An -tx1

61 5d 35 32 3b 63 3b 5a 58 5a 70 62 41 3d 3d 58
59 09 62 20 e2 94 9c 20 f0 9f 90 a2 20 7a 0a
```

- ATE, as it must: `1b` (ESC), `07` (BEL), and `9b` in both spellings — the OSC 52 survives
  only as inert text (`]52;c;ZXZpbA==`)
- LET THROUGH, as it must: `09` (TAB), `e2 94 9c` (├), `f0 9f 90 a2` (🐢)
- ⇒ that pair is the whole claim, and `2.7.aliases`'s configure.verify re-asks it on every
  `grove.provision`, against the INSTALLED copy

## m4 — ssh hands its arguments to a SHELL (`__duct_ssh_tmux`)

`ssh host "tmux send-keys -t '$S' '$what' Enter"` is the shape ten call sites would each
spell. ssh joins its arguments into one line for a login shell on the far side, so a single
quote in any interpolated value closes the quote, and every byte after it runs as the seat
that owns the duct.

two of those values are attacker-reachable, and neither is exotic:

- `$DUCT_SESSION` carries a BRANCH NAME, and `git check-ref-format` permits a single quote
- `$pane_cwd` (`duct.reboot`) is read OFF THE REMOTE BOX — a compromised grove hands its own
  text back, and the local shell runs it (the inversion
  `rule.require.narrowest-terminal-grant` closes at the terminal)

⚠️ a character DENY-LIST reads as if it closes this, and does not. `git.grove.send` refuses
`;`, `&&`, `||`, and a newline — the four a HUMAN types to chain two commands — and permits
`'`, a backtick, `$( )`, and a bare `&`, the four that break OUT of a quote. a deny-list is a
claim about a grammar that always holds more shapes than its author enumerated (m.12 / q11).

⇒ base64 is the fix at CAUSE. its alphabet `[A-Za-z0-9+/=]` holds no shell metacharacter, so
the quotes cannot be closed, and every argument arrives as literal bytes. each arg is quoted,
verb and flags included; the far-side shell removes those quotes, so tmux receives an argv
identical to the local branch's.

### one helper, and why `--tty` and `--host` are flags on it

- ten sites that each quote their own way are ten readers of one rule (m.9). a new remote
  tmux call gets the guarantee by a call to this
- `--tty`: an `attach` needs a pty and every other call must NOT have one (ssh `-t` on a
  non-interactive call mangles the output a caller reads). one ssh flag, so one marker —
  a second helper would leave the one call that needs a tty to write its own raw `ssh` line
- `--host`: `__duct_list_host_sessions` walks the registry, one host at a time, so it asks a
  host that is not `$DUCT_HOST`. its own `ssh` line would be SAFE (a fixed literal) and still
  a second seam — the cost is that the NEXT author reads two shapes and picks either. the
  flag leaves exactly one `ssh` in the file, a claim a check holds with no allowlist to rot
- they are positional markers, not a parse loop: the helper takes tmux's OWN argv after
  them, and a loop would have to guess where ours ends and tmux's begins

## m5 — the ANSWER is stripped at the seam too

📜 measured 2026-08-31 by a redteam of this file: it DEFINED `__duct_strip_escapes` and stated
the threat in full, and applied it to no verb of its own. four sites relayed raw:

```
duct.reboot's $pane_cwd     ← display-message -p '#{pane_current_path}'
duct.refresh's $ttys        ← list-clients -F '#{client_tty}'
duct.list --on's names      ← list-sessions -F '#{session_name}'
the registry refusal, which echoed the bytes it refused
```

- the reboot one is the live attack. a linux dir name may hold any byte but `/` and NUL, so
  a grove `cd`s its pane into a dir whose NAME carries an OSC 52 — and `duct.reboot` is a
  command this repo's own fix-texts tell a human to run, with a key bound to it. tmux emits
  `-p` output RAW, so the sequence reached kitty and rewrote the clipboard
- ⇒ the strip sits at the SEAM, not at the four echoes: four echoes are four readers, and a
  fifth caller tomorrow inherits none of it. the helper encodes what LEAVES and sanitizes
  what ARRIVES — symmetric. that closed the fourth site for free, which is the sign the
  boundary is the right one
- ⚠️ `--tty` is EXEMPT: an `attach` is an interactive tmux client whose whole stdout IS escape
  sequences. a strip there renders the session unusable, and the exposure is the one a human
  chose — `ssh grove` by another name (`rule.require.exemptions-name-their-trigger`: the
  trigger is a tty, never a verdict about which verbs look safe)

### the HOST is clamped before ssh reads it as a positional

`ssh` reads its first positional as a host ONLY IF it does not begin with `-`. one that does
is an OPTION — and `-oProxyCommand=<cmd>` runs a command HERE, on the laptop, before any
connect. `$DUCT_HOST` comes off a `--on` URI, and the registry grammar admits a `-` at the
front. termwork holds `__term_as_ssh_host` for round 5's twin shape, so the seam reuses it
(`rule.forbid.two-writers-on-one-artifact`), with an inline clamp only where termwork is not
loaded — a duct must work in a shell that sourced ductwork alone.

## m6 — BOTH streams, and the status is SSH's

📜 measured 2026-08-31, two defects that one line held at once:

```
ssh "$host" "$remote_cmd" | __duct_strip_escapes
```

- ✋ a pipe carries STDOUT. ssh relays the remote stderr byte-for-byte onto fd 2
  (`SSH_MSG_CHANNEL_EXTENDED_DATA`), so that half reached the terminal RAW while the header
  claimed every value from a grove was inert. and stderr is the stream a grove controls most
  cheaply: a login rc writes there freely
- ✋ `$?` after a pipe is the LAST stage's, so the caller read the SINK's status. the sink
  exits 0 on an empty stream, so `__duct_probe_remote_session` answered "reachable, session
  present" for a host that refused the connect, and `__duct_list_host_sessions` could never
  return its 3 — the code that stops `__duct_refresh_host` from `rm -f` of every registered
  duct of a host that is merely ASLEEP
- 🛑 `set -o pipefail` is NOT the fix: the file is sourced into an interactive zsh without
  `pipe_fail` and into a bare `bash -c` through `$BASH_ENV`, and the two shells spell the
  function-local form differently — two writers of one rule
- ⇒ ssh runs with NO pipe on it, so its status is its own, and each stream reaches the sink
  AT CAPTURE — the idiom `git.grove.push` states at its `STALE` read

### why a scratch FILE for stderr, and not `2> >(__duct_strip_escapes >&2)`

a process substitution is asynchronous. `__duct_probe_remote_session` captures fd 2 with
`2>&1 1>/dev/null`, and a command substitution may close before an async writer has
written — so the evidence would arrive SOMETIMES. a check that reports the truth on most runs
is worse than one that never does. the path comes from `mktemp`, never a fixed name, since
two seats share `/tmp` on a grove (`rule.forbid.fixed-paths-in-a-shared-tmp`).

### why the `rm -f` is NOT a trap

a Ctrl-C mid-ssh aborts before the `rm`, so an abort leaks the file. the `trap … EXIT` that
`git.grove.pull` uses is WRONG here: that skill is an EXECUTABLE with its own trap table, and
this is a FUNCTION sourced into a human's interactive shell. an EXIT trap set here fires when
the human closes their terminal and clobbers whatever they had; a RETURN trap is not unset on
return, so every later function return re-runs `rm -f` against a `local` that is gone.

⇒ that is `rule.forbid.two-writers-on-one-artifact`, where the artifact is the shell's
signal disposition. the residue is a 0600 file in `$TMPDIR` after an abort — litter, not
exposure — and `1.8.tmpfiles` installs the sweep that owns it.

## m7 — the probe's stderr is ALREADY inert, and that is load-bear

`__duct_say_unreachable` REPLAYS `DUCT_PROBE_STDERR` verbatim, inside an "ssh said" fence. it
is inert because `__duct_ssh_tmux` sanitizes both streams at capture, at the one seam.

- ⇒ do NOT restore a `| __duct_strip_escapes` pipe on the probe, and do NOT strip at the
  replay: either would put the guarantee in two places, and the replay is the copy nobody
  re-reads (m.9)
- the replay still uses `printf '%s'`, never `echo` — that is the VERB rule of m2, not a
  second strip. a `Banner` and a `Received disconnect from …: <text>` both land on stderr
  BEFORE auth, so a grove that is merely asleep chooses these bytes

## .see also

- `2.7.aliases/ductwork.sh` — the headers these measurements back
- `gotcha.2-7-aliases.demo=duct-security-seams.md` — the verify's claims over these seams
- `rule.require.security-paramount` · `rule.require.solve-at-cause`
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9, m.12 / q11, m.13

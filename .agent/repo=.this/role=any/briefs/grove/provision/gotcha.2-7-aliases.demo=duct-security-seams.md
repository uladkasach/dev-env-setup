# demo: 2.7.aliases — the duct/termwork/git-subject security hardening trail

## .what

`configure.verify.sh` proves five security-shaped claims about the installed alias suite.
this file records the measurements that produced each claim, so the verify's header can
cite a name instead of carrying the narrative.

## m1 — the parser is bash AND zsh, never `sh`

2026-07-30, a grove that had just converged all three alias files: `sh -n` called each
broken (`sh` on ubuntu is dash, and these files are deliberately bash+zsh — arrays, `[[ ]]`,
`local`, process substitution). `bash -n` / `zsh -n` passed all three. the right question is
"does the shell that will SOURCE this accept it", and exactly two do: zsh via the zshrc,
bash via `.bash_profile`.

a verify that fails on a converged box teaches a reader that ✋ means no defect. the one
run that finds a real syntax error is the one nobody reads (`rule.forbid.failhide`, from
the other side).

## m2 — a copied member no line sources is installed and inert

`bash_aliases.sh`'s head guards each source with `[[ -f … ]]`, correctly. a partial
install cannot break a login. that guard's cost: the inverse failure is equally silent — a
member copied but never sourced produces no error at all. the namespace does not exist. a
human reads that as "the tool is broken" rather than "it was never loaded". the regression
is additive: nobody deletes a source line, somebody adds a fifth `src/X.sh`, wires the `cp`,
and forgets the source line.

## m3 — the duct reaches tmux through one seam, and it must stay one

2026-08-31, a live grove: `ssh` joins its args into one string for a login shell. every
interpolated value is CODE there, never data. ten sites in `ductwork.sh` interpolated a
value that way, several read off the remote box (a pane cwd, a client tty) — a trust
inversion where the far side picks text the near side executes. base64's alphabet holds no
shell metacharacter. `__duct_ssh_tmux` closes that door structurally
(`rule.require.solve-at-cause`).

the count that may not move is bound to the encoder's own shape, not to a remembered form:
2026-08-31, a grep for the literal `ssh "$DUCT_HOST"` read 1 and printed ✔ while
`ssh -t "$DUCT_HOST" "tmux attach -t '$DUCT_SESSION'"` sat fifteen lines below, a second raw
seam the pattern never looked for (`gotcha.a-check-that-cries-wolf`, m.12/q11). the fix
anchors on the VERB in command position (line start, after `;|&(`, or after a reserved word
`if/elif/while/until/then/else/do/!`) — an anchor that itself needed correcting once every
`if ssh …` site at six `git.grove.send` call sites read as no seam at all, since `[;|&(]`
holds no letter.

quoted spans are stripped before the count (`sed 's/"[^"]*"//g'`), since five fix-text
strings say `ssh` inside `echo`/`fix=` literals and a bare verb count would redden against
correct code.

the invariant is WHERE a seam lives, not HOW MANY exist: `__duct_ssh_tmux` legitimately
holds two `ssh` lines — one `-t` attach (needs a pty) and one non-pty seam (needs both
streams to reach the strip separately). a demanded total of 1 would be unreachable while
both guarantees hold.

seen to discriminate 2026-08-31, on this laptop, both halves: red against the installed copy
(predates the repair) — `1 ssh line(s) … leave STDERR unstripped`, `2 ssh line(s) sit
OUTSIDE __duct_ssh_tmux`; green against the checkout, where the pattern returns exactly two
(the attach at 587, the seam at 644), both inside `__duct_ssh_tmux`'s 494-652 span.

## m4 — every ssh in the duct accounts for both streams, and sits inside the one owner

2026-08-31: the seam read `ssh "$host" "$remote_cmd" | __duct_strip_escapes`. a pipe carries
stdout only; ssh relays the remote stderr byte-for-byte onto this process's fd 2 raw. with
`set-clipboard on` in `src/tmux.conf`, an OSC 52 on that channel rewrites the clipboard.
the next paste is a command a grove chose.

the two questions are separate claims with separate readers: does the caller SINK both
streams, and does the seam sit inside the one function that owns it. an idiom match
(matching the exact original line shape) passes only what its author could picture. the
structural test is `-t`/`-tt` OR a `2>` redirect on the SAME line as the verb, matched at
COMMAND POSITION — not a bare word match, since this file says `ssh` in nine `echo`/`fix=`
strings.

that anchor was itself a subset of command position until 2026-08-31: `[;|&(]` holds no
letter. `if ssh …` / `if ! ssh …` (this repo's own idiom at six `git.grove.send` sites)
counted as no seam at all — green by luck of style, not by reach. the two halves (raw-stderr
check, stray-seam check) ask different SPANS of the line: `-t` is read in the OPTION span
(verb to first quote, since `-t` is ssh's own flag), `2>` is read on the RAW line (a redirect
this shell performs, which may sit after the remote command).

seen to discriminate 2026-08-31: red against the installed copy (predates the repair) — `1
ssh line(s) … leave STDERR unstripped`, `2 ssh line(s) sit OUTSIDE __duct_ssh_tmux`; green
against the checkout — the pattern returns exactly two lines, both inside the one function.
that agreement with m3's independent seam-count pattern is the m.9 evidence: two readers of
one set, converged.

## m5 — a remote-chosen name becomes a laptop path through one builder only

2026-08-31 redteam: `duct.list --refresh` asks a grove for tmux session names, one registry
file per answer. a grove is assumed compromised. each name is remote-chosen bytes. four
readers joined one to a path inline, with a `mkdir -p` of its parent — a session named
`../../.claude/settings` lands on `~/.claude/settings.json`, replacing it with a two-key
object holding no `hooks` block and no `permissions` block: every pretooluse gate removed by
a `duct.list`, a pre-approved command (`rule.require.security-paramount`).

the count pattern needed two corrections after it shipped. first, `DUCTWORK_DIR/\$`
(variable immediately after the slash) missed `$DUCTWORK_DIR/ducts/$x.json` — the exact line
the 🌙 below prescribes as its own break. the pattern could not see the regression it was
written to catch (m.12/q11); widened to `DUCTWORK_DIR/[^"]*\$`. second, 2026-09-01: that
widened pattern still missed the brace form `${DUCTWORK_DIR}/…`, used four times across
`mkdir -p` calls, since `\}?` answers where the variable sits but not how the dir is spelled
— a second, independent axis. the lesson: after any repair, ask how many axes the subject
varies on, since a widened pattern tends to widen only the one axis just read.

🌙 the red half remains unproven: by-hand read of the checkout, 2026-09-01, counts exactly 1
join under both patterns (inside the builder). the planted-break watch:
```
printf '%s\n' '  f="${DUCTWORK_DIR}/ducts/$s.json"' >> ~/.bash_aliases.ductwork.sh
rhx grove.provision --what 2.7.aliases --mode plan   # MUST say 2
```

## m6 — a terminal obeys the bytes a grove sends it, so the sink must strip by class

`__duct_strip_escapes` must exist and strip by CLASS (`tr -d` over control ranges), never an
enumerated allow-list. 2026-08-31: a grep for `tr -d '…000-'` passed for a whole release —
the sink it passed ate every non-ASCII byte handed to it, since `\177-\237` reads as "DEL
plus the C1 block" AND is also a utf-8 continuation range: `├` (E2 94 9C) came out as a lone
`E2`, 🐢 (F0 9F 90 A2) as `F0 A2`. a grep of a byte range cannot see that; only running the
sink and reading the RESULT can (`rule.require.seam-claims-have-an-owner`).

the probe carries non-ASCII deliberately (a box glyph and an emoji). it proves both what
the sink must eat (ESC, BEL, C1-CSI) and what it must let through (TAB, the tree glyph, the
turtle) in one run.

this row runs the sink rather than the grep. it proves only the SINK. it makes no claim
about whether `git.grove.send`/`git.grove.play.await` (the call sites) actually route
through it, since this bundle does not own those skills. that half is `— (unproven)` in
`inventory.security-checks.md`.

## m7 — termwork owns the same three hazards ductwork does

2026-08-31: termwork is ductwork's twin and had received none of its fixes. ten inline joins
of `$TERMWORK_DIR/$pid`, `$pid` unchecked from argv, one consumed as `9>"$lockpath"` — a
write destination a caller could steer. a `cat > … <<EOF` record whose `cwd` a directory name
supplies, where a `"` forges a key and `socket` is written first. jq's last-duplicate-wins
lets a forged `socket` override the control socket every later verb hands to `kitten @ --to`.
an `ssh -t "$duct_host"` whose host is a positional. a leading `-` parses as an OPTION
(`-oProxyCommand=<cmd>` runs code on this box).

the expected join count is TWO, not one: the builder emits two path shapes from one grammar
check (a record `$TERMWORK_DIR/$pid.json` and a lock `$TERMWORK_DIR/.lock.$pid`), both inside
the one owner — the claim is "the grammar has one holder", never "the string appears once".
that is also why the pattern is `DIR/[^"]*\$` and not `DIR/\$`: the lock's variable sits after
a literal `.lock.`. the narrow pattern would count 1 and pass while reading half its
subject.

🌙 the red half is unproven: by-hand read of the checkout, 2026-08-31, counts two joins, one
ssh seam, one `jq -n`.

## m8 — a commit subject is remote text, and must never reach a terminal raw

2026-08-31: eight sites spelled `git log -1 --format="%h %s"` for themselves, feeding
fourteen bare `echo`s. a subject is author-chosen bytes carried by `git fetch`; one holding
`\e]52;c;<b64>\a` writes the clipboard on `git tree list`, since `git.grove.pull` writes a
tree a grove named and `git tree list` then walks it.

the reader counts captures with NO sink (a zero, not a tally) — additive. a ninth capture
written like the other eight stays caught with no constant to maintain. bounds, stated: it
reads lines (a `\`-continued capture escapes it, which is why `_git_commit_line`'s pipeline is
one line), excludes only whole-line comments (a trailing `#` still counts, correctly a false
✋ never a false ✔), and reads whether the sink is NAMED, never whether it is REACHED (a
separate probe covers reached, at `_git_commit_line`). it is blind to a capture that spells no
format of its own: `alias.lg`'s body ends `%Creset%s`. `s="$(git lg -1)"` is a real subject
capture this row cannot see, since the format lives in another bundle.

2026-09-01: `--format=` alone is blind to six other spellings git accepts for the same
request — `--pretty=format:"%s"`, `--pretty="%s"`, `--format "%s"` (space), `--pretty
format:"%s"`, `git show -s --format="%s"`. none of the blind forms sat on the tree at
measurement time. the narrow read cost no false ✔ that day, but it is an additive guard
gap (m.12/q11): a ninth capture written `--pretty=` would land unread.

the separator guard (`[^|;&]` between flag and `%s`) exists to keep a hash capture out of
scope: the wider span without it would also describe `h="$(git log -1 --format=%H)";
printf "%s" "$h"`, a false ✋ whose fix-text would wrongly tell a human to sink a hash — no
real subject capture crosses a separator between its flag and its `%s`.

`git lg`'s render was measured as NOT a defect here: an OSC 52 planted in a real commit
subject, read on both sides of the tty, across `git lg -1` (this repo), `git log --oneline`
(stock), `git log -1` (stock) — all three escape on a pty and all three pass raw on a pipe.
the three agree. the alias adds no exposure over stock git; to file that against `2.2.git`
would inflate a stock behavior into a repo defect (`rule.forbid.inflate-an-additive-ask`).
what remains this repo's is the CAPTURE case above.

seen to discriminate, 2026-08-31, four fixtures: the shipped file (green), the holder deleted
(red, no holder), a ninth bare capture added beside it (red, 1 unsunk), the same capture sunk
(green). seen to discriminate, 2026-09-01, the whole form set: each of the six blind
spellings, planted bare then sunk, went red-then-green in turn; the negative case
`h="$(git log -1 --format=%H)"; printf "%s" "$h"` stayed green throughout, proving the
separator guard does not false-positive on a hash capture.

## .see also

- `2.7.aliases/configure.verify.sh` — the phase these measurements gate
- `rule.require.security-paramount`
- `rule.require.solve-at-cause`
- `rule.require.seam-claims-have-an-owner`
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9, m.12/q11
- `rule.forbid.inflate-an-additive-ask`

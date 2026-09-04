# inventory.security-checks

## .what

the ledger of security checks this repo applies. each row names a check, the ONE
boundary that performs it, and the **reader** that proves the check covers every
subject in the tree.

## 🛑 .the reader column is the point — the file-path column was the defect

🛑 **never restore a `lives in` column of hand-written FILE PATHS.** a coverage claim
written by hand is a claim that decays in silence: it cannot report the subject nobody
added to it, so the page reads complete whatever it omits.

📜 measured, in both directions a hand list fails:

- it named `install_env.pt4.terminal.sh` for nvim's sha256 pin — a **path that answers
  "no such file"**, beside a description of a check that works
- it claimed sha256 for **two** subjects (nvim, kitty). the tree held **eight**. the six
  it omitted were as invisible to this page as the day they landed

⇒ so the column is a **reader**: a play that DISCOVERS its subjects from the tree. a row
cannot go stale, because no row states a count or a path.

## .checks adopted

| check | what it guards | the boundary | the reader | its owed home |
|---|---|---|---|---|
| **every wire pull is checked** | a download with NO verification at all | `src/grove.web.sh` — the one wire boundary | ✔ `rhx wire.verify` | — |
| no dox in a public repo | an account id or principal in a published file | `git ls-files` — the publication set | ✔ `rhx dox.verify` | — |
| the duct's one encoded seam | a remote-chosen value that reaches the far shell as CODE | `__duct_ssh_tmux` | 🌙 `2.7.aliases/configure.verify.sh` — green half measured, RED half unproven since it was re-keyed on the VERB | run its break; the phase header carries the three lines |
| a pull cannot write outside `--into` | a GROVE that chooses where a laptop writes | `git.grove.pull` — rsync carries files and dirs only (`--no-links --no-devices --no-specials`); the tar path vets every member NAME and refuses ANY link member | — (unproven) | the skill refuses at the boundary; a reader would need a hostile archive to plant |
| the credential helper answers HTTPS alone | a github pat on the wire in cleartext | `src/git-credential-keyrack.sh` | — (unproven) | `2.2.git/configure.verify.sh` — it already reads this file |
| a remote NAME cannot become a laptop PATH | a grove-chosen tmux session that steers a registry write — `../../.claude/settings` strips every hook | `__duct_as_registry_file` — the ONE path builder, which owns the name grammar | 🌙 `2.7.aliases/configure.verify.sh` — counts the joins; green half measured, RED half unproven | run its break; the phase header carries the two lines |
| EVERY offered host key is attested | a real key offered beside a forged one, both written to `known_hosts` | `git.grove.trust.gen` — `SCAN ⊆ BOOT`, never an OR | — (unproven) | `git.grove.provision test` — it asks a LIVE box |
| a verdict channel is UNGUESSABLE and per-seat | a second seat that pre-creates the rc file and forges a whole verdict | `git.grove.send --reply` / `--detach` — `$HOME/.local/state/grove.reply/<urandom>` | — (unproven) | `git.grove.provision test` — it drives the channel it would check |
| the paved path does not SKIP the anchor | a one-command provision that quietly opts out of the host-key check | `git.grove.provision boot` — `--trust` defaults to verified | — (unproven) | same skill — its own rung 0 climbs this ladder |
| a private key never lands in a shared dir | a symlink squat that steals an ssh key and reports the shred as success | `src/util.yubikey.ssh.sh` — `mktemp -d` 0700 + a `trap … RETURN` | — (prior) | a human's hardware step; no reader here can see it |
| a terminal CONTROL SOCKET is per-user | a squatter that binds kitty's address and both reads and dictates | `src/termwork.sh` — `$XDG_RUNTIME_DIR/termwork`, 0700 | — (unproven) | `4.3.2.emulator/configure.verify.sh` — it already clamps `listen_on` |
| a terminal never obeys grove bytes | OSC 52, which writes the human's clipboard through `set-clipboard on` | `__duct_ssh_tmux` — the INBOUND boundary strips, so no verb of ductwork's own can forget | ✔ `2.7.aliases/configure.verify.sh` — **RUNS** the sink and reads its hex back; the CALL SITES still have no reader | a repo skill — the relays sit in `git.grove.*`, which that bundle cannot see |
| the sink guards BOTH STREAMS | `ssh` relays the remote command's stderr **byte for byte** onto local fd 2 (`SSH_MSG_CHANNEL_EXTENDED_DATA`), and a pipe carries stdout alone — so every escape the sink refuses arrived unstripped on the other stream | `ssh` runs under **no pipe**: stderr to a scratch file, stdout captured, each fed to the one sink at the point of capture | ✔ `2.7.aliases/configure.verify.sh` — asks TWO things of the duct: every command-position `ssh` sinks both streams, AND every one sits inside `__duct_ssh_tmux`. seen RED and GREEN in one run | — |
| a THIRD-PARTY tool's stream is not guessed at | rsync names a refused member on **stdout** and an error on **stderr**, so a reader keyed on one stream holds half its subject — `git.grove.pull`'s refusal was unreachable, and the grove's own filenames reached the terminal raw | `git.grove.pull` — the seam captures `>"$log" 2>&1`, so the reader depends on no convention it did not set | — (unproven) | the two carriers are the reader: `git.grove.push` measured this stream and `git.grove.pull` assumed the other (m.9) |
| every RELAY of grove output owns a sink | a skill that prints a grove's answer to a terminal, with no strip — `git.grove.auth.github.set` did, in the minute after a human pastes a pat | each such skill loads `src/ductwork.sh` **from this checkout** and strips at capture | — (unproven) | m.9 at skill scale: the sink is one fact with N holders, and the holder that never loaded it is invisible to every reader of the others |
| a sink guards the SHARED PRELUDE, not just the branches | `git.grove.send --play` uploads the file over a bare `ssh` **before** it branches to `--bare`, `--detach`, `--reply`, or the duct — so one unsunk line sat on the path of all four. the 2026-08-31 sweep listed four carriers in `git.grove.operations.sh` and this one is in a different file, under a branch that returns first | `git.grove.send`'s `--play` upload — a scratch file for stderr, the sink on both streams, `PIPESTATUS[0]` for the rc | — (unproven) | m.12 — a sweep of the block four carriers SHARE reports a closed class over the set it could reach |
| a laptop tool never OBEYS grove-authored config | `.claude/settings.json` declares `SessionStart`, `PreToolUse`, and `Stop` hooks — commands the harness runs. `PreToolUse` is the gate every bash command passes, so a grove that writes that one file owns the local agent, and collects at the next session open, before any human reads a diff | `GROVE_BOUNDARY_EXCLUDES` — and the TEST is now written above the list: *does this name a program that runs BEFORE a human can read the diff that carried it?* | — (unproven) | the list read as an enumeration of the class and was three members of it; the test is what makes the next member derivable |
| a terminal exposes no CONTROL SOCKET by default | `allow_remote_control yes` hands every process that can reach the socket full control of every window — read a pane, type into a pane, open a new one | `4.3.2.emulator` — the config declares `no`, and a terminal that needs control opts in **per launch** | ✔ `4.3.2.emulator/configure.verify.sh` — asks **kitty's own `load_config`** for the RESOLVED value, so a later line that overrides an earlier one is seen; a DENY of the one wide value, never an allowlist of the narrow ones | — |
| a terminal's config PARSES | a bad value or an unknown key, which kitty reports and then ignores — so a config that half-loads reads identical to one that loaded | `4.3.2.emulator` — kitty's own parser is the reader; this repo asserts no grammar of its own | ✔ `4.3.2.emulator/configure.verify.sh` — seen RED on a bad value and on an unknown key, GREEN on a clean conf and on a map to an unknown action | — |
| ONE set never crosses the boundary, in EITHER direction | a `.git/hooks/post-checkout` carried back by a pull — code the laptop runs on its next checkout. push declared the exclusion and pull carried it (m.9: one policy, two holders) | `GROVE_BOUNDARY_EXCLUDES` in `git.grove.operations.sh` — ONE array, sourced by both carriers of both directions. ⚠️ INBOUND, an `--exclude` is a **request** (the archive is built on the grove), so `_grove_boundary_excluded` vets member names locally before any extract | ✔ the operation's own header — seen to discriminate over 25 rows, refuse and permit both | — |
| a COMMIT SUBJECT never reaches a terminal raw | a branch on a pulled tree whose commit subject carries an OSC 52 — git normalizes `%s` not at all, and EIGHT capture sites fed FOURTEEN echoes | `_git_commit_line` in `src/bash_aliases.sh` — ONE holder, guarded **at capture** through `__duct_strip_escapes` | ✔ `2.7.aliases/configure.verify.sh` — an ADDITIVE count: **zero** subject captures that do not name the sink | — |
| a FILE may not configure the editor that opens it | a modeline (`# vim: …`) or a `.nvimrc` in a pulled tree, applied on OPEN — one keystroke is the whole trigger, with no second step | `src/init.lua` — `modeline`, `modelineexpr`, `exrc` all pinned false near the top | ✔ `4.5.nvim/configure.verify.sh` — reads the LIVE editor's option values, never the file's text | — |
| imagemagick never hands a grove's bytes to another program | debian's default declares NO coder rule, and an absent coder rule is a PERMITTED one — so PS/EPS/PDF/XPS reach ghostscript (present on this box) and MVG/MSL are interpreted, on a tree `git.grove.pull` wrote and `image.nvim` converts | `src/imagemagick.policy.xml` — a SEAT-scoped policy, so the CAMPER (which holds no sudo) owns it for itself | ✔ `4.5.nvim/configure.verify.sh` — three claims: currency, effect (an eps is refused), and **COST** (the six formats `init.lua` declares renderable still read) | — |
| the sink eats an ESCAPE and spares the TEXT | a `tr` range over `\177-\237`, which also eats utf-8 continuation bytes — so `├` and 🐢 were destroyed on every relay, for a release, and a refusal's own evidence went with them | `__duct_strip_escapes` — three stages: `tr` for C0+DEL by byte, `iconv -c` for invalid utf-8, `sed` for C1 as CHARACTERS | ✔ `2.7.aliases/configure.verify.sh` — asks BOTH halves: what must die, what must live | a grep of a byte range cannot see this; only a run can |
| an EC2 TAG never reaches a terminal raw | a tag value — free-form utf-8, written by any `ec2:CreateTags` principal — that carries an OSC 52 | `aws.ec2.get` — the whole render pipes through the sink, never a per-field list | — (unproven) | whether a grove's own role may write tags lives in `ahbode/infrastructure`, so this repo cannot answer it |
| a REGISTRY value never becomes an ssh_config DIRECTIVE | a `\n` in a stored value, which adds `ProxyCommand` — a command THIS laptop runs on every later ssh | two boundaries: `_git_grove_clamp` on the write, `wake_clamp` on the read | — (unproven) | a FILE has two ends, and a writer's check says none about what a reader is handed |
| a registry value never becomes a PROGRAM | `.sshAlias` spliced into a `sed -i` address over `~/.ssh/config`, where a `/` ends the address and the rest is a sed COMMAND | `_git_grove_del` — `awk -v a=…` compared with `==`; `grep -qxF` for the guard | — (unproven) | the same idiom `git.grove.wake`'s [REPLACE] arm uses, deliberately |
| BOTH pull carriers hold ONE policy | rsync `-az --safe-links` landed an in-tree symlink and every device node, while tar refused all links — and a laptop HAS rsync, so the guarded branch never ran | `git.grove.pull` — rsync carries files and dirs only, and REFUSES by name when the far tree held more. that refusal read **stderr** until 2026-08-31 and rsync names a skipped member on **stdout**, so it was unreachable — and the names reached the terminal raw | — (unproven) | a carrier pair is m.9 at transport scale: one claim, two readers, the cheaper one stays. the STREAM was the same shape one layer in — `git.grove.push` read the proven stdout, `git.grove.pull` read the other |
| a DIRECTORY NAME never ends an OSC string | a dir named `x<BEL><ESC>]52;c;<b64><BEL>`, which closes the cwd report and hands the terminal a fresh clipboard write — reachable through any pulled tree, on the next `cd` | `src/zshrc.sh` — `${x//[[:cntrl:]]/}` on OSC 7, OSC 2, and both tmux pane options | ✔ `2.5.zsh/configure.verify.sh` — **RUNS** the strip; seen RED and GREEN in one run | a parameter expansion, so it costs no process on a path that fires every `cd` |
| a terminal pid cannot become a laptop PATH | a `--pid` that steers which file the tab lock's `9>` redirect writes | `__term_as_registry_file` — a pid IS decimal digits, so the allow-list is total | 🌙 `2.7.aliases/configure.verify.sh` — counts 2 joins (record + lock); green half measured, RED half unproven | run its break; the phase header carries the two lines |
| a terminal record is COMPOSED, never templated | a `"` in a directory name that forges a `socket` key, which then picks the control endpoint | `__term_register` — `jq -n --arg` | 🌙 `2.7.aliases/configure.verify.sh` — refuses a heredoc write of that record | it reads the shape, not a live record |
| a session name is CARRIED, never interpolated | a grove-chosen tmux name whose `'` closes the quote in a shell string | `__term_as_attach_command` — base64, whose alphabet holds no metacharacter | 🌙 `2.7.aliases/configure.verify.sh` — demands the builder exist and one ssh seam | run its break |
| an ssh HOST cannot be an ssh OPTION | a `-` at the front, which makes `-oProxyCommand=<cmd>` run on the laptop | `__term_as_ssh_host` — `[A-Za-z0-9._-]`, one `@`, no `-` at the front | 🌙 `2.7.aliases/configure.verify.sh` — demands the clamp exist | run its break |
| `~/.aws/config` takes no un-clamped value | an `--assume` with a newline that adds `credential_process = <cmd>` — arbitrary code the aws cli runs | `aws.reach.set` — `reach_clamp` at the parse, `^[0-9]{12}$` for the account | — (unproven) | the skill refuses at the boundary; `aws.whoami` proves the result |
| an account id is agreed, not FIRST-FOUND | one altered clone under `~/git/<org>/` that redirects which account a box assumes into | `5.13.reach` — reads EVERY clone, halts on disagreement | — (unproven) | `5.13.reach/configure.verify.sh` — it already calls this reader |
| a remote sandbox is minted BY the box, and its ANSWER is held to a grammar | a second seat that pre-creates a guessable `/tmp` path a push then writes through — and, one layer out, a grove that answers `/` to the `mktemp -d`, since a `!= /*` test accepts it | `git.grove.push.verify` — `mktemp -d` under the grove's own `$HOME`, and the answer must match this skill's own template before an `rm -rf` is aimed at it | ✔ the skill's own header — the grammar was run against the real answer and five hostile shapes | — |
| root never walks outside /tmp | a bind mount under a /tmp path that takes root's `find … -delete` into a home dir | `tmp-cleanup.service` — `-xdev` AND `ProtectSystem=strict` + `ReadWritePaths=/tmp` | ✔ `1.8.tmpfiles/provision.verify.sh` — it `diff`s the installed unit against this checkout | — |
| a daemon never EVALs its environment | a `systemctl --user set-environment` that puts code into a loop which ticks every 2 minutes | `machine_resource_procs_monitor` — a `case` over three names, assigned directly | — (unproven) | `1.6.2.monitor/provision.verify.sh` — it already installs this file |
| json is COMPOSED, never templated | a `comm` a process chose for itself (`prctl`), or a control byte in a path | `kitty.snapshot.terminals` — `jq -R -s`, and `snap_as_field` drops every control byte **at capture**, so no consumer of the snapshot inherits an escape | — (unproven) | `4.3.4.snapshot/provision.verify.sh` — it already installs this file |
| a REGISTRY value cannot be an ssh OPTION | the same `-` front that `__term_as_ssh_host` refuses, reached instead through `.sshAlias` in the grove registry — every `git.grove.*` skill that shells out to ssh is a second door on the one clamp | `git.grove.auth.github.set` — calls `__term_as_ssh_host` where it can, and refuses the same grammar inline where it cannot | — (unproven) | m.9 at skill scale: one grammar, N callers. the owed reader counts the callers, never the grammar |
| an injected flag is not a skill's flag | rhachet injects `--skill`, `--repo`, `--role` into **every** skill it runs, so a skill that owns a flag by one of those names silently takes rhachet's value — `aws.reach.set --role` could not run at all | each skill **shifts past** the three injected names, and owns its own under another word (`--of`, `--assume`) | — (unproven) | a repo skill — its subject is every skill's parse loop, which is tracked text |
| a credential helper reads a DECLARED checkout | a repo the human happens to stand in, whose manifest `extends:` anywhere, loaded on every private fetch | `src/git-credential-keyrack.sh` — three rungs, then it refuses | — (unproven) | `2.2.git/configure.verify.sh` — it already reads this file |
| credentials via keyrack | a secret at rest on a box | `rhx keyrack` — every secret on a box arrives through it, so its CALL SITES are the whole set | ✋ **one consumer of twelve writes its value down** — `prove.rack-consumers-are-dispositioned` censuses every call site, prints the exception on every run, and was seen RED on all three drift directions | `5.4.gh` — the fix at cause is `GH_TOKEN` from the env, which gh reads and writes down none of; blocked on a from-scratch grove |
| a declared ASSET actually SHIPS | a fix that exists on the author's disk and reaches no other box. `src/lazy-lock.json` held SC-F1's nvim plugin pins and was UNTRACKED, so a fresh clone lands every plugin on HEAD — unpinned remote lua, into the editor that opens every file | the bundle tree's own `$GROVE_SRC/<path>` refs, each asked against the INDEX | ✔ `prove.declared-assets-are-tracked` — the set is DERIVED from `src/grove.provision/**`, and it was seen RED on a planted untracked asset | — |
| a shipped asset is the CURRENT one | the row above's blind spot: a `git add` run BEFORE a fix and never re-run leaves a path that is tracked, passes every presence check, and whose index copy is the PRE-FIX version — so a commit ships the bug under a green row. measured minutes after round 20 closed: 127 tracked files held an index copy that differed from disk, and 5 were those very repairs (487 insertions) | — | ✋ **unproven** — `prove.declared-assets-are-tracked` asks `ls-files --error-unmatch`, which answers *is this path in the index*, never *does the index hold the fix*. the play states this residue inline | ⚠️ **a tree-wide reader would DECAY** — `git diff --name-only` counts 127 here, nearly all legitimate in-flight rename work, so it reddens on every run and gets silenced (m.13). the claim is not tree-scoped: "current" is relative to an intent no file records. the tractable home is a **commit-time** gate over the files that commit names, not a sweep |
| a reader's CORPUS is the publication set | a gate that walks the DISK, where an untracked file reads exactly like a tracked one — so ✔ covers files that ship to nobody. this hid all three of 2026-09-02's untracked finds at once | `git ls-files` — the one store that answers "does this ship" | ✔ all three sweeps now derive one corpus from one store (`shell.syntax.verify` was the last, on 5 hand-written roots) | — |
| an ABSENT subject BLOCKS the verdict | a reader that quietly shrinks its own subject, then reports clean on the exact corpus it stopped to read (q13 — the index and the disk are two stores) | every sweep counts what it could not open, and refuses a verdict rather than annotate one | ✔ all three sweeps exit 2 on a non-zero count. ⚠️ `-e`, never `-f`: `-f` calls a tracked DIRECTORY absent, which was a permanent false ✋ on `.radio` | — |
| pinned sha256 | a tarball's bytes | `web_verify_sha256` | — (unproven) | a repo skill — it is a SOURCE claim |
| pinned gpg signature | a signed artifact's provenance | `web_verify_gpg_signature` | — (unproven) | a repo skill — SOURCE |
| pinned apt repo key | a third-party apt source | `web_verify_gpg_fingerprints` | 🌙 **partial** — `1.1.keybinds/provision.verify.sh` reads keyd's anchor live; the other five have no reader | a repo skill — SOURCE, over all six |
| pinned clone commit | a git checkout's contents | `git_clone` | — (unproven) | `git.grove.provision test` — it asks the NETWORK |
| pinned registry version | a THIRD-PARTY npm/cargo install | the pin is the spec itself | ✔ `5.3.brains/provision.verify.sh`, `5.14.treesitter/provision.verify.sh` | — |
| pinned editor extension | a marketplace publish that reaches the editor | — | — (unproven) | ⚠️ **unenforceable alone** — the editor auto-updates; see below |
| bounded wire calls | a stall that holds the duct | `src/grove.web.sh` | — (unproven) | a repo skill — SOURCE, over the corpus `wire.verify` already sweeps |
| a bound that can END what it cuts | a TERM-deaf child that outlives `timeout` | `timeout -k` | — (unproven) | same skill as the row above |
| apt is never interactive | a needrestart menu that eats the pane | `PKG_APT_ENV`, `pkg_apt` | — (unproven) | a repo skill — SOURCE |
| sudo cannot reach a prompt | a password ask with no human to answer | `pkg_can_sudo`, `bundle.root.owns` | — (unproven) | a repo skill — SOURCE |
| gpg-signed git commits | commit authorship | `git.commit` skills | — (prior) | out of scope — another repo owns it |
| yubikey-held ssh keys | ssh auth material | `util.yubikey.ssh.sh` | — (prior) | a human's hardware; no reader can see it |
| 1password for untrackables | secrets a repo cannot hold | `backup_env.sh` | — (prior) | out of scope — a vendor owns it |

⚠️ the first row is the one that closes the others' shared hole. every pin row
discovers subjects **by the presence of a check** — so a download with no check
at all is invisible to each of them, by construction. only a reader keyed on the
**fetch** can see it.

🛑 **the reader column may name only files that exist.** an honest `— (unproven)`
beats a name that resolves to no file, because a false name is read as coverage and
a blank is read as a gap. 📜 measured: sixteen `prove.*` names sat here at once, and
every one of them had been culled.

⚠️ `— (prior)`, `— (unproven)`, and `🌙` are three different cells:

| cell | means |
|---|---|
| ✔ | a reader exists, and it has been seen to go RED on a real break |
| 🌙 | a reader exists and is GREEN on the live tree; its red half is unproven, or it covers part of its set |
| `— (unproven)` | this repo could check it and does not yet. the home is named beside it |
| `— (prior)` | no reader here can see it — a hardware token, another repo, a vendor |

🛑 **🌙 was added 2026-08-31, and the row it was added for is why.** the duct-seam
row read ✔ on a check that had gone red on demand — and the break had been planted
in the one form the check's own pattern already matched, so it proved the reader
obeys its author rather than that it can see the whole set (m.12 / q11).

⇒ a ✔ here now means *seen red on a break its author did not enumerate*. a check
that holds less than that is 🌙, and the difference is no formality: a half-proven
check reads as coverage and holds only the half nobody tested.

### ⚠️ .four `— (unproven)` rows were MEASURED BY HAND on 2026-08-31, and held

an uncovered row is not the same as an unknown one. each of these was read
directly against the live tree, and each was clean:

| claim | how it was read | result |
|---|---|---|
| a bound can END what it cuts | every live `timeout <n>` carries `-k` | ✔ every match was a comment; no bare live call |
| apt is never interactive | every live apt goes through `pkg_apt` / `pkg_install` | ✔ the rest are comments and fix-texts |
| sudo cannot reach a prompt | every live `sudo` sits behind a gate | ✔ `pkg_assert_sudo`, or `bundle.root.owns` in `5.4.gh` |
| no fetch escapes the boundary | `rhx wire.verify` over the files it could open | ✔ 0 escapes |

🛑 **this does NOT promote any row to ✔, and the distinction is the whole point.**
a hand measurement is a snapshot with no clamp behind it, so it decays the moment
somebody writes the next line (m.13). what it buys is narrower and still worth
recording:

> a red on any of these rows later is a genuine REGRESSION, not a mess that was
> always there. the baseline is dated, so the next reader knows which they found.

⚠️ and read the fourth row with its own caveat: `wire.verify` reported ✔ over the
files it could OPEN, and a rename had 196 of its subject on disk under another
name. its verdict is honest and its reach was short.

## 🛑 .A SEVENTEENTH GHOST SURVIVED THE CULL — measured 2026-09-02

the sweep below found sixteen and repaired them. the `credentials via keyrack` row kept
its ✔ through that repair, and it was the worst of the set — because it fails in **three
ways at once**, and each one alone would have been enough.

| # | what it did |
|---|---|
| 1 | its "reader" is `rule.require.reach-credentials-through-keyrack` — a **BRIEF**. prose cannot go red, and this page's own bar for ✔ is *"a reader exists, and it has been seen to go RED on a real break"* |
| 2 | that brief is about a **different claim** — *"do not PROBE credential state with a raw `aws`/`gh` call"*. it says not one word about a secret at rest |
| 3 | **the guarded property is FALSE in this tree.** `5.4.gh/configure.upsert.sh:216` pipes the PAT into `gh auth login --with-token`, and `gh` persists it to `~/.config/gh/hosts.yml` in cleartext — on every grove, on the paved path. `5.10.repos` names that file, twice, as cleartext |

⇒ so the row asserted a guarantee, cited prose as its reader, and the prose answered a
question nobody asked — while one bundle over, the paved path wrote the very secret the row
claimed was never at rest.

⚠️ and note WHICH glyph makes this worse than a blank. `— (unproven)` invites the next
reader to look. **`✔` closes the question**, and this ✔ survived a sweep aimed at exactly
this shape. a false ✔ is the one row a cull does not re-read.

⇒ the row now reads `✋`, because the property does not hold.

### 🛑 .and the row named ONE MEMBER OF A SET NOBODY HAD COUNTED

defect 3 above was found by a **human reading prose**. that is the whole tell: the row
claimed *"a secret at rest on a box"* — a claim about a SET — and its evidence was one
instance somebody happened to notice. the set itself had never been swept, which is this
page's own heuristic #2, **A CLAIM WIDER THAN ITS READER**.

⚠️ the obvious sweep is the wrong one. a reader that greps for the tools that persist —
`gh auth login`, `npm config set`, `docker login`, `.netrc`, `cargo login` — is a
**hand-written tool list**, which `rule.require.one-command-provision` grades a blocker by
name: *"it cannot report the member nobody added"*. the tool that writes a secret down
tomorrow is precisely the one absent from that list today.

⇒ so the sweep keys on the secret's ONE SOURCE instead. every secret on a box arrives
through the rack (`rule.require.reach-credentials-through-keyrack`), so a walk over
`keyrack get` CALL SITES cannot miss a consumer, whatever tool that consumer hands the
value to.

**measured 2026-09-02 — 16 files name the rack, 12 call it live:**

| class | n | what it means |
|---|---|---|
| `NAME` | 8 | the key is `AWS_PROFILE` — a selector for a local `~/.aws` stanza, which authorizes none of its own |
| `MEMORY` | 3 | a real secret, and it never reaches disk |
| `PERSISTS` | **1** | `5.4.gh` — and it is the one the human had already found |

⇒ **the class is now bounded, and the prose instance was its only member.** that is a real
result either way: a second one would have been a finding, and its absence is the first
evidence anybody has that the row's exception list is complete.

⚠️ the four files that name the rack and do not call it are PROSE — a comment at
`git-credential-keyrack.sh:238`, an `echo` fix-text at `:423`. a naive counter reads 3 live
calls in that file where the answer is 1, which is m.8: a reader that re-authors its subject
gains a second place to be wrong. the reader strips comments and `echo`/`printf` lines, and
proves that on four fixtures before it is aimed at a real file.

### .the reader, and what it does NOT claim

`prove.rack-consumers-are-dispositioned` does **not** decide whether a consumer writes its
value down — dataflow across a shell function is not something a grep can read, and a reader
that pretended otherwise would manufacture false verdicts both ways. it asks the one question
a grep can answer honestly:

> has a human looked at this call site and written down what it does with the value?

it reddens three ways — an undispositioned consumer, a censused file whose call count grew,
and a census row whose file stopped calling. **all three were exercised on 2026-09-02** and
each fired its own row while the other nine stayed ✔.

🛑 it does **not** fail on the `PERSISTS` row. that finding is known, recorded, and blocked
on a from-scratch grove — so a play that failed on it would be red on every run, and a check
that is always red gets silenced, which would take the other eleven rows down with it. it
prints the finding instead, every run, as a standing 🛑.

### .the fix at cause, and why it halts

`5.4.gh/configure.upsert.sh:15` already names it: **an env `GH_TOKEN` still WORKS — gh reads
it itself**, and persists none of it. the header rejects that route because telling a HUMAN
to `export GH_TOKEN=…` is a one-off command (`rule.require.install-via-procedures`) — but
that objection does not reach a shim the BUNDLE installs, where the box supplies the value
and no human types anything.

⇒ that is a `src/grove.provision/**` change, so it is unproven until it runs on a grove built
from scratch (`rule.require.one-command-provision`). both registered groves are already
converged, and a re-used grove proves the second apply, never the first. **this is the one
legitimate halt that rule grants: it needs a fresh grove.**

⚠️ and the severity is bounded, deliberately stated so nobody re-inflates it. a seat that can
read `~/.config/gh/hosts.yml` (0600, same unix user) could already read the rack, so the copy
buys **no initial access**. its whole delta is **persistence past revocation** — which is why
`rotate the credential`, the first move after a suspected grove compromise, does not evict
unless the old pat is REVOKED.

## 🛑 .SIXTEEN GHOST READERS STOOD IN THAT COLUMN — measured 2026-08-31

```sh
rhx play.run --list
#    └─ read the tracked set for yourself, and match every name in the
#       reader column against it before you trust a single ✔
```

the play family was culled, and **not one** of the sixteen `prove.*` names the
reader column then held survived it. every cell in that column was a claim about
a set with zero members.

⚠️ this is worse than an empty column, and by exactly the margin that makes it
worth its own section: **the tree still shapes its code to satisfy readers that
no longer run**, and cites them by name where a maintainer will read it.

```sh
rhx grepsafe --pattern 'prove\.(sha256-pins|gpg-signature|apt-key|clone-pins|registry-|wire-fetches|offbox-reads|tool-defaults|timeouts-kill|apt-is-never|sudo-is-gated)' --glob 'src/**/*.sh'
#    └─ 29 citations across 20 files
```

⚠️ **29, not the four this section first claimed.** the first count was taken by
eye off a handful of files and written down as if it were the set — q11 in a
brief rather than in a reader: a pattern matched a subset, and the subset's total
was reported as the whole. the command above is the count, and it re-runs.

the four heaviest are worth naming, because each shapes CODE and not only prose:

| file | what it declares for a dead reader |
|---|---|
| `src/grove.web.sh` | its wrappers exist so an off-box-bound reader can find them |
| `5.3.brains/provision.upsert.sh` | its pin var is named for a registry-pin reader |
| `5.14.treesitter/provision.upsert.sh` | same |
| `6.2.codium/provision.upsert.sh` | same |

⇒ the code is correct and the CLAIM that it was checked was false. a reader of
this page believed sixteen readers guarded this repo; **zero did.** that is the
false-✔ half of `gotcha.a-check-that-cries-wolf-gets-silenced`, at the scale of
a whole page.

⚠️ the four rows above still stand, and they are the residue that outlives the
column's repair: **a comment that names a dead reader is a dead pointer with a
plausible destination.** each names a real property the code should keep, so
none of the four is deleted — but each cites an artifact nobody can open, so a
maintainer who follows the name learns the property is optional. the fix is to
name the PROPERTY, never the reader that once checked it.

🛑 and it is this page's own founding defect, re-committed by its own repair.
the ledger exists because a check nobody runs decays (m.13). its repair — name
a reader per row — created sixteen more of exactly that, then outlived them
(m.10).

### .the repair is a HOME per row, never sixteen restored plays

a play is scratch (`rule.forbid.repair-plays`); to restore sixteen would
re-commit m.13 a third time. each row belongs at one of three homes:

| home | for a row whose subject is… | it runs when |
|---|---|---|
| a bundle's `*.verify` | machine state | every `grove.provision` |
| `git.grove.provision test` | a claim about a live box | every provision |
| a skill (`rhx <name>.verify`) | the repo's own tracked text | a human or a hook asks |

⚠️ until a row names a home, its reader cell reads `— (unproven)`. an honest
blank beats a name that resolves to no file.

### ✔ .three rows are re-homed, and each taught a different half of the pattern

| row | home chosen | the lesson |
|---|---|---|
| **dox** | a repo skill — `rhx dox.verify` | key the reader on the **superset** — `git ls-files`, the publication set. a file is dox the moment it is pushed, so a reader keyed on a subdirectory cannot see the one that lands elsewhere |
| **the duct seam** | `2.7.aliases`'s verify | pick the home from the claim's **subject**. it looked like a live-box claim and is a SOURCE claim, so it belongs to the bundle that owns the file, not to the gate that reaches a duct |
| **every wire pull** | a repo skill — `rhx wire.verify` | **a superset minus a named subtraction, never a derived allowlist** — see below |

⇒ the duct row adds the sharper half: **the regression each guards is
ADDITIVE, never a revert.** nobody deletes `__duct_ssh_tmux` or `web_fetch`;
somebody adds an eleventh tmux call, or copies a vendor's `curl … | sh`
one-liner, because that is what every install doc says. so both readers COUNT —
a presence test stays green straight through that exact edit.

#### 🛑 .a DERIVED subject can empty in silence, and an empty subject reads as clean

the obvious subject is "every `.sh` under `src/`" and it looks wrong: it sweeps in
`bash_aliases.sh`, `ductwork.sh`, `termwork.sh` — the three files `2.7.aliases`
copies to `$HOME`. those run in a **human's interactive shell**, where
`grove.web.sh` is never sourced, so `web_fetch` does not exist to call. four
✋ against correct code on the first run.

so the subject was DERIVED instead, from what the run loads. that derivation
failed twice, and the second failure is the instructive one:

1. it read only the entrypoint's `source` lines, and missed `emoji.index.build.sh`
   — run as `bash "$GROVE_SRC/…"` from both phases of its bundle, and whose own
   header records the two unbounded `curl` calls it once held. **the file the
   reader most obviously wanted was the one its subject omitted** (q11, one layer
   up from the pattern)
2. a rename then moved `src/grove.provision/**` on DISK while the corpus was
   enumerated from the INDEX. the derived patterns matched no row, the subject
   fell **204 → 8**, and the reader printed ✔

⇒ the second is not an argument to derive harder:

> **a reader whose SUBJECT comes from one store and whose CORPUS comes from
> another disagrees with itself the moment the two stores drift** (q13).

so both halves now read the **index**, and the filter is a **superset with an
explicit subtraction**: every tracked `src/**/*.sh` plus the bootstrap, minus five
named rows. a new file is IN by default — the safe direction — and a `EXCLUDED`
list cannot silently empty the way an allowlist can.

#### 🛑 .an INCOMPLETE subject is not a pass

both readers now exit **2** when a member of their subject cannot be opened,
rather than print ✔ over the part they could read. this is not pedantry — it is
the only way the caveat reaches a human at all:

> **`rhx` buffers a skill's stderr and relays it only on a NON-ZERO exit.**

so a `⚠️` printed beside a ✔ is discarded by the transport. measured on the same
tree in the same minute: a direct `bash` run printed *"201 tracked files are
ABSENT from disk"*, and `rhx` printed only `✔ none found across 603`. the full
account sits in `gotcha.the-duct-returns-the-send-not-the-answer`, under
`.the same shape one layer IN`.

#### 🛑 .the first row is TWO claims, and a reader must carry both

- **no fetch escapes the boundary** — a `curl`, `wget`, or `git clone` written
  anywhere the run loads, outside `grove.web.sh`
- **every fetch through the boundary is CHECKED** — `web_fetch` bounds the
  transfer and floors the transport, and says none of whether the bytes are the
  right bytes. the pin is what makes them right.

⚠️ the second claim is **file-scoped**, deliberately. a `.sig` and a signer key
are both fetched and neither is verified on its own — each IS the instrument of
the verification. a per-call rule reddens three correct sites, and a reader that
argues with correct code is skipped. so the checkable claim is one step coarser:
a file that reaches the wire must also carry a check.

⇒ its residue, stated rather than hidden: a file with two fetches and one check
passes. the per-call form needs the instrument/artifact split made explicit at
the call — a change to `grove.web.sh`, not to the reader.

#### 🛑 .and the probe asserts its EXPECTED DELTA, never merely a rise

`wire.verify --prove` plants two lines that trip **three** rules between them, so
the only correct answer is `+3`. an earlier run moved the count `+1` where `+2`
was owed: the pipe rule required whitespace after `sh`, and the planted line ends
in a semicolon, so it was blind to every `| sh` that closes a compound statement.

⇒ a probe that accepted any rise would have printed `🌴 BITES` over a rule blind
on every real line — **a false ✔ that carries a probe's authority.** so a
partial bite is a failure, and the message names which half held.

⚠️ two named gaps, stated rather than papered over: a `curl … | sh` inside a
**skill** or inside **`bash_aliases.sh`** is a real defect and this reader will
not see it — neither has a declared boundary to violate. the repair is to
declare one there first, then widen the subject; never to widen the pattern
against a rule that does not exist.

## ✔ .the dox row is the first re-homed, and it was SEEN to bite

`rhx dox.verify` reads `git ls-files` — the **publication** set, which is the
superset a dox reader wants: a file is dox the moment it is pushed, and a
reader keyed on a subdirectory cannot see the one that lands elsewhere.

it carries its own discrimination probe (`--prove`), which plants a canary in
`readme.md` — a REAL tracked file, never a fixture, so it cannot inherit the
author's blind spot (q11):

```
🌲 dox.verify --prove
   ├─ before: 0 hit(s) across 800 tracked files
   ├─ after:  1 hit(s), with one canary planted
   ├─ restore: ✔ readme.md is byte-identical to its pre-probe copy
   └─ 🌴 the reader BITES — the planted id moved the count 0 → 1
```

📜 its first draft reported **55 hits, 53 of them false**: the email pattern
`x@y.z` matched `cloud@aws.ec2`, `local@unix`, and `git@github.com` — this
repo's own `--for` axis. a reader red on the vocabulary of the tree it guards
is silenced within a day. the fix was a closed INCLUDE list of mail domains,
because an exclude list is a claim about a grammar with more shapes than any
author enumerates (m.12).

⚠️ and its `0` above is worth one more sentence, because it was `2` an hour
earlier and the delta was NOT a redaction. the ip rule matched the DOT form
only, so aws's own hostname shape — `ip-<a>-<b>-<c>-<d>`, the same address with
dashes — reached no rule at all. a second rule for the dash form bit on its
first run, in **two briefs nobody had looked at**, each of which had carried a
live grove's address since the day it was written.

⇒ **a count is a claim about a set, and a set is only as big as the reader's
reach.** no fixture answers this — an arm plants only a shape its author can
see (q11). what answered it was a read of the live tree with a second form in
hand.

## ✔ .the ledger's one self-declared hole — CLOSED 2026-08-31

it read: *"a registry install may be unpinned, and no reader refuses it."* the
hole was real and the way it was FRAMED is what kept it open for a fortnight.

### 🛑 the framing was the blocker, not the work

it was posed as a fulcrum for a human — *pin everything, or pin some things?* —
and stated as a table of six unpinned names. both halves were wrong:

- the table listed `declastruct` and `declastruct-aws` as unpinned peers beside
  `@openai/codex`, as though the six were one set. **they are not.** the first
  two are ehmpathy's own registry account; the third is somebody else's
- the deciding question was taken to be *how much do we need this tool to float?*
  — a CAPABILITY question, which no amount of thought can settle, because it
  trades two goods against each other

⇒ the question that settles it in one pass is not about the tool at all:

> **WHO CAN PUBLISH THIS?**

a float is an open grant of arbitrary code execution, as this human, on every
box, at the next apply — to whoever can PUBLISH that package. for a third-party
one it buys convenience from a stranger.

| | float | pin |
|---|---|---|
| **first-party** — `rhachet`, `declastruct`, `declastruct-aws` | 🌙 the grant buys this repo its own release cadence; the control that bounds it is UNBUILT — below | |
| **third-party** — `@openai/codex`, `claude-code`, `tree-sitter-cli` | | ✔ a stranger's account reaches every box |

#### 🛑 the first-party row read `✔ the account is ours`, and that was FALSE

📜 measured 2026-09-03, redteam round 23. the row answered its own question in the
wrong currency: the npm **account** is not what a publish consults.

```
ehmpathy/rhachet .github/workflows/publish.yml
  on: push: tags: [v*]           ← a TAG PUSH publishes
  → .publish-npm.yml → npm publish, via npm OIDC trusted publish
  jobs.publish carries NO `environment:` key
repos/ehmpathy/rhachet/rulesets      → []
repos/ehmpathy/rhachet/environments  → prod, protection_rules []
                                       (and the workflow never names it)
declastruct: byte-for-byte the same shape
```

⇒ **whoever can push a tag can publish.** the credential that can is
`@all.camp.GITHUB_TOKEN` — a classic pat, `repo` scope, which is not per-repo
scopable — held on **every grove**, under a posture that says ASSUME A GROVE
COMPROMISED. so the answer to *WHO CAN PUBLISH THIS?* is **every grove**, and the
row said *us*.

⚠️ this is the shape this file warns about in its own words: *"`✔` closes the
question … a false ✔ is the one row a cull does not re-read."* it survived every
sweep because the ARGUMENT beside it was sound — a pin genuinely would gate this
repo on its own releases — and only the **control** was wrong.

⇒ the row is 🌙 now, which is what an accepted risk with an unbuilt control reads
as. two candidates, and the second is at cause:

| candidate | cost | reach |
|---|---|---|
| gate the `publish` job behind a github environment with a required reviewer | one config per repo; free on a public repo | closes the tag-push path |
| the per-org **app token** with `--scope` — `grove.auth.github.roadmap` phase 2 | large | closes it, AND closes the same credential's push to `main` of this repo |

⚠️ **a PIN is the plausible fix and it is the wrong one.** `5.3.brains/_.sh`'s own
argument says a pin gates the repo on its own release cadence — and a pin holds
against neither a human's `pnpm add -g rhachet` nor this repo's `node_modules`,
which the `.claude` hooks run from.

#### ⚠️ and the same credential can push `main` of THIS repo

`grove.bootstrap.sh` clones `uladkasach/dev-env-setup` at its **default branch**,
anonymously, with no `--at` and no verification, then `exec`s the entrypoint. that
branch is the single anchor under all 48 `$GROVE_SRC/…` → `$HOME` copies — the
zsh rc a login shell sources, the six git aliases that shell out, three root
systemd units, two kitty kittens, `autoconfig.js`, `init.lua`.

measured the same day:

```
repos/uladkasach/dev-env-setup/rulesets       → []
branches/main                                 → protected: true
branches/main/protection
  required_pull_request_reviews   ABSENT
  required_status_checks          ABSENT
  enforce_admins.enabled          false
  required_linear_history         true
  allow_force_pushes              false
```

⇒ `protected: true` forbids a force-push and a delete. it does **not** stop an
ordinary commit push to `main`, and it reads to a reader as a gate it is not.

⚠️ the fix is `required_pull_request_reviews` on `main` — **not** a pin in
`grove.bootstrap.sh`. that file's pin exemption is argued correctly on its own
terms (a bootstrap pinned to a sha can never bootstrap onto a newer commit); what
its note omits is the pin question at all, which is *a guard that names ONE
hazard immunizes the others*, in the tree's most-exempted file.

### ✔ what landed

| site | control | reader |
|---|---|---|
| `@openai/codex` | `@$GROVE_BRAIN_CODEX_PIN` | `5.3.brains/provision.verify.sh` — asks the BINARY |
| `cargo install tree-sitter-cli` | `--version "$GROVE_TREESITTER_PIN"` | `5.14.treesitter/provision.verify.sh` — asks the BINARY |
| `codium --install-extension` | 🛑 none — see below | — |

both readers were seen in BOTH directions on 2026-08-31: green where the box
matched, and **red on a real drift with no break planted** — a box on codex
`0.128.0` against a pin that said `0.151.0`.

🛑 **the home is the bundle's own `provision.verify`, not a repo skill**, and
that is what makes it durable: a repo skill runs when somebody remembers, where a
bundle verify runs on **every** `grove.provision`, on every box. m.13 answered by
construction rather than by discipline.

### 🛑 the red taught a second lesson, about the pin's VALUE

the first `GROVE_BRAIN_CODEX_PIN` was `0.151.0`, read from `npm view` at the
moment the line was typed. the verify went red — correctly — against a box that
had drifted no inch. the **pin** had jumped 23 minors, and the next apply would
have upgraded the box.

> **a pin set to "latest when I wrote it" blesses an unreviewed publish.** it
> performs the exact uptake the pin exists to refuse, by hand, wearing the badge
> of a security control.

⇒ pin to what has been **run**, never to what is **newest**.
`GROVE_BRAIN_CLAUDE_PIN` was already the model — it sits deliberately below
latest — and the reason had gone unread.

### 🛑 the one site that stays `— (unproven)`, and why a pin there would LIE

`codium --install-extension zokugun.sync-settings` takes an `@version` and the
pin would not hold: `extensions.autoUpdate` defaults to true and no file in
`codium/` sets it, so the editor replaces the extension in the background. a
version named at install time is overwritten on the next launch.

**an unenforceable pin is worse than an absent one** — it reads as coverage in
this table and holds no state. that is the claude in-place-updater measurement in
another costume: an updater rewrites the artifact and leaves the install record
alone.

⇒ the control is two parts that must land together — `"extensions.autoUpdate":
false` in this repo's codium settings, AND the pin with a verify that asks the
live extension list. part one changes a human's editor and `6.apps` declines on a
grove, so it cannot be proven the way this repo proves a bundle. it is the
human's call.

⚠️ the residual exposure, stated rather than hidden: a marketplace publish
reaches this **laptop** on the next editor launch. it reaches no grove.

### ✔ .workspace trust — CLOSED 2026-09-02, and why it sat open for five rounds

`codium/profiles/main/data/settings.json:307` declared
`"security.workspace.trust.untrustedFiles": "open"`. it now declares `"prompt"`, which
is the editor's own default.

**the honest grade, which the five prior rounds did not state**: LOW, and ESCALATION
rather than ingress.

| the fact | why it bounds the grade |
|---|---|
| `security.workspace.trust.enabled` appears in NO file here | so it sits at its default `true` — the FOLDER-level trust gate was on the whole time |
| `untrustedFiles` governs **loose files** alone | it decides what happens when a single file is opened into an already-TRUSTED window; it does not disarm the folder gate |
| it needs a human to act | somebody must open a grove-authored loose file, by hand |

⇒ so a grove could not reach the editor on its own. what `open` removed was the prompt
that would have caught a human who opened one file out of a pulled tree.

#### 🛑 .the residue — TWO WRITERS on this artifact, and the loser is silent

`codium/sync.settings.yml` declares `repository: {type: file, path: …/dev-env-setup/codium}`
with `profile: main`. so `profiles/main/data/settings.json` is the sync extension's OWN
repository, and it is written from both ends:

| the human's next action | which copy wins |
|---|---|
| sync **download** | this repo's — the fix lands |
| sync **upload** | the LIVE editor's — the fix is silently reverted |

that is `rule.forbid.two-writers-on-one-artifact` exactly, and it is why no bundle may
manage this path (`repo.overview.md` says so) and why five rounds parked the row rather
than edit it.

⚠️ **so this closure is conditional, and states its condition rather than hides it**: the
declared value is correct now, and it becomes the live value on the next DOWNLOAD. an
upload first reverts it with no signal. a verify cannot settle this from the repo — it
would read the repo's own copy and report ✔ about a file the editor may have already
overwritten (`gotcha.my-own-note-became-my-evidence`, at file scope).

⇒ the durable half is the human's: run a download, or set it in the live editor too.

### ⚠️ two residues that outlive this closure

- **a top-level pin bounds the package, never its dependency tree.** a global
  `pnpm install -g` and a `cargo install` both fetch transitives fresh, with no
  lockfile to hold them. `cargo install --locked` closes the cargo half and is
  NOT shipped: it fails outright against a crate that publishes no lockfile, and
  this repo does not spend an unproven flag on the provision path. the exact
  command to prove it on a fresh grove sits in
  `5.14.treesitter/provision.upsert.sh`
- **no reader reports the SPLIT.** a seventh install can still land unpinned and
  no run reddens. that reader is owed — its subject is every `*install*` line in
  the tree, and its rule is the WHO-CAN-PUBLISH table above

## 🛑 .the rows added 2026-08-31 all share ONE shape

not one was an ABSENT guard. every one was a guard **weaker than its own claim**,
and each was weak in a different way:

| row | the claim it made | what it actually held |
|---|---|---|
| control socket | "the terminal exposes no socket" | it read the FIRST match; kitty resolves the LAST |
| config parses | "the config is valid" | it called `kitty --debug-config`, which this kitty has no such flag for — a permanent 🌙 for its whole life |
| boundary excludes | "`.git` never crosses" | push declared it; PULL carried it back |
| commit subject | "the duct strips escapes" | it stripped on the DUCT path; 14 local echoes had no sink |
| editor options | "a pulled tree cannot configure nvim" | never made; `modeline` was ON by default |
| imagemagick | "imagemagick is present ✔" | present says none of whether its policy is open |

⇒ **a guard's presence is not its reach.** the pattern that finds every one is to
read what the guard MEASURES against what the row CLAIMS, never to ask whether a
guard exists (m.12 / q11, applied to the checks themselves).

### ⚠️ and the third arm — a two-valued reader manufactures false ✋

three readers written THIS round had to grow a third arm, and each was caught by
q1 alone: the evidence and the verdict contradicted each other on one screen.

| reader | its two arms | the state they collapsed |
|---|---|---|
| a coder probe | refused / allowed | *this build carries no such coder* |
| a coder probe | write-refused / not | *this coder has no encoder to ask* |
| an nvim probe | guarded / unguarded | *`-c` runs after the file loads, so the probe asked no question at all* |

⇒ each printed a **false ✋ against correct code**, which is the corrosive half:
a check that argues with correct code gets silenced, and then it is a false ✔.

⚠️ every one of the three was a defect **inside a repair**, not in the tree it
was written to guard. a repair is the likeliest site of the next defect, so the
probe that proves a fix needs its own both-directions read.

## 🛑 .the rows revised 2026-09-01 sharpen that shape — an ADDITIVE guard

the round above read every guard's CLAIM against what it MEASURED. the round after
it turned that instrument on the readers themselves, and found a subclass the
previous pattern cannot reach:

> **a guard that defends against an ADDITION cannot be proven by a fixture beside
> it.** an arm plants only a shape its author can see, so a reader and a fixture
> written by one hand share one blind spot.

| row | the claim it made | what it actually held |
|---|---|---|
| commit subject | "every subject capture is sunk" | it read `--format=` alone; git spells the same request six other ways |
| rc control bytes | "strips before EVERY OSC emit" | it read one partial word, anywhere, comments included — ✔ green with every strip deleted |
| control socket | "remote control is off" | it denied ONE literal of kitty's NINE declared values |
| dox account id | "no account id is written here" | its exemptions blinded it to 102 lines to buy 1 |

⚠️ **none of these had a live hit.** the commit-subject reader's count was correct,
its arms all passed, and zero blind forms sat on the tree — so no run, no fixture,
and no floor could have reddened. the reader was simply unable to see a form no one
had written yet.

⇒ **the instrument is a FORM TABLE, asked of the SUBJECT.** git for its format
spellings, kitty for its declared choices, the rc for its emit sites. enumerate from
the subject's side, never from the reader's, then drive the old and new reader over
the table side by side and PRINT every disagreement.

⚠️ and the corollary that cost three near-misses in one round: **to widen the axis
you have in view narrows no other.** each of the three repairs below manufactured a
false ✋ that its own probe caught before it landed — a quote-strip that ate a
redirect, a span that fused a hash capture to a printf, a per-line check that
reddened on a strip two lines above. the probe that proves a fix owes its own
both-directions read (`rule.require.clamp-edge-cases`).

## 🛑 .and the shape UNDER those readers — A BOUNDARY MUST NOT CONSUME WHAT IT BOUNDS

the form table above asks *which values can reach this reader*. one class of defect
survives a correct answer to that question, because it lives in HOW the reader marks
where a value ends:

> **a reader that marks a boundary by CONSUMING a character has spent that character,
> and whatever needed it next goes unread.**

it is one defect, and it wears a different costume in every parse dialect:

| the reader | what it spent | what went unread |
|---|---|---|
| `[^0-9a-z]` around an id | the character BEFORE | an id at column 0 — no character precedes it |
| `grep -o`, matches never overlap | the delimiter AFTER | the next id, which needed that delimiter as its own head bound |
| `${x#*§}` on a `§`-less string | a separator that was never there — it returns x WHOLE | the fourth field, which silently becomes the third |
| `jq -r '.a, .b'` | one NEWLINE per field | every later field, once a value carries a newline of its own |
| `grep -qxF "$name"` | a `-` at the front, spent on OPTION parse | the name itself — grep exits 2, and `! grep` reads that as absent |

⇒ **the repair is a ZERO-WIDTH bound, or an explicit frame.** `(?<!…)…(?!…)` makes the
match BE the value, so no end is privileged and no neighbour is lost. `@tsv` plus one
`IFS=$'\t' read` makes one record one line, whatever bytes a field carries. `--`
separates options from operands so a value can never be read as a flag.

⚠️ **and a frame can be undone at the LAST step.** `@tsv` escapes a newline to the two
characters `\n`, and **zsh's builtin `echo` expands them again** — so a fix measured
only under bash ships the forgery to every zsh user under a green verdict. print a
framed value with `printf '%s\n'`, and drive a dual-shell file in BOTH dialects.

⚠️ **a frame is also not a sink.** `@tsv` escapes tab, newline, and return; it leaves
ESC alone. a value that reaches a TERMINAL still needs `__duct_strip_escapes`, because
an ESC there is a command rather than text.

## 🛑 .and the shape ABOVE all of them — A GUARD THAT NAMES ONE HAZARD IMMUNIZES THE OTHERS

every shape above asks what a reader gets WRONG. this one asks what a CORRECT guard
hides, and it is the harder of the two because there is no defect to find in the guard:

> **a guard that names ONE hazard reads as a guard against THE hazard. the next reader
> checks the named one, finds it handled, and stops — so an unnamed twin of the same
> cause is protected by the guard's own credibility.**

measured across four independent sites on 2026-09-01. in each, the named half was
correct, careful, and often the subject of a long header:

| the hazard the guard NAMED | the twin it left unnamed |
|---|---|
| fnm would PROMPT, so the `chpwd` hook was made incapable of a prompt | fnm would also FETCH, and a pulled `.nvmrc` names WHICH node the laptop then runs |
| a pnpm call could read a hostile tree, so its two PEERS were rooted at `$HOME` | the third call in the same block — the one whose stdout is `eval`'d |
| a render format could be REFUSED by a policy, so the refusal is read | it could never be WRITTEN, so there is no measurement to read and ✔ prints over zero |
| tar's exit `> 1` is a hard failure, so the caller aborts | tar's exit `== 1` is patched, and the PATCH's own failure is discarded |

⚠️ **the care is what does the damage.** a guard with a thin comment invites a second
look. a guard with thirty lines of correct argument closes the question — so the more
rigorous the account of the named hazard, the less likely anyone re-opens the file to
find its twin. the fnm hook is the worked example: a precise, dated, measured argument
about a prompt, and the fetch went unmentioned for a month.

⇒ so the question to ask of a guard you did not write, and of one you did:

> **this names one way it goes wrong. what is the SECOND way, and does the guard's
> presence make anyone less likely to look?**

⚠️ its near neighbour is m.9 (one fact, N holders) and it is NOT the same: m.9 is one
claim copied, where the copies drift. this is one CAUSE with two effects, where only one
effect was ever written down. a grep finds a drifted copy; no grep finds a hazard nobody
named.

## 🛑 .and the shape ABOVE that one — THE CLAMP IS THE LEAST-REVIEWED CODE AND THE MOST TRUSTED

every shape above is about a check that reads the REPO. this one is about the check that
reads the FIX — the play written to prove a repair, whose ✔ is what licenses the ship.

> **a clamp is written by the same person, in the same minute, as the fix it grades — so
> it inherits that fix's mental model. and no one reviews it, because its whole purpose
> is to be the artifact that says the review is done.**

measured 2026-09-01: five clamps written in ONE round, and every one was wrong on its
first run. not one of the five defects was in the fix — all five were in the reader:

| what the clamp's reader did | which direction it failed |
|---|---|
| matched the retired pattern quoted inside the fix's OWN comment | ✔ "no change today" |
| anchored `^ +-c`, so it missed the flag that rides a `git -c …` line | ✋ "the two copies DIFFER" |
| passed a base allowlist and APPENDED the subject, WIDENING it | ✔ inverted, under correct labels |
| grepped a call pattern over `src/` and caught an EXAMPLE in a header | ✋ "the fix broke a real subject" |
| `head -1` of two verdict lines took the FAILURE one | ✋ graded the wrong sentence |

⚠️ **three of the five failed toward ✔ or toward "no change".** that is the half that
ships a fix believed proven. a clamp gone red gets read at once; a clamp that reports "no
change today" gets shrugged at, and the fix ships unproven.

⇒ the question to ask of every clamp, the one you just wrote included:

> **it printed a verdict. what SUBJECT did it print beside that verdict — and is that
> subject the artifact I changed?**

all five were caught in a single glance, by the same means: the play echoed what it had
EXTRACTED next to what it CONCLUDED, and the two disagreed on one screen. so the habit is
load-bear, never decoration:

> **a clamp must print the subject it read, never only the verdict it reached.**

⚠️ this is q1 turned inward. q1 asks whether a CHECK's evidence agrees with its verdict;
this asks it of the check that grades your own repair — the one place the question goes
unasked, because by then you have stopped the search for defects and started the search
for a green light.

### ⚠️ .and the arm that catches what a self-read cannot — A CONTROL

the habit above catches a clamp whose verdict argues with its own evidence. it cannot catch
a clamp whose evidence is **consistent and produced by a harness that never ran the
subject**.

measured 2026-09-01. a probe of rsync's stdout ran three arms and reported three byte
counts. the two SUBJECT arms were green and agreed with each other. every arm had in fact
run the identical command: the runner took `run "-az -v"` as one string, `shift` ate it as
the label, and `"$@"` was empty — so all three measured the default flag set.

**ARM 3 was a control**: `-az -v` MUST produce output, by definition of `-v`. it reported
zero, which is impossible of the subject and possible only of the harness.

⇒ **a control arm is the only part of a probe that reddens when the PROBE is broken rather
than when the SUBJECT is.** a probe of N subjects with no control cannot tell "all N hold"
from "the probe never ran" — and the second reads exactly like the first.

so the shape of a trustworthy probe is:

| arm | expected | what its failure indicts |
|---|---|---|
| subject arms | whatever holds | the subject |
| **one known-POSITIVE control** | must produce a result | **the probe** |
| one known-NEGATIVE control | must produce none | **the probe** |

⚠️ this is the same demand `gotcha.a-check-that-cries-wolf-gets-silenced` makes of a CHECK
(*"a check proven in one direction only is half proven"*), aimed one layer in — at the probe
that grades the check.

## 🛑 .the shape round 17 found — A CORPUS BOUNDED BY FILE TYPE

every shape below is about a reader that is too narrow **within** its corpus. this one is
about a corpus that is too narrow, and the boundary is invisible because it is an
**extension**.

> **the discipline is complete, enforced, and mandatory — inside one file type. a path
> written in another language is not a gap in any reader; it is outside every reader's
> subject, so it produces no row at all to be absent.**

measured 2026-09-02. this repo's fetch discipline is among its strongest: `git_clone --at`
is MANDATORY (`grove.web.sh:967` returns 2 before a packet moves), every apt key is pinned
with `signed-by=`, every tarball is sha256- or gpg-verified.

and `src/init.lua` fetched **14 repos at default-branch tip**, one of which
(`nvim-treesitter`, `build = ':TSUpdate'`) **executed** on install.

| why no reader saw it | |
|---|---|
| the corpus is `src/**/*.sh` + the bundle tree | `init.lua` is **lua** |
| the fetch is not `git_clone`, `curl`, or `pkg_install` | it is `vim.fn.system{'git','clone',…}` and a plugin-manager spec |
| the trigger is not a provision step | it is `nvim`, on the laptop, at any keystroke |

⚠️ **and a `--mode plan` performed it.** `4.5.nvim/configure.verify` starts nvim headless,
so a survey a human reads as read-only cloned and ran 14 repos on a fresh box.

### .the question this adds

`gotcha.a-check-that-cries-wolf-gets-silenced` q11 asks *in how many FORMS is this subject
written, and which does the pattern match?* — and every worked example there is a LINE
shape. this is the same question one level out:

> **in how many LANGUAGES is this subject written, and which does my corpus hold?**

⇒ and the tell is cheap: **a policy stated as universal, enforced by a reader keyed on one
extension.** if the sentence says *"every fetch is pinned"* and the reader globs `*.sh`,
then every fetch in lua, python, a systemd unit, or a Makefile is unproven — and no count
moves when one is added.

⚠️ **a floor cannot catch this either.** a floor calibrated on `*.sh` ratifies the
extension as the corpus, exactly as m.12's blind first read ratified its own blindness.
what answers it is a planted row **in the form the corpus does not hold**.

## 🛑 .and the shape BESIDE all of them — A CLAIM WIDER THAN ITS READER

every shape above is about a reader that holds less than it should. this one is about a
reader that is **exactly right**, and a sentence above it that is not.

> **the guard is correct. the tree holds the property today. and the COMMENT claims
> something no checker beside it can hold — so the sentence is renewed by a human re-read,
> and by nothing else.**

measured 2026-09-02, and it was the ENTIRE yield of one round: 0 blockers, 3 nitpicks, all
three this shape. the sharpest:

```
claimed:   "🛑 .why every path join goes through here"          (ductwork.sh:51)
reached:   the reader counts joins that name the dir LITERALLY, on one line, and demands 1
```

a fifth reader that aliases the dir first counts **0 + 0**:

```sh
local base="$DUCTWORK_DIR/ducts"     # ← counts 1 (this line)
printf '%s\n' "$base/$name.json"     # ← counts 0. total stays 1. green.
```

⇒ so the row goes green through **the exact additive regression it is shaped for**, and the
comment above it reads as though it could not.

### .the two questions, and why one is not enough

the standing heuristic asks one question of every guard. this shape adds a second:

| # | question | what it catches |
|---|---|---|
| 1 | what does the comment claim, and what does the **code** reach? | the guard is weaker than its claim |
| 2 | what does the comment claim, and what can the **checker** beside it hold? | the guard is fine; the SENTENCE is wide |

⚠️ question 2 is invisible to question 1. the code was correct at every site, the property
held, and a reviewer who traced the mechanism would have found nothing at all.

### 🛑 .the fix is to NARROW THE CLAIM — never to widen the reader

this is the half that costs money if you get it wrong, and two of the three findings shipped
with an explicit warning against the obvious code fix.

a reader widened to catch the alias — one that counts `"$<var>/$<var>"` joins — would flag
`bash_aliases.sh`'s worktree paths, `git-credential-keyrack.sh`, `zshenv.sh`, and every
`$GROVE_SRC/…` in the bundle phases. **well over 200 correct lines in `src/` alone.**

⇒ that is `relay.verify` rebuilt — a reader written and deleted the same hour on 2026-09-02
for flagging several hundred correct lines on its first run. **a false ✋ at that scale does
not stay a false ✋; it decays into a silenced check**
(`gotcha.a-check-that-cries-wolf-gets-silenced`, its opening thesis).

so the honest close for a property no grep can express:

> **write what the reader holds, then say plainly that the wider sentence is a human's to
> renew.** q11 — a count is a claim about a set, and a set is only as big as its reader's
> reach.

## 🛑 .the shape round 18 must hunt — A LESSON QUARANTINED IN ITS FIRST FILE

every shape above asks what a reader or a claim FAILED to reach. this one grants that the
repo already reached it — once — and asks where the reach stopped.

> **the lesson is written down, in this repo, in prose, correctly. it names the attack, the
> cost, and the repair. and it sits in the ONE file whose author learned it, while the peer
> with the identical shape carries the defect the lesson describes.**

measured 2026-09-02. six round-17 findings were closed in one pass, and **three of the six
were this**:

| id | the lesson, and where this repo already held it | where it had not traveled |
|---|---|---|
| SC-F3 | *"a real key beside a forged one is the cheap attack"* — stated verbatim at `git.grove.trust.gen.sh:546`, for ssh host keys | kitty's gpg gate matched a bare `Good signature`, so ANY key in the local gpg store passed |
| PE-F1 | *a findsert keyed on a NAME adopts whatever holds that name* — recorded in `git.grove.wake.sh`'s own header at `:467-504`, for the ssh alias | the duct `[KEEP]`, three paragraphs ABOVE it in the same file, accepted a banner without a read of which box answered |
| PE-F2 | the `..` traversal `case`, already correct at `git.grove.pull.sh:303-312` | `git.grove.push --into ../../tmp/x` wrote outside `$HOME` and reported success |

⚠️ **PE-F1 is the one that settles the shape.** the lesson and the defect were in the SAME
FILE, forty lines apart, by the same author, in one session. so the boundary is not a
directory, a language, or a corpus — it is **the site the author had in hand when the lesson
landed**.

### .the question this adds

every shape above starts from a READER and asks what it misses. this one inverts the search:

> **for every security lesson this repo has written down, where ELSE does that shape occur —
> and did the fix travel?**

⇒ the corpus to sweep is not `src/`. it is the repo's own 🛑 blocks, its `gotcha.*` briefs,
and its `.why` headers. each one names a hazard class in plain prose. **read the class, then
go find its peers.**

### .why no reader can hold this

a lesson is prose, and a peer is recognized by SHAPE, never by text. `Good signature` and a
tofu host-key adoption share no token — they share the property *"the gate binds the act and
not the actor."* that is not a grep.

⚠️ and the tell is the inverse of every other shape here: **the better the prose, the more
persuasive the quarantine.** a well-argued 🛑 block reads as the repo's settled position on
the hazard, so a reader who finds it concludes the hazard is HANDLED — and stops. an absent
lesson invites a search; a present one closes it.

⇒ so this shape cannot be clamped, and it must not be filed as a task
(`rule.forbid.deferred-provision-defects`'s instinct, one level out). it is a **sweep
discipline**: when a lesson lands, the same edit asks *"which other file has this shape?"*
and travels there before the session ends.

## 🛑 .the shape round 20 must hunt — A RULE WITH LIVE INSTANCES

round 19 sharpened the shape above, and the sharper form is worth its own hunt. the
quarantine question asks *where else does this shape occur?* — a search. this one asks
a **countable** question of the rule itself:

> **for every rule this repo declares with an `## .enforcement` clause, how many live
> instances violate it RIGHT NOW?**

### .the measurement that produced it — 2026-09-02

`rule.forbid.bare-globs-in-dual-shell-files` is a well-argued brief. it names the hazard,
tabulates five family members, gives the fix, and grades a violation **blocker**. it even
carries a `.where to look` section that reads:

> `src/bash_aliases.sh` still holds glob-form loops — worktree walks, `*.json`, `*.patch`.

**fourteen instances stood in that file.** the rule had NAMED them, by category, in its own
text — and no reader had ever counted them. one of the fourteen fed a delete path.

⚠️ and the family table had **five** rows where the defect had six members. the sixth,
`${BASH_REMATCH[1]}`, is the only one that fails SILENT — so the five loud rows had trained
the instinct *"zsh errors where bash does not"*, under which a silent member is invisible.
**a list that is nearly complete is more dangerous than one that is obviously partial.**

### .why this is a distinct hunt, not the same one

| the quarantine shape asks | this one asks |
|---|---|
| does this lesson have peers elsewhere? | does this RULE have violators here? |
| answered by a search, over shapes | answered by a COUNT, over a named pattern |
| the rule may not exist yet | the rule exists, is well-argued, and reads as enforced |

⇒ and the second is worse, because **the rule's own quality is what hides the instances.**
a reviewer who finds a sharp brief with an enforcement clause concludes the hazard is
governed. governance is not enforcement, and only a count tells them apart.

### .the test

for each rule brief, ask two questions in order:

1. **is this rule's pattern greppable?** if yes, grep it — the answer is a number, and any
   number above zero is what to report.
2. **does the rule's own text name where to look?** a `.where to look` / `.the family` /
   `.the smells` section is the author's own list of unswept ground. it is the highest-yield
   place in the repo, precisely because it reads as diligence.

⚠️ **a rule whose pattern is NOT greppable is the one that most needs a play.** four such
clamps were written on 2026-09-02, and each caught a defect in itself on its first run —
so an ungreppable rule is not exempt, it is expensive, and its cost is paid in instances
nobody counted (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.13: a check that goes
unrun rots against a tree that moves under it).

## .checks considered, not adopted

| check | why not |
|---|---|
| git-lfs cache of pinned tarballs | availability-only; the sha256 pin covers integrity. adopt if an upstream ever deletes an old release and a fresh install cannot fetch |
| gpg signature for nvim | neovim publishes no release signature at all, so sha256 is the strongest check upstream makes available. `4.5.nvim/provision.upsert.sh` states this at its head |

## .how to add a check

1. put the check in the ONE boundary that owns it — `src/grove.web.sh` for a
   wire concern, `src/grove.pkg.sh` for a package one
   (`rule.require.identical-bundle-composition`)
2. write a play that **discovers** its subjects from the tree, and proves the
   check both ways: green on a good subject, red on a deliberate break
   (`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`)
3. add a row here that names the boundary and the reader — **never a file path
   and never a count**
4. if you evaluated a check and chose against it, record it above with the
   reason, so it is not re-litigated blind

## .see also

- `rule.require.security-paramount` — why this ledger exists at all
- `rule.require.verify-binary-downloads` — the rule the first five rows enforce
- `rule.require.bundle-as-sole-declaration` — the tree IS the inventory; this
  page indexes readers of it, and declares no subject of its own
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9: two readers over one set
  must share a tokenizer, and an audit that pads is an audit that guards none

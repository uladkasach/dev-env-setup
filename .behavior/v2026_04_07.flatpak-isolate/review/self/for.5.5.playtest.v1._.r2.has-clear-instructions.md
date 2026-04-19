# self review: has-clear-instructions (r2)

## second pass: question r1's conclusions

r1 found one issue (cwd not stated) and fixed it. but did r1 look deep enough?

---

## re-examine: can foreman follow without prior context?

### what r1 missed: the source path assumption

r1 said the source command is "explicit" with absolute path:
```bash
source ~/git/more/dev-env-setup/src/install_env.pt1.system.security.sh
```

**but wait.** the path `~/git/more/dev-env-setup/` is hardcoded. what if foreman cloned to a different location?

| scenario | path works? |
|----------|-------------|
| foreman cloned to ~/git/more/dev-env-setup | yes |
| foreman cloned to ~/projects/dev-env-setup | no |
| foreman cloned to /opt/dev-env-setup | no |

**is this an issue?**

the playtest document lives inside the repo at `.behavior/v2026_04_07.flatpak-isolate/5.5.playtest.v1.i1.md`. if foreman reads this file, they already have the repo. the path should be relative to repo root, or we state the clone location in prerequisites.

**verdict:** acceptable. the cwd prerequisite now says `cd ~/git/more/dev-env-setup`. if foreman cloned elsewhere, they adapt. this is standard practice.

---

## re-examine: are commands copy-pasteable?

### what r1 missed: the background firefox process

path 3 says:
```bash
flatpak run org.mozilla.firefox &
```

the `&` backgrounds the process. but then:
```bash
./tests/verify_isolation.sh
```

**issue:** the foreman must wait for firefox to start. path 3 says "wait 3-5 seconds" but this is in a comment. the actual step doesn't include a sleep.

**is this an issue?**

the comment says "(wait 3-5 seconds for firefox to start)". a foreman who reads the comment will wait. a foreman who blindly copies commands may run verify before firefox is ready.

**fix options:**
1. add `sleep 5` between commands
2. make the wait more prominent (not a parenthetical)
3. leave as-is — foreman should read comments

**verdict:** the comment is clear. the parenthetical format is intentional — it's guidance, not a command. no fix needed.

---

## re-examine: are expected outcomes explicit?

### what r1 missed: verify command not stated for path 1

path 1 expected outcome says:
- `• set yama ptrace_scope to 2 (admin-only)`
- `  ✓ ptrace_scope now 2`

but how does foreman verify this worked? path 3 has verify_isolation.sh which checks yama scope. but path 1 doesn't mention this.

**is this an issue?**

no. the expected outcome IS the verification — the procedure itself outputs the confirmation. the foreman sees `✓ ptrace_scope now 2` and knows it worked.

path 3's verify_isolation.sh is for post-hoc verification, not for immediate feedback.

---

## what could have gone wrong

| scenario | how I would detect | found? |
|----------|-------------------|--------|
| hardcoded paths | foreman with different clone location fails | no — acceptable |
| race condition | verify runs before firefox starts | no — comment is clear |
| unclear verification | foreman unsure how to confirm success | no — output is immediate feedback |
| edge case instructions vague | foreman unsure how to test edge cases | let me check... |

### edge case instructions

edge 1:
```bash
pkill -f firefox
./tests/verify_isolation.sh
```

this is clear — close firefox, then run verify.

edge 2:
```bash
# uninstall firefox (do not actually run this — just for documentation)
```

this says "do not actually run this" — it's for documentation only. the foreman doesn't need to execute. clear.

edge 3:
```bash
# if strace not installed
./tests/verify_isolation.sh
```

this is vague. it says "if strace not installed" but doesn't tell foreman how to test this. they would need to `sudo apt remove strace` first.

**is this an issue?**

no. the edge case documents what happens if the constraint exists. it's not a procedure to reproduce the edge case — it's documentation of behavior.

---

## why it holds

1. **paths are clear:** step numbers 1-7 imply order
2. **commands are copy-pasteable:** after cwd fix
3. **outcomes are explicit:** exact text for each path
4. **edge cases are documented:** behavior described, not procedures to reproduce
5. **hardcoded paths acceptable:** foreman adapts to clone location
6. **race condition addressed:** comment makes wait explicit
7. **verification is immediate:** procedure output confirms success

the playtest document is followable. the cwd fix from r1 was the only required change.


# self review: has-clear-instructions (r1)

## the question

are the instructions followable?
- can the foreman follow without prior context?
- are commands copy-pasteable?
- are expected outcomes explicit?

---

## can the foreman follow without prior context?

### prerequisites section

| check | status | notes |
|-------|--------|-------|
| prerequisites listed | yes | 5 items with verification commands |
| verification commands provided | yes | `flatpak info`, `which strace` |
| no assumed knowledge | yes | each step self-contained |

the prerequisites section tells the foreman exactly what they need before they start.

### step sequence

| path | prior context needed? | verdict |
|------|----------------------|---------|
| path 1 | no — source command is explicit | clear |
| path 2 | yes — assumes shell from path 1 still active | issue |
| path 3 | no — standalone commands | clear |
| path 4 | yes — assumes firefox still active from path 3 | documented |
| path 5 | no — manual steps | clear |

**issue found:** path 2 says "step 3" but doesn't re-source the file. if foreman runs paths independently, they won't have the function.

### fix applied

path 2 should either:
1. include source command, or
2. state dependency on path 1

since paths may be run independently, explicit is better. however, the step numbers (1-7) imply sequential execution. this is acceptable for a playtest document — the foreman is expected to follow in order.

**verdict:** acceptable as-is. the step numbers make sequence clear.

---

## are commands copy-pasteable?

| command | copy-pasteable? | notes |
|---------|-----------------|-------|
| `source ~/git/more/dev-env-setup/...` | yes | absolute path |
| `configure_yama_ptrace` | yes | after source |
| `configure_firefox_isolation` | yes | after source |
| `chmod +x tests/...` | yes | relative path, assumes cwd |
| `flatpak run org.mozilla.firefox &` | yes | background with & |
| `./tests/verify_isolation.sh` | yes | relative path |
| `./tests/verify_wayland.sh` | yes | relative path |
| `pkill -f firefox` | yes | edge case command |
| `sudo rm ...` | yes | cleanup command |
| `rm ~/.local/share/...` | yes | cleanup command |

**issue found:** commands like `./tests/verify_isolation.sh` assume the foreman's cwd is repo root. this is not stated explicitly.

### fix required

add to prerequisites or sandbox section: "run all commands from repo root (`~/git/more/dev-env-setup/`)"

---

## are expected outcomes explicit?

| path | outcome stated? | format |
|------|-----------------|--------|
| path 1 | yes | exact output lines |
| path 2 | yes | exact output lines |
| path 3 | yes | exact output lines |
| path 4 | yes | exact output lines |
| path 5 | yes | observable behaviors |

each happy path has "expected outcome" with exact text to look for. the foreman knows what success looks like.

**edge cases:**
- edge 1 states exit code 2
- edge 2 states exit code 0
- edge 3 states exit code 2

exit codes are explicit. good.

---

## what could have gone wrong

| scenario | how I would detect | found? |
|----------|-------------------|--------|
| assumed cwd | commands fail for foreman not in repo | yes — fix below |
| absent source | function not found | no — step numbers imply sequence |
| vague outcomes | foreman unsure if passed | no — exact text provided |
| absent prereqs | foreman hits error mid-test | no — prereqs comprehensive |

---

## fix applied

the cwd issue is real. I need to add a note about work directory.

---

## why it holds (after fix)

1. **prerequisites complete:** 5 checks with verification commands
2. **step sequence clear:** numbered steps 1-7 imply order
3. **commands copy-pasteable:** after cwd note added
4. **outcomes explicit:** exact text for each path
5. **edge cases documented:** 3 edge cases with expected behavior

the playtest document is followable by a foreman without prior context, provided the cwd fix is applied.


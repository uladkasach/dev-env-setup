# F10 — ❓ for the commander: what does "locked" promise against claude's own writes?

🧭 **a vision question. the best guess is retracted; the commander rules.**

- **the question**: the wish says the home file is read-only and dev-env-setup is its one owner. claude itself writes that file (a `/model` switch). mode 0444 stops an in-place write; a write by tmp + rename in the writable `~/.claude/` dir replaces the file and leaves it writable. which contract does the commander want?
- **options**:
  - **A. 0444 + verify + re-apply** (as built). claude's choice persists; `configure.verify` flags `✋ ... is writable` on the next plan; the next apply re-strips role hooks, keeps every other key (the new `model` too), and re-locks. the lock is a guard, the seal is verify + re-apply
  - **B. also lock the dir**: drop the write bit on `~/.claude/` too. a rename fails loud as well; but claude writes other files there (sessions, projects, todos), so this breaks claude
  - **C. `chattr +i`** on the file: no write and no rename by any user; needs root to set and to lift, and F1 already ruled mode over chattr
  - **D. measure first**: a human at a live session runs `/model` under the lock, then rules among A–C
- **lean**: A, with D as the confirm. B breaks claude; C reopens a ruled fulcrum. if D shows claude fails quietly in place (no rename, no error), the lean flips to a fix-text note in the yield
- **rework**: clean
- **confidence in the lean 65%, low because**: claude's write shape is unmeasured here
- **since F9 ruled E**: the shipped value is `off`, so claude writes to a 0600 file and the question
  is not live on any box. option D — a hermetic probe of claude against a read-only sandboxed
  `HOME`, plus one of claude's own settings writes — is owed BEFORE the value flips to `on`, and the
  flip is the commander's (r010 blocker.2, i006)
- **where**: `5.1.execution.from_vision.yield.md` `.open`
- **verdict**: open — for the commander

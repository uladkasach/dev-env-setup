# F014 — the pre-extant `5.6.aws` / `5.12.rack` defects are deferred, not fixed here

- **fork:** fix the 14 peer blockers on `5.6.aws/configure.upsert.sh` and `5.12.rack/_.sh` in this pr · catch them as a dream and fix them in their own pr
- **taken, why:** defer. this branch changes only comments and one decline line in those files (`git diff main` on both). the code the blockers name predates the wish. the fixes rewrite how every ec2 grove's `~/.aws/config` is written, and no grove is reachable to prove them on (the wake needs the keyrack allowlist widen, a human's act)
- **rework:** dirty — the fixes touch the ec2 identity write and the rack's org declare, both read by every cloud grove
- **risk:** low — the defects are as live on `main` as here. the deferral adds no new exposure
- **confidence 80%, why not higher:** two of them (the non-atomic config write, the end-marker truncation) can eat a human's sso profiles. a reviewer may judge that urgent enough to fix in any pr that touches the file
- **where:** 5.1 peer round i001 — r2 b2, n1, n3, n4 · r3 all · r4 all · r5 b1, b2 · r6 b1, b2, n2 · r7 b1–b3, n1, n2, n5 · r9 b1–b5, n2, n5
- **the work:** `.dream/2026_10_26.harden-5-6-aws-config-writes.dream.md`, linked from this route's `dreams/`
- **done here after all, at i002:** the safe, local fixes, each with a play — the atomic config
  write, the unclosed-fence halt, the role-read malfunction, the absent-curl malfunction,
  `declare_org`'s loud refusal and atomic write, the qualified headers
- **still deferred:** the six gaps the dream now lists. each changes an ec2 grove's identity or
  ripples into `5.13.reach`

## i003 — `git.grove.auth.github.set.sh`

- **fork:** fix the skill's structural blockers here · fix its defects here and defer its shape
- **taken, why:** this branch changed three fix-text lines of the skill. i003 pulled the whole
  file into scope. its defects are fixed here — help vs code defaults, the sink polarity, the
  arg-parse hang, the unchecked registry read, unqualified headers, the "a grove is ec2" claims.
  its SHAPE is deferred: the inline remote steps and IMDS probe (r3 b2–b4) and the reach into
  `grove.provision`'s aliases (r5 b1). both are refactors of a credential path, and the skill can
  be proven only against a woken ec2 grove, which waits on the allowlist widen
- **rework:** dirty — the extract changes how a pat reaches a grove's rack
- **confidence 85%:** the deferred shape ships no harm; it costs a reader a decode
- **the work:** gap 7 and 8 of the dream

## i005 — RULED: the drafts leave this pr

- **the commander's verdict:** split. r11 (l3) named ~600 lines of credential-path rewrites in
  `5.6.aws`, `5.12.rack`, and `git.grove.auth.github.set` that no grove had run, plus a regression
  the drafts carried: `mktemp` + `mv -f` turns a symlinked `~/.aws/config` into a plain file
- **done:** the three files are main's again, save the ec2 comments the hetzner tier makes false
  (`rule.forbid.aws-params-off-ec2`); their three plays left the tree. the drafts stand whole in
  `.temp/split.credential-path-repairs/`, and the dream carries them
- **so the i002–i003 fixes above shipped naught**; each is a draft for its own pr

## i004 — the ductwork reach, and defects in code left identical to main

- **fork:** lift `__duct_strip_escapes` out of `ductwork.sh` into a shared leaf in this pr · defer
  the lift, and keep this skill's fix of which copy wins
- **taken, why:** defer. main already sources the same file by the same path; this branch fixed
  which copy wins (the checkout's, always) and added no edge. four more skills reach in the same
  way (`git.grove.auth.keys.set`, `git.grove.operations`, `git.grove.play.await`, `aws.ec2.get`),
  so a lift for one leaves it the odd one out. the lift is one change across all five, plus
  `ductwork.sh` and the `2.7.aliases` install
- **also deferred:** r2 b1–b3, n1–n3 and r7 b1, n1 name `5.16.keys/_.sh` and
  `prove.rack-consumers-are-dispositioned`, both now byte-identical to main (`git diff --stat main`
  prints naught). the defects are real, and as live on main — gap 9
- **rework:** dirty — the lift touches five credential and duct paths and the shell install
- **confidence 85%:** the reach ships no harm today; if `ductwork.sh` moves, this skill fails
  loud at its `-r` check (the other four were not read)
- **the work:** gaps 8 and 9 of the dream

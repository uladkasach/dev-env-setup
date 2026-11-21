# F14 — the tree-wide copy polish is deferred to a dream

## .the fork

5.3 i004 r11 (`enroll-verif-snapshot-blemishes`) raised six nitpicks across the rendered copy:
emphasis caps, the `(s)` plural, `read why:` on rows that write state, layout drift within one
message family, a long integrity block, and three mask words for one idea.

- **A.** fix them all on this branch
- **B.** fix the three blockers in that review here (absent snaps pass, locale-fragile `cause:`,
  two verdict shapes), and defer the six nitpicks to one dream

## .taken — B, and why at the time

the blockers each sat in files this route already changed, and each closed with one edit and one
resnap. the nitpicks do not: caps and plurals live in `src/bundle.upgrade.sh` and
`src/grove.web.sh`, which every bundle calls, and in a dozen bundles this route never opened.
every touched play then owes its own resnap review. the change is safe, since it is copy only,
but it is not clean: it ripples far past this diff.

## .rework — clean

the dream `2026_10_23.provision-copy-polish` lists the shape of the fix. a later branch takes it
with no change here.

## .confidence — 70%, and why it is low

two of the items (the `⚠️` indent and the `cause:` position in `2.8.tmux`) sit in files this
route did change, and could ride along. they were left with the rest so the copy register moves
in one pass, not two.

## .where

`.dream/2026_10_23.provision-copy-polish.dream.md`; route link under `dreams/`.

## .verdict

open

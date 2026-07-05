# inventory.security-checks

## .what

the live ledger of security checks this repo has adopted. each row is a measure
we now apply on purpose. this file grows over time — when we adopt a new check,
add a row and note where it lives.

## .why

- **memory**: a check adopted once is easy to forget on the next install proc
- **audit**: one place to see what protects this environment, and what does not
- **fresh setup**: a new machine inherits the full list, not just luck

## .checks adopted

| check | scope | mechanism | adopted | lives in |
|-------|-------|-----------|---------|----------|
| gpg signature vs pinned fingerprint | binary downloads | `gpg --verify` against pinned fpr in isolated gpg home | 2026-07-05 | `install_env.pt4.terminal.kitty.sh` (kitty) |
| pinned sha256 | binary downloads | `sha256sum -c` before extract, abort on mismatch | 2026-07-05 | `install_env.pt4.terminal.sh` (nvim), `install_env.pt4.terminal.kitty.sh` (kitty) |
| version pin (no @latest drift) | binary downloads | explicit version var in install proc | 2026-07-05 | nvim + kitty install procs |
| gpg-signed git commits | git identity | seaturtle[bot] author + human co-author | (prior) | git.commit skills |
| yubikey-held ssh keys | ssh auth | keys generated/stored on yubikey hardware | (prior) | `util.yubikey.ssh.sh` |
| 1password for secrets | credentials | secrets pulled from op:// uris, never in repo | (prior) | `backup_env.sh`, various |

## .checks considered, not yet adopted

| check | why deferred |
|-------|--------------|
| git-lfs cache of pinned tarballs | availability-only; sha256 pin covers integrity. adopt if upstream ever deletes an old release and a fresh install cannot fetch |
| sha256 pin for nvim's own gpg sig | nvim publishes no release signature at all; sha256 is the strongest check available until upstream signs |

## .how to add a check

1. implement the check in the relevant install proc / skill
2. add a row to **.checks adopted** with scope, mechanism, date, and file
3. if it supersedes a weaker check, note the swap
4. if you evaluated a check and chose not to adopt it, record it in
   **.checks considered** with the reason — so it is not re-litigated blind

## .see also

- rule.require.verify-binary-downloads.md — the rule that mandates the download checks
- rule.require.repo-as-source-of-truth.md

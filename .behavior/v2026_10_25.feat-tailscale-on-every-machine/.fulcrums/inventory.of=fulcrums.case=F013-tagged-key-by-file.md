# F013 — the tagged key reaches `up` by file, never argv

- **fork:** `--auth-key=file:<path>` from a 0600 tempfile · the key on stdin · `--auth-key=<value>` (rejected: `hazard.secrets-in-argv`)
- **taken, why:** a file path in argv leaks no secret to `ps` or the shell history
- **rework:** clean — bundle-local
- **risk:** low|safe — a refused form fails the `up` loudly; the node stays unjoined, never half-joined
- **confidence 70%, why low:** the `file:` prefix is recalled from tailscale's cli, not checked against the kb this round
- **where:** vision `.the contract` §2, assumptions

## .verdict — 5.1.execution, 2026-10-26

`--auth-key=file:<path>` is documented (https://tailscale.com/kb/1241/tailscale-up). the file is 0600, in a 0700 mktemp on `/dev/shm`. if there is no tmpfs, there is no join, so the key never lands on a disk. the file is removed on every path. `prove.rack-consumers-are-dispositioned` carries its MEMORY row. unmeasured on a grove until one is reachable.
## .amended — self review has-consistent-mechanisms, 2026-10-26

the tmpfs base is now `${XDG_RUNTIME_DIR:-/dev/shm}`, the repo's extant RAM-only shape (the usql DSN in `bash_aliases.sh`), rather than `/dev/shm` alone. `$XDG_RUNTIME_DIR` is per-user 0700 already. no tmpfs base → still no join.
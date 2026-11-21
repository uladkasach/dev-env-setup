# F10 — `git grove sync` reads a new box's platform with no host key check

## .the fork

sync must learn whether a new tailnet peer is a hetzner grove before it registers it. it asks the
box (`cat /etc/grove/platform`). a new box has no trusted key yet, and trust needs a registry entry
(`git.grove.trust.gen --grove`), so a read that demands a known key cannot run at first contact.

- **A** — read with `StrictHostKeyChecking=no` and no known_hosts, and keep trust a separate,
  named, human tofu step after the registration
- **B** — demand a known key first: deadlock at first contact (measured: "Host key verification
  failed", every new box)
- **C** — `accept-new` into the real known_hosts: the same trust-on-first-use as A, but silent, and
  it writes trust as a side effect of a read

## .taken: A

- the name it dials is a tailnet peer, resolved by MagicDNS; the tailnet already authenticates
  which node answers to that name, so a spoof needs a node inside the tailnet
- the read carries no secret and forwards no agent (`-o ForwardAgent=no`); its answer is compared
  to one literal
- a registration grants naught: the entry is unreachable for credentialed work until a human runs
  `git.grove.trust.gen --grove <n> --trust tofu`, which sync prints as the next step
- C would write trust silently, which is worse than A's named step

## .rework — clean

one ssh option set in `_git_grove_sync`; no caller depends on it.

## .confidence — 80%

## .risk — risky

it bears on host trust. the bound above (tailnet identity, no secret, no grant) is why A holds.

## .where

`src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh`, `_git_grove_sync`; the comment block
above the ssh call states the same bound

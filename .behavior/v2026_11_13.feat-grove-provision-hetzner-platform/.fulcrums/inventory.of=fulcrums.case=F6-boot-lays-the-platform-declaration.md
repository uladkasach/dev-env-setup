# F6 — the boot lays the platform declaration

## .the fork
- **A (taken):** `git.grove.provision boot` findserts `/etc/grove/platform` over the ground seat, from a registry field `platform` set by `git grove set --platform`
- **B:** wait until ahbode/infrastructure#64's bootstrap writes the line, and halt the boot until then
- **C:** pass `GROVE_ENV_SERVER=cloud@hetzner.hetzbot` into each seat's apply

## .why A
- the derive fails closed on the box without the line, and #64's branch holds no write of it, so B halts the S8 outcome
- C makes every later apply on the box owe the same override by hand; the boot comment forbids a hand-passed server because it hides the detection
- A is a findsert: a builder that lays the same line later finds it in place, and a line that differs halts the boot. so #64 can adopt it without a rewrite

## .rework — clean
one file on the box, one registry field, one boot block. if #64 takes the declaration over, the boot's block reads KEEP and can be dropped.

## .confidence — 75%
the file's owner, per `src/grove.env.sh`, is "the box's builder". the boot is one builder; #64's bootstrap is another. who owns it long-term is #64's call.

## .where
- `src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh` — `--platform`
- `.agent/repo=.this/role=any/skills/git.grove.provision.boot.sh` — step 1

## .verdict
closed: A holds. the boot writes the line today; the bootstrap's write of the same line is handed to ahbode/infrastructure (`handoff.infra.platform-declaration.md`), and the findsert keeps whichever lands first

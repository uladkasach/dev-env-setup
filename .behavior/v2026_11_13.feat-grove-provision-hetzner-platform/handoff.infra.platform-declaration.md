## .what

the hetzner grove bootstrap writes one file, so dev-env-setup can tell the box is a hetzner grove:

```
/etc/grove/platform    root:root 0644    one line: hetzner.hetzbot
```

## .why

- grove.provision keys every box-specific bundle off its platform: `aws.ec2`, `hetzner.hetzbot`, or `unix` (a laptop)
- a hetzner dedicated box answers no probe the way ec2 does: no instance metadata, its dmi names the board maker, and no envvar names the host. so the builder must declare what it built
- with no file, the derivation refuses an ssh seat by name, rather than read the box as a laptop

## .today

dev-env-setup's `git.grove.provision boot` writes the file itself, as a findsert, from the registry field set by `git grove set --platform hetzner.hetzbot`. once the bootstrap writes the same line, the boot finds it in place and keeps it, so no rewrite is owed on either side. a line that differs halts the boot.

## .done when

- a fresh hetzner grove holds `/etc/grove/platform` = `hetzner.hetzbot` before dev-env-setup first reaches it

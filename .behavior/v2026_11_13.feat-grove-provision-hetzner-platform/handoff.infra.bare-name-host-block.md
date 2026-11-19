# handoff → ahbode/infrastructure: the box's BARE name is the camper seat; name the admin block `<box>.ground`

## .the ask

when infra's tools write a `Host` block for a hetzner grove into a human's `~/.ssh/config`,
write it under `Host <box>.ground` (or any name other than the bare box name), never under
`Host <box>`, or stop the write and leave the seat aliases to `git.grove.wake`.

## .what infra writes today

on the create of `grove-ahbode-hetzner-v20261119`, a block appeared in the laptop's
`~/.ssh/config`:

```
Host grove-ahbode-hetzner-v20261119
  HostName <tailnet-ip>
  Port 22
  User ground
  IdentityFile ~/.ssh/id_ed25519
```

the same shape stood for the prior box, `grove-ahbode-hetzner-v20261022`.

## .why it is a defect, not a preference

- the bare box name is the CAMPER seat in every dev-env-setup registry: `git.grove.send <box>`,
  the boot, and the gate all dial it and mean camper
- a block for that name with `User ground` makes every camper-aimed command land on the admin
  seat. 📜 measured 2026-11-18 on `…-v20261022`: for days, sends, applies, the integration
  gate, and a key placement ran as ground. no command errored. the admin seat came to hold a
  keyrack host file, a crew clone, and docker state, and the box was rebuilt to clear it
- a second writer on one alias is also the likely source of the duplicate Host block that
  another session saw return after each removal

## .what dev-env-setup already does about it

- its own blocks live in `~/.ssh/config.d/grove.conf`, Included as the FIRST line of
  `~/.ssh/config`, so its `Host <box>` (camper) wins over infra's today
- every dial passes `grove_ssh_seat_ready`, which reads `ssh -G` back and heals or refuses a
  seat that dials another user
- the boot reads the admin seat's disk after step 3 and halts on crew work or a credential

⇒ so today the block is shadowed and harmless. it is a trap for any laptop whose Include line
is absent, and for any tool that reads `~/.ssh/config` directly.

## .done when

a box create writes no `Host <box>` block that names `User ground`.

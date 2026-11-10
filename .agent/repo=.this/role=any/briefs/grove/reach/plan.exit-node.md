# plan.exit-node

## .what

this laptop's exit node is **off by default**. it routes through one only on a network it does
not trust — an airport, a cafe, a hotel.

| when | exit node | why |
|---|---|---|
| **now** | mullvad, via the tailscale add-on | no house grove yet; mullvad needs no install and no second vpn app |
| **long term** | a house grove | a residential ip — the same tunnel, and no captchas |

```sh
rhx network.vpn.get                     # the route in use, and every choice
sudo -v && rhx network.vpn.set --exit mullvad
sudo -v && rhx network.vpn.set --off
```

## .why off by default

- at home and on the human's own hotspot, the network is trusted, and the firewall already
  drops every inbound connection (`define.invariant.local-grove-is-outbound-only`)
- every commercial vpn exits from datacenter ips that sites list as vpn — mullvad included,
  proton included. each one draws captchas and blocks. a tunnel left on pays that cost on
  every site, for a threat absent on a trusted network

## .why mullvad, and not proton

- mullvad is the one vpn with an official tailscale integration: its servers appear as exit
  nodes in the tailnet. no client to install, no route fight with tailscale
- proton runs its own client, which wants the same routes and dns tailscale holds — one must
  be off while the other is on
- the cost: the add-on ties mullvad to the tailscale account, so mullvad's anonymous account
  number is given up. irrelevant for the airport threat

## .why a house grove, long term

- it exits from the human's own home connection — a residential ip, which sites treat as an
  ordinary visitor. no captchas, no vpn blocklists
- it protects the airport hop exactly as mullvad does: the shared network sees only wireguard
- ⇒ once it exists, mullvad is retired, and `--exit <house grove>` takes its place

## .the steps owed

| step | owner | state |
|---|---|---|
| buy the mullvad add-on; grant this laptop | the human, tailscale admin console | open |
| `network.vpn.set` / `network.vpn.get` | this repo | done |
| a house grove, advertised as an exit node and approved | the human + its provisioner | open |
| retire the mullvad add-on | the human | after the house grove |

## .see also

- `define.invariant.local-grove-is-outbound-only` — the firewall that holds whether or not a
  tunnel is on
- `define.invariant.grove-tailscale-has-one-owner` — why a cloud grove's exit node is its
  provisioner's to set, never this repo's

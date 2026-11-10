# define.invariant.local-grove-is-outbound-only

## .what

a local grove begins every connection it holds. no connection begins from outside it. a cloud
or house grove is reached inbound by design, and that reach is its provisioner's to declare.

## .kind

**nurture.** nature permits a laptop to serve — a dev server a phone can load, a printer it
can find. we chose to refuse all of it, because a local grove has a human at its keyboard and
roams networks it does not own.

## .invariant

```
GROVE_ENV_SERVER == local@unix  ⟹  inbound: new connections dropped, on every interface
                                    outbound: open; replies to it return
GROVE_ENV_SERVER == cloud@*     ⟹  inbound: the duct (ssh), owned by its provisioner
                                    outbound: open
```

| kind | why it exists | inbound | outbound | who declares inbound |
|---|---|---|---|---|
| **local** — `local@unix` | a human works at it | ✋ none, any interface | ✔ | `1.12.firewall` drops it |
| **cloud** / **house** | a human reaches it from afar | ✔ the duct | ✔ | its provisioner (security group, tailnet acl) |

the tailnet is no exception for a local grove: `5.23.tailscale` keeps its node shields-up, and
`1.12.firewall` drops `tailscale0` inbound the same as wifi.

## .why

- **the human is the reason, and the human is at the keyboard.** whoever works on a local grove
  sits in front of it. no task of theirs needs a peer to dial in
- **it roams.** an airport, a cafe, a hotel: every peer on those networks is a stranger. a
  listener on such a box is a target, and listeners appear by chance — a package postinst, a
  dev server bound to `*`, a sync daemon
- **a firewall makes the listener no matter.** to audit every listener on every apply is a
  chase with no end; one default-drop holds whatever starts later
- **a remote grove is the opposite case.** it exists to be reached. its inbound is the product,
  so a drop there cuts the duct this repo reaches it by

## .scope

- governs NEW connections. replies to connections the box began always return
- covers docker: a published port arrives by DNAT through the forward hook, and is dropped
  there when it comes from outside the box
- does not cover `local@cicd` — a runner's network belongs to its host
- does not decide a remote grove's rules; it names who owns them

## .the cost, stated

- a dev server on a local grove cannot be loaded from a phone on the same network
- mdns replies are dropped, so `.local` names, network printers, and cast targets are not
  found from a local grove

## .the counter-argument

a laptop that serves a phone, or finds a printer, is ordinary use, and a blanket drop breaks
it. that is real. the answer is to reach the other device outbound — or to declare that one
port in `1.12.firewall` — and never to leave the whole box open because one case wants a door.

## .what would overturn it

a local grove whose ordinary use requires inbound — one that hosts a service a peer dials. that
box is no longer a laptop in this sense. it declares its own row above, with its port named.

## .enforcement

- a local grove whose declared firewall does not drop new inbound connections = **blocker**
- an inbound allowance added for a local grove with no port named and no reason = **blocker**
- a firewall write on `cloud@*` from this repo = **blocker** — the reach is the provisioner's
- a brief that says "a grove is reached over ssh" with no kind named = **blocker**
  (`repo.overview`, a grove spans both kinds)

## .see also

- `howto.stop-or-open-the-firewall` — stop it, open one port for a test, or declare one
- `plan.exit-node` — when this laptop routes through a vpn, and which one
- `repo.overview` — the two kinds of grove, by reach
- `define.invariant.grove-tailscale-has-one-owner` — the tailnet half, shields-up included
- `rule.require.judge-declared-state-not-live-state` — why `1.12.firewall` verifies the files

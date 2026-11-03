# S006 — a laptop joins with shields up

## .said

> and answer me about hte one way security part. this only shows that i can reach out, but because we didnt add a server, onto local, no one can reach in right?

> does this tailscale addition mean that someone can enter my pop-os via tailscale? or did we block inbound on the laptop local groves laready?

> this should be automatically done on any local grove for laptops via our tailscale install bundles for safety right? sudo tailscale set --shields-up

> otherwise, we leave our tailscale client laptops more vulnerable than needed; sudo tailscale set --shields-up

## .settled

every laptop (`local@unix`) that joins the tailnet does so with shields up: it refuses all inbound
tailnet traffic, and its own outbound reach is unchanged. the tailnet's acl is one fence; shields-up
is a second, on the node, so a wrong acl or a stray listener on the laptop is never reachable. the
bundle sets it at the first `up`, sets it on a laptop already joined, reads it back, and the
verify ✋s a laptop with shields down. a laptop already shielded takes no write and asks no root.

## .landed

- `src/grove.provision/5.devtools/5.23.tailscale/configure.upsert.sh` · `configure.verify.sh` · `_.sh`
- the laptop row of `rule.require.the-provisioner-joins-the-tailnet`

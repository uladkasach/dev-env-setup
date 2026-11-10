# howto.stop-or-open-the-firewall

## .what

a local grove drops every new inbound connection (`1.12.firewall`,
`define.invariant.local-grove-is-outbound-only`). this is how to turn it off, how to open
one hole for a few minutes, and how to declare a port that stays open.

| you want | reach for | lasts until |
|---|---|---|
| it off, now — the firewall broke a task | **stop** | the next start, apply, or boot |
| one port open for a quick test | **a live hole** | the next reload, apply, or boot |
| one port open for good | **a declared port** | it is removed from the repo |

⇒ the first two are live changes and revert on their own. only the third is a decision, and
only the third goes in the repo (`rule.require.repo-as-source-of-truth`).

## .stop — the firewall is in the way

```sh
sudo systemctl stop grove-firewall       # off: deletes the grove_firewall table alone
sudo systemctl start grove-firewall      # back on
```

- stop removes this firewall's table and no other — tailscale's and docker's rules stay
- `systemctl disable` is never the move: the next apply re-enables it, and the box boots open
  meanwhile
- an apply also restores it: `configure.upsert` starts the unit wherever it is inactive

⚠️ a stopped firewall is an open laptop. on a shared network, stop it for the test, then start it.

## .a live hole — one port, a few minutes

to load a dev server from your phone, for example:

```sh
sudo nft insert rule inet grove_firewall input tcp dport 3000 accept
```

- it opens port 3000 alone, and leaves the rest of the drop in place
- it is gone at the next `systemctl reload`, apply, or boot — no cleanup owed
- see it live: `sudo -v && rhx network.firewall.get`

## .a declared port — it stays open

edit the repo copy, then apply. never edit `/etc/grove/firewall.nft` — the verify reports the
drift, and the next apply overwrites it.

1. add one rule to the `input` chain of
   `src/grove.provision/1.system/1.12.firewall/firewall.nft`, after the dhcpv6 rule:

   ```nft
   # <port>: <what serves it>, reached by <whom> — <why it must be inbound>
   ip saddr <lan-cidr> tcp dport 3000 accept comment "dev server, from my phone on home wifi"
   ```

2. apply — the kernel checks the ruleset before any file lands:

   ```sh
   sudo -v && rhx grove.provision --what 1.12.firewall --mode apply
   ```

the invariant asks three things of each declared port:

- **the port is named** — `tcp dport 3000`, never a range left open "for later"
- **the source is narrowed** where you can — a home subnet, never the whole internet. an
  airport network hands its peers the same address range as a home one, so a subnet rule is a
  convenience, never a guarantee
- **the reason is written** in the comment above it

⚠️ a port for a tailnet peer needs one more step: `5.23.tailscale` holds the laptop
shields-up, which refuses tailnet traffic before this firewall sees it.

## .see also

- `define.invariant.local-grove-is-outbound-only` — why the drop exists, and what it costs
- `src/grove.provision/1.system/1.12.firewall/` — the ruleset, the unit, and their verify
- `rhx network.firewall.get` — declared, loaded, and every listener behind it

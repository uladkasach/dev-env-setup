# F1 — the authority form names the grove, never the host

## .the fork
- **A** `house://localhost` — the wish's symmetry suggestion
- **B** `house://<user>` or `house://<user>@<host>` — the seat's unix identity
- **C** `house://<name>` — the grove's registry name (`house-1`); the registry row holds
  `at = <seat-user>@<host>:<port>`

## .taken: C, and why at the time
- `localhost` already names a grove: `term=grove` reads *"`localhost` is a grove"* — the
  visible laptop. two groves on one authority is the overload `rule.forbid.domain-term-ambiguity` forbids
- ductwork treats the host `localhost` as *this machine, no ssh* (`ductwork.sh:842-844`), so a
  duct to `localhost` would land in the supervisor's own tmux — a send to the wrong seat that
  reports success
- one box hosts N house groves; only a name tells them apart
- `<user>@<host>` puts unix detail in the ledger key; `term=exid` already splits *the name is
  ours* from *the address is the box's*. the remote-laptop stone then changes the row's `at`,
  never the uri
- it mirrors `duct://<alias>/…`, where the authority is an ssh alias

## .rework
clean — no parser reads `house://` yet; nheuron#18 owns the parser and has not shipped it.

## .confidence 75% — why not higher
the scheme `house://` vs a plain `grove://<name>` with `type=house` in the row is a second
fork inside C, left to #18; a uri that carries the kind may duplicate the row's `type`.

## .where
`1.vision.yield.md` `.the contract`; case=3 `[t1]`.

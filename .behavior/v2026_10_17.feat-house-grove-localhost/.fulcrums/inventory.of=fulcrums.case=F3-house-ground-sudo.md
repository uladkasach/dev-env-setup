# F3 — does the house ground hold NOPASSWD sudo on the host?

## .the fork
- **A** yes — identical composition with EC2; every bundle's ground path behaves as there
- **B** no — the host's own `local@unix` run already owns every box-wide fact; the house
  ground declines them all and exists only as the seat a human sits in

## .taken: A, and why at the time
- `rule.require.identical-bundle-composition`: a seat that differs from EC2's needs a physical
  reason, and "it would duplicate the host's writes" is not one — those writes read `•`
- the camper/ground custody split is the property worth keep: the agent never holds the ground
  key (case=3 `[t2]`)

## .the cost, stated plainly
on EC2 the ground seat is root of a disposable box. here it is **root of the laptop that holds
the human's rack, sso cache, and ssh keys**. whoever holds the ground key holds the laptop —
which the human already does. the risk is the key's custody, not the grant — and F12 settles
that custody with a touch, since a key file is readable by the supervisor's uid on this box.

## .rework
clean — one sudoers drop-in.

## .confidence 55% — why low
B is defensible, and this is a blast-radius call on the human's own machine. **the wisher's to
rule.**

## .where
case=1 `[t0]`; case=2 `[t0]`.

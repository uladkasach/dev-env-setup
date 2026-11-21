# F2 — the seat unix names

## .the fork
- **A** literal `camper` / `ground` — as on EC2
- **B** `<name>-camper` / `<name>-ground` — e.g. `house-1-camper`
- **C** `<name>.camper` — mirrors the ssh alias `house-1.ground`

## .taken: B, and why at the time
- A collides on the second house grove of one box
- C: debian's `adduser` NAME_REGEX refuses a dot, and `chown user.group` legacy syntax reads
  the dot as a separator. B is legal under every tool
- the ssh alias keeps the extant `<name>` / `<name>.ground` shape (`term=grove.alias`); only
  the unix user differs

## .rework
clean today — no seat is minted. **dirty the day one is**: `term=ground` notes a unix username
is the least reversible name in the system.

## .confidence 60% — why low
not yet measured: whether any bundle or play matches the LITERAL `camper` / `ground`
(`prove.ground-seat-converges` checks "identity"). if one does, it must read the seat role
from the marker (F5) rather than the username — a cost the execution stone must grep first.

## .where
case=1 stdout; case=3.

## .risk: low
a unix username is a label. the grants and keys that ride on each seat are graded in F3, F4, F12; the name itself touches no credential and no prod write. a rename after mint is dirty rework, not an exposure.
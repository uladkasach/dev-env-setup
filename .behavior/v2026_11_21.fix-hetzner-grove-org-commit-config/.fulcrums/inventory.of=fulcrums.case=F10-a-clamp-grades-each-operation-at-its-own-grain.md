# F10 — a clamp grades each operation at its own grain; the public entry gets its own arms

## .the fork

peer round i002 of 5.3 (r009, blockers 1 and 3) read the two clamps as acceptance tests and asked
that every action arm enter through the public contract (`grove.provision --what …`,
`git.grove.provision boot …`) rather than call a bundle phase or a boot step directly.

- **all arms through the public entry** — a boot needs a live grove for most of its steps; the
  provision entry sources the whole runtime per arm. each arm would cost minutes and a fixture
  of the whole box
- **operation-grain arms, plus public-entry arms** — the phase functions and the boot steps ARE
  the contract their runtime calls (`bundle.upgrade` names `grove_provision_<slug>_<phase>`; the
  boot names its steps), so the operation-grain arms grade a real contract; and a separate set of
  arms enters through the public entry, so a break in dispatch or env derivation still reddens

## .taken

the second. the meter clamp gains row 12: the shipped `grove.provision._.sh`, under `env -i`, a
fixture HOME, and a pinned tier, plans `5.26.commitorgs` for a fresh seat and for a meter the real
writer granted (12a, 12b). the boot clamp already enters through `git.grove.provision.boot.sh`
for its cli arms and its `--from 4` resume. every one of this repo's 73 plays clamps at the
operation grain this way; none drives a whole box per arm.

## .rework

clean: more public-entry arms can be added beside the others; none of the operation-grain arms
would change.

## .confidence

80%. the reviewer's rule is written for typescript acceptance suites, where a blackbox call is
cheap; here a blackbox boot is a live grove.

## .where

`.play/permanent/prove.commitorgs-reads-the-meter-as-the-gate.play.sh` (row 12);
`.play/permanent/prove.boot-steps-name-each-verdict.play.sh`.

## .verdict

open: disputed in 5.3 peer round i002, for the council.

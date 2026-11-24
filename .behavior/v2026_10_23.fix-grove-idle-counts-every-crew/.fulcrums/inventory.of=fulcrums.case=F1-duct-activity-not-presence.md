# F1 — the duct signal is tmux session activity, not duct presence

## .the fork
- **presence**: any live tmux session on the box holds it awake
- **activity**: each live window holds the box only while its `#{window_activity}` (last pane output) is under the limit

## .taken — activity
- the infra doctrine reads occupancy as evidence of work, never presence; a forgotten tmux pane
  once billed a grove ~13h (`genGroveHibernatorUserData.ts`, lines 95-104)
- every duct at work prints, so activity still holds every busy crew
- the duct registry (`~/.ductwork/ducts/`) holds 1 entry here against 128 actor trace dirs, so a
  registry-keyed signal would miss most crews; tmux is the ground truth of a duct

## .rework — clean
one line in the check: emit `now` per live session instead of `#{window_activity}`.

## .confidence — 70%, and why it is low
the wish says *"no duct"*, which reads as presence. a crew parked at a prompt for 3h dies under
activity and lives under presence.

## .where
`src/grove.provision/1.system/1.12.hibernate/idle-hibernate.sh`, the duct block.

## .verdict
approved — director ahbode-ktlo, 2026-10-23: the call is clean

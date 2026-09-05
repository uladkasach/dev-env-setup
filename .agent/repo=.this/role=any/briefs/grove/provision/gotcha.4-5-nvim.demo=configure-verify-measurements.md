# gotcha.4-5-nvim.demo=configure-verify-measurements

## .what

the dated measurements behind `4.5.nvim/configure.verify.sh`'s modeline/exrc guard, plugin
pin, and imagemagick policy claims.

## m1 — the modeline/exrc guard fired for real

this box, 2026-08-31, nvim 0.12.3: a file whose last line reads `# vim: shiftwidth=7
tabstop=7` set both options on open, on a config with the three guard lines cut. the guarded
config (as shipped) refused it — `src/init.lua` carries the pin.

## m2 — seen to discriminate, two probes, two questions

2026-08-31:

**does the GUARD work?** `src/init.lua` opened the probe file above, beside the same config
with only the guard's three lines cut:

| config | result |
|---|---|
| as shipped | sw=8 ts=8 modeline=false — refused |
| guard lines cut | sw=7 ts=7 modeline=true — obeyed |

**does THIS CLASSIFIER read it?** five report strings:

| GUARDOPTS report | verdict |
|---|---|
| all three off | GREEN |
| modeline on | RED |
| modelineexpr on | RED |
| exrc on | RED |
| no report at all | 🌙 |

rows 2-4 flip ONE option each on purpose — an all-off-vs-all-on pair alone cannot see a
dropped `&&` in the guard, which is the edit that will actually happen
(rule.require.seam-claims-have-an-owner). before the fix landed on this box, the classifier
reported `modeline=true modelineexpr=false exrc=false` — it fired for real, not on a fixture.

## m3 — imagemagick policy, seen to discriminate

2026-08-31, imagemagick 6.9.12 on this box:

**does the POLICY work?** `src/imagemagick.policy.xml` placed at a temp seat path; every
carried coder asked in both directions:

| coder set | without the policy | with the policy |
|---|---|---|
| PS PS2 PS3 EPS PDF XPS MSL MVG MAGICK TEXT LABEL CAPTION (12) | all open | all REFUSED |
| SHOW WIN PLT EPHEMERAL | no subject on this build | — |
| png jpg jpeg gif webp avif (6) | read | still read |

**do THESE CLASSIFIERS read it?** twelve rows, all green:

| claim | arm | verdict |
|---|---|---|
| 5 (refusal) | policy refusal | GREEN |
| | a successful read | RED |
| | no coder in the build | 🌙 |
| | file could not open | 🌙 |
| | an unrelated failure | RED — never a silent pass |
| 6 (cost) | all five read | GREEN |
| | avif alone refused | RED:avif |
| | png alone refused | RED:png — opposite loop end |
| | two refused | RED:webp avif |

claim 5's third arm exists because an earlier two-valued reader folded "no MVG coder" into
"allowed". it reported a correct policy line as a defect — the evidence that refuted it
printed on the same line (gotcha.a-check-that-cries-wolf-gets-silenced, q1).

## m4 — one render-set list, three holders

2026-09-01: a hand-written `png jpg gif webp avif` loop in this file declared FIVE formats.
`init.lua`'s own `IMAGE_DIFF_EXTS` declares SIX; `init.lua:285` already warns of a third
holder of the same list. one list, three holders — the cheapest one to edit stayed wrong
(gotcha.a-check-that-cries-wolf-gets-silenced, m9). the render set is now derived from
`init.lua` at read time, never typed here.

## m5 — the table window is the table, never a line count

2026-09-01: a `grep -A2` reader hand-types a constant for a reflowed table's extent. reflow
the table one-entry-per-line and such a reader sees only a PREFIX — `-A2` reads 2 of 6 on a
reflowed table, and 2 of 7 with a 7th entry added. it under-reads in the ✔ direction, which a
count of read rows alone cannot catch (inventory.security-checks, "an ADDITIVE guard").

## .see also

- `gotcha.a-check-that-cries-wolf-gets-silenced` — q1 (m3's third arm) and m9 (m4's drift)
- `rule.require.seam-claims-have-an-owner` — m2's two-probe requirement
- `rule.require.bounded-probes-in-verifies` — why every probe here runs under `timeout`
- `rule.forbid.failhide` — why a skipped format is never counted as a passed one

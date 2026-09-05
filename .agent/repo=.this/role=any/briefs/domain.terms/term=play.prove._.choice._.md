# domain.term: play.prove

term.chosen   = prove (as the verb slot of a play name)
term.kind     = verb
term.synonyms.forbidden:
- verify (taken, and narrower — a `verify` READS the box; a `prove` DRIVES it first)
- test (jest's word here; a play is not a test suite)
- check (says a claim was looked at, not that it was established)
- exercise (names the drive and drops the verdict)
- benchmark (measures a rate, asserts no claim)
- smoketest (taken, and at a different SUBJECT — a `prove` proves a BUNDLE, a smoketest
             proves a BOX. it is also a skill, not a play, and it writes fixtures the
             inventory does not declare; see `term=smoketest._.choice.reason.md`)

## .what
the verb of a play that **establishes a property by MAKING the machine demonstrate it** — it
drives real runs, then judges what they produced.

the distinction from `verify` is the WRITE, and it is load-bear: a `verify` asks what the box
already says, and must not mutate it. a `prove` cannot answer its question without a run — an
idempotency claim, a fixed point, a chain that must break — because the property is about what
HAPPENS, not about what is.

## ⚠️ .a `prove` DRIVES, and it still may not CONVERGE

`prove` is the ONLY play verb that may run a command which changes the box, and the licence
is narrow: it drives **to OBSERVE**, never to leave the box better. what it
drives is always `grove.provision` or a test suite — never a hand-rolled write of its own.

> a play that writes to CONVERGE a machine is forbidden outright
> (`rule.forbid.repair-plays`). machine state is a bundle. no exceptions.

so the test on a `prove` is: **is every write it makes a call INTO the inventory?** if it
reaches past `grove.provision` and writes a file, a config, or a package itself, it has
become what that rule forbids, whatever its name says.

## .the family it belongs to — THREE verbs, and every one only READS the machine
a play's verb says what the play does:

| verb | reads? | may drive? | asserts a verdict? |
|------|--------|-----------|--------------------|
| `diagnose` | yes | no | **no** — reports every branch, judges none |
| `verify` | yes | **no** | yes — exits 0 or names each failed claim |
| `prove` | yes | **only via `grove.provision` or a suite** | yes — and names which run disproved it |

🛑 there is no `repair` row, and none may be added: **a play may never write machine state**
(`rule.forbid.repair-plays`).

⚠️ one verb sits OUTSIDE this table because it does not read the machine at all:
`rollback` — the development-only verb that moves a test box BACKWARD so a bundle's first
apply can be re-tested (`term=play.rollback`). it is the only play that may write outside a
call into `grove.provision`, and its four conditions are what stop it from becoming a repair.

## .why it is NOT `verify`, in one measurement
`rule.require.prove-each-bundle-plan-apply-apply` demands plan → apply → apply. the idempotency
claim it makes — *does a re-run converge rather than duplicate, fail, or prompt?* — is
unanswerable by any read of the box. it is a claim about the SECOND run, so a second run must
happen. `verify`'s own `.reason` states read-only is what that word MEANS, so to name these
plays `verify.*` would break the word that the `diagnose`/`verify` split rests on.

## .refs
where the term is used:
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.prove-each-bundle-plan-apply-apply.md

⚠️ `prove.svc-chat-integration-e2e` (drives the BUNDLES, rebuilds the testdb, then the suite) and
`prove.svc-chat-integration` (drives only the SUITE) are ONE verb at two SCOPES,
deliberately: both drive and both judge, so both are
`prove`. the depth of the drive lives in the SUBJECT slot (`-e2e`), never in the verb — a cost
axis in the verb slot was proposed and refused the same round
(`term=play.verify._.choice.reason.md` → `.disputes`).

## .reason
see the ref-level cluster beside this choice:
- `term=play.prove._.choice.reason.md` — why the family needed a fourth verb, the `verify`
  dispute, and why a `prove` play's own checks are held to the discriminate bar

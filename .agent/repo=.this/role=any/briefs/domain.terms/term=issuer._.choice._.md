# domain.term: issuer

term.chosen   = issuer
term.kind     = noun
term.synonyms.forbidden:
- provider    (names who SUPPLIES a credential; the issuer is who can REVOKE it, and the two are often different parties)
- authority   (too broad — every gate in a chain is an authority of something)
- upstream    (a direction, not a party; it names where to look and never who answers)
- source      (already the word for where a value is READ from — a vault is a source, and a vault refuses none)
- vault       (the STORE. it holds a credential and has no opinion on whether the credential works)
- server      (taken — `$server = $tier@$platform`, this repo's box-class tag)

## .what

the party that **minted** a credential and can therefore refuse it — github for a
pat, aws sts for a session, an sso idp for a token. it is the only party whose
judgment makes a credential `live`.

## .the third leg of declared / live

`declared` and `live` are a pair about STATE (`term=declared`, `term=live`). a
credential needs a third word, because its live standing is held by no party on
this box:

| what | who holds it | how to read it |
|---|---|---|
| the ENTRY | the rack | `keyrack list` — is it stored, is it declared |
| the VALUE | the vault | `keyrack get` — do bytes come back |
| the STANDING | the **issuer** | ask the issuer — it is the only reader |

⇒ so a credential can be **perfectly declared and dead**, and no local read can
tell. that is `term=entry`'s fifth state, and the issuer is who settles it.

## .why the word is needed

a check that reads only the first two rows measures the DECLARED credential and
reports green on a value the issuer refuses. `diagnose.grove-github-credential`
had eight such rows and no ninth for a month.

⚠️ and the gap is invisible in the output: eight ✔ reads as a healthy credential,
because a row nobody wrote produces no row
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12).

## .refs
- .agent/repo=.this/role=any/briefs/creds/rule.require.github-token-at-all-camp.md

## .reason
see the ref-level cluster beside this choice:
- `term=issuer._.choice.reason.md` — the measurement that named it, the rejected
  synonyms, and why a byte COUNT is not a credential check

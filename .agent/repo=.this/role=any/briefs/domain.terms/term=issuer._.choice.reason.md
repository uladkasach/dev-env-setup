# domain.term.choice.reason: issuer

## .etymology

`issuer` = the party that ISSUED the credential. it is the word every credential
standard already uses — jwt's `iss` claim, an x.509 issuer field, oauth's
authorization server. so this is a word ADOPTED, never coined
(`rule.require.ubiqlang` — take the word in use where no better one exists).

⇒ and it carries the one property the concept needs: **a party that issues is a
party that can revoke.** no other candidate implies that.

## .the measurement that named it — 2026-08-28

`diagnose.grove-github-credential` had eight rows and ran green on a box that
could not clone a single repo:

```
── 4. does the rack hold an ENTRY for the slug      ✔ @all.camp.GITHUB_TOKEN
── 5. does a COLD get return bytes                  ✔ 40 bytes
── 6. consumer A — the gh cli                       ✋ not logged in
── 7. consumer B — plain https git                  ✔ helper on disk
```

every row was TRUE. the credential was stored, declared, centrally vaulted, and
readable cold from the grove's own instance role. and github answered `401`.

⇒ the play measured **six ways to be sure a credential is stored** and no way to
learn whether it works. that asymmetry is what wanted a word: with `issuer`
named, the absent row is obvious; without it, the page reads complete.

## .the row that closed it, and the header it reads

```
── 9. the ISSUER — does github still honor the token the rack hands out?
   status:  HTTP/2 401
   scopes:  <absent>
     ✋ github does NOT recognize this token
```

the row reads a HEADER rather than a status code, and the reason is that the
issuer's refusals are not one fact:

| the issuer's answer | what it means | the repair |
|---|---|---|
| 401, `x-oauth-scopes` PRESENT | it knows the token; the call needs a scope it lacks | widen it |
| 401, `x-oauth-scopes` ABSENT | it has no record of the token | mint a fresh one |
| 403 | it knows the token and refuses on policy | neither — a policy change |

⚠️ **those take different repairs, and a status code alone cannot separate them.**
the bundle's own fix-text had said *"expired, was revoked, or lacks the scopes"* —
three causes in one sentence, and a hurried reader picks one
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.7: a plausible, specific,
wrong fix is the one that gets applied).

### ✔ the row was seen to DISCRIMINATE — both directions, 2026-08-30

a check proven in one direction is half proven, so the row was held to both
(`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`). same play,
same box, same slug — only the stored value changed:

| the value | what row 9 printed |
|---|---|
| a pat github had no record of | `401` / `scopes: <absent>` / ✋ does NOT recognize |
| a freshly minted pat | `200` / `scopes: read:org, read:user, repo, user:email` / ✔ ACCEPTS |

⇒ so the ✋ arm fired on a real break and the ✔ arm on a real pass. and rows 1-8
were **identical across both runs** — 40 bytes, `ghp_`, entry healthy, vault
readable — which is the asymmetry this term exists to name, seen twice.

⚠️ **the SCOPE arm is still unexercised, and probably unreachable here.**
`GET /user` accepts any live classic pat whatever its scopes, so a 401 that
carries `x-oauth-scopes` cannot be produced at that endpoint. the branch is
written and has never run.

⇒ that is not idle: an arm that cannot fire at the endpoint it guards is an arm
that will never contradict its author. to prove it, the row would have to ask an
endpoint a scope actually gates (`GET /user/orgs` needs `read:org`) with a pat
that lacks it. recorded as owed rather than left to read as green
(`term=bite`).

## .why a byte COUNT is not a credential check

row 5 counted 40 bytes and called it *"a classic pat is ~40"*. that is a
coincidence a wrong value satisfies easily — any 40 characters pass.

so the row now reads the PREFIX as well, and the prefix is public by design
(github publishes them so scanners can spot a leak):

```
✔ prefix 'ghp_' — a classic pat, and 40 bytes is its exact length
```

⇒ that separates three states a byte count collapses into one: *stored text that
was never a token*, *a token of the wrong KIND* (`ghs_`, `gho_`, a fine-grained
`github_pat_`), and *a real classic pat the issuer refuses*. only the third is
this term's subject, and the first two used to hide inside it.

## .the rejected synonyms, and why each was refused

| word | why it was refused |
|---|---|
| `provider` | names who SUPPLIES. an sso idp provides a session that aws sts issued; a vault provides a value it never issued. the two roles come apart constantly |
| `authority` | every gate in a chain is an authority of some fact. it names a rank, not a party |
| `upstream` | a DIRECTION. it says where to look and never who answers, so it cannot carry a verdict |
| `source` | **taken.** a vault is a source — where a value is READ from — and a source refuses none. to overload it would erase the exact distinction this term draws |
| `vault` | **taken**, and it is the near-miss. `aws.params` STORES the pat and has no opinion on whether github honors it. the whole measurement above is the gap between those two |
| `server` | **taken.** `$server = $tier@$platform` is this repo's box-class tag |

## .evidence

- a play with 8 rows ran green against a credential its issuer refused
- the fix-text a human would have followed named three causes with three repairs
- a 40-byte count read as proof of a valid pat, and 40 bytes proves the LENGTH

## .disputes

none open.

## .see also

- `term=declared._.choice._.md` / `term=live._.choice._.md` — the pair this completes
- `term=entry._.choice._.md` — the fifth state, whose settler this is
- `rule.require.github-token-at-all-camp` — the credential this was measured on

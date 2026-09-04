# domain.term.choice.reason: trust

## .etymology
ssh's own frame. the `known_hosts` mechanism is called TOFU — trust on first use — and its
prompt asks a trust question, never a key question: "the authenticity of host X can't be
established. are you sure you want to continue?". what a human answers there is whether they
TRUST the endpoint, not what key it holds. the word was taken from the domain's own mouth.

chosen over:
- `hostkey` — see the dispute below; it names the box's asset, not ours
- `fingerprint` — the SHA256 digest is the *evidence* weighed to decide a trust; to name the
  operation after it would be to name a step after its input
- `knownhost` — names the FILE the trust is written into. a term that names its own storage
  decays with the storage (`def.domain-discovery`: the schema is not the domain)

## .disputes

### dispute: hostkey  —  raised 2026-07-26  —  status: RESOLVED (keep `trust`)
- raised.by  = <traveler> (the human, on reading the skill name aloud)
- claim      = the skill was first declared `git.grove.hostkey.gen`. the operation does read
               and write host keys, so `hostkey` names what it literally handles.
- counter    = three grounds, and the first is a safety defect, not a style quibble:
               1. **it misnames the act as authorship.** in this vocabulary `gen` is
                  find-or-create (`rule.require.get-set-gen-verbs`), so `hostkey.gen` reads as
                  "find-or-CREATE a host key for the grove" — an act we must NEVER perform. the
                  box authors its own host key at boot; to generate one would be to forge the
                  very identity the operation exists to verify. a name that describes a
                  forbidden act as its purpose is a pit of failure, not of success.
               2. **it names the wrong side's asset.** the hostkey belongs to the GROVE. the
                  thing this operation creates belongs to US — a local record that we accept
                  that key. one is the box's property, the other is our belief about it. to
                  share one word across both sides of a trust relation is exactly the overload
                  `ubiqlang.ambiguous-from-overload` warns of.
               3. **it hides the written object.** a reader of `hostkey.gen` cannot tell what
                  lands on disk. `trust.gen` says it: a trust entry is findserted.
- resolution = keep `trust`; record `hostkey` as a forbidden synonym IN THIS POSITION. the
               word `hostkey` stays legitimate for the box's actual key (a scan returns host
               keys, and the skill body still says so) — what is forbidden is `hostkey` as the
               noun of the OPERATION. dispute closed; the skill is renamed
               `git.grove.trust.gen`.

## .evidence
- the verb canon forces the read: `gen` = findsert (`rule.require.get-set-gen-verbs`), so the
  noun that follows it is the thing brought into existence. under `trust` that is true (we do
  create a trust); under `hostkey` it is false and dangerous (we must never create one)
- the operation's own guarantees are trust-shaped, not key-shaped: already-trusted = no-op,
  CHANGED = fail loud and refuse. those are the semantics of a trust record, not of key
  material
- the asymmetry is real in code: the key is READ (`ssh-keyscan` of the grove) while the trust
  is WRITTEN (append to `~/.ssh/known_hosts`). one operation, two objects, opposite directions
  — which is precisely why one word cannot carry both
- narrative: a headless duct cannot answer ssh's trust prompt, so the trust must be recorded
  ahead of time. no part of the box's key changes; only what we believe about it

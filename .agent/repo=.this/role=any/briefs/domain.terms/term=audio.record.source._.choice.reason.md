# domain.term.choice.reason: audio.record.source

## .etymology

pipewire and pulseaudio's own word, taken whole. it is what the box prints and what the box
accepts:

```
pactl list short sources
pw-record --target <source>
pactl set-source-mute <source> 0
pactl set-source-volume <source> 60%
```

⇒ this is an **adoption**, not a coinage, and the argument for it is not convenience. every
fix-text this family prints hands the human a `pactl` line, and every diagnosis asks them to
read `pactl` output. a repo word that differed would force a translation at exactly the moment
a human is least inclined to trust the tool — when a check has just refused their mic.

## .the rejected synonyms, and why each fails

| word | why not |
|---|---|
| `mic` | names hardware, and the set does not match. a `.monitor` is a source with no mic behind it; a usb interface is one mic behind several sources. the word would be true of the common case and false of every case that matters |
| `device` | the kernel's noun, one level down. `pactl list short sources` and `pactl list short cards` are different sets, and `device` invites a reader to conflate them |
| `input` | spent three times over already — stdin, a domain operation's `input` argument, a form field. `rule.forbid.domain-term-ambiguity` |
| `channel` | a source HAS channels (this family records mono, `AUDIO_RECORD_CHANNELS`). to name the endpoint by its component is a category error |
| `stream` | what a source yields once opened. a source exists while nobody records; a stream does not |

## .disputes

### dispute: `mic` reads friendlier than `source` — raised 2026-09-06 — status: RESOLVED (keep `source`)

- raised.by  = the author, while the error text was written
- claim      = every line a human reads in this family is about a microphone. *"your mic is
               muted"* reads better than *"source is muted"*, and the audience is one human
               about to record their grandmother, not a daemon.
- counter    = the two words name different sets, and the difference IS the top hazard. a
               `.monitor` is a source and is not a mic; the whole reason
               `__audio_source_is_monitor` exists is that a monitor passes every check a
               presence test can run. to call the argument a `mic` would assert the very fact
               the probe is there to test.
- resolution = keep `source` in the contract — the flag, the term, the skill name. **prose may
               say `mic` freely**, and does: *"prove a mic will actually capture sound"*,
               *"a live mic in a real room always returns a noise floor"*. the split is the
               same one `rule.forbid.domain-term-synonyms` draws: a synonym is forbidden in a
               CONTRACT and allowed in a COMMENT, where it describes the concept from the
               human's angle.

⇒ so the friendliness was kept and the precision was not traded for it.

## .evidence

### this term anchors the declared/live split

`source` is the one noun both halves of the split take as their subject, which is what makes
the split legible at all:

| skill | reads | of the same source |
|---|---|---|
| `audio.record.source.get` | the DECLARED state — mute flag, volume, kind, format | what the box SAYS |
| `audio.record.probe` | the LIVE signal — bit-exact-zero or a noise floor | what the mic RETURNS |

they disagree exactly when it matters: a hardware mute switch, a dead jack, or an app that
holds the device exclusively all read declared-healthy and return silence. one shared noun is
what lets a human hold both readings of one subject in mind.

⇒ that split is also why `term=live._.choice._.md` needed its `.the SCOPE` clause — its
unqualified *"live never carries a verdict"* is a config-check rule, and here no declaration
determines the signal.

### measured 2026-09-06 — the ad-hoc reads that produced this cluster

four raw `pactl` calls were typed to answer *"why does it show muted? my mic is defo not
muted"*. the human's read: **"why dont you write a skill for this instead?"**

the skill was `audio.record.source.get`, and to author it forced this term's contract to be
named — which surfaced a defect the four raw reads could not:

```sh
__audio_source_muted() { [[ "$(pactl get-source-mute "$1" 2>/dev/null)" == *yes* ]]; }
```

a boolean over a call that can FAIL, so *"the box could not answer"* took the same branch as
*"the box said fine"*. the reader is now three-valued (`yes` / `no` / `?`), and the same pass
found a second silent-source hazard nobody had checked: a source at **0% volume** is silent
with its mute flag clear.

⇒ the full account is in `rule.forbid.adhoc-shell`, under `.measured again — 2026-09-06`.

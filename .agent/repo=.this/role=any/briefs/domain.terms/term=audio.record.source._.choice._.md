# domain.term: audio.record.source

term.chosen   = source
term.kind     = noun
term.boundary = audio.record
term.synonyms.forbidden:
- mic          (hardware. a source may be a monitor, a loopback, or a null device — see below)
- device       (the kernel's word; several sources can ride one device)
- input        (overloaded — stdin, an operation's `input` arg, a form field)
- channel      (a source HAS channels; it is not one)
- stream       (a stream is what a source yields once opened, never the source)

## .what
a capture endpoint the audio daemon declares. adopted whole from pipewire/pulse, where it is
the exact term `pactl list short sources` prints and `pw-record --target` accepts.

⇒ borrowed, never coined: to rename it would put this repo's word and the box's word out of
step at the one place a human reads both (`rule.require.trust-but-verify` — the box's own
output is the evidence, and it says `source`).

## 🛑 .a `.monitor` IS a source, and it is the hazard the word carries

pipewire's model has one pair — a **sink** is an output, a **source** is a capture endpoint —
and every sink also publishes a `<sink>.monitor` **source**: the loopback of what the box
PLAYS.

⚠️ so *"it is a source"* proves no part of *"it hears the room"*. a monitor:

| it does | so a check that reads only presence |
|---|---|
| open, and yield a stream | passes |
| return a healthy peak | passes |
| exit clean, with a large file | passes |

…and holds the box's own playback. that is `rule.forbid.failhide` with every layer green,
which is why `__audio_source_is_monitor` exists and why `audio.record.probe` refuses a monitor
before it measures at all.

⇒ **the discriminator is the name, not the signal.** a monitor with music on it and a mic in a
loud room are indistinguishable by peak.

## ⚠️ .near-collision — `sink` is already spent, on a different concept

`term=sink._.choice._.md` claims the bare word for a SECURITY concept: the one place
remote-chosen bytes are made inert. that is unrelated to an audio output, and the two would
collide the moment anyone wrote a bare `sink` here.

⇒ so this cluster carries its boundary (`audio.record.source`), and an audio output — if one
is ever needed — is `audio.record.sink`, never bare. the extant `term=sink` is in arrears
under `rule.require.boundary-qualified-terms`; it is left in place until disturbed, since a
bulk rename is a blocker under that same rule.

## .refs
- .agent/repo=.this/role=any/skills/audio.record.source.get.sh   # `--source`, reads the DECLARED state
- .agent/repo=.this/role=any/skills/audio.record.probe.sh        # `--source`, measures the LIVE signal
- .agent/repo=.this/role=any/skills/audio.record.operations.sh   # `__audio_source_is_monitor`, `__audio_sources_real`

## .reason
see the ref-level cluster beside this choice:
- `term=audio.record.source._.choice.reason.md` — why it is adopted rather than coined, the
  `mic` dispute, and the declared/live split it anchors

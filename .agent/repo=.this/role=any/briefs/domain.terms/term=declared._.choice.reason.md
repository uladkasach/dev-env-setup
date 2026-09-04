# domain.term.choice.reason: declared

## .etymology

`declared` was chosen because it names *who put the state there* — somebody wrote it down, on
purpose, in a file the machine reads at boot. that authorship is the whole reason the term
matters: a declaration reinstates itself, so it outranks whatever the machine holds this
instant.

the rejected words each name a side effect rather than the act:

| rejected | why it fails |
|----------|--------------|
| `persistent` | names a *property* (it survives), not the act. a cached file is persistent too, and no boot replays it |
| `durable` | same fault as persistent, and already carries a storage sense elsewhere |
| `static` | implies it never changes. a declaration is edited often; what it does not do is *evaporate* |
| `config` | too broad — every knob is config; this term is specifically the state a boot replays |
| `desired` | borrowed from declarative-infra jargon, and wrong here: fstab is not an aspiration, it is what WILL happen |
| `intended` | same as desired, and worse — it invites "intended vs actual" drift talk when the point is causal, not aspirational |

`declared` also pairs cleanly with `live` in shape and length, which
`rule.prefer.symmetric-term-pairs` asks for. `persistent`/`live` and `desired`/`actual` both
read as mismatched halves.

## .the incident that earned it

`configure_swapfile` added `/swapfile`, swapped it on, and wrote it into `/etc/fstab` — on a
grove whose kernel resumes from a different target that `ec2-hibinit-agent` had registered.
`systemctl hibernate` then refused.

two checkers were written for this, and the first draft of each read the LIVE state:

| checker | read | verdict on a poisoned box |
|---------|------|---------------------------|
| the guard in `configure_swapfile` | `swapon --show` | silent |
| `verify.swap.hibernate-safe` | active swap | **SAFE** |

both were run on a freshly resumed grove-1 that had *no active swap at all*, while
`/etc/fstab` still named the bad file. the live read said clean; the declaration said broken.
the declaration was right — and the very next boot would have proven it.

the matching false repair: `sudo swapoff /swapfile` fixed that boot and only that boot,
because the fstab line swapped it back on at the next one. that is what forced the vocabulary
— there was no single word for "the thing a swapoff fails to touch" until this one.

## .evidence

- discovery: a live failure, then a live re-run of both checkers against a known-poisoned box
- invariant: a verdict on machine state MUST rest on the declaration; live state may be
  reported only as context, and only when labelled transient
- the test that decides it: *"if i reboot this box right now, does my verdict still hold?"*

## .disputes

none open.

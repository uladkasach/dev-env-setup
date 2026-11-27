# gotcha: imagemagick 6 tokenizes the text inside an xml comment

## .what

imagemagick 6 reads `policy.xml` with its own tokenizer, not an xml parser. it does not skip
a comment as text. it walks the comment token by token, in search of its end.

a `'`, `"`, or `` ` `` inside a comment opens a quoted token. that token runs to the next
twin character, wherever it sits: past the comment end, through the rules, into a later
comment. every rule it crosses is **silently dropped**.

## .the measurement — 2026-10-25, 6.9.11 on a grove

`4.5.nvim/imagemagick.policy.xml` carried `debian's` in its rule 0 comment, and `init.lua's`
in its rule 3 comment. the file installed, equalled the checkout byte for byte, and
`convert -list policy` reported only two of its eleven rules:

```
Coder rights: None pattern: {TEXT,SHOW,WIN,PLT,LABEL,CAPTION,EPHEMERAL}
Delegate rights: None pattern: *
```

the resource caps, `path @*`, the ghostscript class, and the MSL/MVG class were gone. an
`.eps` reached ghostscript. the grove's stock policy, which this file replaced, **had**
closed PS. so the hardened file left the box weaker than the default.

## .the test

```sh
rhx imagemagick.policy.get    # count the rules in force against the rules in the file
```

a byte-equal `cmp` proves the copy. only the tool's own list proves the parse.

## .the clamp

- `4.5.nvim` never installs its policy FILE. it fences only the `<policy …/>` lines into the
  file the tool reads (`grove_provision_4_5_nvim_policy_render`), so no comment of the
  checkout ever reaches the tokenizer
- the policy file's comments may then carry any character. a rule line itself still may not:
  a quote inside a `<policy>` line would be fenced in, and bite the same way
- `4.5.nvim/configure.verify` asks the live tool whether an eps is refused. that is the
  check that would have gone ✋ on 2026-10-25, where the `cmp` read green

## .see also

- `rule.require.prove-changes-on-a-grove` — the grove run is what found it. the laptop
  had not yet taken the root install
- `gotcha.a-check-that-cries-wolf-gets-silenced` — the inverse case: a check that read
  green while the claim was false

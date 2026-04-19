# self review: has-pruned-backcompat (r4)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.3.1.blueprint.product.v1.i1.md`

## reference documents

- `0.wish.md` — original request
- `1.vision.md` — includes "questions for wisher — answered"

---

## backwards compatibility analysis

### wisher's stated position on breakage

from `1.vision.md`, "questions for wisher — answered":

| question | answer | implication |
|----------|--------|-------------|
| feature breakage tolerance | **yes, acceptable** | can lock down portals aggressively |
| file share need | yes, via portal | need download/upload portal, not full fs access |
| drag-drop | may not work | accepted per wisher |

**conclusion**: the wisher explicitly accepts feature breakage for security. backwards compatibility is NOT a requirement.

---

## backcompat concerns in blueprint

### concern 1: x11 fallback

**what**: blueprint removes x11 socket access via `--nosocket=x11 --nosocket=fallback-x11`.

**is this backcompat?** no — this is the core security feature. x11 access must be blocked.

**wisher position**: acceptable. vision states "x11 fallback: isolation fails — must use wayland only".

**decision**: keep as designed.

---

### concern 2: filesystem access removal

**what**: blueprint removes `--nofilesystem=home --nofilesystem=host`.

**is this backcompat?** no — this is the core security feature. direct filesystem access must be blocked.

**wisher position**: acceptable. portal provides mediated file access for uploads/downloads.

**decision**: keep as designed.

---

### concern 3: drag-drop behavior

**what**: drag-drop from host file manager to firefox may not work after changes.

**is this backcompat?** potentially, but wisher accepted.

**wisher position**: from vision, "behavior depends on portal implementation — may or may not work" and "we accept potential breakage here per wisher answers".

**decision**: keep as designed. no fallback needed.

---

### concern 4: debug with ptrace

**what**: yama ptrace_scope=2 blocks same-uid ptrace, which includes `gdb` and `strace` from host.

**is this backcompat?** this breaks debug from host.

**wisher position**: vision "uncomfortable tradeoffs" table lists:
- "debug | can't attach gdb/strace to firefox"

this tradeoff was documented and accepted. root/CAP_SYS_PTRACE still works for debug.

**decision**: keep as designed. this is the security feature. debug requires explicit privilege escalation, which is acceptable.

---

### concern 5: clipboard behavior

**what**: clipboard access between host and firefox goes through portal, may have latency.

**is this backcompat?** minor behavior change.

**wisher position**: vision "uncomfortable tradeoffs" table lists:
- "clipboard | needs portal, may have latency"

this tradeoff was documented. clipboard still works, just mediated.

**decision**: keep as designed. not a breakage, just a change in mechanism.

---

### concern 6: screenshot tools

**what**: host screenshot tools cannot capture firefox window content.

**is this backcompat?** yes, this is a behavior change.

**wisher position**: vision "uncomfortable tradeoffs" table lists:
- "screenshots | host screenshot tools can't capture firefox"

this is actually a security FEATURE — it prevents screen capture attacks.

**decision**: keep as designed. this is intentional protection, not accidental breakage.

---

## backcompat fallbacks found

**none**. the blueprint does not include any "to be safe" fallbacks or backwards compatibility shims.

---

## reflection

this is a security feature, not a refactor. the wisher explicitly accepted feature breakage. the blueprint correctly removes access (x11, filesystem) rather than adds fallback paths.

**no backcompat violations found**. the blueprint is correct to change:
- x11 access — blocked (security requirement)
- direct filesystem access — blocked (security requirement)
- drag-drop — may not work (accepted breakage)
- same-uid debug — blocked (accepted tradeoff, documented in vision)
- clipboard — mediated via portal (accepted tradeoff, documented in vision)
- screenshots — blocked from host capture (security feature, documented in vision)

**traceability to wisher**: all 6 concerns were either:
1. explicitly requested as security features, or
2. documented in the vision's "uncomfortable tradeoffs" table and accepted

**rule applied**: backcompat is only required when the wisher requests it. in this case, the wisher explicitly accepted breakage for security. the vision's "uncomfortable tradeoffs" section serves as evidence of informed consent.


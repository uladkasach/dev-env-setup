#!/usr/bin/env bash
######################################################################
# .what = source API keys for bhrain review skills
#
# .why  = enables guard reviews that need API access
#         this is a stub for repos that don't have keyrack setup
#
# .note = this file is sourced, not executed
######################################################################

# check if rhx keyrack is available and unlock if so
#
# ⚠️ `|| true` is load-bear and stays: this file is SOURCED, so a non-zero exit
#    would kill the caller's shell rather than degrade the review.
#
# 🛑 .but the `2>/dev/null` beside it is gone — removed 2026-09-29
#
#    the two were written as one gesture and they are not the same claim:
#      - `|| true` says *"a failed unlock must not halt the caller"*  ← correct
#      - `2>/dev/null` says *"and the caller must not LEARN it failed"* ← a swallow
#
#    ⇒ the rack names WHY it refused in exactly that stream, and the causes want
#    opposite repairs — `locked 🔒` wants an unlock retried by a human at the
#    browser, `absent 🫧` wants an entry wired, and a lapsed sso wants a login
#    (`term=swallow`, `term=entry`).
#
#    ⚠️ and the cost lands late and unattributably. with the stream sunk, a
#    guard review fails MINUTES later on an opaque auth error from the brain,
#    and no line anywhere names the unlock that quietly did not happen
#    (`rule.forbid.failhide`).
#
#    the stream is kept, so the refusal is on the page beside the review that
#    will fail because of it.
if command -v rhx &> /dev/null; then
  rhx keyrack unlock --owner ehmpath --env test || true
fi

# export any required environment variables if not already set
# (guards may need these for bhrain review skills)

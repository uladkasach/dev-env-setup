#!/usr/bin/env bash
######################################################################
# the `--for` axis — DERIVED from the environment, never detected twice
#
# .what = the `--for local|cloud` vocabulary: what a RUN can be for.
#
# .why it DERIVES rather than detects
#         "which machine is this?" has exactly one answer here, and it lives in
#         `grove.env.sh` as `$server`'s tier (rule.require.conform-to-sdk-environment).
#         `--for local|cloud` IS that tier — the same fact under a cli spelling —
#         so this file reads it rather than probe the box again.
#
#         a second probe is a defect this repo repeats. three separate artifacts
#         each held a second answer to this one question, and each drifted from
#         the first, so the rule is absolute: derive, never re-detect
#         (rule.require.bundle-as-sole-declaration).
#
# .values — what a RUN can be for
#   local — a machine with a screen and a human at its keyboard
#   cloud — a grove: a headless box reached over ssh/ssm, no screen, no human
#
# ⚠️ .why there are only TWO values, and why a bundle does not read them
#         a two-valued axis cannot express what a bundle actually depends on. a ci
#         runner is `local@cicd` — local tier, no screen, no human — so `local`
#         alone would offer it a gpu terminal, a browser flatpak, and a keyboard
#         remap. `--for` scopes a RUN; a bundle decides for ITSELF, on the fact it
#         depends on, by a test of `$GROVE_ENV_SERVER` inline — see
#         rule.require.grove-provision-bundles.
#
# 🛑 there is NO `grove_env_has_screen` / `grove_env_has_human` to reach for
#   - both were declared, then removed on 2026-07-29
#   - each name claimed a fact its body could not check
#   - `grove.env.sh`'s final `.note` carries all three reasons
#
# .note = safe to source. this file declares functions and takes no other action,
#         which is what lets a login shell source it on every startup.
#
# .refs = term=--for._.choice._.md — the term this file declares
######################################################################

# .what = which kind of machine this is, when the human does not say
# .why  = it reads the environment's tier rather than probe the box, so a run and
#         a bundle leaf can never disagree about where they are. `--for` still
#         overrides, because a derivation can be wrong and a human must be able
#         to say so
grove_for_detect() {
  # the environment may not be derived yet — a play may source this file alone
  if [ -z "${GROVE_ENV_SERVER:-}" ]; then
    grove_env_derive >/dev/null 2>&1 || true
  fi

  ####################################################################
  # the tier IS the --for value. one fact, one spelling per surface
  #
  # 🛑 an underived environment answers EMPTY — never `local`
  #   - `grove_env_derive` refuses to guess a platform, and halts instead
  #   - a guess here would reinstate the very default it refuses
  #   - `local` is the dangerous half: every interactive gate reads it as
  #     "a human is at a keyboard"
  #   - the empty answer fails `grove_for_valid`, so the caller halts
  ####################################################################
  case "${GROVE_ENV_SERVER:-}" in
    cloud@*) echo "cloud" ;;
    local@*) echo "local" ;;
    *)       return 1 ;;
  esac
}

# .what = is this a legitimate `--for` value?
# .why  = one validator, so every caller rejects the same words. a run is always
#         for exactly ONE kind of machine, so there is no third value to accept
grove_for_valid() {
  [ "${1:-}" = "cloud" ] || [ "${1:-}" = "local" ]
}

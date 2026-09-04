#!/usr/bin/env bash
######################################################################
# .what = prove that `starship` RUNS here, at the pinned version
#
# .why  = the upsert's exit code says its commands returned 0. it does not say
#         the binary runs — a truncated extract, a wrong architecture, or an
#         absent musl loader all leave a file on disk that will not execute.
#
# .why the VERSION and not merely the presence
#         a stale binary from an earlier pin satisfies "a file is here" while the
#         box is not at the version this repo declares. the claim is "starship is
#         at 1.24.2", so the check must read the version back.
#
# .why by explicit path and not the bare name
#         the same PATH trap the upsert names: `~/.local/bin` is on PATH only if
#         the dir existed when ~/.profile was sourced. a bare-name check would
#         fail on a first run that in fact SUCCEEDED, which cries wolf, and a
#         roll full of false failures gets ignored.
#
# guarantee:
#   - READ-ONLY. it runs a version flag and repairs no state
#
# exit:
#   0 = starship runs here at the pinned version
#   1 = it does not, and the fix is named
######################################################################

grove_provision_2_6_starship_provision_verify() {
  local version="1.24.2"
  local bin="$HOME/.local/bin/starship"

  if [[ ! -x "$bin" ]]; then
    echo "   ✋ no executable starship at $bin" >&2
    echo "      ⇒ provision.upsert did not take" >&2
    echo "      fix: rhx grove.provision --what 2.6.starship --mode apply" >&2
    return 1
  fi

  local have
  have="$("$bin" --version 2>/dev/null | awk 'NR==1{print $2}')"

  if [[ -z "$have" ]]; then
    echo "   ✋ starship is present at $bin but does not RUN" >&2
    echo "      ⇒ a truncated extract, or a binary for another architecture" >&2
    echo "      fix: rhx grove.provision --what 2.6.starship --mode apply" >&2
    return 1
  fi

  if [[ "$have" != "$version" ]]; then
    echo "   ✋ starship is at v${have}, and this repo declares v${version}" >&2
    echo "      ⇒ a binary from an earlier pin is still in place" >&2
    echo "      fix: rhx grove.provision --what 2.6.starship --mode apply" >&2
    return 1
  fi

  echo "   • starship v${have} runs ✔"

  ####################################################################
  # whether it is REACHABLE by name is worth a line, and is not a failure
  #
  # .why not a failure: the binary claim holds either way. a shell that cannot
  #      find it by name has a PATH question, and PATH is `2.4.zsh`'s and
  #      ubuntu's ~/.profile's business — not this bundle's. so it reports, and
  #      leaves the claim it owns intact
  ####################################################################
  # ⚠️ the note goes to STDOUT. the `•` above it does, and the runtime carries
  #    stderr on a SEPARATE pipe — so on stderr this qualifier had no order
  #    relative to the fact it qualifies, and could print above it. stderr's
  #    unordered, unpadded delivery is for a ✋, which SHOULD break the
  #    alignment; this block returns 0 and states so in its own banner above
  command -v starship &>/dev/null \
    || echo "     note: not on PATH yet — a NEW shell picks up ~/.local/bin"
}

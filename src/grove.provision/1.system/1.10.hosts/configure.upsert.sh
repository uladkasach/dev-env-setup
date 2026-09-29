#!/usr/bin/env bash
######################################################################
# .what = converge `/etc/hosts` to the declared ssm-proxy aliases — see `_.sh`
#
# .why a whole-file RENDER, and never an append
#   - an append cannot repair a fused line, reap a renamed stage, or add the
#     final newline whose absence fused the line in the first place
#   - ⇒ the render passes every line it does not own through untouched, and a
#     guard below refuses any candidate that lost one
#
# .why the READ comes before root (`define.provision-defect-shapes`, shape 2)
#   - ground converges it first; the camper, which holds no sudo, then finds the
#     file already converged and never asks
#
# .why the swap is a RENAME inside /etc
#   - every lookup on the box reads this file; a `tee` over it truncates first,
#     so a lookup mid-write sees an empty hosts file
#   - `mktemp` lands in /tmp, a different filesystem, where `mv` is a copy — so
#     the new file is staged beside the target and renamed over it
#
# guarantee:
#   - idempotent: a converged file is left untouched, with no sudo asked
#   - every line that names no ssm-proxy alias survives byte for byte
######################################################################

grove_provision_1_10_hosts_configure_upsert() {
  local hosts=/etc/hosts candidate
  candidate="$(mktemp)" || return 1

  if ! grove_provision_1_10_hosts_render "$hosts" > "$candidate"; then
    echo "   ✋ could not render the converged $hosts" >&2
    rm -f "$candidate"
    return 1
  fi

  # 0. already converged — no root asked
  if cmp -s "$hosts" "$candidate"; then
    echo "   • the ssm-proxy aliases are already declared in $hosts ✔"
    rm -f "$candidate"
    return 0
  fi

  # it does not hold, and this seat cannot set it — the seat with root owns it
  if ! pkg_can_sudo; then
    bundle.root.declines "the ssm-proxy aliases in $hosts" \
      "$hosts differs from the declared set"
    rm -f "$candidate"
    return 0
  fi

  ####################################################################
  # 🛑 refuse a candidate that dropped a line this bundle does not own
  #   - the render keeps them by construction; this proves it on the bytes, since
  #     a wrong /etc/hosts breaks every name lookup on the box
  #   - `localhost` is the line whose loss hurts most, so it is named on its own
  ####################################################################
  local foreign_live foreign_candidate
  foreign_live="$(sed -E 's/(# managed by declastruct)([^[:space:]])/\1\n\2/g' "$hosts" \
                    | grep -cv 'aws\.ssmproxy\.' || true)"
  foreign_candidate="$(grep -cv 'aws\.ssmproxy\.' "$candidate" || true)"
  if [[ "$foreign_live" != "$foreign_candidate" ]] \
     || { grep -q 'localhost' "$hosts" && ! grep -q 'localhost' "$candidate"; }; then
    echo "   ✋ the rendered $hosts would lose a line this bundle does not own" >&2
    echo "      ⇒ $foreign_live such lines live, $foreign_candidate in the candidate" >&2
    echo "      ⇒ refused, so $hosts is untouched. read the candidate: $candidate" >&2
    return 1
  fi

  pkg_assert_sudo || { rm -f "$candidate"; return 1; }

  # stage beside the target, then rename over it — see the header
  local staged="$hosts.grove-provision.new"
  if ! sudo install -m 0644 -o root -g root "$candidate" "$staged"; then
    echo "   ✋ could not stage $staged" >&2
    rm -f "$candidate"
    return 1
  fi
  rm -f "$candidate"

  if ! sudo mv -f "$staged" "$hosts"; then
    echo "   ✋ could not swap $staged over $hosts" >&2
    sudo rm -f "$staged"
    return 1
  fi

  echo "   • the ssm-proxy aliases declared in $hosts (fused lines split, stale aliases reaped)"
}

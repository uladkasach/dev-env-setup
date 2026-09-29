#!/usr/bin/env bash
######################################################################
# .what = prove the ssm-proxy aliases LOOK UP to 127.0.0.1, the file holds no
#         fused or stale line, and no cloned repo declares an alias the table lacks
#
# .why `getent`, never a grep for the name
#   - the claim is that a db client's lookup lands on the tunnel, and `getent` asks
#     the same resolver order the client does (nsswitch), where a grep proves only
#     that some line spells the name
#
# .why the repo cross-check
#   - the table in `_.sh` is a second copy of a fact the repos own
#     (`.database.tunnel.local.host`), so it drifts the day a repo adds an env
#   - ⇒ this reads every cloned repo's `config/*.json` and names the gap
#   - a box with no repo cloned yet reads none, and that is no failure — the table
#     is what a fresh box relies on
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_1_10_hosts_configure_verify() {
  local hosts=/etc/hosts failed=0 alias ip got declared
  ip="$(grove_provision_1_10_hosts_ip)"
  declared=" $(grove_provision_1_10_hosts_aliases) "

  # 1. each declared alias looks up to the tunnel's local end
  for alias in $(grove_provision_1_10_hosts_aliases); do
    got="$(getent hosts "$alias" 2>/dev/null | awk '{print $1; exit}')"
    if [[ "$got" == "$ip" ]]; then
      echo "   • $alias → $ip ✔"
      continue
    fi
    echo "   ✋ $alias looks up to '${got:-absent}', want $ip" >&2
    echo "      ⇒ every db read through that tunnel dies with ENOTFOUND" >&2
    echo "      fix: rhx grove.provision --what 1.10.hosts --mode apply" >&2
    failed=1
  done

  # 2. no line fused onto a declastruct comment — it breaks the NEXT host's entry
  if grep -qE '# managed by declastruct[^[:space:]]' "$hosts"; then
    echo "   ✋ $hosts holds a line fused onto a '# managed by declastruct' comment" >&2
    echo "      ⇒ the host after the comment is read as part of it, so it looks up to nowhere" >&2
    echo "      fix: rhx grove.provision --what 1.10.hosts --mode apply" >&2
    failed=1
  else
    echo "   • no line in $hosts is fused onto another ✔"
  fi

  # 3. the file ends in a newline — its absence is what fuses the next append
  if [[ -s "$hosts" && -n "$(tail -c1 "$hosts")" ]]; then
    echo "   ✋ $hosts has no final newline, so the next append fuses onto its last line" >&2
    echo "      fix: rhx grove.provision --what 1.10.hosts --mode apply" >&2
    failed=1
  else
    echo "   • $hosts ends in a newline ✔"
  fi

  # 4. no ssm-proxy alias the table does not declare — a renamed stage's leftover
  local stale
  stale="$(awk '
    { for (i = 2; i <= NF; i++) { if ($i ~ /^#/) break; if ($i ~ /^aws\.ssmproxy\./) print $i } }
  ' "$hosts" | while read -r alias; do
      [[ "$declared" == *" $alias "* ]] || printf '%s ' "$alias"
    done)"
  if [[ -n "$stale" ]]; then
    echo "   ✋ $hosts names ssm-proxy aliases no row declares: ${stale% }" >&2
    echo "      ⇒ a stage that was renamed leaves its old alias behind" >&2
    echo "      fix: rhx grove.provision --what 1.10.hosts --mode apply" >&2
    failed=1
  else
    echo "   • every ssm-proxy alias in $hosts is declared ✔"
  fi

  # 5. every alias a cloned repo declares is in the table
  if ! command -v jq >/dev/null 2>&1; then
    echo "   🌙 jq is absent, so the repos' declared aliases cannot be read (5.3.brains installs it)"
    return $failed
  fi
  local config host absent="" count=0
  for config in "$HOME"/git/*/*/config/*.json; do
    [[ -r "$config" ]] || continue
    host="$(jq -r '.database.tunnel.local.host // empty' "$config" 2>/dev/null)"
    [[ "$host" == aws.ssmproxy.* ]] || continue
    count=$(( count + 1 ))
    [[ "$declared" == *" $host "* ]] && continue
    [[ " $absent " == *" $host "* ]] || absent="$absent $host"
  done
  if [[ -n "$absent" ]]; then
    echo "   ✋ a cloned repo declares ssm-proxy aliases this box does not:${absent}" >&2
    echo "      ⇒ its tunnel will reach for sudo to add the alias, and fail with no terminal" >&2
    echo "      fix: add each to \`grove_provision_1_10_hosts_aliases\` in 1.10.hosts/_.sh, then apply" >&2
    failed=1
  else
    echo "   • every alias the cloned repos declare is covered ✔ ($count config(s) read)"
  fi

  return $failed
}

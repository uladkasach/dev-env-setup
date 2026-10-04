#!/usr/bin/env bash
######################################################################
# .what = the ssm-proxy host aliases in `/etc/hosts` — `aws.ssmproxy.<cluster>.<env>`
#         → 127.0.0.1, one line per env a repo tunnels a database through
#
# .why it exists
#   - `rhx use.vpc.tunnel` adds its `.database.tunnel.local.host` alias via `sudo tee`
#   - with no terminal that sudo cannot ask, so every db read dies `ENOTFOUND`
#   - ⇒ the seat that CAN write /etc pre-seeds it, and the skill's findsert never sudos
#
# .why a DECLARED table, never a scan of the cloned repos
#   - ground writes /etc, but the repos sit in the camper's $HOME, out of its reach
#   - the VERIFY reads every cloned `config/*.json` and reddens on an alias this lacks
#
# 🛑 no account id, no endpoint: this repo is PUBLIC (`rule.forbid.dox-in-public-repo`)
#
# usage:
#   rhx grove.provision --what 1.10.hosts --mode apply
######################################################################

# .what = every alias this box must map to 127.0.0.1
# 🛑 a row per `.database.tunnel.local.host` a repo declares. the verify names any it misses
# ⚠️ `.dev` is the pre-rename name of `prep`, and it is STILL LIVE — measured 2026-09-28:
#   svc-jobs and svc-proknow name it in `config/prep.json`, and three repos' schema
#   deploy scripts hardcode it for every non-prod env. it leaves this table only once
#   no repo names it; the verify's cross-check is what will show that
grove_provision_1_10_hosts_aliases() {
  printf 'aws.ssmproxy.ahbodedb.dev aws.ssmproxy.ahbodedb.prep aws.ssmproxy.ahbodedb.prod'
}

# .what = the ip every alias maps to — the local end of an ssm port-forward
grove_provision_1_10_hosts_ip() { printf '127.0.0.1'; }

# .what = the comment on each line — declastruct-unix-network's own marker
# .why identical on purpose: the tunnel skill writes this exact line, so the two
#   writers render ONE line and neither sees the other's as foreign
grove_provision_1_10_hosts_comment() { printf 'managed by declastruct'; }

####################################################################
# .what = render the converged /etc/hosts from the live one, on stdout
#
# .three moves, in order
#   1. SPLIT a line fused onto a declastruct comment. an append onto a file with no
#      trailing newline yields `…# managed by declastruct127.0.0.1 other.host`, which
#      breaks the OTHER host's line; a split restores both
#   2. DROP every owned line — a declared alias is re-rendered in 3, and an
#      undeclared one (a renamed stage, as `.dev` was) is a leftover
#   3. APPEND each declared alias, in the declastruct format
#
# .guarantee: every line that names no ssm-proxy alias passes through byte for byte
####################################################################
grove_provision_1_10_hosts_render() {
  local live="$1" ip comment alias
  ip="$(grove_provision_1_10_hosts_ip)"
  comment="$(grove_provision_1_10_hosts_comment)"

  sed -E "s/(# ${comment})([^[:space:]])/\\1\\n\\2/g" "$live" \
    | awk '
        {
          owned = 0
          for (i = 2; i <= NF; i++) {
            if ($i ~ /^#/) break
            if ($i ~ /^aws\.ssmproxy\./) { owned = 1; break }
          }
          if (!owned) print
        }'

  for alias in $(grove_provision_1_10_hosts_aliases); do
    printf '%s\t%s\t# %s\n' "$ip" "$alias" "$comment"
  done
}

grove_provision_1_10_hosts() {
  bundle.upgrade 1.10.hosts.configure.upsert
  bundle.upgrade 1.10.hosts.configure.verify
}

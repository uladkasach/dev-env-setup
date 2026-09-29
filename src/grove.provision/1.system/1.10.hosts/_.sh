#!/usr/bin/env bash
######################################################################
# .what = the ssm-proxy host aliases in `/etc/hosts` — `aws.ssmproxy.<cluster>.<env>`
#         → 127.0.0.1, one line per env a repo tunnels a database through
#
# .why it exists
#   - a repo's `config/<env>.json` names its db tunnel's LOCAL end as
#     `.database.tunnel.local.host`; `rhx use.vpc.tunnel` opens the ssm port-forward
#     with no root, then ensures that alias via `sudo tee -a /etc/hosts`
#   - in a shell with no terminal that sudo cannot ask, so every db read and every
#     provision that looks the alias up dies with `ENOTFOUND`
#   - ⇒ pre-seed the alias here, as the seat that CAN write /etc; the tunnel skill's
#     findsert (`setUnixHostAlias`, keyed on the hostname) then finds it and never
#     reaches for sudo
#
# .why a DECLARED table, and never a scan of the cloned repos
#   - /etc is written by the seat with root (ground), and the repos are cloned into
#     each seat's own $HOME — on a grove, into the camper's
#   - ⇒ a scan on ground reads no configs, and the camper that holds them cannot
#     write (`define.provision-defect-shapes`, a VERIFY that reads state a LATER
#     component writes). a table converges on a fresh box with no repo cloned
#   - the VERIFY closes the drift a table invites: it reads every cloned repo's
#     `config/*.json` and reddens on an alias a repo declares that this table lacks
#
# 🛑 .no account id, no endpoint — this repo is PUBLIC (`rule.forbid.dox-in-public-repo`)
#   - an alias maps a NAME to 127.0.0.1; it points no tool at a real resource
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

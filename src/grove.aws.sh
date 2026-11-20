#!/usr/bin/env bash
######################################################################
# the aws identity runtime — how this box's own aws identity is reached,
# and how ~/.aws/config is written beside a writer we do not own
#
# .what = three operations every aws writer here shares:
#           grove_aws_identity_endpoint   which IMDS endpoint serves the box's identity
#           grove_aws_config_fence_drop   copy the config through, minus one fenced block
#           grove_aws_config_swap         replace the config atomically, iff [default] held
#
# .why one file, beside `grove.env.sh`
#   - `5.6.aws` (a bundle) and `aws.reach.set` / `aws.reach.del` (skills) all
#     write ~/.aws/config, and all three need the same three answers
#   - three copies of one rule drift; the common ancestor of a bundle and a
#     skill is `src/`, so the rule lives here once
#     (`rule.prefer.most-common-denominator`)
#
# .why the ENDPOINT is the one fact that varies by platform
#   - both grove platforms serve identity through one protocol: an IMDSv2
#     endpoint. ec2's sits at 169.254.169.254, the sdk default. a hetzner
#     grove's is infra's signer on loopback, named in camper's [default]
#   - so every body this repo writes keeps `credential_source =
#     Ec2InstanceMetadata`; a hetzner body adds one line,
#     `ec2_metadata_service_endpoint = <this answer>`
#   - 📌 a `source_profile = default` hop was the wish's shape. from recall of
#     botocore, a source profile must yield credentials through the PROFILE
#     providers, which exclude instance metadata — so it is not used here.
#     the hetzner grove's first apply measures both (route F5)
#
# 🛑 .why [default] is RE-READ before every swap, on every platform
#   - on a hetzner grove, [default] is infra's: its identity skill rewrites it
#     on its own schedule, with a tmp + `mv` swap
#   - our writers read the file, rebuild it, and write it back. a rewrite
#     between our read and our write would put back the [default] bytes we read
#   - ⇒ the swap re-reads [default] at the last moment and refuses if it moved
#
# 🛑 .why a fence whose BEGIN marker is gone is still ours
#   - infra's writer drops every line from `[default]` to the next `[` header,
#     comments included. our fences open with a comment line that sits BEFORE
#     their `[profile …]` header, so the first fence after [default] loses its
#     begin marker on infra's second run
#   - a dropper keyed on the begin marker alone would then miss the block, and
#     the next upsert would append a twin `[profile …]` — the last one wins in
#     silence
#   - ⇒ with no begin marker, the dropper falls back to the fence's own section
#     header, up to its end marker. the end marker is still ours, so the block
#     is still named; no human config is touched
#
# usage: sourced, never run
#   source "$GROVE_SRC/grove.aws.sh"
######################################################################

# .what = the file every aws writer here edits
# .why aws offers one file for profiles, so every writer names this one path
grove_aws_config() { printf '%s/.aws/config' "$HOME"; }

######################################################################
# .what = print one section of an aws config, header line included
#
# .why  = [default] is compared byte for byte before every swap, and
#         read for its endpoint and region. one reader, so both reads agree
#
# usage: grove_aws_config_section cfg=<path> name=<default|profile x>
# .note  the header match tolerates the spaces infra's own matcher tolerates:
#        `[ default ]` and `[default]` are one section to the sdk
#
# 🛑 .why comment and blank lines are LEFT OUT
#   - a section runs to the next `[` header, so a fence that opens right after
#     [default] puts its `# grove: …` begin line inside [default]'s span
#   - a byte compare that kept it would read our own fence drop as a change to
#     [default], and refuse every re-run
#   - ⇒ the compare reads what the sdk reads: headers and key lines
######################################################################
grove_aws_config_section() {
  local cfg="" name="" arg
  for arg in "$@"; do
    case "$arg" in
      cfg=*)  cfg="${arg#cfg=}" ;;
      name=*) name="${arg#name=}" ;;
    esac
  done
  [[ -f "$cfg" ]] || return 0
  awk -v want="$name" '
    function norm(s) { gsub(/^\[[[:space:]]*|[[:space:]]*\]$/, "", s); gsub(/[[:space:]]+/, " ", s); return s }
    /^\[/ { inside = (norm($0) == want) }
    inside && $0 !~ /^[[:space:]]*([#;]|$)/ { print }
  ' "$cfg"
}

######################################################################
# .what = read one key's value out of one section
# usage: grove_aws_config_value cfg=<path> name=<section> key=<key>
######################################################################
grove_aws_config_value() {
  local cfg="" name="" key="" arg
  for arg in "$@"; do
    case "$arg" in
      cfg=*)  cfg="${arg#cfg=}" ;;
      name=*) name="${arg#name=}" ;;
      key=*)  key="${arg#key=}" ;;
    esac
  done
  grove_aws_config_section cfg="$cfg" name="$name" | awk -v key="$key" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (index(line, key) != 1) next
      rest = substr(line, length(key) + 1)
      if (rest !~ /^[[:space:]]*=/) next
      sub(/^[[:space:]]*=[[:space:]]*/, "", rest)
      sub(/[[:space:]]+$/, "", rest)
      print rest
      exit
    }
  '
}

######################################################################
# .what = the IMDS endpoint that serves this box's own aws identity
#
# stdout: the endpoint; EMPTY on ec2, where the sdk default is the answer
# rc:
#   0 = known (empty on ec2, a loopback url on hetzner)
#   1 = a grove platform whose endpoint is not declared yet — on hetzner,
#       [default] names no `ec2_metadata_service_endpoint` (infra's serve
#       is not wired)
#   2 = this box has no platform identity (a laptop, or a tag this file
#       does not know — fail CLOSED)
#   3 = an endpoint is declared and sits outside its grammar
#
# 🛑 .why the hetzner endpoint must be LOOPBACK
#   - the value is copied into every body this repo writes, and the sdk sends
#     its identity requests there. infra's signer serves on loopback with a
#     hop limit of 1 — parity with ec2's link-local endpoint
#   - an endpoint off the box would hand this grove's identity flow to another
#     host. so a value other than a loopback http url is refused, never copied
######################################################################
grove_aws_identity_endpoint() {
  local endpoint
  case "${GROVE_ENV_SERVER:-}" in
    *@aws.ec2) return 0 ;;
    *@hetzner.hetzbot)
      endpoint="$(grove_aws_config_value cfg="$(grove_aws_config)" name=default key=ec2_metadata_service_endpoint)"
      [[ -n "$endpoint" ]] || return 1
      [[ "$endpoint" =~ ^http://(127\.0\.0\.1|localhost|\[::1\]):[0-9]{1,5}/?$ ]] || { printf '%s' "$endpoint"; return 3; }
      printf '%s' "$endpoint"
      return 0 ;;
    *) return 2 ;;
  esac
}

# .what = the IMDS base url for an identity endpoint: ec2's link-local default when
#         the endpoint is empty, a final slash cut so `$base/latest/…` joins clean
grove_aws_imds_base() {
  local base="${1:-http://169.254.169.254}"
  printf '%s' "${base%/}"
}

# .what = the named road to this box's identity, from `grove_aws_identity_endpoint`'s rc
#   known          — the endpoint is known (ec2's sdk default, or hetzner's loopback signer)
#   serve-unwired  — a hetzner grove whose [default] names no endpoint yet
#   bad-endpoint   — an endpoint is declared outside its grammar
#   unmapped       — a camp grove (`cloud@*`) on a platform this file knows no road for
#   no-identity    — a box with no platform identity at all (a laptop)
# .why  = every reader dispatches on a word, never on the rc's integer map
# .note pure: reads the rc and GROVE_ENV_SERVER
grove_aws_identity_road() {
  case "$1" in
    0) printf known ;;
    1) printf serve-unwired ;;
    2) [[ "${GROVE_ENV_SERVER:-}" == cloud@* ]] && { printf unmapped; return 0; }
       printf no-identity ;;
    *) printf bad-endpoint ;;
  esac
}

######################################################################
# .what = copy the config through to stdout, minus ONE fenced block
#
# usage: grove_aws_config_fence_drop cfg=<path> open=<line> shut=<line> header=<line>
#                                    [open_was=<line> shut_was=<line>]
#   open   = the fence's begin marker
#   shut   = the fence's end marker
#   open_was / shut_was = a retired marker pair, dropped too, so a rename of the
#            fence word never orphans a block a prior version wrote
#   header = the first section header inside the fence (e.g. `[profile ambient]`)
#
# .the two shapes it drops
#   - whole fence: from `open` to `shut`, inclusive — the shape every writer leaves
#   - orphan fence: `open` is gone (infra's writer ate it, see the file header),
#     so from `header` to `shut`, inclusive — only where `shut` follows `header`
#     with no other section header between, so a human's same-name section
#     outside any fence is never touched
#
# .note it prints; the caller owns the write, the compare, and the swap
######################################################################
# .what = the awk prelude both fence passes share: the open/shut tests, and
#   pass 1, which marks each orphan span (header … shut, with no open before it)
#   in `orphan_from[<header line>] = <shut line>`
# 🛑 .why declared ONCE: if drop and set disagree on which span is an orphan, a
#   re-run appends a twin `[profile …]` (the last wins in the sdk, silently) or
#   drops the wrong block. one program text cannot disagree with itself
GROVE_AWS_FENCE_SPANS_AWK='
    function isopen(l) { return l == open || (openw != "" && l == openw) }
    function isshut(l) { return l == shut || (shutw != "" && l == shutw) }
    NR == FNR {
      if ($0 == header && !infence) { cand = NR }
      else if (cand && /^\[/) { cand = 0 }
      if (isopen($0)) { infence = 1 }
      if (isshut($0)) {
        if (!infence && cand) { orphan_from[cand] = NR }
        infence = 0; cand = 0
      }
      next
    }
'

grove_aws_config_fence_drop() {
  local cfg="" open="" shut="" header="" openw="" shutw="" arg
  for arg in "$@"; do
    case "$arg" in
      cfg=*)      cfg="${arg#cfg=}" ;;
      open=*)     open="${arg#open=}" ;;
      shut=*)     shut="${arg#shut=}" ;;
      header=*)   header="${arg#header=}" ;;
      open_was=*) openw="${arg#open_was=}" ;;
      shut_was=*) shutw="${arg#shut_was=}" ;;
    esac
  done
  [[ -f "$cfg" ]] || return 0
  awk -v open="$open" -v shut="$shut" -v header="$header" -v openw="$openw" -v shutw="$shutw" "$GROVE_AWS_FENCE_SPANS_AWK"'
    # pass 2: print all but the dropped spans
    {
      if (skipto) { if (FNR == skipto) { skipto = 0 }; next }
      if (isopen($0)) { skip = 1; next }
      if (skip) { if (isshut($0)) { skip = 0 }; next }
      if (FNR in orphan_from) { skipto = orphan_from[FNR]; next }
      print
    }
  ' "$cfg" "$cfg"
}

######################################################################
# .what = copy the config through to stdout, with ONE fenced block set IN PLACE
#
# usage: grove_aws_config_fence_set cfg=<path> open=<line> shut=<line> header=<line>
#                                   body=<text> [open_was=<line> shut_was=<line>]
#   body = the whole fence, its own open and shut lines included
#   the rest = as `grove_aws_config_fence_drop`, which finds the same spans
#
# 🛑 .why in place, never drop-then-append
#   - two writers share this file (`5.6.aws` and `aws.reach.set`), and each one's
#     append moved the OTHER's block, so no apply ever wrote the bytes the last
#     one left, and every run on a healthy box was a write
#   - the reach drop also stranded its blank line mid-file, once per run
#   - 📜 2026-11-14, an ec2 camper: the config hash moved on every apply of
#     both bundles while every profile held its content
#   - ⇒ the body lands where the FIRST prior span stood; any later span (a twin,
#     a legacy fence) is dropped; with no span at all, it is appended once,
#     after one blank line
#
# .note it prints; the caller owns the compare and the swap
######################################################################
grove_aws_config_fence_set() {
  local cfg="" open="" shut="" header="" openw="" shutw="" body="" arg
  for arg in "$@"; do
    case "$arg" in
      cfg=*)      cfg="${arg#cfg=}" ;;
      open=*)     open="${arg#open=}" ;;
      shut=*)     shut="${arg#shut=}" ;;
      header=*)   header="${arg#header=}" ;;
      open_was=*) openw="${arg#open_was=}" ;;
      shut_was=*) shutw="${arg#shut_was=}" ;;
      body=*)     body="${arg#body=}" ;;
    esac
  done
  [[ -f "$cfg" ]] || { printf '%s\n' "$body"; return 0; }
  GROVE_FENCE_BODY="$body" awk -v open="$open" -v shut="$shut" -v header="$header" -v openw="$openw" -v shutw="$shutw" "$GROVE_AWS_FENCE_SPANS_AWK"'
    function put() { if (!done) { printf "%s\n", ENVIRON["GROVE_FENCE_BODY"]; done = 1; last = "x" } }
    # pass 2: the first span becomes the body; later spans drop; all else copies
    {
      if (skipto) { if (FNR == skipto) { skipto = 0 }; next }
      if (isopen($0)) { put(); skip = 1; next }
      if (skip) { if (isshut($0)) { skip = 0 }; next }
      if (FNR in orphan_from) { put(); skipto = orphan_from[FNR]; next }
      print; last = $0; any = 1
    }
    END {
      if (done) exit
      if (any && last != "") print ""
      printf "%s\n", ENVIRON["GROVE_FENCE_BODY"]
    }
  ' "$cfg" "$cfg"
}

######################################################################
# .what = replace the config with a new body, atomically, iff [default] held
#
# usage: grove_aws_config_swap cfg=<path> new=<path> default_before=<bytes> default=<keep|own>
#   new            = the rebuilt file; it is moved over cfg, or removed
#   default_before = the [default] section as the caller READ it
#   default        = keep — [default] is another writer's (hetzner): the new
#                           body must carry it byte for byte
#                    own  — this writer owns [default] (5.6.aws on ec2)
#
# rc: 0 = swapped · 3 = [default] moved since the read (another writer ran) ·
#     4 = the new body changed a [default] this writer does not own · 1 = io
#
# .why `mv` and not `cat >`: a reader never sees half a file, and it matches
#   the swap infra's own writer makes
#
# ⚠️ .the bound: it guards [default] ONLY
#   - the re-read covers the one section a FOREIGN writer owns, so infra's
#     identity skill is never clobbered (rc 3)
#   - this repo's own fences (`5.6.aws`, `aws.reach.set`) are NOT compared: two
#     of them run at the same moment could each rebuild from the same bytes, and
#     the later `mv` would drop the earlier fence
#   - that window is accepted, not guarded: a provision runs both writers in
#     series, so the one overlap is a human's hand `aws.reach.set` beside an
#     apply — and the next apply re-lays whichever fence it lost
######################################################################
grove_aws_config_swap() {
  local cfg="" new="" before="" own="" arg now newdefault
  for arg in "$@"; do
    case "$arg" in
      cfg=*)            cfg="${arg#cfg=}" ;;
      new=*)            new="${arg#new=}" ;;
      default_before=*) before="${arg#default_before=}" ;;
      default=*)        own="${arg#default=}" ;;
    esac
  done

  # another writer moved [default] since the caller read it — never clobber
  now="$(grove_aws_config_section cfg="$cfg" name=default)"
  if [[ "$now" != "$before" ]]; then rm -f "$new"; return 3; fi

  # a writer that does not own [default] may not change it, even by accident
  if [[ "$own" == keep ]]; then
    newdefault="$(grove_aws_config_section cfg="$new" name=default)"
    if [[ "$newdefault" != "$before" ]]; then rm -f "$new"; return 4; fi
  fi

  # the tool's stderr is KEPT, never left raw: `grove_aws_config_swap_said` renders it
  #   under the caller's own 💥 line, where a raw `mv:` would land above it at column 0
  GROVE_AWS_SWAP_SAID=""
  GROVE_AWS_SWAP_SAID="$(chmod 600 "$new" 2>&1 && mv -f "$new" "$cfg" 2>&1)" || { rm -f "$new"; return 1; }
}

# .what = what the swap's io tool said, one `⇒ it said:` line each, under <indent>
# .note = prints naught where the swap raised no io fault
grove_aws_config_swap_said() {
  [[ -n "${GROVE_AWS_SWAP_SAID:-}" ]] || return 0
  printf '%s\n' "$GROVE_AWS_SWAP_SAID" | sed "s/^/${1}⇒ it said: /"
}

# .what = a tmp path BESIDE the config, so the swap's `mv` is one rename
grove_aws_config_tmp() { mktemp "$(dirname "$(grove_aws_config)")/.config.grove.XXXXXX"; }

# .what = the human words for a swap's refusal rc, for every caller's fix-text
grove_aws_config_swap_why() {
  case "$1" in
    3) printf '[default] changed while this run read the file — another writer (infra'"'"'s identity skill) ran at the same moment. re-run to rebuild from the new bytes' ;;
    4) printf 'the rebuilt file would change [default], which this writer does not own — a defect here, not on the box' ;;
    *) printf 'the write failed (io) — check that %s is writable' "$(grove_aws_config)" ;;
  esac
}

# .what = the trust-policy action a role refused, read off aws's AccessDenied text
# .why  = an IAM Roles Anywhere session carries a source identity and session tags,
#   and a chained AssumeRole passes both on. a trust statement that allows
#   sts:AssumeRole alone refuses it on one, and once that is granted, on the other.
#   📜 measured 2026-11-16 on hetzner, one denial at a time. ec2 sessions carry neither
# .note pure. prints the refused action; rc 1 when the text names neither. shared by
#   `aws.reach.set` (the write's proof) and `5.13.reach` (the verify), so both repairs agree
grove_aws_trust_refused() {
  local said="$1"
  [[ "$said" == *sts:SetSourceIdentity* ]] && { printf 'sts:SetSourceIdentity'; return 0; }
  [[ "$said" == *sts:TagSession* ]] && { printf 'sts:TagSession'; return 0; }
  return 1
}

# .what = the actions a role's trust statement owes a roles-anywhere session — all at once
# .why  = to name one refusal at a time costs infra one edit and one round trip per action
grove_aws_trust_actions_owed() { printf '"sts:AssumeRole", "sts:SetSourceIdentity", "sts:TagSession"'; }

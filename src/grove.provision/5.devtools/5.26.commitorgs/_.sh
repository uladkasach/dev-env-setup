#!/usr/bin/env bash
######################################################################
# .what = let a cloud grove's crews commit for each org its github token can
#         push to — derived from the token, granted by the bundle
#
# .why
#   - `git.commit.set` and `git.commit.push` refuse a crew whose org the seat's
#     org commit meter does not allow: `no org config for <org>`
#   - the meter is one file per seat, so a fresh or rebuilt box has none, and
#     its first crew is refused at the done gate
#   - the grove's token already says which orgs its work may reach: its push
#     scope is the grant. a list typed here would be a second copy of that fact
#
# .why cloud seats only
#   - on a local grove the meter is the human's own choice of which orgs his
#     clones may commit for; no fact on the box answers it, so this declines
#
# .why it never overwrites a block or a damaged meter
#   - a block is a human's word, kept as is; a damaged meter is read by a human
#     before it is cleared, since a block may sit inside it
#
# usage:
#   rhx grove.provision --what 5.26.commitorgs --mode plan
######################################################################

# .what = the org commit meter, where `git.commit.uses --org` writes it
grove_provision_5_26_commitorgs_meter_path() {
  printf '%s' "$HOME/.rhachet/storage/repo=ehmpathy/role=mechanic/.meter/git.commit.uses.org.jsonc"
}

# .what = the bound, in seconds, on the one github read this bundle makes
GROVE_COMMITORGS_GH_SECONDS=60

# .what = the keyrack orgs this seat's github token can push to, space-joined, sorted
# .why  = the meter is keyed on the keyrack org (the `org:` a crew tree's
#         `.agent/keyrack.yml` names), so each github org maps back through
#         `grove_org_clonedir` — a github org named apart from its keyrack org reads
#         as the keyrack org
# .note = returns 1 on a failed read, so an unread token is never an empty set
grove_provision_5_26_commitorgs_token_orgs() {
  local ghorgs ghorg found=''
  ghorgs="$(timeout -k 5 "$GROVE_COMMITORGS_GH_SECONDS" gh api --paginate 'user/repos?per_page=100' \
    --jq '.[] | select(.owner.type=="Organization" and .permissions.push==true) | .owner.login' \
    </dev/null 2>/dev/null)" || return 1
  for ghorg in $(printf '%s\n' "$ghorgs" | sort -u); do
    found="${found:+$found }$(grove_org_clonedir "$ghorg")"
  done
  printf '%s' "$(printf '%s\n' $found | sort -u | tr '\n' ' ' | sed 's/ $//')"
}

# .what = how the commit gate will read one org, from the meter's presence + bytes
#
# args: org=<org> presence=absent|present|unreadable bytes=<the file's bytes>
# stdout: allowed · allowed@all · blocked · blocked@all · unset · corrupt
#
# .why it mirrors `check_org_blocker` = the gate decides a commit, so a verdict
#      here that disagreed with it would be a ✔ over a refused crew
grove_provision_5_26_commitorgs_state_of() {
  local org='' presence='' bytes='' leaf all arg
  for arg in "$@"; do
    case "$arg" in
      org=*)      org="${arg#org=}" ;;
      presence=*) presence="${arg#presence=}" ;;
      bytes=*)    bytes="${arg#bytes=}" ;;
    esac
  done
  [[ -n "$org" && -n "$presence" ]] || {
    echo "✋ ConstraintError: grove_provision_5_26_commitorgs_state_of needs org= and presence=" >&2
    return 2
  }

  [[ "$presence" == "absent" ]] && { echo unset; return 0; }
  [[ "$presence" == "present" ]] || { echo corrupt; return 0; }

  # the gate demands an object at the top and an object at `.orgs`
  printf '%s' "$bytes" \
    | jq -s -e '.[0] | type == "object" and ((.orgs // {}) | type == "object")' >/dev/null 2>&1 \
    || { echo corrupt; return 0; }

  leaf="$(printf '%s' "$bytes" | jq -s -r --arg k "$org" '.[0].orgs[$k] // "unset"' 2>/dev/null)" \
    || { echo corrupt; return 0; }
  case "$leaf" in
    allowed|blocked) echo "$leaf"; return 0 ;;
    unset) ;;
    *) echo corrupt; return 0 ;;
  esac

  all="$(printf '%s' "$bytes" | jq -s -r '.[0].orgs["@all"] // "unset"' 2>/dev/null)" \
    || { echo corrupt; return 0; }
  case "$all" in
    allowed|blocked) echo "${all}@all" ;;
    unset) echo unset ;;
    *) echo corrupt ;;
  esac
}

# .what = one `<org>=<state>` line per org.  args: orgs= presence= bytes=
grove_provision_5_26_commitorgs_states_of() {
  local orgs='' presence='' bytes='' org arg
  for arg in "$@"; do
    case "$arg" in
      orgs=*)     orgs="${arg#orgs=}" ;;
      presence=*) presence="${arg#presence=}" ;;
      bytes=*)    bytes="${arg#bytes=}" ;;
    esac
  done
  for org in $orgs; do
    printf '%s=%s\n' "$org" "$(grove_provision_5_26_commitorgs_state_of org="$org" presence="$presence" bytes="$bytes")"
  done
}

# .what = the orgs whose state is one of a set, space-joined.  args: states= in=
grove_provision_5_26_commitorgs_orgs_in() {
  local states='' in='' org state found='' arg
  for arg in "$@"; do
    case "$arg" in
      states=*) states="${arg#states=}" ;;
      in=*)     in="${arg#in=}" ;;
    esac
  done
  while IFS='=' read -r org state; do
    [[ -n "$org" ]] || continue
    grove_provision_5_26_commitorgs_is_listed word="$state" list="$in" && found="${found:+$found }$org"
  done <<< "$states"
  printf '%s' "$found"
}

# .what = ` (via @all)` for an `@all` verdict, else empty
grove_provision_5_26_commitorgs_scope_of() { [[ "$1" == *@all ]] && printf ' (via @all)'; return 0; }

# .what = the meter's presence on THIS seat: absent|present|unreadable
grove_provision_5_26_commitorgs_meter_presence() {
  local path
  path="$(grove_provision_5_26_commitorgs_meter_path)"
  [[ -e "$path" ]] || { echo absent; return 0; }
  [[ -f "$path" && -r "$path" ]] || { echo unreadable; return 0; }
  echo present
}

# .what = the meter's bytes on THIS seat; returns 1 on a failed read
grove_provision_5_26_commitorgs_meter_bytes() {
  cat "$(grove_provision_5_26_commitorgs_meter_path)" 2>/dev/null
}

# .what = set each named org to `allowed` in the meter, and keep every other key
#         args: orgs=<space-joined> presence=absent|present bytes=<the file's bytes>
# .why  = the same shape `git.commit.uses --org <org> allow` writes, through a temp
#         file and a rename, so a reader sees the prior file or the new one, never half
# .note = the caller passes only unset orgs; a blocked or damaged meter never gets here
grove_provision_5_26_commitorgs_meter_allow() {
  local orgs='' presence='' bytes='' arg path dir temp updated org
  for arg in "$@"; do
    case "$arg" in
      orgs=*)     orgs="${arg#orgs=}" ;;
      presence=*) presence="${arg#presence=}" ;;
      bytes=*)    bytes="${arg#bytes=}" ;;
    esac
  done
  [[ "$presence" == "absent" ]] && bytes='{ "orgs": {} }'

  updated="$bytes"
  for org in $orgs; do
    updated="$(printf '%s' "$updated" | jq --arg org "$org" '.orgs = ((.orgs // {}) | .[$org] = "allowed")')" || return 1
  done

  path="$(grove_provision_5_26_commitorgs_meter_path)"
  dir="$(dirname "$path")"
  mkdir -p "$dir" || return 1
  temp="$path.tmp.$$"
  printf '%s\n' "$updated" > "$temp" || { rm -f "$temp"; return 1; }

  # a meter that changed since it was read (a human's block, a second apply) is never
  # written over: returns 3, and the caller says so
  if ! grove_provision_5_26_commitorgs_meter_unchanged presence="$presence" bytes="$bytes"; then
    rm -f "$temp"; return 3
  fi
  mv -f "$temp" "$path" || { rm -f "$temp"; return 1; }
}

# .what = is the meter as it was read?  args: presence=absent|present bytes=<the bytes read>
grove_provision_5_26_commitorgs_meter_unchanged() {
  local presence='' bytes='' arg path
  for arg in "$@"; do
    case "$arg" in presence=*) presence="${arg#presence=}" ;; bytes=*) bytes="${arg#bytes=}" ;; esac
  done
  path="$(grove_provision_5_26_commitorgs_meter_path)"
  [[ "$presence" == absent ]] && { [[ ! -e "$path" ]]; return; }
  [[ "$(cat "$path" 2>/dev/null)" == "$bytes" ]]
}

# .what = is jq on this seat? the classifier and the writer both parse with it
grove_provision_5_26_commitorgs_has_jq() { command -v jq >/dev/null 2>&1; }

# .what = the refusal where jq is absent; returns 0 where it refused, 1 where jq is here
# .why  = with no jq every meter reads as damaged, and the damaged fix clears the file,
#         which loses any block in it. so the absent tool is named, never a damaged meter
grove_provision_5_26_commitorgs_refuses_without_jq() {
  grove_provision_5_26_commitorgs_has_jq && return 1
  echo "   ✋ ConstraintError: jq is absent on $(whoami)@$(hostname), so the org commit meter cannot be read" >&2
  echo "      ├─ why: the meter's reader and writer both parse with jq; the meter itself is not judged" >&2
  echo "      └─ fix: rhx grove.provision --what 5.26.commitorgs --mode apply   # its provision installs jq" >&2
  return 0
}

# .what = the refusal where the meter path holds no readable file (a dir, a mode-000 file);
#         returns 0 where it refused.  args: the presence, the seat
# .why  = `cat` and `rm` both fail on such a path, so the damaged fix would not serve
grove_provision_5_26_commitorgs_refuses_unreadable() {
  local presence="$1" seat="$2" path
  [[ "$presence" == unreadable ]] || return 1
  path="$(grove_provision_5_26_commitorgs_meter_path)"
  echo "   ✋ ConstraintError: the org commit meter path on $seat holds no readable file, so the commit gate refuses every org" >&2
  echo "      ├─ file: $path" >&2
  echo "      ├─ read why: ls -ld $path" >&2
  echo "      └─ fix: once a human has seen what holds the path and moved it aside, re-run — rhx grove.provision --what 5.26.commitorgs --mode apply" >&2
  return 0
}

# .what = the fix block for a damaged meter, one step per line, each step named
# .why  = the clear loses any block in the file, so the read comes first, apart, and the
#         re-block is named after the apply
grove_provision_5_26_commitorgs_damaged_fix() {
  local path seat="$1"
  path="$(grove_provision_5_26_commitorgs_meter_path)"
  echo "      ├─ file: $path" >&2
  echo "      ├─ 1. read it first, on $seat — note any org it blocks: cat $path" >&2
  echo "      ├─ 2. then clear it, which loses every key in it: rm $path" >&2
  echo "      ├─ 3. then apply: rhx grove.provision --what 5.26.commitorgs --mode apply" >&2
  echo "      └─ 4. then set each block from step 1 again: rhx git.commit.uses --org <org> block" >&2
}

# .what = one `<org> <tree>` line per crew tree on this seat, with the `org:` its
#         `.agent/keyrack.yml` declares — the org the commit gate checks
# .note = `grove_org_of_manifest` is the one reader of that line's grammar
grove_provision_5_26_commitorgs_crew_orgs() {
  local manifest tree org
  for manifest in "$HOME"/git/*/_worktrees/*/.agent/keyrack.yml; do
    [[ -f "$manifest" ]] || continue
    tree="$(basename "$(dirname "$(dirname "$manifest")")")"
    org="$(grove_org_of_manifest "$manifest")"
    printf '%s %s\n' "${org:-<none>}" "$tree"
  done
}

# .what = the crew orgs on this seat outside a set, each once, in scan order
grove_provision_5_26_commitorgs_crew_orgs_outside() {
  local orgs="$1" crew_org tree found=''
  while IFS=' ' read -r crew_org tree; do
    [[ -n "$crew_org" && "$crew_org" != "<none>" ]] || continue
    grove_provision_5_26_commitorgs_is_listed word="$crew_org" list="$orgs" && continue
    grove_provision_5_26_commitorgs_is_listed word="$crew_org" list="$found" && continue
    found="${found:+$found }$crew_org"
  done < <(grove_provision_5_26_commitorgs_crew_orgs)
  printf '%s' "$found"
}

# .what = the crew trees on this seat whose manifest names one org, space-joined
grove_provision_5_26_commitorgs_crew_trees_of() {
  local want="$1" crew_org tree found=''
  while IFS=' ' read -r crew_org tree; do
    [[ "$crew_org" == "$want" ]] && found="${found:+$found }$tree"
  done < <(grove_provision_5_26_commitorgs_crew_orgs)
  printf '%s' "$found"
}

# .what = a list of orgs as words: `org 'ahbode'`, `orgs 'ahbode', 'ehmpathy'`
grove_provision_5_26_commitorgs_orgs_phrase_of() {
  local -a words
  read -r -a words <<< "$1"
  [[ "${#words[@]}" -eq 1 ]] && { printf "org '%s'" "${words[0]}"; return 0; }
  printf "orgs '%s'" "${words[0]}"
  printf ", '%s'" "${words[@]:1}"
}

# .what = `it` for one org, `each` for several — the pronoun a sentence about the list takes
grove_provision_5_26_commitorgs_each_of() {
  local -a words
  read -r -a words <<< "$1"
  [[ "${#words[@]}" -eq 1 ]] && { printf 'it'; return 0; }
  printf 'each'
}

# .what = is a word one of a space-joined list?  args: word=<w> list=<a b c>
# .why  = a bounded match, so `ahbode` is never found inside `ahbode-labs`
grove_provision_5_26_commitorgs_is_listed() {
  local word='' list='' arg
  for arg in "$@"; do
    case "$arg" in
      word=*) word="${arg#word=}" ;;
      list=*) list="${arg#list=}" ;;
    esac
  done
  [[ " $list " == *" $word "* ]]
}

# .what = the one decline line for a seat this bundle does not serve;
#         returns 0 where this run declines, 1 where it acts
grove_provision_5_26_commitorgs_declines() {
  if [[ "${GROVE_ENV_SERVER:-}" != cloud@* ]]; then
    echo "   🌙 declined — on a ${GROVE_ENV_SERVER:-local} grove the org commit meter is the human's own choice"
    echo "      ├─ why: no fact on the box answers which orgs the human's clones may commit for"
    echo "      └─ who: the human, at their own terminal; this output holds no command a clone could run"
    return 0
  fi
  if grove_env_seat_is_admin; then
    echo "   🌙 declined — '$(grove_env_seat)' is this grove's admin seat; crews commit from the crew seat"
    return 0
  fi
  return 1
}

grove_provision_5_26_commitorgs() {
  bundle.upgrade 5.26.commitorgs.provision.upsert
  bundle.upgrade 5.26.commitorgs.provision.verify
  bundle.upgrade 5.26.commitorgs.configure.upsert
  bundle.upgrade 5.26.commitorgs.configure.verify
}

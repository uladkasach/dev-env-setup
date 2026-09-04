#!/usr/bin/env bash
######################################################################
# .what = prove every alias file is present, current, parses, AND is
#         sourced, and that the duct/termwork/commit-subject seams hold
# .why each file is DIFFED against the checkout — a stale file exists, works, and reads as an older revision no file test can see
# .why it sources `ductwork.sh`, safely — the sink row needs to see what a sink DOES to bytes; the `source` sits inside a subshell `$( … )`
# guarantee: READ-ONLY — writes no file, needs no privilege
# exit: 0 = every claim held; 1 = a claim failed, and which file is named
######################################################################

# .what = print one ✋ failure (a headline plus optional detail lines)
_verify_fail() {
  printf '   ✋ %s\n' "$1" >&2
  shift
  local line
  for line in "$@"; do
    [[ -n "$line" ]] && printf '      %s\n' "$line" >&2
  done
  failed=$(( failed + 1 ))
}

# .what = fail unless $1 declares function $2 — 7 of 8 checks gate on a function's presence; one holder for the pattern
_verify_has_fn() {
  local file="$1" fn="$2" label="$3" why="$4"
  shift 4
  grep -q "^${fn}()" "$file" && return 0
  _verify_fail "$label declares no $fn" "⇒ $why" "$@"
  return 1
}

grove_provision_2_7_aliases_configure_verify() {
  local failed=0
  # 🛑 mirrors configure.upsert's copy list (m.9): a member in one and not the other is copied-never-judged or judged-never-copied
  local pairs=(
    "bash_aliases.sh:.bash_aliases"
    "ductwork.sh:.bash_aliases.ductwork.sh"
    "termwork.sh:.bash_aliases.termwork.sh"
    "brains.auth.sh:.bash_aliases.brains.auth.sh"
  )
  local bundle_dir="$GROVE_SRC/grove.provision/2.shell/2.7.aliases"
  local pair src_name dst_name src dst
  for pair in "${pairs[@]}"; do
    src_name="${pair%%:*}"; dst_name="${pair##*:}"
    src="$bundle_dir/$src_name"; dst="$HOME/$dst_name"
    if [[ ! -f "$dst" ]]; then
      local absent_why="the zshrc sources it; 'git tree'/'git grove' fail with 'no such file'"
      [[ "$dst_name" == ".bash_aliases" ]] || absent_why=".bash_aliases sources it by path; every login prints 'no such file'"
      _verify_fail "~/$dst_name is ABSENT" "⇒ $absent_why" \
        "fix: rhx grove.provision --what 2.7.aliases --mode apply"
      continue
    fi
    if [[ ! -f "$src" ]]; then
      _verify_fail "the checkout has no $src_name to compare against; cannot judge current"
    elif ! cmp -s "$src" "$dst"; then
      _verify_fail "~/$dst_name DIFFERS from the checkout" \
        '⇒ an older revision, invisible to a file test; reads as "my edit had no effect"' \
        "read why: diff $src $dst"
    fi
    # .why the parser is bash AND zsh, never `sh` — the shell that SOURCES this at login must accept it (.refs = gotcha.2-7-aliases.demo=duct-security-seams.md, m1)
    local parser rejected=""
    for parser in bash zsh; do
      command -v "$parser" >/dev/null 2>&1 || continue
      "$parser" -n "$dst" 2>/dev/null || rejected="${rejected:+$rejected and }$parser"
    done
    [[ -n "$rejected" ]] && _verify_fail "~/$dst_name does NOT parse as $rejected" \
      "⇒ surfaces at LOGIN, line number refers to THIS file; read why: ${rejected%% *} -n $dst"
  done
  # .why an unsourced member fails silently — the upsert's own `[[ -f ]]` guard swallows it (.refs = gotcha.2-7-aliases.demo=duct-security-seams.md, m2)
  local parent="$HOME/.bash_aliases"
  if [[ -f "$parent" ]]; then
    local unsourced=""
    for pair in "${pairs[@]}"; do
      dst_name="${pair##*:}"
      [[ "$dst_name" == .bash_aliases.*.sh ]] || continue
      grep -q "source ~/$dst_name" "$parent" || unsourced="${unsourced:+$unsourced }~/$dst_name"
    done
    if [[ -n "$unsourced" ]]; then
      _verify_fail "~/.bash_aliases carries no source line for: $unsourced" \
        "⇒ installed and inert — no error, no alert, namespace absent" \
        "fix: add [[ -f ~/<name> ]] && source ~/<name> to src/bash_aliases.sh"
    else
      echo "   • every copied member is named by a source line ✔"
    fi
  fi
  # .why ssh joins its args into one string, and several are read off the remote box; base64 closes the door structurally.
  #   the invariant is WHERE a seam lives, never HOW MANY (.refs = gotcha.2-7-aliases.demo=duct-security-seams.md, m3)
  local duct="$HOME/.bash_aliases.ductwork.sh"
  if [[ -f "$duct" ]] && _verify_has_fn "$duct" "__duct_ssh_tmux" "~/.bash_aliases.ductwork.sh" \
       "the seam that base64-encodes every tmux argument is GONE" \
       "read why: rule.require.solve-at-cause"; then
    local seams
    seams="$(grep -vE '^[[:space:]]*#' "$duct" | sed 's/"[^"]*"//g' \
      | awk '/^__duct_ssh_tmux\(\)/{inside=1} inside && /^}/{inside=0; next} !inside' \
      | grep -cE '(^|[^_[:alnum:]-])ssh([[:space:]]|$)' || true)"
    [[ "$seams" == "0" ]] || _verify_fail \
      "~/.bash_aliases.ductwork.sh holds $seams ssh seam(s) OUTSIDE __duct_ssh_tmux" \
      "⇒ ssh joins its args into one string; an interpolated value is CODE there" \
      "fix: route through __duct_ssh_tmux (--tty for an attach, --host otherwise)" \
      "read why: grep -nE '(^|[^_[:alnum:]-])ssh[[:space:]]' $duct"
  fi
  # .why a bare ssh line leaves the remote's stderr raw on fd 2 (an OSC 52 there rewrites the clipboard); match is
  #   COMMAND-POSITION, since this file says "ssh" in nine echo/fix strings (.refs = gotcha.2-7-aliases.demo=duct-security-seams.md, m4)
  if [[ -f "$duct" ]]; then
    local ssh_cmd_pat='(^[[:space:]]*((if|elif|while|until|then|else|do|!)[[:space:]]+)*|[;|&(][[:space:]]*|[$][(][[:space:]]*)ssh[[:space:]]'
    local fn_start fn_end raw_err=0 stray=0 ln lineno
    fn_start="$(grep -n '^__duct_ssh_tmux()' "$duct" | head -1 | cut -d: -f1)"
    fn_end=""; [[ -n "$fn_start" ]] && fn_end="$(awk -v s="$fn_start" 'NR>s && /^}/ {print NR; exit}' "$duct")"
    while IFS= read -r ln || [[ -n "$ln" ]]; do
      [[ -z "$ln" ]] && continue
      lineno="${ln%%:*}"
      # `-t` reads in the OPTION SPAN, never the whole line — tmux's own `-t` is a TARGET flag, misclassified whole-line
      local ssh_opts="${ln#*:}"; ssh_opts="${ssh_opts#*ssh }"; ssh_opts="${ssh_opts%%\"*}"
      [[ "$ssh_opts" =~ (^|[[:space:]])-tt?([[:space:]]|$) || "${ln#*:}" =~ 2\> ]] \
        || raw_err=$(( raw_err + 1 ))
      # and it must sit inside the ONE function that owns the verb
      [[ -n "$fn_start" && -n "$fn_end" && "$lineno" -ge "$fn_start" && "$lineno" -le "$fn_end" ]] \
        || stray=$(( stray + 1 ))
    done < <(grep -nE "$ssh_cmd_pat" "$duct" | grep -vE '^[0-9]+:[[:space:]]*#')
    if [[ "$raw_err" != "0" ]]; then
      _verify_fail "$raw_err ssh line(s) in the duct leave STDERR unstripped" \
        "⇒ a pipe carries stdout only; ssh's own fd 2 stays raw" \
        'fix: ssh … 2>"$scratch" then __duct_strip_escapes < "$scratch" >&2; read why: grep -nE '"'"'$ssh_cmd_pat'"'"' '"$duct"
    else
      echo "   • every ssh in the duct sinks both streams ✔"
    fi
    if [[ -z "$fn_start" || -z "$fn_end" ]]; then
      _verify_fail "the duct declares no __duct_ssh_tmux, so the one-seam claim is unreadable"
    elif [[ "$stray" != "0" ]]; then
      _verify_fail "$stray ssh line(s) sit OUTSIDE __duct_ssh_tmux" \
        "⇒ a second seam needs its own clamp, quotes, and streams" \
        "fix: call __duct_ssh_tmux (--tty / --host); read why: grep -nE '$ssh_cmd_pat' $duct"
    else
      echo "   • every ssh sits inside __duct_ssh_tmux ✔ (lines $fn_start-$fn_end)"
    fi
  fi
  # .why a duct name arrives from a grove, assumed compromised — joined raw it could escape to `~/.claude/settings`
  #   (.refs = gotcha.2-7-aliases.demo=duct-security-seams.md, m5)
  if [[ -f "$duct" ]]; then
    local joins
    joins="$(grep -vE '^[[:space:]]*#' "$duct" | grep -cE 'DUCTWORK_DIR\}?/[^"]*\$' || true)"
    if _verify_has_fn "$duct" "__duct_as_registry_file" "~/.bash_aliases.ductwork.sh" \
         "the ONE builder for the registry name grammar is GONE" \
         "read why: rule.require.security-paramount"; then
      [[ "$joins" == "1" ]] || _verify_fail \
        "~/.bash_aliases.ductwork.sh joins \$DUCTWORK_DIR to a variable on $joins lines, may do so on 1" \
        "⇒ a duct name arrives from a grove, assumed compromised" \
        "fix: build via __duct_as_registry_file ([A-Za-z0-9._-] segments only)" \
        "see them: grep -nE 'DUCTWORK_DIR\}?/[^\"]*\$' $duct"
    fi
    # .why __duct_strip_escapes must strip by CLASS, never an allow-list — a leak here rewrites the clipboard via
    #   OSC 52; this row RUNS the sink, and proves it alone (call sites unproven — inventory.security-checks.md)
    #   (.refs = gotcha.2-7-aliases.demo=duct-security-seams.md, m6)
    if _verify_has_fn "$duct" "__duct_strip_escapes" "~/.bash_aliases.ductwork.sh" \
         "the one sink for grove-chosen bytes is GONE" \
         "read why: rule.require.security-paramount"; then
      local sink_hex
      sink_hex="$(
        # shellcheck disable=SC1090
        source "$duct" >/dev/null 2>&1
        printf 'a\033]52;c;ZXZpbA==\007\302\233X\233Y\tb \342\224\234 \360\237\220\242 z\n' \
          | __duct_strip_escapes | od -An -tx1 | tr '\n' ' '
      )" || sink_hex=""
      sink_hex="$sink_hex "
      local sink_let="" sink_ate="" probe
      for probe in "1b:ESC" "07:BEL" "9b:C1-CSI"; do
        [[ "$sink_hex" == *" ${probe%%:*} "* ]] && sink_let="$sink_let ${probe#*:}"
      done
      for probe in "09:TAB" "e2 94 9c:U+251C(tree)" "f0 9f 90 a2:U+1F422(turtle)"; do
        [[ "$sink_hex" != *" ${probe%%:*} "* ]] && sink_ate="$sink_ate ${probe#*:}"
      done
      if [[ "$sink_hex" == " " ]]; then
        _verify_fail "__duct_strip_escapes answered an EMPTY stream for the probe" \
          "⇒ a stage is absent (iconv is glibc); fails CLOSED, correctly" \
          "fix: install glibc's iconv, then re-apply 2.7.aliases"
      elif [[ -n "$sink_let" ]]; then
        _verify_fail "__duct_strip_escapes LET THROUGH:$sink_let" \
          "⇒ a terminal OBEYS these; with set-clipboard on, OSC 52 writes the clipboard" \
          'fix: cut C0+DEL by byte, then iconv, then sed \xC2[\x80-\x9F], in order' \
          "read why: rule.require.security-paramount"
      elif [[ -n "$sink_ate" ]]; then
        _verify_fail "__duct_strip_escapes ATE:$sink_ate" \
          "⇒ corrupts the evidence a caller shows a human to audit a refusal" \
          'cause: a byte cut over \177-\237 also eats utf-8 continuation bytes; fix: cut \177 only, take C1 as CHARACTERS after iconv'
      fi
    fi
  fi
  # .why termwork shares ductwork's hazards: an unchecked pid steers a write, a heredoc cwd forges a jq key, a bad
  #   host parses as an option. join count is TWO — one owner, a record path and a lock path (.refs = gotcha.2-7-aliases.demo=duct-security-seams.md, m7)
  local term="$HOME/.bash_aliases.termwork.sh"
  if [[ -f "$term" ]]; then
    local term_joins term_seams
    term_joins="$(grep -vE '^[[:space:]]*#' "$term" | grep -cE 'TERMWORK_DIR/[^"]*\$' || true)"
    term_seams="$(grep -vE '^[[:space:]]*#' "$term" | sed 's/"[^"]*"//g' \
      | grep -cE '(^|[^_[:alnum:]-])ssh([[:space:]]|$)' || true)"
    if _verify_has_fn "$term" "__term_as_registry_file" "~/.bash_aliases.termwork.sh" \
         "the ONE builder for the pid grammar is GONE"; then
      [[ "$term_joins" == "2" ]] || _verify_fail \
        "~/.bash_aliases.termwork.sh joins \$TERMWORK_DIR on $term_joins lines, may do so on 2" \
        "⇒ a pid is decimal digits; any other value has no business in a redirect path" \
        "fix: build via __term_as_registry_file (record|lock); read why: grep -nE 'TERMWORK_DIR/\$' $term"
    fi
    if _verify_has_fn "$term" "__term_as_ssh_host" "~/.bash_aliases.termwork.sh" \
         "a host that starts with '-' parses as an OPTION (-oProxyCommand= runs code here)"; then
      [[ "$term_seams" == "1" ]] || _verify_fail \
        "~/.bash_aliases.termwork.sh holds $term_seams ssh seams, may hold 1" \
        "fix: clamp via __term_as_ssh_host, carry via __term_as_attach_command" \
        "read why: grep -nE '(^|[^_[:alnum:]-])ssh[[:space:]]' $term"
    fi
    _verify_has_fn "$term" "__term_as_attach_command" "~/.bash_aliases.termwork.sh" \
      "a grove-chosen session name interpolated raw; a quote in it breaks out"
    grep -qE '^[[:space:]]*cat > "\$TERMWORK_DIR' "$term" && _verify_fail \
      "~/.bash_aliases.termwork.sh writes its registry record by heredoc" \
      "⇒ a '\"' in a cwd forges a key; jq's last-duplicate-wins picks it" \
      "fix: compose with jq -n --arg, as __term_register does"
  fi
  # .why a subject is author-chosen bytes from git fetch; one that holds an OSC 52 writes the clipboard on
  #   `git tree list`. separators keep a hash capture (--format=%H) out of the match (m.12/q11)
  #   (.refs = gotcha.2-7-aliases.demo=duct-security-seams.md, m8)
  local aliases="$HOME/.bash_aliases"
  if [[ -f "$aliases" ]] && _verify_has_fn "$aliases" "_git_commit_line" "~/.bash_aliases" \
       "the ONE holder that strips a commit subject is gone" \
       "fix: rhx grove.provision --what 2.7.aliases --mode apply"; then
    local subject_pat='git[^|;&]*--(pretty|format)[= ][^|;&]*%s'
    local unsunk
    unsunk="$(grep -vE '^[[:space:]]*#' "$aliases" | grep -E "$subject_pat" \
      | grep -vc '__duct_strip_escapes' || true)"
    [[ "$unsunk" == "0" ]] || _verify_fail \
      "~/.bash_aliases captures $unsunk commit subject(s) with no sink" \
      "⇒ author-chosen bytes; an OSC 52 in one writes the clipboard" \
      "fix: capture via _git_commit_line, or pipe through __duct_strip_escapes" \
      "read why: grep -nE '$subject_pat' $aliases"
  fi
  [[ "$failed" -eq 0 ]] && echo "   • alias suite present, current, parses (${#pairs[@]} files) ✔" \
    && echo "   • the duct reaches tmux through one encoded seam ✔" \
    && echo "   • a registry path is built by one owner, and grove bytes are stripped ✔" \
    && echo "   • termwork holds one pid-path owner, one ssh seam, one jq record ✔" \
    && echo "   • every commit subject is captured through the strip sink ✔"
  [[ "$failed" -eq 0 ]] || return 1
}

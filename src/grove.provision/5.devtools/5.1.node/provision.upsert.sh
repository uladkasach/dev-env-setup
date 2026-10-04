#!/usr/bin/env bash
# .what = install fnm, the LTS node it manages, and pnpm
# .ref  = https://github.com/Schniz/fnm
# .why
#   - the BINARY, never fnm's shell installer — that one appends a PATH block
#     to ~/.bashrc, a second writer (rule.forbid.two-writers-on-one-artifact)
#   - fnm goes on PATH by hand here, for THIS shell; `configure` serves the rest
#   - every corepack call leans on `CI=1`, declared once at the driver
# .refs = gotcha.5-1-node.demo=fnm-pnpm-install-measurements — every (mN) below
#
# guarantee:
#   - the same verified bytes land at the same path with the same mode
#   - the fnm binary is NEVER placed unless its bytes matched their pinned digest

grove_provision_5_1_node_provision_upsert() {
  # the PINNED RELEASE ASSET, never the unversioned installer url — no hash is
  # expressible for that (rule.require.verify-binary-downloads, m2)
  local fnm_version="v1.39.0"
  local fnm_sha256="sha256:7807664f39d39fc518da1c35ba0181e4b3267603c4b1dedeb4b5fc6ae440a224"
  local fnm_url="https://github.com/Schniz/fnm/releases/download/${fnm_version}/fnm-linux.zip"
  local fnm_home="$HOME/.local/share/fnm"

  # a PRIVATE temp dir — a fixed /tmp path for a future executable is claimable
  local tmp_dir
  tmp_dir="$(web_tempdir fnm)" || return 1

  # UNCONDITIONAL, no `command -v fnm` short-circuit — a re-run self-heals
  if ! web_fetch "$fnm_url" --into "$tmp_dir/fnm.zip"; then
    echo "   ✋ could not download fnm ${fnm_version}" >&2
    echo "      ⇒ with no node, every rhachet/npm-driven tool on this box is" >&2
    echo "        unreachable — web_fetch named the wire fault above" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # verify BEFORE the unpack — the file it yields is made executable soon after
  if ! web_verify_sha256 --file "$tmp_dir/fnm.zip" --sha256 "$fnm_sha256"; then
    echo "      ⇒ fnm is NOT installed, and the archive is discarded unopened." >&2
    echo "        a box with no node beats a box that unpacked bytes nobody" >&2
    echo "        vouched for" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  echo "   • fnm ${fnm_version} verified against its pinned sha256 ✔"

  # -j flattens the archive's dirs, so the binary lands at a known path; -o
  # overwrites, which keeps a re-run idempotent
  if ! unzip -oqj "$tmp_dir/fnm.zip" -d "$tmp_dir/out"; then
    echo "   ✋ could not unpack the fnm archive" >&2
    echo "      ⇒ it matched its pinned digest, so the bytes are correct — this" >&2
    echo "        is unzip itself. confirm it is present: command -v unzip" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if [[ ! -f "$tmp_dir/out/fnm" ]]; then
    echo "   ✋ the fnm archive carried no 'fnm' binary" >&2
    echo "      ⇒ upstream changed the archive's layout — name the new path here," >&2
    echo "        never loosen the check. read what it holds:" >&2
    echo "      unzip -l $tmp_dir/fnm.zip" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  mkdir -p "$fnm_home" || { rm -rf "$tmp_dir"; return 1; }
  if ! install -m 0755 "$tmp_dir/out/fnm" "$fnm_home/fnm"; then
    echo "   ✋ could not place fnm at $fnm_home/fnm" >&2
    echo "      ⇒ verified download — check the dir is writable: ls -ld $fnm_home" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  rm -rf "$tmp_dir"

  export PATH="$fnm_home:$HOME/.fnm:$PATH"
  if ! command -v fnm >/dev/null 2>&1; then
    echo "   ✋ fnm is not on PATH after its install" >&2
    echo "      ⇒ placed at $fnm_home/fnm but not found there, so node cannot" >&2
    echo "        be installed. read why: ls -l $fnm_home/fnm" >&2
    return 1
  fi
  eval "$(fnm env --shell bash)"

  fnm install --lts || return 1

  # the default is the `lts-latest` ALIAS, never a `fnm list` scrape (m3)
  if ! fnm default lts-latest; then
    echo "   ✋ fnm has no 'lts-latest' alias after 'fnm install --lts'" >&2
    echo "      ⇒ with no default, node is on PATH in no shell. read what it" >&2
    echo "        holds: fnm list" >&2
    return 1
  fi
  fnm use lts-latest
  echo "   • node $(fnm current 2>/dev/null) set as the fnm default"

  # the BASELINE versions land BESIDE the lts — an absent pin opens a prompt a
  # duct cannot answer. declared in `_.sh`, which the verify reads too (m4)
  local want roster
  roster="$(fnm list 2>/dev/null || true)"   # read ONCE; only this loop changes the set

  while read -r want; do
    [[ -n "$want" ]] || continue

    # `fnm install` of a present version exits NON-ZERO, so it is asked first
    if grove_node_version_present "$want" "$roster"; then
      echo "   • node v$want already present — skipped"
      continue
    fi

    if fnm install "$want"; then
      echo "   • node v$want installed"
      roster="$roster"$'\n'"v$want"
    else
      echo "   ✋ fnm could not install node v$want" >&2
      echo "      ⇒ a repo that pins it opens fnm's interactive install prompt on" >&2
      echo "        every 'cd', which a duct cannot answer" >&2
      echo "      ⇒ check the version is real: fnm list-remote | grep v$want" >&2
      return 1
    fi
    # process substitution, never a pipe — a piped loop is a subshell
  done < <(grove_node_versions_wanted)

  # pnpm's global bin dir goes on PATH BEFORE a global install, else corepack
  # refuses. BOTH spellings; the PRUNE below, not PATH order, makes that safe
  export PNPM_HOME="$HOME/.local/share/pnpm"
  mkdir -p "$PNPM_HOME/bin"
  export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"

  # pnpm goes on EVERY node this box holds, at the DECLARED version — never
  # `@latest`, and an undeclared pin is a HARD stop (m5). a per-version
  # failure is not fatal; the verify owns that verdict
  local pnpm_want
  pnpm_want="$(grove_pnpm_version_wanted)"

  # empty means the manifest is ABSENT (a partial checkout, the head of a
  # cascade) or declares none (the repo at fault) — told apart below (m6)
  local pnpm_manifest; pnpm_manifest="$(dirname "$GROVE_SRC")/package.json"
  if [[ ! -f "$pnpm_manifest" ]]; then
    echo "   ✋ no package.json beside this checkout's src/ ($pnpm_manifest)" >&2
    echo "      ⇒ checkout is PARTIAL — package.json and .nvmrc sit beside src/," >&2
    echo "        and a push of src/ alone sends neither; this is the HEAD of a" >&2
    echo "        cascade (no pnpm ⇒ no rhx ⇒ no keyrack ⇒ no gh token). fix it" >&2
    echo "        here, not downstream" >&2
    echo "      fix: send the manifests, then re-run —" >&2
    echo "        rhx git.grove.push <grove> --from package.json --into 'git/more/dev-env-setup' --mode apply" >&2
    echo "        rhx git.grove.push <grove> --from .nvmrc --into 'git/more/dev-env-setup' --mode apply" >&2
    return 1
  fi
  if [[ -z "$pnpm_want" ]]; then
    echo "   ✋ $pnpm_manifest declares no pnpm version" >&2
    echo "      ⇒ expected \"packageManager\": \"pnpm@<x>\" (declapract stamps it" >&2
    echo "        into every repo) — a defect in the REPO, not this box; absent" >&2
    echo "        it, this phase would fall to pnpm@latest, and grow two pnpms" >&2
    return 1
  fi
  echo "   • pnpm pinned to $pnpm_want (declared by packageManager)"

  local ver pnpm_absent=()
  while read -r ver; do
    [[ -n "$ver" ]] || continue
    fnm use "$ver" --silent-if-unchanged >/dev/null 2>&1 || continue

    # `web_corepack`/`web_npm`, BOUNDED — a stall multiplies per node. `corepack
    # enable` stays bare, since it reaches no registry (m7)
    corepack enable || true
    if ! web_corepack install -g "pnpm@$pnpm_want"; then
      echo "   • corepack declined pnpm for node v$ver — fall back to npm"
      web_npm install -g "pnpm@$pnpm_want" || pnpm_absent+=("v$ver")
    fi
  done < <(grove_node_versions_wanted; echo "lts-latest")

  fnm use lts-latest --silent-if-unchanged >/dev/null 2>&1 || true   # back to the box's default

  # CACHE every pnpm this box may be ASKED for, so corepack's shim never asks to
  # fetch one — on a duct that question eats the run (m11)
  # ⚠️ `-g --cache-only` is no redundancy, and 🛑 `--cache-only` alone does NOT
  #    protect the default — `COREPACK_DEFAULT_TO_LATEST=0` at the driver does.
  #    one cache per $HOME, so the loop is NOT per node (m12)
  local cached=() cache_fresh=() cache_absent=()
  while read -r ver; do
    [[ -n "$ver" ]] || continue
    if grove_pnpm_cached "$ver"; then cached+=("$ver"); continue; fi
    # the cache is re-ASKED: corepack can exit 0 on a fetch it never lands (m12)
    if web_corepack install -g --cache-only "pnpm@$ver" >/dev/null 2>&1 \
       && grove_pnpm_cached "$ver"; then
      cache_fresh+=("$ver")
    else
      cache_absent+=("$ver")
    fi
  done < <(grove_pnpm_versions_wanted)

  echo "   • pnpm cached: ${#cached[@]} held, ${#cache_fresh[@]} fetched${cache_fresh:+ (${cache_fresh[*]})}"
  if [[ "${#cache_absent[@]}" -gt 0 ]]; then
    echo "   ✋ pnpm could not be cached: ${cache_absent[*]}" >&2
    echo "      ⇒ a repo that pins one of those opens corepack's download" >&2
    echo "        prompt on 'pnpm install', and a duct is tmux — the question" >&2
    echo "        holds the pane and eats every command sent after it" >&2
    echo "      ⇒ check the version is real: npm view pnpm@<x> version" >&2
    return 1
  fi

  if [[ "${#pnpm_absent[@]}" -gt 0 ]]; then
    echo "   🌙 pnpm could not be installed for: ${pnpm_absent[*]}"
    echo "      a 'cd' into a repo that pins one of those gets node without pnpm"
    echo "      read why: fnm use <version> && corepack install -g pnpm@$pnpm_want"
  fi

  # report the pnpm that ANSWERS, never the one just installed — corepack's shim
  # dispatches on `packageManager`, a property of the DIRECTORY. it reports and
  # never deletes, since a stray pnpm may be the human's (m8, m9)
  local pnpm_live
  pnpm_live="$(pnpm --version 2>/dev/null)"
  if [[ "$pnpm_live" == "$pnpm_want" ]]; then
    echo "   • pnpm $pnpm_live ✔"
  else
    echo "   🌙 pnpm answers $pnpm_live here, and this phase installed $pnpm_want"
    echo "      corepack's shim dispatches on the nearest 'packageManager' field —"
    echo "      one binary, two versions, not two binaries"
    echo "      read why: cd ~ && pnpm --version   # away from any declaration"
  fi

  # prune the SHADOWED shims — pnpm's own fossils from its 10.x→11.x dir move,
  # in pnpm's OWN dirs only; the live dir is pnpm's ANSWER, never a constant (m10)
  local shadow shadows=() pruned=() live_dir fossil_dir
  live_dir="$(grove_pnpm_shim_dir_live)"
  while read -r shadow; do
    [[ -n "$shadow" ]] || continue
    shadows+=("$shadow")
  done < <(grove_pnpm_shim_shadows)

  if [[ "${#shadows[@]}" -eq 0 ]]; then
    echo "   • no shadowed pnpm shims ✔ (live dir: ${live_dir:-<pnpm did not answer>})"
  else
    if [[ "$live_dir" == "$PNPM_HOME/bin" ]]; then fossil_dir="$PNPM_HOME"; else fossil_dir="$PNPM_HOME/bin"; fi
    for shadow in "${shadows[@]}"; do
      rm -f "$fossil_dir/$shadow" && pruned+=("$shadow")
    done
    echo "   • pruned ${#pruned[@]} shadowed shim(s) from $fossil_dir: ${pruned[*]}"
    echo "     (each also lives in $live_dir, which is the dir pnpm writes)"
  fi
}

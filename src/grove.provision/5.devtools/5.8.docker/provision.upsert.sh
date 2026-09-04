#!/usr/bin/env bash
# .what = install docker engine + compose from docker's own apt repo
# .ref  = https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
# .why
#   - ubuntu's `docker.io` lags releases and ships no compose v2 plugin; the
#     upstream repo is what docker's own docs install and test
#   - no `docker run hello-world` here — it pulls an image (non-hermetic),
#     fails an air-gapped box, and leaves a stopped container forever;
#     `provision.verify` asks `docker info` instead, which needs no pull
#     (rule.require.upgrade-entries-verify-themselves)
#
# guarantee:
#   - apt converges, and `groupadd -f` / `usermod -aG` both re-run safely
#   - it applies on EVERY server (see this bundle's `_.sh`)

grove_provision_5_8_docker_provision_upsert() {
  pkg_assert_apt || return 1

  # is the BOX already provisioned? read this BEFORE the sudo assert, since
  # every seat is asked to run this box-wide phase and only ground can
  # (.refs = gotcha.5-8-docker.demo=roster-exec-time)
  local boxready="true"
  command -v docker >/dev/null 2>&1                || boxready="false"
  command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1 || boxready="false"
  command -v newuidmap >/dev/null 2>&1             || boxready="false"
  docker compose version >/dev/null 2>&1           || boxready="false"
  systemctl is-active --quiet docker 2>/dev/null   || boxready="false"

  if [[ "$boxready" == "true" ]]; then
    echo "   • the engine, the compose plugin, uidmap, and the daemon are all"
    echo "     present, so this phase has no box change left to make ✔"
    return 0
  fi

  # every write below lands outside every $HOME (apt, keyrings, a unit, a
  # group, a linger flag) — `bundle.root.owns`, never a hand-rolled decline,
  # so ground runs this bundle rather than a human typing a printed command
  # (rule.require.one-command-provision, rule.require.bundle-as-sole-declaration)
  bundle.root.owns "the docker engine" \
    "docker, compose, uidmap, or the daemon is absent" || return 0

  pkg_install ca-certificates || return 1
  pkg_install curl || return 1

  # 1. docker's release key
  sudo install -m 0755 -d /etc/apt/keyrings || return 1

  # the fetch does NOT run as root — only the write does, since parsing
  # untrusted bytes as root is a needless risk; it is not piped into `sudo
  # dd` either, since a pipe leaves no artifact to verify before it lands as
  # apt's trust anchor (rule.require.verify-binary-downloads). the pin is
  # TIER 2, the highest evidence available for this vendor
  # (.refs = gotcha.5-8-docker.demo=roster-exec-time)
  local keydst="/etc/apt/keyrings/docker.asc"
  local keytmp
  keytmp="$(web_tempdir dockerkey)" || return 1

  if ! web_fetch https://download.docker.com/linux/ubuntu/gpg \
    --into "$keytmp/docker.asc"; then
    echo "   ✋ could not fetch docker's apt release key" >&2
    echo "      ⇒ apt refuses an unsigned repo, so the install cannot proceed" >&2
    echo "      ⇒ web_fetch names the wire fault above; a stall and a 404 differ" >&2
    rm -rf "$keytmp"
    return 1
  fi

  if ! web_verify_gpg_fingerprints --file "$keytmp/docker.asc" \
    --fpr 9DC858229FC7DD38854AE2D88D81803C0EBFCD88; then
    echo "      ⇒ docker is NOT installed, and docker's source is NOT declared." >&2
    echo "        that is the safe outcome — a box with no docker beats a box" >&2
    echo "        whose apt trusts an anchor nobody vouched for" >&2
    rm -rf "$keytmp"
    return 1
  fi

  if ! sudo dd if="$keytmp/docker.asc" of="$keydst" status=none; then
    echo "   ✋ could not install docker's apt release key to $keydst" >&2
    rm -rf "$keytmp"
    return 1
  fi
  rm -rf "$keytmp"
  echo "   • docker's release key verified against its pinned fingerprint ✔"

  # apt fetches as `_apt`, not root, so a root-only key reads as unsigned
  sudo chmod a+r "$keydst" || return 1

  # 2. the repo — declared whole, so a re-run converges rather than appends;
  # `signed-by=$keydst` names one variable, so the two paths cannot drift
  local arch codename
  arch="$(dpkg --print-architecture)"
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

  if ! echo "deb [arch=$arch signed-by=${keydst}] https://download.docker.com/linux/ubuntu $codename stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null; then
    echo "   ✋ could not declare docker's apt source" >&2
    return 1
  fi
  pkg_refresh || return 1

  # 3. the packages, through `pkg_install` — a bare `apt-get install` reopens
  # the interactive-prompt hole the package boundary closes
  # (rule.require.every-function-has-a-driver). `uidmap` serves the SEATS
  # THAT HOLD NO SUDO, whose rootless daemon needs its setuid tools
  # (.refs = gotcha.5-8-docker.demo=roster-exec-time)
  if ! pkg_install \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin uidmap; then
    echo "   ✋ the docker packages would not install (see the error above)" >&2
    return 1
  fi

  sudo systemctl enable --now docker || return 1

  # 4. the group — so a human drives docker without sudo. `-f`, never bare
  # `groupadd`, since the package usually creates it already
  # (rule.require.idempotent-install-procedures)
  sudo groupadd -f docker || return 1
  sudo usermod -aG docker "$USER" || return 1

  # 5. let seats with NO sudo keep a daemon of their own alive. they are NOT
  # added to the docker group instead — that grant is root-equivalent
  # (.refs = gotcha.5-8-docker.demo=roster-exec-time); LINGER is the part
  # only a sudo seat can set, keeping a rootless daemon up past logout. the
  # derivation reads both halves from the box, so no seat is hardcoded
  local dockergroup seat
  dockergroup=",$(getent group docker | awk -F: '{print $4}'),"
  while IFS=: read -r seat _ uid _ _ _ shell; do
    [[ "$uid" -ge 1000 && "$uid" -lt 65534 ]] || continue
    [[ "$shell" == *nologin* || "$shell" == *false ]] && continue
    [[ "$dockergroup" == *",$seat,"* ]] && continue

    if sudo loginctl enable-linger "$seat" 2>/dev/null; then
      echo "   • $seat lingers, so its own rootless daemon outlives a logout ✔"
    else
      # all three lines go to stdout, none to stderr — this is a LOOP, so a
      # stderr line could land under a different seat's message
      echo "   🌙 could not set linger for $seat"
      echo "      ⇒ its rootless daemon will still run while a session is open,"
      echo "        and stop at that seat's last logout"
    fi
  done < <(getent passwd)

  # no `newgrp docker` note below — that is a hand step a duct pane cannot
  # take; the verify phases RE-ASK under `sg docker` instead, which needs none
  echo "   • docker installed ✔"
  echo "     .note = the group takes effect on a NEW login, so this run's own"
  echo "       shell is refused by the socket. the verify phases re-ask under"
  echo "       'sg docker', so no step is owed"
}

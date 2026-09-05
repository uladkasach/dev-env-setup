#!/usr/bin/env bash
# .what = docker engine, the compose plugin, and the group that lets a user
#   drive it without sudo
# .why a `docker` group member can bind-mount `/`, so ground's grant adds no
#   capability while the camper's route is ROOTLESS, its own dockerd in its
#   own namespace; provision owns the BOX and needs sudo, configure owns the
#   SEAT and needs none (.refs = gotcha.5-8-docker.demo=roster-exec-time)
#
# usage:
#   rhx grove.provision --what 5.8.docker --mode apply

# .what = is THIS seat on the docker group's roster?
# .why shared here since three phases ask it; `id -nG` alone is stale at exec
#   time, so `getent group` reads the roster fresh and `grep -x` never `-qx`
#   avoids a SIGPIPE into `tr` (.refs = gotcha.5-8-docker.demo=roster-exec-time)
_docker_roster_names_me() {
  id -nG 2>/dev/null | tr ' ' '\n' | grep -x docker >/dev/null && return 0
  getent group docker 2>/dev/null | cut -d: -f4 | tr ',' '\n' | grep -x "$(id -un)" >/dev/null
}

grove_provision_5_8_docker() {
  bundle.upgrade 5.8.docker.provision.upsert
  bundle.upgrade 5.8.docker.provision.verify
  bundle.upgrade 5.8.docker.configure.upsert
  bundle.upgrade 5.8.docker.configure.verify
}

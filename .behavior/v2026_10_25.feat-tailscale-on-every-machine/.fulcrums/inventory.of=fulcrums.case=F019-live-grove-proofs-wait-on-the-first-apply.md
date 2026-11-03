# F019 — the live-grove proofs wait on the commander's first apply

- **fork:** prove these on a real box now · or record them as open proofs that chain from the
  laptop's first apply:
  - the hetzner probe's real read of `/etc/grove/platform`
  - the off-ec2 github token read from `os.secure`
  - `git.grove.auth.github.set`'s header line on a live grove
- **taken, why:** record them as open proofs. a live run is owed and is not reachable from here
  - the hetzner grove sits behind the tailnet, and this pr's own `5.23.tailscale` is what gives
    the laptop a route to it. that route is the commander's act `tailscale-174-first-apply`
  - no ec2 or house grove holds an `os.secure` github entry today, so there is no off-ec2 read
    to run against
  - the logic of each is proven hermetically:
    - `prove.hetzner-probe-reads-its-declaration`: the probe, the ladder, and the halt
    - `prove.gh-names-no-aws-params-off-ec2`: the vault choice in every fix-text
  - each play's transcript is snapped
- **the run that closes it**, once the first apply lands, on the hetzner grove:
  - `rhx git.grove.send <hetzner grove> --play prove.hetzner-probe-reads-its-declaration`
  - `rhx grove.provision --what 5.4.gh --mode plan`
- **rework:** clean. a live run adds evidence and changes no code unless it finds a defect
- **risk:** low|safe. no prod write, and the vault rule (`rule.forbid.aws-params-off-ec2`) is
  clamped hermetically
- **confidence 80%, why not higher:** the real `/etc/grove/platform` on the hetzner grove is
  written by infra's bootstrap, and its first line is unread from here

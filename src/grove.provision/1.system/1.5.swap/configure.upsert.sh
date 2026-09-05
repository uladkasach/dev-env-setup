#!/usr/bin/env bash
######################################################################
# .what = size, create, label, arm, and record a swapfile for THIS box
#
# ⚠️ the size is PINNED, never derived
#   - a derived `ram*2, capped at free_disk/2` reads well and gives a DIFFERENT file per box
#   - 📜 on a 36G-RAM laptop it reproduces 72G only when `/` holds 144G+ free
#   - below that it hands you 40G, or 20G, and reports ✔ either way
#   - ⇒ a human who set 72G on purpose has no surface that would tell them it changed
#   - so the size is `GROVE_SWAP_SIZE_GIB`, and free disk is a REFUSAL rather than a cap
#   - a shrink nobody is told of is a hidden failure in a success's shape (`rule.forbid.failhide`)
#
# .why a box that cannot fit the pin ✋s rather than shrinks
#   - a 32G-disk grove genuinely cannot hold 72G, which is worth SAYING out loud
#   - the override is one env var, named in the error
#   - ⇒ a smaller box is a deliberate choice on the record
#
# .why fstab is written only AFTER `swapon` succeeds
#   - an fstab line that names an invalid swap area can stall a BOOT
#   - a box that will not boot is the most expensive failure this repo can cause
#   - ⇒ the order is create → mkswap → swapon → record
#
# .why a partial swapfile is cleared first
#   - a prior interrupted run leaves a 0-byte `/swapfile`
#   - `fallocate` will not overwrite it and `mkswap` will not label it
#   - ⇒ the clear is what makes this idempotent rather than merely re-runnable
#
# guarantee:
#   - idempotent: it returns early when swap is already active, and otherwise converges
#   - it DEFERS on a box that registers its own hibernation swap target
#   - it names the repair when it finds damage a past run already did
######################################################################

grove_provision_1_5_swap_configure_upsert() {
  local swapfile="/swapfile"

  ####################################################################
  # DEFER to a box that already arranges its own swap for hibernation
  #
  # .what a nonzero /sys/power/resume_offset means
  #   - the image registered a specific swapfile at a specific block offset
  #   - that is the target the kernel writes its ram image to
  #   - ⇒ the arrangement is box lifecycle, the image's concern (rule.require.bounded-contexts)
  #
  # .note = this is a BOUNDARY, not an applicability decline
  #   - it asks "has somebody else claimed this resource?", never "am I local or cloud?"
  #   - ⇒ it is not the early-return shape rule.require.identical-bundle-composition governs
  #
  # 📜 the damage this guard prevents, on an aws hibernatable grove
  #   - ec2-hibinit-agent creates /swap-hibinit at boot, registers its offset, then swaps it off
  #   - this step then added a SECOND, larger swapfile at a different offset
  #   - ⇒ the only ACTIVE swap no longer matched the registered resume target
  #   - `systemctl hibernate` refused outright:
  #
  #       Call to Hibernate failed: Not enough suitable swap space for hibernation
  #       available on compatible block devices and file systems
  #
  #   - the box still ran fine, so the damage was invisible until somebody hibernated
  ####################################################################
  local resume_offset
  resume_offset="$(cat /sys/power/resume_offset 2>/dev/null || echo 0)"
  if [[ -n "$resume_offset" && "$resume_offset" != "0" ]]; then
    echo "   • this machine registers a hibernation swap target; deferred"
    echo "      ├─ resume: $(cat /sys/power/resume 2>/dev/null) offset $resume_offset"
    echo "      └─ why:    a second swapfile would break hibernate; the image owns this"

    ##################################################################
    # 🛑 a DEFER protects the next box and cannot heal this one
    #   - every grove built before this guard carries the swapfile this step added
    #   - that box's hibernate stays broken until somebody swaps it back
    #   - the symptom surfaces far from the cause, possibly weeks later
    #   - ⇒ the fix is named HERE, where both halves of the conflict are visible
    #   - (rule.require.errors-name-the-fix)
    #
    # 🛑 the check reads FSTAB, not the live swap
    #   - a live `swapoff` looks like a fix and is not
    #   - the fstab line this step wrote re-arms the same conflict on the next boot
    #   - 📜 right after a resume this box showed NO active swap at all
    #   - ⇒ an active-swap check would go quiet on a box that is still poisoned
    #
    # .the check is deliberately narrow
    #   - it asks only whether THIS step's swapfile is in fstab on a box with a resume target
    #   - that is the exact damage this step does, and it is decidable
    #   - "does the active swap match the registered offset?" is not decidable
    #   - a resume target names a block device plus an offset, never a path
    ##################################################################
    if grep -q "^$swapfile " /etc/fstab 2>/dev/null; then
      echo "" >&2
      echo "   ✋ heads up — this box already carries the conflict this guard prevents" >&2
      echo "      what: /etc/fstab names $swapfile, so it is swapped on at every" >&2
      echo "            boot — yet the kernel resumes from a different target, so" >&2
      echo "            hibernate refuses. a live swapoff will NOT hold; the line" >&2
      echo "            in fstab brings it back on the next boot" >&2
      echo "      fix:  drop the line, then hand the swap back to the image —" >&2
      echo "        sudo sed -i '\\|^$swapfile |d' /etc/fstab" >&2
      echo "        sudo swapoff $swapfile" >&2
      echo "        sudo swapon <the image swapfile, e.g. /swap-hibinit>" >&2
      echo "      then prove it — rhx git.grove.send <grove> --play verify.swap.hibernate-safe" >&2
    fi
    return 0
  fi

  # skip if the swapfile is already active
  #
  # .why no `-q`
  #   - under `pipefail` it exits on match, SIGPIPEs swapon, and the pipeline reports 141
  #   - ⇒ an ACTIVE swapfile would read as absent and this would re-create it
  #   - (gotcha.pipefail-grep-q)
  if swapon --show | grep "$swapfile" >/dev/null; then
    echo "   • swapfile already active"
    return 0
  fi

  ####################################################################
  # the size — DECLARED, and checked against this box (see the header)
  #
  # .`GROVE_SWAP_SIZE_GIB` is the ONLY way this run produces another size
  #   - ⇒ a box that cannot fit the pin is told so by name
  ####################################################################
  local size_gib="${GROVE_SWAP_SIZE_GIB:-72}"

  if ! [[ "$size_gib" =~ ^[0-9]+$ ]] || (( size_gib < 2 )); then
    echo "   ✋ GROVE_SWAP_SIZE_GIB is '$size_gib', which is not a size in GiB" >&2
    echo "      ⇒ it must be a whole number of gibibytes, 2 or more" >&2
    echo "      fix: GROVE_SWAP_SIZE_GIB=32 rhx grove.provision --what 1.5.swap --mode apply" >&2
    return 1
  fi

  local free_gib
  free_gib=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')

  ####################################################################
  # ⚠️ half the free disk is the cap, and a pin above it is a ✋, never a shrink
  #   - a swapfile that fills the root volume takes the box down, so the cap is real
  #   - this names the shortfall and the override, then stops
  #   - ⇒ the one box that most needs a human's attention no longer gets the least
  ####################################################################
  if (( size_gib > free_gib / 2 )); then
    echo "   ✋ a ${size_gib}G swapfile does not fit: / has ${free_gib}G free" >&2
    echo "      ⇒ the ceiling is HALF the free disk ($(( free_gib / 2 ))G here), so a" >&2
    echo "        swapfile can never fill the root volume and take the box down" >&2
    echo "      ⇒ this used to shrink to fit and report ✔ — so a box quietly got a" >&2
    echo "        different swapfile than the one declared. it now stops instead" >&2
    echo "      fix, whichever is true for this box:" >&2
    echo "        · it should be smaller — name it:" >&2
    echo "            GROVE_SWAP_SIZE_GIB=$(( free_gib / 2 )) rhx grove.provision --what 1.5.swap --mode apply" >&2
    echo "        · it should be ${size_gib}G — grow the root volume or clear space, then re-drive" >&2
    return 1
  fi

  local size="${size_gib}G"

  # ⚠️ every write below is root's and lands OUTSIDE every `$HOME`
  #   - /swapfile and /etc/fstab are box-wide facts by definition
  #   - ⇒ a seat with no root declines here rather than fails
  #   - ground sets it with this same bundle, and `configure.verify` reads it either way
  bundle.root.owns "the swapfile" \
    "$swapfile is not active; / has ${free_gib}G free" || return 0

  ####################################################################
  # clear a partial swapfile left by a prior failed run
  #   - its 0-byte remains block a retry
  #   - and an fstab line that names an invalid swap area can stall a boot
  #   - ⇒ this clear is what makes the step idempotent, not merely re-runnable
  ####################################################################
  if [[ -e "$swapfile" ]] && ! sudo swaplabel "$swapfile" &>/dev/null; then
    echo "   • clear a partial swapfile left by a prior run"
    sudo rm -f "$swapfile"
    sudo sed -i "\|^$swapfile |d" /etc/fstab
  fi

  # each call must fail loud — a swapon that never happened must NOT reach fstab
  if [[ ! -e "$swapfile" ]]; then
    echo "   • create ${size} swapfile..."
    if ! sudo fallocate -l "$size" "$swapfile"; then
      echo "   ✋ fallocate could not reserve $size at $swapfile" >&2
      echo "      ⇒ the partial file is removed, so a retry starts clean" >&2
      sudo rm -f "$swapfile"
      return 1
    fi
    if ! sudo chmod 600 "$swapfile"; then
      echo "   ✋ chmod 600 failed on $swapfile" >&2
      echo "      ⇒ swapon REFUSES a world-readable swapfile, so this must hold" >&2
      return 1
    fi
    if ! sudo mkswap "$swapfile"; then
      echo "   ✋ mkswap could not label $swapfile" >&2
      echo "      ⇒ the file is removed, so a retry starts clean" >&2
      sudo rm -f "$swapfile"
      return 1
    fi
  fi

  if ! sudo swapon "$swapfile"; then
    echo "   ✋ swapon refused $swapfile — so it is NOT added to fstab" >&2
    echo "      ⇒ that omission is deliberate: an fstab entry for a bad swap area" >&2
    echo "        can stall a BOOT, which is why the order is swapon-then-fstab" >&2
    echo "      read why: the swapon error above names the cause" >&2
    return 1
  fi

  # fstab only AFTER swapon proved the file works, so a boot can never trip on it
  if ! grep -q "^$swapfile " /etc/fstab; then
    echo "$swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
    echo "   • swapfile recorded in /etc/fstab, so it re-arms at boot"
  fi

  # print the size AND the headroom, so a reader can judge the pin rather than trust it
  echo "   • swapfile declared: $size (the pin; / had ${free_gib}G free)"
}

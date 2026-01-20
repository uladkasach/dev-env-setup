#!/usr/bin/env bash
######################################################################
# .what = cleanup test artifacts from /tmp
#
# .why  = removes ephemeral test dirs that accumulate over long sessions
#         targets ONLY explicit prefixes we've identified from our tests
#
# usage:
#   ./cleanup-tmp.sh    # run these sudo rm -rf commands
######################################################################
set -euo pipefail

# bind tests
sudo rm -rf /tmp/bind-behavior-bound-test-*
sudo rm -rf /tmp/bind-behavior-notfound-test-*
sudo rm -rf /tmp/bind-behavior-test-*

# cleanup tests
sudo rm -rf /tmp/cleanup-idempotent-*
sudo rm -rf /tmp/cleanup-localgrain-behaver-*
sudo rm -rf /tmp/cleanup-localgrain-no-behaver-*
sudo rm -rf /tmp/cleanup-localgrain-no-file-*
sudo rm -rf /tmp/cleanup-localgrain-other-*
sudo rm -rf /tmp/cleanup-no-settings-*
sudo rm -rf /tmp/cleanup-no-stale-*
sudo rm -rf /tmp/cleanup-stale-other-*
sudo rm -rf /tmp/cleanup-stale-ours-*
sudo rm -rf /tmp/cleanup-valid-rhachet-*

# review tests
sudo rm -rf /tmp/review-behavior-nocriteria-test-*
sudo rm -rf /tmp/review-behavior-notfound-test-*
sudo rm -rf /tmp/review-behavior-test-*

# roles-init tests
sudo rm -rf /tmp/roles-init-behaver-idempotent-test-*
sudo rm -rf /tmp/roles-init-behaver-test-*
sudo rm -rf /tmp/roles-init-cleanup-test-*

# bhrain tests
sudo rm -rf /tmp/bhrain-reflect-source-*
sudo rm -rf /tmp/bhrain-reflect-target-*

# claude tests
sudo rm -rf /tmp/claude-adapter-test-*
sudo rm -rf /tmp/claude-config-test-*
sudo rm -rf /tmp/claude-test-*

# rhachet tests
sudo rm -rf /tmp/rhachet-test-*

# prune tests
sudo rm -rf /tmp/prune-test-*

# generic test- prefixes
sudo rm -rf /tmp/test-both-*
sudo rm -rf /tmp/test-brains-*
sudo rm -rf /tmp/test-claude-*
sudo rm -rf /tmp/test-neither-*
sudo rm -rf /tmp/test-no-brains-*
sudo rm -rf /tmp/test-no-pkg-*
sudo rm -rf /tmp/test-opencode-*

echo "✨ cleanup complete"

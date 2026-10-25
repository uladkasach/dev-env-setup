#!/usr/bin/env bash
######################################################################
# .what = show, per peer lane of one stone's guard, the facts the guard
#         reads before it decides to pour that lane or hold it
#
# .why  = a guard round that pours no lane prints only the held verdicts;
#         it never says WHY each lane was held. this reads the same inputs
#         the guard reads (the artifact hash, the givens at that hash, the
#         cache filter, the meter, the level latch) and names the verdict,
#         with no review started and no file written
#
# usage:
#   route.guard.lanes.get.sh --stone 5.1.execution.from_vision --route .behavior/<route>
#
# guarantee:
#   - read-only: starts no review, writes no artifact, no meter, no passage
#   - reads the installed rhachet-roles-bhrain dist, so it sees what the
#     guard sees, patches included
#   - exit 0 = answered, 1 = malfunction, 2 = bad input
######################################################################
set -euo pipefail

stone=""
route=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stone) stone="${2:-}"; shift 2 ;;
    --route) route="${2:-}"; shift 2 ;;
    # rhx passes its own dispatch flags through; they are not this skill's
    --skill|--repo|--role) shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

if [[ -z "$stone" || -z "$route" ]]; then
  echo "✋ ConstraintError: --stone and --route are required" >&2
  echo "   fix: route.guard.lanes.get.sh --stone <stone> --route .behavior/<route>" >&2
  exit 2
fi
if [[ ! -d "$route" ]]; then
  echo "✋ ConstraintError: no route dir at '$route'" >&2
  exit 2
fi

dist="$(cd node_modules/rhachet-roles-bhrain/dist && pwd -P)"
route_abs="$(cd "$route" && pwd -P)"

ROUTE="$route_abs" STONE="$stone" DIST="$dist" node - <<'NODE'
const path = require('path');
const d = (p) => require(path.join(process.env.DIST, p));
const route = process.env.ROUTE;
const op = 'domain.operations/route';
(async () => {
  const { getAllStones } = d(`${op}/stones/getAllStones`);
  const { findOneStoneByPattern } = d(`${op}/stones/asStoneGlob`);
  const { computeStoneReviewInputHash } = d(`${op}/guard/review/computeStoneReviewInputHash`);
  const { getAllStoneGuardArtifactsByHash } = d(`${op}/guard/artifact/getAllStoneGuardArtifactsByHash`);
  const { getAllCachedPassedReviews } = d(`${op}/guard/review/getAllCachedPassedReviews`);
  const { getAllReviewPeersByLevel } = d(`${op}/guard/review/getAllReviewPeersByLevel`);
  const { getOneCacheSafePeerReviewArtifact } = d(`${op}/guard/review/peer/getOneCacheSafePeerReviewArtifact`);
  const { getAllRouteStoneGuardReviewPeerMeters } = d(`${op}/guard/review/peer/meter/getAllRouteStoneGuardReviewPeerMeters`);
  const { asMeterBySlug } = d(`${op}/guard/review/asMeterBySlug`);
  const { getStoneGuardLevelsPoured } = d(`${op}/judges/getStoneGuardLevelsPoured`);
  const { computeReviewPeerVerdict } = d(`${op}/guard/review/peer/meter/computeReviewPeerVerdict`);
  const { getGuardPeerReviews } = d('domain.objects/Driver/RouteStoneGuard');

  // the stone, as the guard finds it
  const stones = await getAllStones({ route });
  const stone = findOneStoneByPattern({ stones, pattern: process.env.STONE });
  if (!stone || !stone.guard) {
    console.error(`✋ ConstraintError: stone '${process.env.STONE}' not found, or unguarded, in ${route}`);
    process.exit(2);
  }

  // the inputs the guard reads, in its order
  const hash = await computeStoneReviewInputHash({ stone, route });
  const prior = await getAllStoneGuardArtifactsByHash({ stone, hash, route });
  const cached = getAllCachedPassedReviews({ reviews: prior.reviews });
  const meterBySlug = asMeterBySlug({
    meters: await getAllRouteStoneGuardReviewPeerMeters({ route, stone: stone.name }),
  });
  const levelsPoured = await getStoneGuardLevelsPoured({ stone, route });
  const peers = getAllReviewPeersByLevel({ peerReviews: getGuardPeerReviews(stone.guard) });

  console.log('🐢 heres the wave...');
  console.log('');
  console.log(`🐚 route.guard.lanes.get --stone ${stone.name}`);
  console.log(`   ├─ hash: ${hash}`);
  console.log(`   ├─ givens at this hash: ${prior.reviews.length} (cache-eligible: ${cached.length})`);
  console.log(`   ├─ levels poured: ${[...levelsPoured].join(', ') || '(none)'}`);
  console.log('   └─ lanes');
  peers.forEach((pr, i) => {
    const last = i === peers.length - 1;
    const bar = last ? '      └─' : '      ├─';
    const pad = last ? '         ' : '      │  ';
    const atHash = prior.reviews
      .filter((r) => r.index === pr.index)
      .sort((a, b) => a.iteration - b.iteration);
    const latest = atHash[atHash.length - 1] ?? null;
    const cacheSafe = getOneCacheSafePeerReviewArtifact({ cachedReviews: cached, index: pr.index, slug: pr.slug });
    const rounds = meterBySlug.get(pr.slug)?.rounds ?? 0;
    const verdict = computeReviewPeerVerdict({
      rounds,
      budget: pr.budget,
      blockers: cacheSafe?.blockers ?? Infinity,
      nitpicks: cacheSafe?.nitpicks ?? 0,
      exitClass: cacheSafe?.exitClass,
      wasExhausted: rounds >= pr.budget,
    });
    console.log(`${bar} r${pr.index}: ${pr.slug} (l${pr.level}, ${rounds}/${pr.budget})`);
    console.log(`${pad}├─ givens at hash: ${atHash.map((r) => `i${r.iteration}:${r.exitClass}`).join(' ') || '(none)'}`);
    console.log(`${pad}├─ latest at hash: ${latest ? `i${latest.iteration} ${latest.exitClass}, ${latest.blockers} blockers` : '(none)'}`);
    console.log(`${pad}├─ cache read: ${cacheSafe ? `i${cacheSafe.iteration}, ${cacheSafe.blockers} blockers` : '(miss)'}`);
    console.log(`${pad}└─ pre-gate verdict: ${verdict}`);
  });
})().catch((error) => {
  console.error(`💥 MalfunctionError: ${error.message}`);
  process.exit(1);
});
NODE
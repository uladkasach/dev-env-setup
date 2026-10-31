#!/usr/bin/env bash
# .what = prove the installed rhachet-roles-bhrain guard never serves a lane an older cached
#         verdict once a LATER given at the same hash refused or malfunctioned — the lane runs again
# .how  = drive the guard's own readers (the given parse, the cache filter, the per-rung cache read)
#         from the installed dist, on fixture givens. no route, no review, no file written
# .why  = the guard cached only passed givens, so a later refusal was skipped and the OLDER passed
#         verdict served; the lane was held and never re-ran, while the judge read the refusal as one
#         blocker. a residual that no stance and no re-run could clear. the cure is a local pnpm patch
#         (patches/rhachet-roles-bhrain@0.42.1.patch); the upstream cure is a radio task
#
# arms:
#   0  the fixture took: a refusal parses as `constraint`, a review as `passed`
#   1  RED before the patch: [i9 passed, i10 constraint] → no cache read, the lane re-runs
#   2  [i9 passed, i10 malfunction] → no cache read
#   3  [i9 passed] alone → i9 is reused (a clean cache is kept)
#   4  [i9 constraint, i10 passed] → i10 is reused (a refusal before a pass does not void it)
#   5  a refusal at ANOTHER rung voids no cache at this one
set -euo pipefail

dist="$(cd node_modules/rhachet-roles-bhrain/dist && pwd -P)"

DIST="$dist" node - <<'NODE'
const path = require('path');
const d = (p) => require(path.join(process.env.DIST, p));
const { asPeerReviewVerdictFromContent } = d('domain.operations/route/guard/review/peer/asPeerReviewVerdictFromContent');
const { getAllCachedPassedReviews } = d('domain.operations/route/guard/review/getAllCachedPassedReviews');
const { getOneCacheSafePeerReviewArtifact } = d('domain.operations/route/guard/review/peer/getOneCacheSafePeerReviewArtifact');

// the two given shapes, as the guard writes them to disk
const contentPassed = [
  '├─ stdout', '│  ├─', '│  │', '│  │  0 blockers', '│  │  5 nitpicks', '│  └─',
  '└─ passage allowed', '   └─ exit code: 0',
].join('\n');
const contentRefused = [
  '├─ stderr', '│  ├─', '│  │', '│  │  ✋ ConstraintError: clone enroll depth budget spent', '│  └─',
  '└─ passage blocked', '   ├─ blocked by constraints', '   └─ exit code: 2 ✋',
].join('\n');
const contentBroken = [
  '├─ stderr', '│  ├─', '│  │', '│  │  💥 MalfunctionError: the brain went dark', '│  └─',
  '└─ passage blocked', '   └─ exit code: 1 💥',
].join('\n');

// one given at a rung, as `getAllStoneGuardArtifactsByHash` reads it
const given = ({ iteration, index, slug, content }) => ({
  iteration,
  index,
  path: `/r/.reviews/peer/5.1.x._.review.i${String(iteration).padStart(3, '0')}.h.r${String(index).padStart(3, '0')}._.given.by_peer.${slug}.md`,
  ...asPeerReviewVerdictFromContent({ content }),
});

// the cache read the guard makes for one lane
const cacheRead = ({ reviews, index, slug }) =>
  getOneCacheSafePeerReviewArtifact({
    cachedReviews: getAllCachedPassedReviews({ reviews }),
    index,
    slug,
  });

const arms = [];
const check = (label, ok, detail) => arms.push({ label, ok, detail });
const slug = 'enroll-impl-arch-defects';

// 0 the fixture took
const p = given({ iteration: 9, index: 11, slug, content: contentPassed });
const r = given({ iteration: 10, index: 11, slug, content: contentRefused });
const m = given({ iteration: 10, index: 11, slug, content: contentBroken });
check('0a a review parses as passed', p.exitClass === 'passed', p.exitClass);
check('0b a refusal parses as constraint', r.exitClass === 'constraint', r.exitClass);
check('0c a malfunction parses as malfunction', m.exitClass === 'malfunction', m.exitClass);

// 1 the defect: a later refusal must void the older passed verdict
const read1 = cacheRead({ reviews: [p, r], index: 11, slug });
check('1  [i9 passed, i10 constraint] → no cache read, the lane re-runs', read1 === null,
  read1 ? `served i${read1.iteration}` : 'miss');

// 2 a later malfunction voids it too
const read2 = cacheRead({ reviews: [p, m], index: 11, slug });
check('2  [i9 passed, i10 malfunction] → no cache read', read2 === null,
  read2 ? `served i${read2.iteration}` : 'miss');

// 3 a clean cache is kept
const read3 = cacheRead({ reviews: [p], index: 11, slug });
check('3  [i9 passed] alone → i9 reused', read3?.iteration === 9, read3 ? `i${read3.iteration}` : 'miss');

// 4 a refusal BEFORE a pass voids naught
const r9 = given({ iteration: 9, index: 11, slug, content: contentRefused });
const p10 = given({ iteration: 10, index: 11, slug, content: contentPassed });
const read4 = cacheRead({ reviews: [r9, p10], index: 11, slug });
check('4  [i9 constraint, i10 passed] → i10 reused', read4?.iteration === 10, read4 ? `i${read4.iteration}` : 'miss');

// 5 a refusal at another rung voids no cache here
const rOther = given({ iteration: 10, index: 10, slug: 'enroll-impl-behavior-intent', content: contentRefused });
const read5 = cacheRead({ reviews: [p, rOther], index: 11, slug });
check('5  a refusal at r10 leaves r11 i9 reused', read5?.iteration === 9, read5 ? `i${read5.iteration}` : 'miss');

// the verdict
const failed = arms.filter((a) => !a.ok);
console.log('🐢 heres the wave...');
console.log('');
console.log('🐚 prove.guard-reruns-a-lane-whose-latest-given-refused');
arms.forEach((a, i) => {
  const bar = i === arms.length - 1 ? '   └─' : '   ├─';
  console.log(`${bar} ${a.ok ? '✔' : '✋'} ${a.label}${a.ok ? '' : `  (got: ${a.detail})`}`);
});
console.log('');
if (failed.length > 0) {
  console.log(`🐢 bummer dude — ${failed.length} arm(s) do not hold`);
  // exit 1, never 2: play.run reads 2 as "declined, its subject absent"
  process.exit(1);
}
console.log('🐢 righteous — every arm holds');
NODE

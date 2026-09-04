#!/usr/bin/env bash
######################################################################
# .what = the browser concern — today, exactly one browser
#
# .why the CONCERN and the BROWSER are separate nodes
#   - a dir named for the concern must not hold files that install one implementation
#   - the next browser-adjacent concern would have no home but INTO the firefox files
#   - ⇒ `1.3.browser` would come to mean "firefox plus whatever else arrived"
#   - the name says what it holds at each level (rule.require.bundle-names-name-their-subject):
#
#     1.3.browser     the concern — which browser, and how the box reaches it
#     1.3.1.firefox   this browser — its build, its profile, its extensions
#
# .why one child is not over-nested
#   - the two levels answer different questions
#   - "which browser does this box use?" has an answer that could change
#   - "is firefox installed and configured?" is about one artifact
#
# usage:
#   rhx grove.provision --what 1.3.browser --mode apply
######################################################################

grove_provision_1_3_browser() {
  bundle.upgrade 1.3.1.firefox
}

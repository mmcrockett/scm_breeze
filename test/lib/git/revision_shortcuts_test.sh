#!/bin/bash
# ------------------------------------------------------------------------------
# SCM Breeze - Streamline your SCM workflow.
# Copyright 2011 Nathan Broadbent (http://madebynathan.com). All Rights Reserved.
# Released under the LGPL (GNU Lesser General Public License)
# ------------------------------------------------------------------------------
#
# Unit tests for numbered revision shortcuts

export scmbDir="$(cd -P "$(dirname "$0")" && pwd)/../../.."

# Zsh compatibility
if [ -n "${ZSH_VERSION:-}" ]; then
  shell="zsh"
  SHUNIT_PARENT=$0
  setopt shwordsplit
  setopt append_history
fi

# Load test helpers
source "$scmbDir/test/support/test_helper.sh"

# Load functions to test
source "$scmbDir/lib/scm_breeze.sh"
source "$scmbDir/lib/git/revision_shortcuts.sh"

#-----------------------------------------------------------------------------
# Unit tests
#-----------------------------------------------------------------------------

test_expand_revisions_range_mode() {
  local error="Range mode not expanded correctly"
  assertEquals "$error" 'HEAD~1..HEAD' \
    "$(
      eval args="$(__scmb_expand_revisions range -1)"
      token_quote "${args[@]}"
    )"
  assertEquals "$error" 'HEAD~3..HEAD~2' \
    "$(
      eval args="$(__scmb_expand_revisions range -3)"
      token_quote "${args[@]}"
    )"
  assertEquals "$error" 'diff HEAD~3..HEAD~2 --stat' \
    "$(
      eval args="$(__scmb_expand_revisions range diff -3 --stat)"
      token_quote "${args[@]}"
    )"
}

test_expand_revisions_rev_mode() {
  local error="Rev mode not expanded correctly"
  assertEquals "$error" 'HEAD~1' \
    "$(
      eval args="$(__scmb_expand_revisions rev -1)"
      token_quote "${args[@]}"
    )"
  assertEquals "$error" 'reset HEAD~3' \
    "$(
      eval args="$(__scmb_expand_revisions rev reset -3)"
      token_quote "${args[@]}"
    )"
  assertEquals "$error" 'blame HEAD~1 -- file.txt' \
    "$(
      eval args="$(__scmb_expand_revisions rev blame -1 -- file.txt)"
      token_quote "${args[@]}"
    )"
}

test_expand_revisions_leaves_non_matching_args_alone() {
  local error="Non-matching args should pass through untouched"
  assertEquals "$error" 'diff --name-only' \
    "$(
      eval args="$(__scmb_expand_revisions range diff --name-only)"
      token_quote "${args[@]}"
    )"
  # Only a bare '-N' should match, not flags that merely contain digits.
  assertEquals "$error" 'diff -n30' \
    "$(
      eval args="$(__scmb_expand_revisions range diff -n30)"
      token_quote "${args[@]}"
    )"
}

test_expand_revisions_stops_at_separator() {
  local error="Args after '--' should not be rewritten"
  assertEquals "$error" 'diff -- -1' \
    "$(
      eval args="$(__scmb_expand_revisions range diff -- -1)"
      token_quote "${args[@]}"
    )"
}

# load and run shUnit2
source "$scmbDir/test/support/shunit2"

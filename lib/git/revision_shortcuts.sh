# ------------------------------------------------------------------------------
# SCM Breeze - Streamline your SCM workflow.
# Copyright 2011 Nathan Broadbent (http://madebynathan.com). All Rights Reserved.
# Released under the LGPL (GNU Lesser General Public License)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Numbered revision shortcuts for git commands
# ------------------------------------------------------------------------------

# Rewrites '-N' style args into git revisions, so commands that walk history
# can take a plain integer instead of spelling out 'HEAD~N' by hand.
#
#   mode 'range': -N => the diff introduced by the commit N steps back, i.e.
#                 HEAD~1..HEAD for -1, HEAD~N..HEAD~(N-1) for N > 1.
#   mode 'rev':   -N => a single revision, N steps back, i.e. HEAD~N.
#
# Stops rewriting once a literal '--' separator is seen, so pathspecs after
# '--' are left untouched.
# Return a string which can be `eval`ed like:
#   eval args="$(__scmb_expand_revisions range "$@")"
__scmb_expand_revisions() {
  local mode="$1"
  shift

  local args
  args=() # initially empty array. zsh 5.0.2 from Ubuntu 14.04 requires this to be separated
  local seen_separator=0
  for arg in "$@"; do
    if [[ $seen_separator -eq 0 && "$arg" == "--" ]]; then
      seen_separator=1
      args+=("$arg")
    elif [[ $seen_separator -eq 0 && "$arg" =~ ^-[0-9]+$ ]]; then
      local n="${arg#-}"
      if [[ "$mode" == "range" ]]; then
        if (( n == 1 )); then
          args+=("HEAD~1..HEAD")
        else
          args+=("HEAD~${n}..HEAD~$((n - 1))")
        fi
      else
        args+=("HEAD~${n}")
      fi
    else
      args+=("$arg")
    fi
  done

  # Generate a quoted array string to assign to "eval args="
  echo "( $(token_quote "${args[@]}") )"
}

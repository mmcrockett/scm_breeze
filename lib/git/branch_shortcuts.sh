# ------------------------------------------------------------------------------
# SCM Breeze - Streamline your SCM workflow.
# Copyright 2011 Nathan Broadbent (http://madebynathan.com). All Rights Reserved.
# Released under the LGPL (GNU Lesser General Public License)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Numbered shortcuts for git branch
# ------------------------------------------------------------------------------

# Function wrapper around 'll'
# Adds numbered shortcuts to output of ls -l, just like 'git status'
unalias $git_branch_alias > /dev/null 2>&1; unset -f $git_branch_alias > /dev/null 2>&1
function __scmb_git_branch_shortcuts {
  fail_if_not_git_repo || return 1

  # Fall back to normal git branch, if any unknown args given
  if [[ "$($_git_cmd branch | wc -l)" -gt 300 ]] || ([[ -n "$@" ]] && [[ "$@" != "-a" ]]); then
    exec_scmb_expand_args $_git_cmd branch "$@"
    return $?
  fi

  # Use ruby to inject numbers into git branch output
  ruby -e "$(
    cat <<EOF
    output = %x($_git_cmd branch --color=always $(token_quote "$@"))
    line_count = output.lines.to_a.size
    output.lines.each_with_index do |line, i|
      spaces = (line_count > 9 && i < 9 ? "  " : " ")
      puts line.sub(/^([ *+]{2})/, "\\\1\033[2;37m[\033[0m#{i+1}\033[2;37m]\033[0m" << spaces)
    end
EOF
)"

  # Set numbered file shortcut in variable
  local e=1 IFS=$'\n'
  for branch in $($_git_cmd branch "$@" | sed "s/^[*+ ]\{2\}//"); do
    export $GIT_ENV_CHAR$e="$branch"
    if [ "${scmbDebug:-}" = "true" ]; then echo "Set \$$GIT_ENV_CHAR$e  => $file"; fi
    let e++
  done
}

function __scmb_git_worktree_path_for_branch {
  local target_branch="$1"
  $_git_cmd worktree list --porcelain 2>/dev/null | awk -v target_branch="$target_branch" '
    /^worktree / { path = substr($0, 10); next }
    /^branch / {
      ref = substr($0, 8)
      sub(/^refs\/heads\//, "", ref)
      if (ref == target_branch) { print path; exit }
    }
  '
}

function __scmb_git_checkout_shortcuts {
  fail_if_not_git_repo || return 1

  if [ -z "$1" ]; then
    exec_scmb_expand_args $_git_cmd checkout
    return $?
  fi

  local args
  eval "args=$(scmb_expand_args "$@")"

  # If a single, non-flag branch arg is given, check if it lives in a worktree.
  if [ "${#args[@]}" -eq 1 ]; then
    local branch="${args[@]}"

    if [ -n "$branch" ] && [ "${branch#-}" = "$branch" ]; then
      local worktree_path=$(__scmb_git_worktree_path_for_branch "$branch")

      if [ -n "$worktree_path" ] && [ -d "$worktree_path" ]; then
        echo "Switching to worktree: $worktree_path"
        cd "$worktree_path"
        return $?
      fi
    fi
  fi

  __safe_eval "$_git_cmd" checkout "${args[@]}"
}

function __scmb_git_worktree_shortcuts {
  fail_if_not_git_repo || return 1

  # Expand numbered shortcuts (e.g. `1` -> `$e1`) so `gwtr 1`, `gwta 1`, etc. work.
  # Reset positional params from the expanded array so the rest of the function
  # can keep using $1/$2/$#/"$@" portably across bash and zsh.
  local args
  eval "args=$(scmb_expand_args "$@")"
  set -- "${args[@]}"

  # Translate `worktree remove <branch>` to `worktree remove <path>` by looking
  # up the branch's worktree. If no worktree is registered for that name, fall
  # through so native git handles paths or errors as usual.
  if [ "$1" = "remove" ] && [ "$#" -eq 2 ]; then
    local name="$2"
    if [ -n "$name" ] && [ "${name#-}" = "$name" ]; then
      local worktree_path
      worktree_path=$(__scmb_git_worktree_path_for_branch "$name")
      if [ -n "$worktree_path" ]; then
        __safe_eval "$_git_cmd" worktree remove "$worktree_path"
        return $?
      fi
    fi
  fi

  # Only intervene on:  worktree add <single-non-flag-name>
  # and only when git_worktree_directory selects a placement strategy.
  if [ "$1" = "add" ] && [ -n "$git_worktree_directory" ] && [ "$#" -eq 2 ]; then
    local name="$2"
    if [ -n "$name" ] && [ "${name#-}" = "$name" ]; then
      local repo_root=$($_git_cmd rev-parse --show-toplevel) || return 1
      local path
      local path_name="${name//\//-}"   # keep branch name, sanitize only directory path part

      case "$git_worktree_directory" in
        # Example using repo 'scm_breeze'
        # - create worktree 'scm_breeze-new-branch-to-work-on' next to 'scm_breeze'
        # To not have the basename of the repo use '..' instead (or absolute path)
        sibling)
          path="$(dirname "$repo_root")/$(basename "$repo_root")-$path_name"
          ;;
        # Example using repo 'scm_breeze' and 'other_related_repo'
        # Running 'git worktree add new-branch-to-work-on' in both repos
        # This helps when you have a feature tha may span multiple repos
        # - create directory 'new-branch-to-work-on' next to 'scm_breeze'
        # - create worktree 'scm_breeze' inside 'new-branch-to-work-on'
        # - create worktree 'other_related_repo' inside 'new-branch-to-work-on'
        feature)
          mkdir -p "$(dirname "$repo_root")/$path_name"
          path="$(dirname "$repo_root")/$path_name/$(basename "$repo_root")"
          ;;
        *)
          if [ -d "$git_worktree_directory" ]; then
            path="${git_worktree_directory%/}/$(basename "$repo_root")-$path_name"
          else
            echo "scm_breeze: git_worktree_directory '$git_worktree_directory' is not 'sibling' or an existing directory" >&2
            return 1
          fi
          ;;
      esac

      if $_git_cmd show-ref --verify --quiet "refs/heads/$name"; then
        __safe_eval "$_git_cmd" worktree add "$path" "$name"
      else
        __safe_eval "$_git_cmd" worktree add -b "$name" "$path"
      fi
      return $?
    fi
  fi

  __safe_eval "$_git_cmd" worktree "$@"
}

__git_alias "$git_branch_alias"              "__scmb_git_branch_shortcuts" ""
__git_alias "$git_branch_all_alias"          "__scmb_git_branch_shortcuts" "-a"
__git_alias "$git_branch_move_alias"         "__scmb_git_branch_shortcuts" "-m"
__git_alias "$git_branch_delete_alias"       "__scmb_git_branch_shortcuts" "-d"
__git_alias "$git_branch_delete_force_alias" "__scmb_git_branch_shortcuts" "-D"

# Define completions for git branch shortcuts
if [ "$GIT_SKIP_SHELL_COMPLETION" != "yes" ]; then
  if breeze_shell_is "bash"; then
    for alias_str in $git_branch_alias $git_branch_all_alias $git_branch_move_alias $git_branch_delete_alias; do
      __define_git_completion $alias_str branch
      complete -o default -o nospace -F _git_"$alias_str"_shortcut $alias_str
    done
  fi
fi

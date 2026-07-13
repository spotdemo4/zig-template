#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 || -z $1 || -z $2 ]]; then
  printf 'Usage: %s "Title" "Description"\n' "${0##*/}" >&2
  exit 1
fi

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf 'The initializer must be run from a Git repository.\n' >&2
  exit 1
}
root=$(realpath "$root")
script_path=$(realpath "$0")
if [[ $(pwd -P) != "$root" || $script_path != "$root/init.sh" ]]; then
  printf 'Run ./init.sh from the repository root.\n' >&2
  exit 1
fi
if [[ ! -d $root/.git || -L $root/.git ]]; then
  printf 'Linked worktrees and repositories with a .git file are not supported.\n' >&2
  exit 1
fi
if [[ $(git config --bool core.sparseCheckout || true) == true ]]; then
  printf 'Sparse checkouts are not supported.\n' >&2
  exit 1
fi
if ! worktree_status=$(git status --porcelain=v1 --untracked-files=all); then
  printf 'Unable to inspect the Git worktree.\n' >&2
  exit 1
fi
if [[ -n $worktree_status ]]; then
  printf 'Commit or discard all existing worktree changes before running the initializer.\n' >&2
  exit 1
fi
tracked_file_list=$(mktemp)
if ! git ls-files -z >"$tracked_file_list"; then
  rm -f "$tracked_file_list"
  printf 'Unable to inspect tracked files.\n' >&2
  exit 1
fi
mapfile -d '' -t tracked_files <"$tracked_file_list"
rm "$tracked_file_list"

git_name=$(git config user.name || true)
git_email=$(git config user.email || true)
if [[ -z $git_name || -z $git_email ]]; then
  printf 'Configure Git user.name and user.email before running the initializer.\n' >&2
  exit 1
fi
if [[ $git_name =~ [[:cntrl:]] || $git_email =~ [[:cntrl:]] ]]; then
  printf 'Git user.name and user.email cannot contain control characters.\n' >&2
  exit 1
fi

title=$1
description=$2
version=0.0.1
year=$(date +%Y)

if [[ $title =~ [[:cntrl:]] || $description =~ [[:cntrl:]] ]]; then
  printf 'Title and description cannot contain control characters.\n' >&2
  exit 1
fi

slug=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
if [[ ! $slug =~ ^[a-z][a-z0-9-]*$ ]]; then
  printf 'Title must produce a package name beginning with a letter.\n' >&2
  exit 1
fi
module=${slug//-/_}

remote=$(git remote get-url origin 2>/dev/null) || {
  printf 'Unable to read the origin remote.\n' >&2
  exit 1
}
if [[ $remote == *'?'* || $remote == *'#'* ]]; then
  printf 'Origin URL cannot contain a query string or fragment.\n' >&2
  exit 1
fi
mapfile -t remote_urls < <(git config --get-all remote.origin.url)
mapfile -t push_urls < <(git config --get-all remote.origin.pushurl || true)

repo_name=${root##*/}
new_git_dir="${root%/*}/.${repo_name}.git-new.$$"
old_git_dir="${root%/*}/.${repo_name}.git-old.$$"
if [[ -e $new_git_dir || -e $old_git_dir ]]; then
  printf 'Temporary Git directory already exists.\n' >&2
  exit 1
fi
git init --bare --quiet --initial-branch=main "$new_git_dir"
new_git=(git --git-dir="$new_git_dir" --work-tree="$root")
swap_started=false
changes_started=false
cleanup_git_reset() {
  local status=$?
  trap - EXIT INT TERM HUP
  if $swap_started && [[ -e $old_git_dir ]]; then
    rm -rf .git
    mv "$old_git_dir" .git
    if [[ ! -e $script_path ]]; then
      git restore -- init.sh || true
    fi
  elif $changes_started; then
    git restore --source=HEAD --staged --worktree -- . || true
    git clean -fd || true
  fi
  rm -rf "$new_git_dir"
  exit "$status"
}
trap cleanup_git_reset EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

case $remote in
  http://* | https://*)
    scheme=${remote%%://*}
    remote_path=${remote#*://}
    authority=${remote_path%%/*}
    host=${authority##*@}
    repo_path=${remote_path#*/}
    repo_path=${repo_path%.git}
    web_url="${scheme}://${host}/${repo_path}"
    ;;
  git@*:*)
    host=${remote#git@}
    host=${host%%:*}
    repo_path=${remote#*:}
    repo_path=${repo_path%.git}
    web_url="https://${host}/${repo_path}"
    ;;
  ssh://*)
    remote_path=${remote#ssh://}
    authority=${remote_path%%/*}
    host=${authority##*@}
    host=${host%%:*}
    repo_path=${remote_path#*/}
    repo_path=${repo_path%.git}
    web_url="https://${host}/${repo_path}"
    ;;
  *)
    printf 'Unsupported origin URL.\n' >&2
    exit 1
    ;;
esac

repo_path=${repo_path#/}
repo_path=${repo_path%.git}
if [[ $repo_path != */* ]]; then
  printf 'Origin must identify an owner and repository.\n' >&2
  exit 1
fi
if [[ ! $host =~ ^[A-Za-z0-9.-]+(:[0-9]+)?$ || ! $repo_path =~ ^[A-Za-z0-9._/-]+$ ]]; then
  printf 'Origin URL contains unsupported host or path characters.\n' >&2
  exit 1
fi
provider_host=${host%%:*}

replace_literal() {
  local old=$1 new=$2 pattern replacement
  shift 2
  pattern=$(printf '%s' "$old" | sed 's/[][\\.^$*@]/\\&/g')
  replacement=$(printf '%s' "$new" | sed 's/[&@\\]/\\&/g')
  sed -i "s@${pattern}@${replacement}@g" "$@"
}

escape_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

escaped_description=$(escape_string "$description")
nix_description=$(printf '%s' "$escaped_description" | sed 's/${/\\${/g')

changes_started=true
old_slug=zig-template
old_module=zig_template
old_description='zig template'
old_url=https://trev.zip/template/zig
case $module in
  addrspace | align | allowzero | and | anyframe | anytype | asm | async | await | break | callconv | catch | comptime | const | continue | defer | else | enum | errdefer | error | export | extern | fn | for | if | inline | linksection | noalias | noinline | nosuspend | opaque | or | orelse | packed | pub | resume | return | struct | suspend | switch | test | threadlocal | try | union | unreachable | usingnamespace | var | volatile | while)
    module="_$module"
    ;;
esac
replace_literal "$old_slug" "$slug" flake.nix
replace_literal "$old_module" "$module" build.zig build.zig.zon src/main.zig flake.nix
replace_literal '0.2.4' "$version" build.zig.zon flake.nix
sed -i '/^[[:space:]]*\.fingerprint = /d' build.zig.zon
if command -v zig >/dev/null; then
  zig_command=(zig build)
else
  zig_command=(nix develop -c zig build)
fi
if zig_output=$("${zig_command[@]}" 2>&1); then
  printf '%s\n' "$zig_output"
else
  fingerprint=$(printf '%s\n' "$zig_output" | sed -n 's/.*suggested value: \(0x[0-9a-fA-F]*\).*/\1/p')
  if [[ -z $fingerprint ]]; then
    printf '%s\n' "$zig_output" >&2
    printf 'Unable to generate the Zig package fingerprint.\n' >&2
    exit 1
  fi
  sed -i "/^[[:space:]]*\.minimum_zig_version = /i\\    .fingerprint = $fingerprint, // Changing this has security and trust implications." build.zig.zon
  "${zig_command[@]}"
fi
replace_literal "$old_description" "$nix_description" flake.nix
replace_literal "$old_url" "$web_url" flake.nix
replace_literal 'Copyright (c) 2026 trev' "Copyright (c) $year $git_name" LICENSE

if [[ ${provider_host,,} == github.com ]]; then
  is_github=true
  raw_url="https://raw.githubusercontent.com/${repo_path}/refs/heads/main"
  check_badge="[![check](${web_url}/actions/workflows/check.yaml/badge.svg?branch=main)](${web_url}/actions/workflows/check.yaml)"
  vulnerable_badge="[![vulnerable](${web_url}/actions/workflows/vulnerable.yaml/badge.svg?branch=main)](${web_url}/actions/workflows/vulnerable.yaml)"
else
  is_github=false
  raw_url="${web_url}/raw/branch/main"
  check_badge="[![check](${web_url}/actions/workflows/check.yaml/badge.svg?branch=main&logo=forgejo&logoColor=%23bac2de&label=check&labelColor=%23313244)](${web_url}/actions?workflow=check.yaml)"
  vulnerable_badge="[![vulnerable](${web_url}/actions/workflows/vulnerable.yaml/badge.svg?branch=main&logo=forgejo&logoColor=%23bac2de&label=vulnerable&labelColor=%23313244)](${web_url}/actions?workflow=vulnerable.yaml)"
fi

language_badge="[![zig](<https://img.shields.io/badge/dynamic/regex?url=${raw_url}/build.zig.zon&search=.minimum_zig_version%20%3D%20%22(.*)%22&replace=%241&logo=zig&logoColor=%23bac2de&label=version&labelColor=%23313244&color=%23F7A41D>)](https://ziglang.org/)"

{
  printf '# %s\n\n' "$title"
  printf '%s\n%s\n%s\n\n' "$check_badge" "$vulnerable_badge" "$language_badge"
  printf '%s\n' "$description"
} >README.md

remove_checks() {
  local key
  for key in "$@"; do
    sed -i "/^          $key = {$/,/^          };$/d" flake.nix
  done
}

read_secondary_repository() {
  local provider=$1 input remote_path authority secondary_provider_host scheme
  read -r -p "$provider repository URL: " input
  if [[ $input == *'?'* || $input == *'#'* ]]; then
    printf 'Repository URL cannot contain a query string or fragment.\n' >&2
    exit 1
  fi
  secondary_remote=$input
  case $input in
    http://* | https://*)
      scheme=${input%%://*}
      remote_path=${input#*://}
      authority=${remote_path%%/*}
      secondary_host=${authority##*@}
      secondary_repo_path=${remote_path#*/}
      secondary_repo_path=${secondary_repo_path%.git}
      secondary_web_url="${scheme}://${secondary_host}/${secondary_repo_path}"
      ;;
    git@*:*)
      secondary_host=${input#git@}
      secondary_host=${secondary_host%%:*}
      secondary_repo_path=${input#*:}
      secondary_repo_path=${secondary_repo_path%.git}
      secondary_web_url="https://${secondary_host}/${secondary_repo_path}"
      ;;
    ssh://*)
      remote_path=${input#ssh://}
      authority=${remote_path%%/*}
      secondary_host=${authority##*@}
      secondary_host=${secondary_host%%:*}
      secondary_repo_path=${remote_path#*/}
      secondary_repo_path=${secondary_repo_path%.git}
      secondary_web_url="https://${secondary_host}/${secondary_repo_path}"
      ;;
    *)
      printf 'Unsupported repository URL.\n' >&2
      exit 1
      ;;
  esac
  secondary_repo_path=${secondary_repo_path#/}
  secondary_repo_path=${secondary_repo_path%.git}
  secondary_provider_host=${secondary_host%%:*}
  if [[ $secondary_repo_path != */* ]]; then
    printf 'Repository URL must identify an owner and repository.\n' >&2
    exit 1
  fi
  if [[ ! $secondary_host =~ ^[A-Za-z0-9.-]+(:[0-9]+)?$ || ! $secondary_repo_path =~ ^[A-Za-z0-9._/-]+$ ]]; then
    printf 'Repository URL contains unsupported host or path characters.\n' >&2
    exit 1
  fi
  if [[ $provider == GitHub && ${secondary_provider_host,,} != github.com ]]; then
    printf 'GitHub repository URL must use github.com.\n' >&2
    exit 1
  fi
  if [[ $provider == Forgejo && ${secondary_provider_host,,} == github.com ]]; then
    printf 'Forgejo repository URL cannot use github.com.\n' >&2
    exit 1
  fi
}

if [[ ! -d .github ]]; then
  remove_checks actions-gh renovate-gh
fi
if [[ ! -d .forgejo ]]; then
  remove_checks actions-fj renovate-fj
fi

if $is_github; then
  if [[ -f .github/renovate.json ]]; then
    replace_literal "spotdemo4/$old_slug" "$repo_path" .github/renovate.json
  fi
  if [[ -d .forgejo ]]; then
    read -r -p 'GitHub origin detected. Delete .forgejo? [y/N] ' reply || reply=
    if [[ $reply =~ ^[Yy]$ ]]; then
      rm -rf .forgejo
      remove_checks actions-fj renovate-fj
    else
      read_secondary_repository Forgejo
      "${new_git[@]}" remote add forgejo "$secondary_remote"
      replace_literal 'template/zig' "$secondary_repo_path" .forgejo/renovate.json
      replace_literal 'https://trev.zip/api/v1' "${secondary_web_url%/$secondary_repo_path}/api/v1" .forgejo/renovate.json
      replace_literal 'REGISTRY: trev.zip' "REGISTRY: $secondary_host" .forgejo/workflows/release.yaml
      replace_literal '//trev.zip/api/packages' "//$secondary_host/api/packages" .forgejo/workflows/release.yaml
    fi
  fi
else
  if [[ -f .forgejo/renovate.json ]]; then
    replace_literal 'template/zig' "$repo_path" .forgejo/renovate.json
    replace_literal 'https://trev.zip/api/v1' "${web_url%/$repo_path}/api/v1" .forgejo/renovate.json
    replace_literal 'REGISTRY: trev.zip' "REGISTRY: $host" .forgejo/workflows/release.yaml
    replace_literal '//trev.zip/api/packages' "//$host/api/packages" .forgejo/workflows/release.yaml
  fi
  if [[ -d .github ]]; then
    read -r -p 'Non-GitHub origin detected. Delete .github? [y/N] ' reply || reply=
    if [[ $reply =~ ^[Yy]$ ]]; then
      rm -rf .github
      remove_checks actions-gh renovate-gh
    else
      read_secondary_repository GitHub
      "${new_git[@]}" remote add github "$secondary_remote"
      replace_literal "spotdemo4/$old_slug" "$secondary_repo_path" .github/renovate.json
    fi
  fi
fi

"${new_git[@]}" config core.bare false
"${new_git[@]}" config user.name "$git_name"
"${new_git[@]}" config user.email "$git_email"
"${new_git[@]}" remote add origin "${remote_urls[0]}"
for url in "${remote_urls[@]:1}"; do
  "${new_git[@]}" remote set-url --add origin "$url"
done
for url in "${push_urls[@]}"; do
  "${new_git[@]}" remote set-url --add --push origin "$url"
done
"${new_git[@]}" add -A
existing_tracked=()
for file in "${tracked_files[@]}"; do
  if [[ -e $file || -L $file ]]; then
    existing_tracked+=("$file")
  fi
done
"${new_git[@]}" add -f -- "${existing_tracked[@]}"
"${new_git[@]}" rm --cached --quiet -- init.sh
env \
  GIT_AUTHOR_NAME="$git_name" \
  GIT_AUTHOR_EMAIL="$git_email" \
  GIT_COMMITTER_NAME="$git_name" \
  GIT_COMMITTER_EMAIL="$git_email" \
  "${new_git[@]}" -c commit.gpgsign=false -c core.hooksPath=/dev/null commit --quiet --message 'chore: initialize project'

swap_started=true
mv .git "$old_git_dir"
if ! rm "$script_path"; then
  mv "$old_git_dir" .git
  printf 'Unable to remove init.sh.\n' >&2
  exit 1
fi
if ! mv "$new_git_dir" .git; then
  mv "$old_git_dir" .git
  git restore -- init.sh
  printf 'Unable to activate the new Git repository.\n' >&2
  exit 1
fi
swap_started=false
rm -rf "$old_git_dir"
trap - EXIT INT TERM HUP

printf 'Initialized %s (%s) from %s with a new root commit.\n' "$title" "$version" "$web_url"

#!/usr/bin/env bash
# The script often single-quotes text containing $ for printf, sed and Nix
# shellcheck disable=SC2016

# Initializes a project from this template. init.test.sh tests it.

set -euo pipefail
# Functions that print their result run in command substitutions
shopt -s inherit_errexit

old_slug=zig-template
old_module=zig_template
old_description='zig template'
old_url=https://trev.zip/template/zig
old_maintainer='maintainers.spotdemo4'
old_maintainer_email=me@trev.xyz
version=0.0.1

# Forges, by the name of their configuration directory and flake check suffix
declare -A forge_names=([github]=GitHub [gitea]=Gitea [forgejo]=Forgejo)
declare -A forge_checks=([github]=gh [gitea]=gt [forgejo]=fj)
forges=(github gitea forgejo)

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

# Sets remote_host, remote_repo_path and remote_web_url from a Git remote URL.
# The label names the URL in error messages.
parse_remote() {
  local label=$1 url=$2 scheme=https remote_path authority
  if [[ $url == *'?'* || $url == *'#'* ]]; then
    die "$label cannot contain a query string or fragment."
  fi
  case $url in
    http://* | https://*)
      scheme=${url%%://*}
      remote_path=${url#*://}
      authority=${remote_path%%/*}
      remote_host=${authority##*@}
      remote_repo_path=${remote_path#*/}
      ;;
    git@*:*)
      remote_host=${url#git@}
      remote_host=${remote_host%%:*}
      remote_repo_path=${url#*:}
      ;;
    ssh://*)
      remote_path=${url#ssh://}
      authority=${remote_path%%/*}
      remote_host=${authority##*@}
      remote_host=${remote_host%%:*}
      remote_repo_path=${remote_path#*/}
      ;;
    *)
      die "Unsupported ${label,}."
      ;;
  esac
  remote_repo_path=${remote_repo_path#/}
  remote_repo_path=${remote_repo_path%.git}
  if [[ $remote_repo_path != */* ]]; then
    die "$label must identify an owner and repository."
  fi
  if [[ ! $remote_host =~ ^[A-Za-z0-9.-]+(:[0-9]+)?$ || ! $remote_repo_path =~ ^[A-Za-z0-9._/-]+$ ]]; then
    die "$label contains unsupported host or path characters."
  fi
  remote_web_url="$scheme://$remote_host/$remote_repo_path"
}

# Prints the package name for a project title.
slugify() {
  local slug
  slug=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  if [[ ! $slug =~ ^[a-z][a-z0-9-]*$ ]]; then
    die 'Title must produce a package name beginning with a letter.'
  fi
  printf '%s\n' "$slug"
}

# Prints the Zig module name for a slug. Zig identifiers can't contain hyphens
# or be keywords, so those are replaced and prefixed.
zig_module() {
  local module=${1//-/_}
  case $module in
    addrspace | align | allowzero | and | anyframe | anytype | asm | async | await | break | callconv | catch | comptime | const | continue | defer | else | enum | errdefer | error | export | extern | fn | for | if | inline | linksection | noalias | noinline | nosuspend | opaque | or | orelse | packed | pub | resume | return | struct | suspend | switch | test | threadlocal | try | union | unreachable | usingnamespace | var | volatile | while)
      module="_$module"
      ;;
  esac
  printf '%s\n' "$module"
}

# Prints a value escaped for a double-quoted Nix string.
nix_string() {
  local value=$1
  # shellcheck disable=SC1003
  value=${value//'\'/'\\'}
  value=${value//'"'/'\"'}
  value=${value//'${'/'\${'}
  printf '%s\n' "$value"
}

# Replaces every occurrence of old with new in the given files.
replace_literal() {
  local old=$1 new=$2 file content
  shift 2
  for file in "$@"; do
    content=$(<"$file")
    printf '%s\n' "${content//"$old"/"$new"}" >"$file"
  done
}

remove_checks() {
  local key
  for key in "$@"; do
    sed -i "/^          $key = {$/,/^          };$/d" flake.nix
  done
}

# Prints the template commit this project started from. Repositories created
# with "use this template" have a new commit, but its tree matches the
# template's.
find_template_commit() {
  local commit tree
  local -A template_trees=()
  if ! GIT_TERMINAL_PROMPT=0 git fetch --quiet --no-tags "$old_url" main 2>/dev/null; then
    return
  fi
  while read -r commit tree; do
    if [[ ! -v template_trees[$tree] ]]; then
      template_trees[$tree]=$commit
    fi
  done < <(git log --format='%H %T' FETCH_HEAD)
  while read -r tree; do
    # nix flake init drops the executable bit from init.sh
    tree=$(git ls-tree -z "$tree" | sed -z 's/^100644\( blob [0-9a-f]*\tinit\.sh\)$/100755\1/' | git mktree -z --missing)
    if [[ -v template_trees[$tree] ]]; then
      printf '%s\n' "${template_trees[$tree]}"
      return
    fi
  done < <(git log --format='%T' HEAD)
}

# Checks that the initializer runs from the root of a regular Git repository
# with a Git user.
check_repository() {
  root=$(git rev-parse --show-toplevel 2>/dev/null) || die 'The initializer must be run from a Git repository.'
  root=$(realpath "$root")
  script_path=$(realpath "$0")
  if [[ $(pwd -P) != "$root" || $script_path != "$root/init.sh" ]]; then
    die 'Run ./init.sh from the repository root.'
  fi
  if [[ ! -d $root/.git || -L $root/.git ]]; then
    die 'Linked worktrees and repositories with a .git file are not supported.'
  fi
  if [[ $(git config --bool core.sparseCheckout || true) == true ]]; then
    die 'Sparse checkouts are not supported.'
  fi
  git_name=$(git config user.name || true)
  git_email=$(git config user.email || true)
  if [[ -z $git_name || -z $git_email ]]; then
    die 'Configure Git user.name and user.email before running the initializer.'
  fi
  if [[ $git_name =~ [[:cntrl:]] || $git_email =~ [[:cntrl:]] ]]; then
    die 'Git user.name and user.email cannot contain control characters.'
  fi
}

# Checks that a repository URL's host suits its forge: GitHub repositories are
# on github.com, and Gitea and Forgejo repositories are anywhere else.
check_forge_host() {
  local label=$1 forge=$2 host=${3%%:*}
  if [[ $forge == github && ${host,,} != github.com ]]; then
    die "$label must use github.com."
  fi
  if [[ $forge != github && ${host,,} == github.com ]]; then
    die "$label cannot use github.com."
  fi
}

# Sets forge and is_github from the forge the user says hosts origin. The
# default is GitHub for github.com, and Forgejo for any other host.
read_forge() {
  local default=forgejo reply
  if [[ ${provider_host,,} == github.com ]]; then
    default=github
  fi
  read -r -p "Which forge hosts origin? [github/gitea/forgejo] ($default) " reply || reply=
  forge=${reply,,}
  forge=${forge:-$default}
  case $forge in
    github | gitea | forgejo) ;;
    *) die 'Forge must be github, gitea or forgejo.' ;;
  esac
  check_forge_host "${forge_names[$forge]} origin URL" "$forge" "$host"
  if [[ $forge == github ]]; then
    is_github=true
  else
    is_github=false
  fi
}

# Checks the title and description, and reads the project's location from the
# origin remote.
check_project() {
  if [[ $title =~ [[:cntrl:]] || $description =~ [[:cntrl:]] ]]; then
    die 'Title and description cannot contain control characters.'
  fi
  slug=$(slugify "$title")
  module=$(zig_module "$slug")

  remote=$(git remote get-url origin 2>/dev/null) || die 'Unable to read the origin remote.'
  parse_remote 'Origin URL' "$remote"
  host=$remote_host
  repo_path=$remote_repo_path
  web_url=$remote_web_url
  provider_host=${host%%:*}
  read_forge
  mapfile -t remote_urls < <(git config --get-all remote.origin.url)
  mapfile -t push_urls < <(git config --get-all remote.origin.pushurl || true)
}

# Checks that the worktree is clean and records the tracked files.
check_worktree() {
  local worktree_status
  # Repositories set up with nix flake init have no commits yet. Commit the
  # template so a failed run can be rolled back; the new repository replaces it.
  if ! git rev-parse --verify --quiet HEAD >/dev/null; then
    git add -A
    git_as_user git -c commit.gpgsign=false -c core.hooksPath=/dev/null commit --quiet --message 'chore: add template'
  fi

  worktree_status=$(git status --porcelain=v1 --untracked-files=all) || die 'Unable to inspect the Git worktree.'
  if [[ -n $worktree_status ]]; then
    die 'Commit or discard all existing worktree changes before running the initializer.'
  fi
  mapfile -d '' -t tracked_files < <(git ls-files -z)
  wait "$!" || die 'Unable to inspect tracked files.'
}

# Runs a Git command as the Git user, whatever the environment sets.
git_as_user() {
  env \
    GIT_AUTHOR_NAME="$git_name" \
    GIT_AUTHOR_EMAIL="$git_email" \
    GIT_COMMITTER_NAME="$git_name" \
    GIT_COMMITTER_EMAIL="$git_email" \
    "$@"
}

# Creates the repository that replaces .git once the project is initialized,
# and restores the template if initialization fails.
start_new_repository() {
  local repo_name=${root##*/}
  new_git_dir="${root%/*}/.${repo_name}.git-new.$$"
  old_git_dir="${root%/*}/.${repo_name}.git-old.$$"
  if [[ -e $new_git_dir || -e $old_git_dir ]]; then
    die 'Temporary Git directory already exists.'
  fi
  git init --bare --quiet --initial-branch=main "$new_git_dir"
  new_git=(git --git-dir="$new_git_dir" --work-tree="$root")
  swap_started=false
  changes_started=false
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
}

cleanup() {
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
    git clean -fdq || true
  fi
  rm -rf "$new_git_dir"
  exit "$status"
}

# Removes the template's own files and replaces its metadata with the project's.
apply_metadata() {
  local year library_field=
  year=$(date +%Y)

  rm init.test.sh template.schema.json
  sed -i '/^        # nix flake init /,/^        };$/d' flake.nix
  remove_checks init
  sed -i '/^# Linguist: exclude template /,/^$/d' .gitattributes

  if [[ -n $template_commit ]]; then
    if $is_library; then
      library_field=', "library": true'
    fi
    printf '{ "$schema": "%s", "url": "%s", "commit": "%s"%s }\n' \
      "$old_url/raw/branch/main/template.schema.json" "$old_url" "$template_commit" "$library_field" >.template.json
  else
    printf 'Warning: unable to find the template commit; .template.json was not created.\n' >&2
  fi

  replace_literal "$old_slug" "$slug" flake.nix
  replace_literal "$old_module" "$module" build.zig build.zig.zon src/main.zig flake.nix
  sed -i -E "s@^(    \.version = \")[^\"]*@\1$version@" build.zig.zon
  sed -i -E "/^[[:space:]]*pname = \"$slug\";$/,/^[[:space:]]*version = /s@^([[:space:]]*version = \")[^\"]*@\1$version@" flake.nix
  replace_literal "$old_description" "$(nix_string "$description")" flake.nix
  replace_literal "$old_url" "$web_url" flake.nix
  replace_literal 'Copyright (c) 2026 trev' "Copyright (c) $year $git_name" LICENSE
  # Only the template's author has a nixpkgs maintainer entry.
  if [[ ${git_email,,} != "$old_maintainer_email" ]]; then
    replace_literal "[ $old_maintainer ]" \
      "[ { name = \"$(nix_string "$git_name")\"; email = \"$(nix_string "$git_email")\"; } ]" flake.nix
  fi
}

# Replaces the program with a library module.
make_library() {
  local workflow
  rm src/main.zig
  cat >build.zig <<EOF
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Users of this package import the module by this name.
    const mod = b.addModule("$module", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
EOF
  cat >src/root.zig <<EOF
//! $module says hello.
const std = @import("std");

/// Returns a greeting for name. The caller owns the returned memory.
pub fn hello(allocator: std.mem.Allocator, name: []const u8) std.mem.Allocator.Error![]u8 {
    return std.fmt.allocPrint(allocator, "Hello, {s}!", .{name});
}

test "hello" {
    const greeting = try hello(std.testing.allocator, "world");
    defer std.testing.allocator.free(greeting);
    try std.testing.expectEqualStrings("Hello, world!", greeting);
}
EOF

  # There's no program to run or put in an image, and the package has no
  # binaries to install.
  sed -i "/^              doInstallCheck = true;\$/,/^              '';\$/d" flake.nix
  sed -i -E '/^                (mainProgram|downloadPage) = /d' flake.nix
  sed -i 's@^\( *\)cp -R zig-out "$out"$@\1mkdir "$out"@' flake.nix
  sed -i '/^        # nix build #images/,/^        };$/d' flake.nix
  sed -i '/^### run$/,/^### format$/{/^### format$/!d}' CONTRIBUTING.md

  # Zig users fetch the library's source, so there are no artifacts or images
  # to release.
  for workflow in .github/workflows/release.yaml .gitea/workflows/release.yaml .forgejo/workflows/release.yaml; do
    if [[ -f $workflow ]]; then
      sed -i -E '/^            (packages|images)\.x86_64-linux\.default\./d; s/^(          PACKAGES:) \|$/\1 packages.x86_64-linux.default/' "$workflow"
    fi
  done
  if [[ -f .github/workflows/release.yaml ]]; then
    sed -i '/^      packages: write$/d' .github/workflows/release.yaml
  fi
  for workflow in .gitea/workflows/release.yaml .forgejo/workflows/release.yaml; do
    if [[ -f $workflow ]]; then
      sed -i -E '/^          (CONTAINER_REGISTRY_PASSWORD|DELETE_OLD_RELEASE_ARTIFACTS): /d' "$workflow"
    fi
  done
}

# Generates the package fingerprint, which Zig suggests when it's missing, and
# checks that the project builds.
set_fingerprint() {
  local zig_command zig_output fingerprint
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
      die 'Unable to generate the Zig package fingerprint.'
    fi
    sed -i "/^[[:space:]]*\.minimum_zig_version = /i\\    .fingerprint = $fingerprint, // Changing this has security and trust implications." build.zig.zon
    "${zig_command[@]}"
  fi
}

# Replaces the README's title, badges and description, and points its usage
# instructions at the project.
write_readme() {
  local raw_url check_badge vulnerable_badge encoded_lock_url nixpkgs_badge language_badge
  local image readme_sections
  if $is_github; then
    raw_url="https://raw.githubusercontent.com/${repo_path}/refs/heads/main"
    check_badge="[![check](${web_url}/actions/workflows/check.yaml/badge.svg?branch=main)](${web_url}/actions/workflows/check.yaml)"
    vulnerable_badge="[![vulnerable](${web_url}/actions/workflows/vulnerable.yaml/badge.svg?branch=main)](${web_url}/actions/workflows/vulnerable.yaml)"
  else
    raw_url="${web_url}/raw/branch/main"
    check_badge="[![check](${web_url}/actions/workflows/check.yaml/badge.svg?branch=main&logo=${forge}&logoColor=%23bac2de&label=check&labelColor=%23313244)](${web_url}/actions?workflow=check.yaml)"
    vulnerable_badge="[![vulnerable](${web_url}/actions/workflows/vulnerable.yaml/badge.svg?branch=main&logo=${forge}&logoColor=%23bac2de&label=vulnerable&labelColor=%23313244)](${web_url}/actions?workflow=vulnerable.yaml)"
  fi

  # The validated raw URL only needs colons and slashes double-encoded for Shields.
  encoded_lock_url="${raw_url}/flake.lock"
  encoded_lock_url=${encoded_lock_url//:/%253A}
  encoded_lock_url=${encoded_lock_url//\//%252F}
  nixpkgs_badge="[![nixpkgs](https://shields.trev.zip/endpoint?url=https%3A%2F%2Fnix-shield.trev.zip%2Fbadge%3Furl%3D${encoded_lock_url}%26input%3Dnixpkgs&logoColor=%23bac2de&labelColor=%23313244&color=%235277C3)](https://nixos.org/)"
  if $is_library; then
    # Libraries show the minimum zig version they support.
    language_badge="[![zig](<https://shields.trev.zip/badge/dynamic/regex?url=${raw_url}/build.zig.zon&search=.minimum_zig_version%20%3D%20%22(.*)%22&replace=%3E%3D%241&logo=zig&logoColor=%23bac2de&label=version&labelColor=%23313244&color=%23F7A41D>)](https://ziglang.org/)"
  else
    language_badge="[![zig](<https://shields.trev.zip/badge/dynamic/regex?url=${raw_url}/build.zig.zon&search=.minimum_zig_version%20%3D%20%22(.*)%22&replace=%241&logo=zig&logoColor=%23bac2de&label=version&labelColor=%23313244&color=%23F7A41D>)](https://ziglang.org/)"
  fi

  if $is_library; then
    readme_sections=$(sed -n '/^## contributing$/,$p' README.md)
    printf -v readme_sections '## using\n\n```sh\nzig fetch --save git+%s.git\n```\n\nthen, in `build.zig`:\n\n```zig\nconst dep = b.dependency("%s", .{ .target = target, .optimize = optimize });\nexe.root_module.addImport("%s", dep.module("%s"));\n```\n\n%s' \
      "$web_url" "$module" "$module" "$module" "$readme_sections"
  else
    readme_sections=$(sed -n '/^## using$/,$p' README.md)
    readme_sections=${readme_sections//"$old_url"/"$web_url"}
    if $is_github; then
      image="ghcr.io/${repo_path,,}:latest"
    else
      image="$host/${repo_path,,}:latest"
    fi
    readme_sections=${readme_sections//trev.zip\/template\/zig:latest/"$image"}
  fi

  {
    printf '# %s\n\n' "$title"
    printf '%s\n%s\n%s\n%s\n\n' "$check_badge" "$vulnerable_badge" "$nixpkgs_badge" "$language_badge"
    printf '%s\n\n%s\n' "$description" "$readme_sections"
  } >README.md
}

# Sets secondary_remote, secondary_repo_path and secondary_web_url from the URL
# of the project's repository on another forge.
read_secondary_repository() {
  local forge=$1 label="${forge_names[$1]} repository URL"
  read -r -p "$label: " secondary_remote
  parse_remote 'Repository URL' "$secondary_remote"
  check_forge_host "$label" "$forge" "$remote_host"
  secondary_repo_path=$remote_repo_path
  secondary_web_url=$remote_web_url
}

# Points a forge's Renovate configuration at a repository.
configure_renovate() {
  local forge=$1 repo_path=$2 web_url=$3 file=.$1/renovate.jsonc
  if [[ ! -f $file ]]; then
    return
  fi
  if [[ $forge == github ]]; then
    replace_literal "spotdemo4/$old_slug" "$repo_path" "$file"
  else
    replace_literal 'template/zig' "$repo_path" "$file"
    replace_literal 'https://trev.zip/api/v1' "${web_url%/"$repo_path"}/api/v1" "$file"
  fi
}

# Removes a forge's configuration and its flake checks.
remove_forge() {
  rm -rf ".$1"
  remove_checks "actions-${forge_checks[$1]}" "renovate-${forge_checks[$1]}"
}

# Points the origin forge's configuration at the project's repository, and
# keeps each other forge's configuration only if the project also uses it.
configure_providers() {
  local other reply
  for other in "${forges[@]}"; do
    if [[ ! -d .$other ]]; then
      remove_forge "$other"
    fi
  done
  configure_renovate "$forge" "$repo_path" "$web_url"

  for other in "${forges[@]}"; do
    if [[ $other == "$forge" || ! -d .$other ]]; then
      continue
    fi
    read -r -p "Also use ${forge_names[$other]}? [y/N] " reply || reply=
    if [[ $reply =~ ^[Yy]([Ee][Ss])?$ ]]; then
      read_secondary_repository "$other"
      "${new_git[@]}" remote add "$other" "$secondary_remote"
      configure_renovate "$other" "$secondary_repo_path" "$secondary_web_url"
    else
      remove_forge "$other"
    fi
  done
}

configure_editors() {
  local reply
  read -r -p 'Are you using Zed? [Y/n] ' reply || reply=
  if [[ $reply =~ ^[Nn]([Oo])?$ ]]; then
    rm -rf .zed
  fi

  read -r -p 'Are you using VS Code? [Y/n] ' reply || reply=
  if [[ $reply =~ ^[Nn]([Oo])?$ ]]; then
    rm -rf .vscode
  fi
}

# Formats the project and commits it as the new repository's root commit.
commit_new_repository() {
  local url file existing_tracked=()
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
  nix fmt

  "${new_git[@]}" add -A
  for file in "${tracked_files[@]}"; do
    if [[ -e $file || -L $file ]]; then
      existing_tracked+=("$file")
    fi
  done
  "${new_git[@]}" add -f -- "${existing_tracked[@]}"
  "${new_git[@]}" rm --cached --quiet -- init.sh
  git_as_user "${new_git[@]}" -c commit.gpgsign=false -c core.hooksPath=/dev/null commit --quiet --message 'chore: initialize project'
}

# Replaces .git with the new repository and removes the initializer.
activate_new_repository() {
  swap_started=true
  mv .git "$old_git_dir"
  if ! rm "$script_path"; then
    mv "$old_git_dir" .git
    die 'Unable to remove init.sh.'
  fi
  if ! mv "$new_git_dir" .git; then
    mv "$old_git_dir" .git
    git restore -- init.sh
    die 'Unable to activate the new Git repository.'
  fi
  swap_started=false
  rm -rf "$old_git_dir"
  trap - EXIT INT TERM HUP
}

main() {
  if [[ $# -ne 2 || -z $1 || -z $2 ]]; then
    die "Usage: ${0##*/} \"Title\" \"Description\""
  fi
  title=$1
  description=$2

  check_repository
  check_project
  check_worktree
  start_new_repository
  template_commit=$(find_template_commit)

  read -r -p 'Is this project a library? [y/N] ' reply || reply=
  is_library=false
  if [[ $reply =~ ^[Yy]([Ee][Ss])?$ ]]; then
    is_library=true
  fi

  changes_started=true
  apply_metadata
  if $is_library; then
    make_library
  fi
  set_fingerprint
  write_readme
  configure_providers
  configure_editors
  commit_new_repository
  activate_new_repository

  printf 'Initialized %s (%s) from %s with a new root commit.\n' "$title" "$version" "$web_url"
}

# init.test.sh sources the script to test its functions.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi

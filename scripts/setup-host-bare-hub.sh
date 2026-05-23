#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: scripts/setup-host-bare-hub.sh --hub-root /absolute/path [--mode auto|host|container] [--github-user-name NAME] [--github-user-email EMAIL] [--fetch-origin yes|no]\n' >&2
  exit 1
}

hub_root=""
mode="auto"
github_user_name=""
github_user_email=""
fetch_origin="no"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hub-root)
      shift
      hub_root="${1:-}"
      ;;
    --mode)
      shift
      mode="${1:-}"
      ;;
    --github-user-name)
      shift
      github_user_name="${1:-}"
      ;;
    --github-user-email)
      shift
      github_user_email="${1:-}"
      ;;
    --fetch-origin)
      shift
      fetch_origin="${1:-}"
      ;;
    *)
      usage
      ;;
  esac
  shift || true
done

[ -n "$hub_root" ] || usage

case "$hub_root" in
  /*) ;;
  *)
    printf 'refused: --hub-root must be absolute\n' >&2
    exit 1
    ;;
esac

case "$mode" in
  auto|host|container) ;;
  *)
    usage
    ;;
esac

case "$fetch_origin" in
  yes|no) ;;
  *)
    usage
    ;;
esac

resolve_mode() {
  if [ "$mode" = "host" ] || [ "$mode" = "container" ]; then
    printf '%s\n' "$mode"
    return
  fi

  env_mode="${HUB_BOOTSTRAP_MODE:-}"
  if [ "$env_mode" = "host" ] || [ "$env_mode" = "container" ]; then
    printf '%s\n' "$env_mode"
    return
  fi

  if [ -f "/.dockerenv" ] || [ -f "/run/.containerenv" ] || [ -n "${KUBERNETES_SERVICE_HOST:-}" ]; then
    printf 'container\n'
    return
  fi

  printf 'host\n'
}

effective_mode="$(resolve_mode)"

configure_identity() {
  if [ -n "$github_user_name" ] && [ -n "$github_user_email" ]; then
    git --git-dir="$hub_root/.bare" config user.name "$github_user_name"
    git --git-dir="$hub_root/.bare" config user.email "$github_user_email"
    return
  fi

  printf 'Use existing git credentials? Y/N: '
  read -r use_existing

  case "$use_existing" in
    Y|y)
      return
      ;;
    N|n)
      if [ -z "$github_user_name" ]; then
        printf 'GitHub username: '
        read -r github_user_name
      fi

      if [ -z "$github_user_email" ]; then
        printf 'GitHub email: '
        read -r github_user_email
      fi

      [ -n "$github_user_name" ] || {
        printf 'refused: github username required\n' >&2
        exit 1
      }
      [ -n "$github_user_email" ] || {
        printf 'refused: github email required\n' >&2
        exit 1
      }

      git --git-dir="$hub_root/.bare" config user.name "$github_user_name"
      git --git-dir="$hub_root/.bare" config user.email "$github_user_email"
      ;;
    *)
      printf 'refused: answer Y or N\n' >&2
      exit 1
      ;;
  esac
}

write_devpodignore() {
  target_dir="$1"
  [ -d "$target_dir" ] || return 0
  cat > "$target_dir/.devpodignore" <<'EOF'
# managed by setup-host-bare-hub; defensive sync guard
*
!.devpodignore
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source_checkout="$(cd "$script_dir/.." && pwd -P)"
default_branch="$(git -C "$source_checkout" symbolic-ref --quiet --short HEAD || git -C "$source_checkout" rev-parse --abbrev-ref HEAD)"

mkdir -p "$hub_root"

if [ ! -d "$hub_root/.bare" ]; then
  git clone --bare "$source_checkout" "$hub_root/.bare" >/dev/null
fi

printf 'gitdir: ./.bare\n' > "$hub_root/.git"

mkdir -p \
  "$hub_root/work" \
  "$hub_root/repos" \
  "$hub_root/state/opencode/exported_sessions" \
  "$hub_root/tmp"

write_devpodignore "$hub_root"
write_devpodignore "$hub_root/work"
write_devpodignore "$hub_root/repos"
write_devpodignore "$hub_root/tmp"

if ! git --git-dir="$hub_root/.bare" worktree list | grep -F "$hub_root/main" >/dev/null 2>&1; then
  rm -rf "$hub_root/main"
  git --git-dir="$hub_root/.bare" worktree add "$hub_root/main" "$default_branch" >/dev/null
fi

git --git-dir="$hub_root/.bare" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

if [ "$fetch_origin" = "yes" ]; then
  git --git-dir="$hub_root/.bare" fetch origin >/dev/null 2>&1 || true
fi

configure_identity

write_devpodignore "$hub_root/main"

if [ "$effective_mode" = "host" ]; then
  while IFS= read -r -d '' dir_path; do
    chmod 700 "$dir_path"
  done < <(find "$hub_root" -type d -print0)

  while IFS= read -r -d '' file_path; do
    case "$file_path" in
      */.bare/hooks/*)
        chmod 700 "$file_path"
        ;;
      *)
        chmod 600 "$file_path"
        ;;
    esac
  done < <(find "$hub_root" -type f -print0)
fi

printf 'ok: ensured host bare-hub layout at %s\n' "$hub_root"

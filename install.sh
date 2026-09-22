#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
BACKUP_ROOT="$HOME/.git-bootstrap-backups/$(date +%Y%m%d-%H%M%S)"
PERSONAL_EMAIL="ramonlimaramos@gmail.com"
PERSONAL_GH_USER="ramonlimaramos"
PERSONAL_KEY="$HOME/.ssh/id_ed25519"
PROFESSIONAL_KEY="$HOME/.ssh/id_ed25519_github_enterprise"
PROFESSIONAL_EMAIL="ramon.ramos@podium.com"
SSH_CONFIG="$HOME/.ssh/config"

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh [--with-professional] [--dry-run] [--skip-gh-auth] [--skip-github-settings]

Options:
  --with-professional      Also prepare the professional SSH key.
  --dry-run                Print actions without changing files.
  --skip-gh-auth           Do not run GitHub CLI authentication.
  --skip-github-settings   Do not open GitHub SSH key settings.
USAGE
}

DRY_RUN=0
SKIP_GH_AUTH=0
SKIP_GITHUB_SETTINGS=0
WITH_PROFESSIONAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-professional)
      WITH_PROFESSIONAL=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-gh-auth)
      SKIP_GH_AUTH=1
      ;;
    --skip-github-settings)
      SKIP_GITHUB_SETTINGS=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

log() {
  print -r -- "$*"
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would run: $*"
    return 0
  fi
  log "run: $*"
  "$@"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

find_brew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    print -r -- /opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    print -r -- /usr/local/bin/brew
  elif command_exists brew; then
    command -v brew
  else
    return 1
  fi
}

install_homebrew() {
  if find_brew >/dev/null; then
    return
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would install Homebrew"
    return 0
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

brew_install_if_missing() {
  local brew="$1"
  local package="$2"
  if "$brew" list --formula "$package" >/dev/null 2>&1; then
    log "ok: brew formula $package"
  else
    run "$brew" install "$package"
  fi
}

backup_file() {
  local target="$1"
  [[ -e "$target" ]] || return 0

  local backup="$BACKUP_ROOT/${target#"$HOME"/}"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would backup: $target -> $backup"
    return 0
  fi
  mkdir -p "${backup:h}"
  cp -p "$target" "$backup"
  log "backup: $target -> $backup"
}

install_file() {
  local source="$1"
  local target="$2"

  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
    log "ok: $target"
    return 0
  fi

  backup_file "$target"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would write: $target"
    return 0
  fi
  mkdir -p "${target:h}"
  cp "$source" "$target"
  log "wrote: $target"
}

ensure_ssh_key() {
  local key="$1"
  local email="$2"
  run mkdir -p "$HOME/.ssh"
  run chmod 700 "$HOME/.ssh"

  if [[ -f "$key" ]]; then
    if [[ ! -f "$key.pub" ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log "would recover public key from: $key"
      else
        local public_key
        public_key="$(ssh-keygen -y -f "$key")"
        print -r -- "$public_key" > "$key.pub"
        chmod 644 "$key.pub"
      fi
    fi
    log "ok: SSH key exists at $key"
    return 0
  fi

  if [[ -e "$key.pub" ]]; then
    log "error: restore the private key for $key.pub before continuing" >&2
    return 1
  fi

  run ssh-keygen -t ed25519 -C "$email" -f "$key" -N ""
  if [[ "$DRY_RUN" -eq 0 ]]; then
    chmod 600 "$key"
    chmod 644 "$key.pub"
  fi
}

copy_public_key_to_clipboard() {
  local pubkey="$PERSONAL_KEY.pub"
  if [[ ! -f "$pubkey" ]]; then
    log "missing: $pubkey"
    return 0
  fi

  if command_exists pbcopy; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "would copy public key to clipboard: $pubkey"
    else
      pbcopy < "$pubkey"
      log "copied public key to clipboard: $pubkey"
    fi
  fi
}

open_github_ssh_settings() {
  [[ "$SKIP_GITHUB_SETTINGS" -eq 0 ]] || return 0
  command_exists open || return 0
  run open "https://github.com/settings/ssh/new"
}

install_git_configs() {
  install_file "$ROOT_DIR/templates/gitconfig" "$HOME/.gitconfig"
  install_file "$ROOT_DIR/templates/gitconfig-personal" "$HOME/.gitconfig-personal"
  install_file "$ROOT_DIR/templates/gitconfig-professional" "$HOME/.gitconfig-professional"
}

install_ssh_config() {
  install_file "$ROOT_DIR/templates/ssh-config-managed" "$SSH_CONFIG"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    chmod 600 "$SSH_CONFIG"
  fi
}

setup_gh_auth() {
  [[ "$SKIP_GH_AUTH" -eq 0 ]] || return 0
  command_exists gh || return 0

  if gh auth status --hostname github.com >/dev/null 2>&1; then
    if ! run gh auth switch --user "$PERSONAL_GH_USER"; then
      run gh auth login --hostname github.com --git-protocol ssh --web
    fi
  else
    run gh auth login --hostname github.com --git-protocol ssh --web
  fi
  run gh auth setup-git --hostname github.com
}

print_next_steps() {
  cat <<STEPS

Next steps:
1. Confirm the copied SSH public key is added to GitHub:
   https://github.com/settings/keys
2. Test SSH:
   ssh -T git@github.com
3. Verify Git identity inside a personal repo:
   git config user.name
   git config user.email
4. Keep professional repos under ~/Developer/professional/, ~/Developer/podium/, or ~/Developer/podium-github/.
STEPS
  if [[ "$WITH_PROFESSIONAL" -eq 1 ]]; then
    cat <<'STEPS'
5. Sign into the professional GitHub account and add its public key:
   pbcopy < ~/.ssh/id_ed25519_github_enterprise.pub
   https://github.com/settings/ssh/new
6. Authenticate GitHub CLI with that account (verify the browser account):
   gh auth login --hostname github.com --git-protocol ssh --web
   gh auth status --hostname github.com
7. Test the professional key, authorizing organization SSO if required:
   ssh -T git@github.com-professional
STEPS
  else
    log "Professional access requires a separate key/account; rerun with --with-professional to prepare the key."
  fi
}

main() {
  install_homebrew
  local brew
  brew="$(find_brew)" || brew=""

  if [[ -n "$brew" ]]; then
    if [[ "$DRY_RUN" -eq 0 ]]; then
      eval "$("$brew" shellenv)"
    fi
    brew_install_if_missing "$brew" git
    brew_install_if_missing "$brew" gh
    brew_install_if_missing "$brew" git-delta
  else
    if [[ "$DRY_RUN" -eq 0 ]]; then
      log "error: Homebrew unavailable after installation" >&2
      return 1
    fi
    log "would install git, gh, and git-delta after Homebrew"
  fi

  ensure_ssh_key "$PERSONAL_KEY" "$PERSONAL_EMAIL"
  if [[ "$WITH_PROFESSIONAL" -eq 1 ]]; then
    ensure_ssh_key "$PROFESSIONAL_KEY" "$PROFESSIONAL_EMAIL"
  fi
  install_git_configs
  install_ssh_config
  copy_public_key_to_clipboard
  open_github_ssh_settings
  setup_gh_auth
  print_next_steps
}

main "$@"

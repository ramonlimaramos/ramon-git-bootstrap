#!/bin/zsh
set -euo pipefail

repo="${0:A:h:h}"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
export HOME="$fixture/ramon.ramos"
mkdir -p "$HOME"

sed '$d' "$repo/install.sh" |
  sed "s|/opt/homebrew/bin/brew|$fixture/missing-arm-brew|g; s|/usr/local/bin/brew|$fixture/missing-intel-brew|g" > "$fixture/functions.zsh"
source "$fixture/functions.zsh"
ROOT_DIR="$repo"
command_exists() { return 1; }
if find_brew > "$fixture/output"; then
  print -u2 'FAIL: absent Homebrew reported success'
  exit 1
fi
[[ ! -s "$fixture/output" ]]
DRY_RUN=1
WITH_PROFESSIONAL=1
SKIP_GH_AUTH=1
SKIP_GITHUB_SETTINGS=1
main > "$fixture/dry-run.log"
[[ ! -e "$HOME/.ssh" && ! -e "$HOME/.gitconfig" ]]
mkdir "$HOME/.ssh"
chmod 755 "$HOME/.ssh"
main > "$fixture/dry-run-existing.log"
[[ "$(stat -f %Lp "$HOME/.ssh")" == 755 ]]

DRY_RUN=0
ensure_ssh_key "$PERSONAL_KEY" "$PERSONAL_EMAIL" > "$fixture/key.log"
original="$(shasum "$PERSONAL_KEY")"
rm "$PERSONAL_KEY.pub"
ensure_ssh_key "$PERSONAL_KEY" "$PERSONAL_EMAIL" >> "$fixture/key.log"
[[ "$(shasum "$PERSONAL_KEY")" == "$original" ]]
ssh-keygen -lf "$PERSONAL_KEY.pub" >/dev/null
ensure_ssh_key "$PROFESSIONAL_KEY" "$PROFESSIONAL_EMAIL" >> "$fixture/key.log"
[[ -f "$PROFESSIONAL_KEY" && -f "$PROFESSIONAL_KEY.pub" ]]
print orphan > "$HOME/.ssh/orphan.pub"
if ensure_ssh_key "$HOME/.ssh/orphan" "$PERSONAL_EMAIL" > /dev/null 2>&1; then
  print -u2 'FAIL: public-only key should require restoration'
  exit 1
fi
[[ "$(cat "$HOME/.ssh/orphan.pub")" == orphan ]]

install_git_configs > "$fixture/config.log"
for scope in personal professional; do
  mkdir -p "$HOME/Developer/$scope/project"
  git -C "$HOME/Developer/$scope/project" init -q
  ssh_command="$(git -C "$HOME/Developer/$scope/project" config --get core.sshCommand)"
  resolution="$(eval "$ssh_command -G git@github.com" 2>/dev/null)"
  [[ "$resolution" == *$'hostname ssh.github.com\n'* ]]
  [[ "$resolution" == *$'port 443\n'* ]]
  git -C "$HOME/Developer/$scope/project" remote add origin https://github.com/example/project.git
  [[ "$(git -C "$HOME/Developer/$scope/project" ls-remote --get-url origin)" == git@github.com:example/project.git ]]
  if [[ "$scope" == personal ]]; then
    [[ "$ssh_command" == *'~/.ssh/id_ed25519 '* ]]
  else
    [[ "$ssh_command" == *'~/.ssh/id_ed25519_github_enterprise '* ]]
  fi
done
print 'PASS: Homebrew absence, dry-run, key preservation/recovery, identities and port 443'

# ramon-git-bootstrap

Bootstrap personal Git, GitHub CLI, and SSH configuration on a new macOS install.

This project intentionally separates identity from terminal appearance. Terminal and shell visual setup lives in `macos-terminal-bootstrap`; this repository only handles Git/GitHub/SSH.

## Defaults

- Personal GitHub user: `ramonlimaramos`
- Personal Git email: `ramonlimaramos@gmail.com`
- Personal SSH key: `~/.ssh/id_ed25519`
- Personal workspace: `~/Developer/personal/`
- Professional workspace: `~/Developer/professional/`
- Compatibility professional workspaces: `~/Developer/podium/`, `~/Developer/podium-github/`
- Default branch: `main`
- GitHub SSH transport: `ssh.github.com:443`

GitHub SSH is configured through port `443` because some networks block GitHub SSH on port `22`.

## Install

```sh
cd ~/Developer/personal/shell/ramon-git-bootstrap
./install.sh
```

To preview changes:

```sh
./install.sh --dry-run
```

## What It Does

- Installs Homebrew when missing.
- Installs `git`, `gh`, and `git-delta` when missing.
- Generates `~/.ssh/id_ed25519` when the personal SSH key is missing.
- Copies the public key to the clipboard.
- Opens GitHub SSH key settings.
- Installs:
  - `~/.gitconfig`
  - `~/.gitconfig-personal`
  - `~/.gitconfig-professional`
  - `~/.ssh/config`
- Runs GitHub CLI auth with the personal account when needed.
- Backs up overwritten files to:

```sh
~/.git-bootstrap-backups/<timestamp>/
```

## Git Config Split

The generated `~/.gitconfig` uses `includeIf`:

- Repos under `~/Developer/personal/` use `~/.gitconfig-personal`.
- Repos under `~/Developer/professional/` use `~/.gitconfig-professional`.
- Existing compatibility paths `~/Developer/podium/` and `~/Developer/podium-github/` also use `~/.gitconfig-professional`.

## Commit Signing

Commit signing is intentionally not configured in v1. It can be added later with SSH signing once the identity split is stable.

## Validate

```sh
zsh -n install.sh
shellcheck install.sh
```

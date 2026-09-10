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

Each scope pins its own SSH key with `core.sshCommand`, and rewrites
`https://github.com/` to `git@github.com:` so an HTTPS remote follows the same
key. Without that rewrite an HTTPS remote goes through
`credential.helper = !gh auth git-credential`, which serves whichever GitHub CLI
account is currently active: a personal repository cloned over HTTPS fails with
`Repository not found` while the CLI happens to be switched to the professional
account, and the reverse is equally true. The rewrite is resolution-time only —
`git remote -v` still shows the URL you cloned.

The GitHub CLI itself has no per-directory setting. When a `gh` command must run
against a specific account regardless of which one is active:

```sh
GH_TOKEN=$(gh auth token --user ramonlimaramos) gh pr list
```

## Commit Signing

Commit signing is intentionally not configured in v1. It can be added later with SSH signing once the identity split is stable.

## Validate

```sh
zsh -n install.sh
shellcheck install.sh
```

To prove the scopes are isolated, ask git what it resolves in each tree. The
answers must differ, and neither depends on the active GitHub CLI account:

```sh
git -C ~/Developer/personal/<repo> config --get core.sshCommand
git -C ~/Developer/personal/<repo> ls-remote --get-url origin
git -C ~/Developer/professional/<repo> config --get core.sshCommand
git -C ~/Developer/professional/<repo> ls-remote --get-url origin
```

Each key should also authenticate as the account it belongs to:

```sh
ssh -T -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes -F /dev/null git@github.com
ssh -T -i ~/.ssh/id_ed25519_github_enterprise -o IdentitiesOnly=yes -F /dev/null git@github.com
```

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

After the terminal bootstrap, paste this into Terminal on the **new Mac**
from any directory. It downloads the public repository without GitHub login
and prepares both personal and professional keys:

```zsh
(
  set -e
  setup_dir="$(mktemp -d)"
  curl -fsSL \
    https://github.com/ramonlimaramos/ramon-git-bootstrap/archive/refs/heads/main.tar.gz \
    -o "$setup_dir/bootstrap.tar.gz"
  tar -xzf "$setup_dir/bootstrap.tar.gz" -C "$setup_dir"
  /bin/zsh "$setup_dir/ramon-git-bootstrap-main/install.sh" --with-professional
)
```

Omit `--with-professional` for personal-only key setup. All paths use `~` or
`$HOME`, so a new macOS username such as `ramon.ramos` is supported.

From an existing checkout:

```sh
cd ~/Developer/personal/shell/ramon-git-bootstrap
./install.sh
```

To preview changes:

```sh
./install.sh --dry-run
```

The installer replaces the managed Git and SSH config files listed below,
backing up existing versions. Merge any additional host entries or custom Git
settings from the backup afterward. It does not copy credentials from your
old Mac. New keys are generated without a passphrase; add one with
`ssh-keygen -p -f ~/.ssh/id_ed25519` (and the professional path) if desired.
Existing private keys are preserved. If only a public key exists, restore its
private key before proceeding; if only the private key exists, the installer
recovers the public key and may prompt for its passphrase.

## Finish Account Setup

1. The installer copies the **personal** public key and opens GitHub settings.
   Verify the browser is signed into `ramonlimaramos`, then paste and save it.
   Complete the personal GitHub CLI login when prompted.
2. For professional access, switch the browser to `Ramon-ramos_podium`, then run:

   ```sh
   pbcopy < ~/.ssh/id_ed25519_github_enterprise.pub
   open https://github.com/settings/ssh/new
   gh auth login --hostname github.com --git-protocol ssh --web
   gh auth status --hostname github.com
   ```

   Add the professional public key to that account and complete login with the
   professional browser session. Authorize organization SSO when required.
3. Verify both SSH identities:

   ```sh
   ssh -T git@github.com-personal
   ssh -T git@github.com-professional
   ```

   Each greeting must name the expected account. GitHub reports successful
   authentication with exit code 1 because it does not provide shell access.

These registration/login steps are interactive and are not completed merely
by generating keys. Never copy private keys into the repository or README.

## What It Does

- Installs Homebrew when missing.
- Installs `git`, `gh`, and `git-delta` when missing.
- Generates `~/.ssh/id_ed25519` when the personal SSH key is missing.
- With `--with-professional`, also prepares `~/.ssh/id_ed25519_github_enterprise`.
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
key. Both commands explicitly set `ssh.github.com:443` while keeping
`-F /dev/null` to isolate the selected key from other SSH configuration.
Without that rewrite an HTTPS remote goes through
`credential.helper = !gh auth git-credential`, which serves whichever GitHub CLI
account is currently active: a personal repository cloned over HTTPS fails with
`Repository not found` while the CLI happens to be switched to the professional
account, and the reverse is equally true. The rewrite is resolution-time only —
the stored remote URL remains unchanged (`git config --get remote.origin.url`).

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
shellcheck --shell=bash install.sh
zsh tests/test_bootstrap.zsh
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
ssh -T -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes -F /dev/null -o HostName=ssh.github.com -p 443 git@github.com
ssh -T -i ~/.ssh/id_ed25519_github_enterprise -o IdentitiesOnly=yes -F /dev/null -o HostName=ssh.github.com -p 443 git@github.com
```

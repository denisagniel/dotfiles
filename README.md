# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io). One command sets
up a new Mac or Linux server with a consistent shell, prompt, and R environment.

## What's here

| Source file                       | Installed as             | Purpose                                        |
| --------------------------------- | ------------------------ | ---------------------------------------------- |
| `dot_zshrc.tmpl`                  | `~/.zshrc`               | Tiered zsh config (oh-my-zsh on Mac, graceful fallback on servers) |
| `dot_zsh_custom`                  | `~/.zsh_custom`          | Personal aliases & functions                   |
| `dot_Rprofile`                    | `~/.Rprofile`            | R session defaults + interactive helpers       |
| `dot_Renviron.tmpl`              | `~/.Renviron`            | R env vars (secrets injected from chezmoi data) |
| `dot_gitconfig.tmpl`             | `~/.gitconfig`           | Git identity + sensible defaults               |
| `dot_config/starship.toml`        | `~/.config/starship.toml`| Portable, git-aware prompt                      |
| `.chezmoiexternal.toml`           | —                        | Clones zsh plugins (autosuggestions, syntax-highlighting, fzf-tab) into `~/.local/share` |
| `run_once_before_10-bootstrap.sh.tmpl` | —                   | Installs CLI tools on first apply              |
| `.chezmoi.toml.tmpl`              | `~/.config/chezmoi/…`    | Prompts for per-machine values (incl. secrets) |

## New machine setup

```sh
# 1. Install chezmoi (also installs to ~/.local/bin if you lack root)
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <your-repo-url>
```

That single command: clones the repo, prompts for git identity + any secrets,
symlinks/writes every dotfile, clones the zsh plugins, and runs the bootstrap
installer. Then `exec zsh`.

If you already have the repo locally (like this one), instead:

```sh
chezmoi init --source ~/RAND/tools/dotfiles
chezmoi diff          # preview what would change in $HOME
chezmoi apply         # apply it
```

## Secrets — how they're handled

**No plaintext secrets live in this repo.** Three layers:

1. **AWS credentials → `~/.aws/credentials`** (AWS-native, gitignored). The
   Bedrock SDK and aws-cli read this automatically. See `SECRETS.md`.
2. **Other API keys (Census, etc.) → chezmoi config data**. Entered at
   `chezmoi init` time, stored in `~/.config/chezmoi/chezmoi.toml` (machine-local,
   never committed), and injected into `.Renviron` via templating.
3. **Escape hatch → `~/.config/dotfiles/secrets.zsh`**. A gitignored file that
   `.zshrc` sources if present. Handy on locked-down servers.

## Daily use

```sh
chezmoi edit ~/.zshrc     # edit the source, not the live file
chezmoi diff              # see pending changes
chezmoi apply             # apply
chezmoi cd                # jump to the source repo to commit/push
```

Edit sources here, commit, push. On other machines: `chezmoi update` (pull + apply).

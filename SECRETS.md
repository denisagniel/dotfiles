# Secrets handling

**Rule: no plaintext secret ever gets committed to this repo.** This file
explains where secrets live instead and how to reproduce them on a new machine.

## AWS credentials

Live in `~/.aws/credentials` (mode `600`), the AWS-native location. Both the
Bedrock SDK (used by Claude Code via `CLAUDE_CODE_USE_BEDROCK=1`) and the aws
CLI read it automatically — no env vars needed.

```ini
# ~/.aws/credentials
[default]
aws_access_key_id = <your key id>
aws_secret_access_key = <your secret>
```

```ini
# ~/.aws/config
[default]
region = us-west-2
```

> ⚠️ This key previously sat in plaintext in `~/.zshrc`. Consider rotating it in
> the AWS console; update `~/.aws/credentials` with the new value afterward.

## API keys (Census, etc.)

Stored in chezmoi's per-machine config (`~/.config/chezmoi/chezmoi.toml`, never
committed) and injected into `~/.Renviron` at `chezmoi apply` time via the
`dot_Renviron.tmpl` template. You're prompted for them on `chezmoi init`.

To change one later:
```sh
chezmoi init            # re-prompts, or
$EDITOR ~/.config/chezmoi/chezmoi.toml   # edit directly, then:
chezmoi apply
```

## Shell-only secrets

If you have a secret that must be a shell env var and isn't AWS, put it in
`~/.config/dotfiles/secrets.zsh` (mode `600`, gitignored). `~/.zshrc` sources it
automatically if present. Copy this file manually to new machines.

## On a new machine

1. `chezmoi init --apply <repo>` → prompts for API keys, writes `.Renviron`.
2. Copy `~/.aws/credentials` over manually (or `aws configure`).
3. Copy `~/.config/dotfiles/secrets.zsh` if you use it.

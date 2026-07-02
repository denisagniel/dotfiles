
# --- dotfiles: hand off interactive logins to zsh ---------------------------
# zsh is built into ~/.local/bin (no sudo needed to change login shell).
# Guards: only when interactive ($prompt set), zsh exists, and we're not
# already in zsh — so scp/rsync/git-over-ssh and nested shells are unaffected.
if ( $?prompt && -x ~/.local/bin/zsh && ! $?ZSH_VERSION ) then
    setenv SHELL ~/.local/bin/zsh
    exec ~/.local/bin/zsh -l
endif
# --- end dotfiles zsh handoff -----------------------------------------------

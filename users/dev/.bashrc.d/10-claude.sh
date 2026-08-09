# --- Claude Code shortcuts (dev user).
# `cc` launches Claude Code with permission prompts bypassed. This is the alias
# that devsh/dev-cc and the tmux split scaffold resolve inside an interactive
# dev shell (see users/ethan/.bashrc.d/10-devsh.sh and users/ethan/bin/dev-cc).
alias cc='claude --dangerously-skip-permissions'

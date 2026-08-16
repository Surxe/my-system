# --- Claude Code shortcuts (dev user).
# `cc` launches Claude Code with permission prompts bypassed. This is the alias
# that devsh/dev-cc and the tmux split scaffold resolve inside an interactive
# dev shell (see users/ethan/.bashrc.d/10-devsh.sh and users/ethan/localbin/dev-cc).
alias cc='claude --dangerously-skip-permissions'

# Disable Claude Code's TUI mouse-click capture (v2.1.195+). The capture
# intermittently desyncs from the terminal, leaving the UI unclickable /
# interactions silently dropped, and also causes accidental prompt approvals.
# Setting this keeps the scroll wheel and restores native text selection;
# prompts are answered with arrow keys + Enter. (todo t-0051)
export CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1

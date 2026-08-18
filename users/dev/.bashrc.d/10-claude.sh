# --- Claude Code shortcuts (dev user).
# `cc` launches Claude Code with permission prompts bypassed, wrapped in a
# relaunch loop so the in-session `new` command (users/dev/localbin/new) can start
# a genuinely fresh session instead of `/clear` — which, by design, inherits the
# /rename name and only drops the AI-generated title (todo t-0053). `new` writes
# the file named by CLAUDE_NEW_SENTINEL; on Claude exit this loop sees it and
# relaunches (new session id + fresh AI title) rather than returning to the shell.
# A normal exit (no sentinel) breaks the loop, exactly as the old alias did.
#
# Still resolved by devsh/dev-cc and the tmux split scaffold inside an interactive
# dev shell (see users/ethan/.bashrc.d/10-devsh.sh and users/ethan/localbin/dev-cc):
# a function loads in interactive dev shells the same way the old alias did.
cc() {
    local sentinel="${XDG_RUNTIME_DIR:-/tmp}/claude-new.$$"
    export CLAUDE_NEW_SENTINEL="$sentinel"
    while :; do
        rm -f "$sentinel"
        claude --dangerously-skip-permissions "$@"
        [ -e "$sentinel" ] || break
    done
    rm -f "$sentinel"
    unset CLAUDE_NEW_SENTINEL
}

# Fully release Claude Code's TUI mouse capture. Its mouse tracking (v2.1.195+)
# intermittently desyncs from the terminal, leaving the UI unclickable /
# interactions silently dropped, and also causes accidental prompt approvals.
# The milder CLAUDE_CODE_DISABLE_MOUSE_CLICKS keeps the scroll wheel but leaves
# mouse reporting on, which still swallows click-drag so native text selection /
# copy stays broken. CLAUDE_CODE_DISABLE_MOUSE=1 releases the mouse entirely:
# click-drag selection + terminal copy work with no modifier. Trade-off is no
# scroll wheel (scroll with PageUp / Ctrl); prompts are answered with arrow keys
# + Enter. (todo t-0051)
export CLAUDE_CODE_DISABLE_MOUSE=1

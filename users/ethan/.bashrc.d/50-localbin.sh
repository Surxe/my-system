# Ensure ~/.local/bin is on PATH (todo-capture and other copied executables).
case ":$PATH:" in
    *:"$HOME/.local/bin":*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac

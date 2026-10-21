# Shell integration

term-cut launches top-level zsh login sessions with an app-owned `ZDOTDIR`. The bundled `.zshenv` restores the previous directory, loads the user's `.zshenv`, and installs `preexec` / `precmd` hooks. The rest of zsh startup proceeds normally. User startup files are never written by the application.

The hooks send private `OSC 7777` reports through the PTY: `start` before a command and `done;<exit status>` before the next prompt. These reports contain no command text. SwiftTerm's registered handler updates the session's status without replacing its standard OSC handlers. Shell builtins, syntax errors, interrupted commands, and shell exits are covered.

- Green: the prompt is ready after a successful command.
- Yellow: a foreground command is running.
- Red: the last command returned a nonzero status. It remains red until another command starts or the session closes.
- Gray: activity is unavailable, the session ended normally, or no sessions are open.

The menu bar combines all session states: failed, running, unavailable, ready, then ended. A failure in a hidden tab or pane therefore remains visible. Tooltips and accessibility labels describe the state as text.

Automatic integration applies only to the app's top-level zsh login shells. Other shells report gray. A nested shell, an interactive SSH connection, or a background job has no separate command tracking; the parent foreground command keeps its own status. A nonzero exit code indicates the command's result, regardless of any words printed to stdout or stderr.

References: [zsh hook functions](https://zsh.sourceforge.io/Doc/Release/Functions.html#Hook-Functions), [zsh startup files](https://zsh.sourceforge.io/Doc/Release/Files.html#Startup_002fShutdown-Files).

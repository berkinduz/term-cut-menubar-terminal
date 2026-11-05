# Restore the user's startup directory before continuing normal zsh startup.
case ${PEEKSH_ORIGINAL_ZDOTDIR+x} in
    x) builtin export ZDOTDIR="$PEEKSH_ORIGINAL_ZDOTDIR" ;;
    *) builtin unset ZDOTDIR ;;
esac
builtin unset PEEKSH_ORIGINAL_ZDOTDIR
if [[ -r "${ZDOTDIR-$HOME}/.zshenv" ]]; then
    builtin source "${ZDOTDIR-$HOME}/.zshenv"
fi
if [[ -o interactive ]]; then
    builtin autoload -Uz "${${(%):-%x}:A:h}/peeksh-integration"
    peeksh-integration
    builtin unfunction peeksh-integration
fi

# Restore the user's startup directory before continuing normal zsh startup.
case ${TERM_CUT_ORIGINAL_ZDOTDIR+x} in
    x) builtin export ZDOTDIR="$TERM_CUT_ORIGINAL_ZDOTDIR" ;;
    *) builtin unset ZDOTDIR ;;
esac
builtin unset TERM_CUT_ORIGINAL_ZDOTDIR
if [[ -r "${ZDOTDIR-$HOME}/.zshenv" ]]; then
    builtin source "${ZDOTDIR-$HOME}/.zshenv"
fi
if [[ -o interactive ]]; then
    builtin autoload -Uz "${${(%):-%x}:A:h}/term-cut-integration"
    term-cut-integration
    builtin unfunction term-cut-integration
fi

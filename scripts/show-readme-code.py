#!/usr/bin/env python3
"""Render the real demo source in the terminal using Kanagawa Dragon colors."""
import sys
from pathlib import Path
from pygments import highlight
from pygments.formatters import TerminalTrueColorFormatter
from pygments.lexers import JavascriptLexer
from pygments.style import Style
from pygments.token import Comment, Keyword, Name, Number, Operator, Punctuation, String, Text

class DragonStyle(Style):
    background_color = '#181616'
    styles = {
        Text: '#c5c9c5', Keyword: '#a292a3', Name: '#c5c9c5',
        Name.Function: '#8ba4b0', Name.Builtin: '#8ea4a2',
        Number: '#c4b28a', Operator: '#8ba4b0', Punctuation: '#c5c9c5',
        String: '#8a9a7b', Comment: '#a6a69c',
    }

source = Path(sys.argv[1])
print(f'\033[38;2;139;164;176m{source}\033[0m')
rendered = highlight(source.read_text(), JavascriptLexer(), TerminalTrueColorFormatter(style=DragonStyle))
for number, line in enumerate(rendered.splitlines(), 1):
    print(f'\033[38;2;100;100;92m{number:2}  \033[0m{line}')

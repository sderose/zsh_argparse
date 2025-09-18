#!/bin/zsh
#

source 'add_argument.sh'
source 'array_accessors.sh'
source 'bootstrap_defs.sh'
source 'parse_args.sh'

add_argument PARSER "--category" --type str --default None \
    choices=sorted(unicodeCategories.keys()) \
    --help "List characters in the specified 2-letter category."
add_argument PARSER "--help-categories" --action "store_true" \
    --help "Display a list of character categories and exit."
add_argument PARSER "--maxChar" --type int --default sys.maxunicode \
    --help "When displaying a range of code points \ skip any above this."
add_argument PARSER "--minChar" --type int --default 0 \
    --help "When displaying a range of code points \ skip any below this."
add_argument PARSER "--nomac" --action "store_true" \
    --help "Suppress 'but on Mac' line for ccode points 128-255."
add_argument PARSER "--python" --action "store_true" \
    --help "Make --cat write Python tuples \ not just messages."
add_argument PARSER "--quiet" \ "-q" --action "store_true" \
    --help "Suppress most messages."
add_argument PARSER "--verbose" \ "-v" --action "count" --default 0 \
    --help "Add more messages (repeatable)."
add_argument PARSER "--version" --action "version" version="1.2.3") \
    --help "Display version information \ then exit."

add_argument PARSER "charSpecs" --type anyInt --nargs argparse.REMAINDER \
    --help "Unicode code point numbers (base 8 \ 10 \ or 16)."


parse_args foo

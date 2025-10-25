#!/bin/zsh
#


###############################################################################
# Test zerg.

source test_funcs.sh
source ../zerg_setup.sh

if [[ `sv_type PARSER` != "undef" ]]; then
    tMsg 0 "'PARSER' already defined. Nuking it first."
    aa_del PARSER
fi

tHead "Testing zerg_new"
zerg_new PARSER

tHead "Testing adds"

###############################################################################
# Types

zerg_add PARSER "--maxPi" --type float --default sys.maxunicode \
    --help "When displaying a range of code points \ skip any above this."
typeset -p maxPi

zerg_add PARSER "--minChar" --type int --default 0 \
    --help "When displaying a range of code points \ skip any below this."
typeset -p PARSER__minChar

zerg_add PARSER "--charSpecs" --type anyInt --nargs argparse.REMAINDER --help \
     "Unicode code point numbers (base 8 \ 10 \ or 16)."
typeset -p PARSER__charSpecs

zerg_add PARSER "--category" --type str --default "aardvark" \
    --choices "aardvark basilisk catoblepus dog" \
    --help "List stuff in the specified category."
typeset -p PARSER__category



zerg_add PARSER "--anyint-option" --anyint
typeset -p PARSER__anyint

zerg_add PARSER "--bool-option" --bool
typeset -p PARSER__bool

zerg_add PARSER "--char-option" --char
typeset -p PARSER__char

zerg_add PARSER "--date-option" --date
typeset -p PARSER__date

zerg_add PARSER "--datetime-option" --datetime
typeset -p PARSER__datetime

zerg_add PARSER "--duration-option" --duration
typeset -p PARSER__duration

zerg_add PARSER "--epoch-option" --epoch
typeset -p PARSER__epoch

zerg_add PARSER "--float-option" --float
typeset -p PARSER__float

zerg_add PARSER "--hexint-option" --hexint
typeset -p PARSER__hexint

zerg_add PARSER "--int-option" --int
typeset -p PARSER__int

zerg_add PARSER "--lang-option" --lang
typeset -p PARSER__lang

zerg_add PARSER "--logprob-option" --logprob
typeset -p PARSER__logprob

zerg_add PARSER "--octint-option" --octint
typeset -p PARSER__octint

zerg_add PARSER "--path-option" --path
typeset -p PARSER__path

zerg_add PARSER "--prob-option" --prob
typeset -p PARSER__prob

zerg_add PARSER "--regex-option" --regex
typeset -p PARSER__regex

zerg_add PARSER "--str-option" --str
typeset -p PARSER__str

zerg_add PARSER "--time-option" --time
typeset -p PARSER__time

zerg_add PARSER "--some-name" --ident
typeset -p PARSER__some_name

zerg_add PARSER "--some-names" --idents
typeset -p PARSER__some_names

zerg_add PARSER "--uident-option" --uident
typeset -p PARSER__uident

zerg_add PARSER "--url-option" --url
typeset -p PARSER__url


###############################################################################
### Actions

zerg_add PARSER "--help-categories" --action "store_true" \
    --help "Display a list of categories and exit."
typeset -p PARSER__help_categories

zerg_add PARSER "--nomac-option" --action "store_false" --dest mac --default 1 \
    --help "Suppress 'but on Mac' line for code points 128-255."
typeset -p PARSER__nomac

zerg_add PARSER "--setPi-option" --type float --action "store_const" --const 3.14 \
    --default 0.0 --help "Store pi somewhere."
typeset -p PARSER__setPi

zerg_add PARSER "--quiet-option -q-option --silent-option" --action "store_true" \
    --help "Suppress most messages."
typeset -p PARSER__quiet

zerg_add PARSER "--verbose-option -v" --action "count" --default 0 \
    --help "Add more messages (repeatable)."
typeset -p PARSER__verbose

zerg_add PARSER "--help-option" --action "help" \
    --help "Display help information then exit."
typeset -p PARSER__help

zerg_add PARSER "--version-option" --action "version" \
    --help "Display version information then exit."
typeset -p PARSER__version

zerg_add PARSER "--ignore-option" --action "append" --type anyint \
    --help "Keep a list of things to ignore."
typeset -p PARSER__ignore

zerg_add PARSER "--ignoreEscape-option -iesc" --action "append_const" --dest ignore \
    --const 27 --help "Keep a list of things to ignore."
typeset -p PARSER__ignore


###############################################################################
### RE-use

### Parsing
tHead "Testing parse"
zerg_parse PARSER -q -v --verbose --nomac --maxchar 65535 hello.txt

echo "Got: quiet $quiet, verbose $verbose, nomac $nomac, maxchar $maxchar."
#echo "Total fails: $FAILCT."

#!/bin/zsh
#


###############################################################################
# Test zerg.

local TEST_V="" TEST_TYPES="1" TEST_ACTIONS=""
if [[ $1 == "-v" ]]; then
    TEST_V=1; ZERG_V=1; shift
fi

source test_funcs.sh
source ../zerg_setup.sh

if [[ `sv_type PARSER` != "undef" ]]; then
    tMsg 0 "'PARSER' already defined. Nuking it first."
    zerg_del "PARSER"
    if [[ "$PARSER" ]] || [[ "$PARSER__quiet" ]]; then
        tMsg 0 "zerg_del for PARSER assoc failed!"
        return
    else
        tMsg 0 "Successfully removed PARSER assoc."
    fi
fi

tHead "Testing zerg_new"
zerg_new PARSER --ignore-case --ignore-case-choices --description "A simple parser." --allow-abbrev --allow-abbrev-choices --epilog "Nevermore." --var-style assoc
#aa_export -f view --sort PARSER

tHead "Testing adds"
zerg_add PARSER "--quiet -q --silent" --store-true --help "Less chatty."
[ $? ] || tMsg 0 "zerg_add for PARSER --quiet failed."
zerg_add PARSER "--verbose -v" --action count --help "More chatty."
[ $? ] || tMsg 0 "zerg_add for PARSER --verbose failed."
zerg_add PARSER "--max" --int --default 999
[ $? ] || tMsg 0 "zerg_add for PARSER --max failed."

tHead "After zerg_adds:"
#aa_export -f view --sort PARSER__quiet
#aa_export -f view --sort PARSER__verbose

tHead "Testing parse"
zerg_parse PARSER --quiet -v -v hello.txt

tHead "Results"
aa_export -f view --sort PARSER__results

return


###############################################################################
#
tHead "More adds"

zerg_add PARSER "--verbose -v" --action count --help "More chatty."
[ $TEST_V ] && typeset -p PARSER__verbose

zerg_add PARSER "--ignore-case -i" --action store_true --dest no_case --help "Disregard case distinctions."
[ $TEST_V ] && typeset -p PARSER__no_case

zerg_add -q PARSER "notgood" --action store_true --help "Bad name, add should fail."
[ $TEST_V ] && typeset -p PARSER__quiet

[ -v PARSER__quiet ] || tMsg 0 "PARSER__quiet missing"
[ -v verbose ] || tMsg 0 "PARSER__verbose missing"
[ -v PARSER__i ] && tMsg 0 "PARSER__i unexpected"
[ -v PARSER__ignore_case ] || tMsg 0 "PARSER__ignore_case missing"

tHead "Testing parse"
zerg_parse PARSER --verbose --silent hello.txt file2.txt

echo "Got: quiet $quiet, verbose $verbose, nomac $nomac, maxchar $maxchar."
typeset -p PARSER__results

tHead "Testing zerg_to_argparse"
ap=`zerg_to_argparse PARSER`

tHead "Bailing, short test."
return

###############################################################################
# Types
#
if [ $TEST_TYPES ]; then
    zerg_add PARSER "--maxPi" --type float --default 98765 \
        --help "When displaying a range of code points \ skip any above this."
    [ $TEST_V ] && typeset -p maxPi

    zerg_add PARSER "--minChar" --type int --default 0 \
        --help "When displaying a range of code points \ skip any below this."
    [ $TEST_V ] && typeset -p PARSER__minChar

    zerg_add PARSER "--charSpecs" --type anyInt --nargs remainder --help \
         "Unicode code point numbers (base 8 \ 10 \ or 16)."
    [ $TEST_V ] && typeset -p PARSER__charSpecs

    zerg_add PARSER "--category" --type str --default "aardvark" \
        --choices "aardvark basilisk catoblepus dog" \
        --help "List stuff in the specified category."
    [ $TEST_V ] && typeset -p PARSER__category


    zerg_add PARSER "--anyint-option" --anyint
    [ $TEST_V ] && typeset -p PARSER__anyint_option

    zerg_add PARSER "--bool-option" --bool
    [ $TEST_V ] && typeset -p PARSER__bool_option

    zerg_add PARSER "--char-option" --char
    [ $TEST_V ] && typeset -p PARSER__char_option

    zerg_add PARSER "--date-option" --date
    [ $TEST_V ] && typeset -p PARSER__date_option

    zerg_add PARSER "--datetime-option" --datetime
    [ $TEST_V ] && typeset -p PARSER__datetime_option

    zerg_add PARSER "--duration-option" --duration
    [ $TEST_V ] && typeset -p PARSER__duration_option

    zerg_add PARSER "--epoch-option" --epoch
    [ $TEST_V ] && typeset -p PARSER__epoch_option

    zerg_add PARSER "--float-option" --float
    [ $TEST_V ] && typeset -p PARSER__float_option

    zerg_add PARSER "--hexint-option" --hexint
    [ $TEST_V ] && typeset -p PARSER__hexint_option

    zerg_add PARSER "--int-option" --int
    [ $TEST_V ] && typeset -p PARSER__int_option

    zerg_add PARSER "--lang-option" --lang
    [ $TEST_V ] && typeset -p PARSER__lang_option

    zerg_add PARSER "--logprob-option" --logprob
    [ $TEST_V ] && typeset -p PARSER__logprob_option

    zerg_add PARSER "--octint-option" --octint
    [ $TEST_V ] && typeset -p PARSER__octint_option

    zerg_add PARSER "--path-option" --path
    [ $TEST_V ] && typeset -p PARSER__path_option

    zerg_add PARSER "--prob-option" --prob
    [ $TEST_V ] && typeset -p PARSER__prob_option

    zerg_add PARSER "--regex-option" --regex
    [ $TEST_V ] && typeset -p PARSER__regex_option

    zerg_add PARSER "--str-option" --str
    [ $TEST_V ] && typeset -p PARSER__str_option

    zerg_add PARSER "--time-option" --time
    [ $TEST_V ] && typeset -p PARSER__time_option

    zerg_add PARSER "--some-name" --ident
    [ $TEST_V ] && typeset -p PARSER__some_name_option

    zerg_add PARSER "--some-names" --idents
    [ $TEST_V ] && typeset -p PARSER__some_names_option

    zerg_add PARSER "--uident-option" --uident
    [ $TEST_V ] && typeset -p PARSER__uident_option

    zerg_add PARSER "--url-option" --url
    [ $TEST_V ] && typeset -p PARSER__url_option
fi


###############################################################################
### Actions
#
if [ $TEST_ACTIONS ]; then
    zerg_add PARSER "--help-categories" --action "store_true" \
        --help "Display a list of categories and exit."
    [ $TEST_V ] && typeset -p PARSER__help_categories

    zerg_add PARSER "--nomac-option" --action "store_false" --dest mac --default 1 \
        --help "Suppress 'but on Mac' line for code points 128-255."
    [ $TEST_V ] && typeset -p PARSER__nomac_option

    zerg_add PARSER "--setPi-option" --type float --action "store_const" --const 3.14 \
        --default 0.0 --help "Store pi somewhere."
    [ $TEST_V ] && typeset -p PARSER__setPi_option

    zerg_add PARSER "--quiet-option -q-option --silent-option" --action "store_true" \
        --help "Suppress most messages."
    [ $TEST_V ] && typeset -p PARSER__quiet_option

    zerg_add PARSER "--verbose-option -v" --action "count" --default 0 \
        --help "Add more messages (repeatable)."
    [ $TEST_V ] && typeset -p PARSER__verbose_option

    zerg_add PARSER "--help-option" --action "help" \
        --help "Display help information then exit."
    [ $TEST_V ] && typeset -p PARSER__help_option

    zerg_add PARSER "--version-option" --action "version" \
        --help "Display version information then exit."
    [ $TEST_V ] && typeset -p PARSER__version_option

    zerg_add PARSER "--ignore-option" --action "append" --type anyint \
        --help "Keep a list of things to ignore."
    [ $TEST_V ] && typeset -p PARSER__ignore_option

    zerg_add PARSER "--ignore-escape-option -iesc" --action "append_const" --dest special_dest \
        --const 27 --help "Keep a list of things to ignore."
    [ $TEST_V ] && typeset -p PARSER__ignore-escape_option
fi


###############################################################################
### Test re-use

### Parsing
tHead "Testing parse"
zerg_parse -v PARSER --quiet -v --nomac --maxchar 65535 hello.txt

echo "Got: quiet $quiet, verbose $verbose, nomac $nomac, maxchar $maxchar."

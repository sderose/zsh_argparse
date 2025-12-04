#!/bin/zsh
# Test zerg, a zsh argument parser.
#
if [[ $1 == "-v" ]]; then
    ZERG_V=0; shift
fi

local TEST_TYPES=""
local TEST_ACTIONS="1"
local TEST_TOGGLE=1

source test_funcs.sh
source ../zerg_setup.sh

if [[ `zsh_type PARSER` != "undef" ]]; then
    warn 0 "'PARSER' already defined. Nuking it first."
    zerg_del "PARSER"
    if [[ "$PARSER" ]] || [[ "$PARSER__quiet" ]]; then
        warn 0 "zerg_del for PARSER assoc failed!"
        return
    else
        warn 0 "Successfully removed PARSER assoc."
    fi
fi

tHead "Testing zerg_new"
zerg_new PARSER --ignore-case --ignore-case-choices --description "A simple parser." --allow-abbrev --allow-abbrev-choices --epilog "Nevermore." --var-style assoc
#aa_export -f view --sort PARSER

tHead "Testing adds"
zerg_add PARSER "--quiet -q --silent" --store-true --help "Less chatty."
[ $? ] || warn 0 "zerg_add for PARSER --quiet failed."
zerg_add PARSER "--verbose -v" --action count --help "More chatty."
[ $? ] || warn 0 "zerg_add for PARSER --verbose failed."
zerg_add PARSER "--maxChar" --int --default 999
[ $? ] || warn 0 "zerg_add for PARSER --maxChar failed."

tHead "After zerg_adds"
#aa_export -f view --sort PARSER__quiet
#aa_export -f view --sort PARSER__verbose

tHead "Testing parse"
zerg_parse PARSER --quiet -v -v hello.txt

tHead "Results"
aa_export -f view --sort PARSER__results


###############################################################################
#
tHead "Testing w/ many more adds"

zerg_add PARSER "--ignore-case -i" --action store_true --dest no_case --help "Disregard case distinctions."
[ $ZERG_V ] && typeset -p PARSER__no_case

zerg_add -q PARSER "notgood" --action store_true --help "Bad name, add should fail."
[ $ZERG_V ] && typeset -p PARSER__quiet

[ -v PARSER__quiet ] || warn 0 "PARSER__quiet missing"
[ -v verbose ] || warn 0 "PARSER__verbose missing"
[ -v PARSER__i ] && warn 0 "PARSER__i unexpected"
[ -v PARSER__ignore_case ] || warn 0 "PARSER__ignore_case missing"

tHead "Testing parse"
zerg_parse PARSER --verbose --silent hello.txt file2.txt

echo "Got: quiet $quiet, verbose $verbose, maxChar $maxChar."
typeset -p PARSER__results

tHead "Testing zerg_to_argparse"
ap=`zerg_to_argparse PARSER`
print $ap


###############################################################################
# Types
#
if [ $TEST_TYPES ]; then
    tHead "Adding args for many types and actions."

    zerg_add PARSER "--minChar" --type int --default 0 \
        --help "When displaying a range of code points \ skip any below this."
    [ $ZERG_V ] && typeset -p PARSER__minChar

    zerg_add PARSER "--charSpecs" --type anyInt --nargs remainder --help \
         "Unicode code point numbers (base 8 \ 10 \ or 16)."
    [ $ZERG_V ] && typeset -p PARSER__charSpecs

    zerg_add PARSER "--category" --type str --default "aardvark" \
        --choices "aardvark basilisk catoblepus dog" \
        --help "List stuff in the specified category."
    [ $ZERG_V ] && typeset -p PARSER__category

    for cur in ${(ko)zerg_types}; do
        # Presently no types have [-_], but be thorough in case.
        local cur_opt=$cur:gs/_/-/
        warn 1 "*** Adding arg --type '$cur' and --$cur_opt."
        zerg_add PARSER "--${cur_opt}-o1" --type $cur
        zerg_add PARSER "--${cur_opt}-o2" --$cur_opt --dest result_${cur}_o1
        [ $ZERG_V ] && typeset -p PARSER__${cur}-o1
        is_zergtypename $cur || warn 0 "Type didn't pass: '$cur'."
        #is_of_zerg_type -q $cur 99
        #(( $? > 1 )) && warn 0 "is_of_zerg_type problem for type '$cur'."
        #is_$cur -q 99
        #(( $? > 1 )) && warn 0 "is_$cur problem."
    done
fi

if [ $TEST_ACTIONS ]; then
    for cur in ${(ko)zerg_actions}; do
        [[ $cur == toggle ]] && continue  # test separately
        local cur_opt=$cur:gs/_/-/
        warn 1 "*** Adding arg via --action '$cur' as --${cur_opt}-o1."
        zerg_add PARSER "--${cur_opt}-o1" --action $cur
        warn 1 "    And short way --$cur_opt, as --${cur_opt}-o2"
        zerg_add PARSER "--${cur_opt}-o2" --$cur_opt --dest result_${cur}_o1
        [ $ZERG_V ] && typeset -p PARSER__${cur}_o1
    done
fi

if [ $TEST_TOGGLE ]; then
fi


###############################################################################
### Test re-use

tHead "Testing parse again"
zerg_new PAR2
zerg_add PAR2 "--verbose -v" --count
zerg_add PAR2 "--category" --choices "aardvark basilisk catoblepus dog" \
    --help "List stuff in the specified category."
zerg_add PAR2 "--uchar" --hexint --default 0x2002

zerg_parse -v PAR2 --quiet -v -v -v --category basilisk --uchar 0xBEEf hello.txt

aa_export PAR2__results

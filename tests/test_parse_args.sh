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
[ $TEST_V ] && typeset -p PARSER__no_case

zerg_add -q PARSER "notgood" --action store_true --help "Bad name, add should fail."
[ $TEST_V ] && typeset -p PARSER__quiet

[ -v PARSER__quiet ] || tMsg 0 "PARSER__quiet missing"
[ -v verbose ] || tMsg 0 "PARSER__verbose missing"
[ -v PARSER__i ] && tMsg 0 "PARSER__i unexpected"
[ -v PARSER__ignore_case ] || tMsg 0 "PARSER__ignore_case missing"

tHead "Testing parse"
zerg_parse PARSER --verbose --silent hello.txt file2.txt

echo "Got: quiet $quiet, verbose $verbose, maxchar $maxchar."
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
    [ $TEST_V ] && typeset -p PARSER__minChar

    zerg_add PARSER "--charSpecs" --type anyInt --nargs remainder --help \
         "Unicode code point numbers (base 8 \ 10 \ or 16)."
    [ $TEST_V ] && typeset -p PARSER__charSpecs

    zerg_add PARSER "--category" --type str --default "aardvark" \
        --choices "aardvark basilisk catoblepus dog" \
        --help "List stuff in the specified category."
    [ $TEST_V ] && typeset -p PARSER__category

    for cur in ${(ko)zerg_types}; do
        echo "*** Adding arg --type '$cur' and --$cur."
        zerg_add PARSER "--${cur}-o1" --type $cur
        zerg_add PARSER "--${cur}-o2" --$cur --dest result_${cur}_o1
        [ $TEST_V ] && typeset -p PARSER__${cur}-o1
        is_zergtypename $cur || tMsg 0 "Type didn't pass: '$cur'."
        #is_of_zerg_type -q $cur 99
        #(( $? > 1 )) && tMsg 0 "is_of_zerg_type problem for type '$cur'."
        #is_$cur -q 99
        #(( $? > 1 )) && tMsg 0 "is_$cur problem."
    done

    for cur in ${(ko)zerg_actions}; do
        cur=$cur:gs/_/-/
        echo "*** Adding arg --action '$cur'."
        zerg_add PARSER "--${cur}-o1" --action $cur
        zerg_add PARSER "--${cur}-o2" --$cur --dest result_${cur}_o1
        [ $TEST_V ] && typeset -p PARSER__${cur}-o1
    done
fi



###############################################################################
### Test re-use

tHead "Testing parse again"
zerg_parse -v PARSER --quiet -v -v -v --maxchar 65535 --category basilisk --hexint-o1 0xBEEf hello.txt

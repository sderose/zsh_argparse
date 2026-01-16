#!/bin/zsh
# Test zerg, a zsh argument parser.
#
if [[ $1 == "-v" ]]; then
    ZERG_V=0; shift
fi

local TEST_TYPES="1"
local TEST_ACTIONS="1"
local TEST_TOGGLE="1"

if ! [ -v ZERG_SETUP ]; then
    source ../zerg.plugin.zsh || return 99
fi
source test_funcs.zsh

if [[ `zsh_type PARSER` != "undef" ]]; then
    warn "'PARSER' already defined. Nuking it first."
    zerg_del "PARSER"
    if [[ "$PARSER" ]] || [[ "$PARSER__quiet" ]]; then
        warn "zerg_del for PARSER assoc failed!"
        return
    else
        warn "Successfully removed PARSER assoc."
    fi
fi

warn "====Testing zerg_new"
zerg_new PARSER --ignore-case --ignore-case-choices --description "A simple parser." --allow-abbrev --allow-abbrev-choices --epilog "Nevermore." --var-style assoc
#aa_export -f view --sort PARSER

warn "====Testing adds"
zerg_add PARSER "--quiet -q --silent" --store-true --help "Less chatty."
[ $? ] || warn "zerg_add for PARSER --quiet failed."
zerg_add PARSER "--verbose -v" --action count --help "More chatty."
[ $? ] || warn "zerg_add for PARSER --verbose failed."
zerg_add PARSER "--maxChar" --int --default 999
[ $? ] || warn "zerg_add for PARSER --maxChar failed."

warn "====After zerg_adds"
#aa_export -f view --sort PARSER__quiet
#aa_export -f view --sort PARSER__verbose

warn "====Testing parse"
zerg_parse PARSER --quiet -v -v hello.txt

warn "====Results"
aa_export -f view --sort PARSER__results


###############################################################################
#
warn "====Testing w/ many more adds"

zerg_add PARSER "--ignore-case -i" --action store_true --dest case_ig --help "Disregard case distinctions."
[ $ZERG_V ] && typeset -p PARSER__ignore_case

zerg_add -q PARSER "notgood" --action store_true --help "Bad name, add should fail."
#[ $ZERG_V ] && typeset -p PARSER__quiet

[ -v PARSER__quiet ] || warn "PARSER__quiet def missing"
[ -v verbose ] || warn "PARSER__verbose def missing"
[ -v PARSER__i ] && warn "PARSER__i def unexpected"
[ -v PARSER__ignore_case ] || warn "PARSER__ignore_case def missing"

warn "====Testing parse"
zerg_parse PARSER --verbose --silent -i hello.txt file2.txt

aa_export PARSER__results
[[ $PARSER__results[quiet] == "1" ]] || warn "Result for 'quiet' failed."
[[ $PARSER__results[verbose] == "1" ]] || warn "Result for 'verbose' failed."
[[ $PARSER__results[maxChar] == "999" ]] || warn "Result for 'maxChar' failed."
[[ $PARSER__results[case_ig] == "1" ]] || warn "Result for 'case_ig' failed."

warn "====Testing zerg_to_argparse"
ap=`zerg_to_argparse PARSER`
print $ap

warn "====Testing zerg_to_case"
ca=`zerg_to_case PARSER`
print $ca


###############################################################################
# Types
#
if [ $TEST_TYPES ]; then
    warn 1 "====Adding args for many types and actions."

    zerg_add PARSER "--minChar" --type int --default 0 \
        --help "When displaying a range of code points \ skip any below this."
    [ $ZERG_V ] && typeset -p PARSER__minChar

    zerg_add PARSER "--charSpecs" --type anyInt --nargs remainder --help \
         "Unicode code point numbers (base 8 \ 10 \ or 16)."
    [ $ZERG_V ] && typeset -p PARSER__charSpecs

    zerg_add PARSER "--category" --type str --action store --default "aardvark" \
        --choices "aardvark basilisk catoblepus dog" \
        --help "List stuff in the specified category."
    [ $ZERG_V ] && typeset -p PARSER__category

    for cur in ${(ko)zerg_types}; do
        # Presently no types have [-_], but be thorough in case.
        local cur_opt=$cur:gs/_/-/
        #warn 1 "*** Adding arg --type '$cur' and --$cur_opt."
        zerg_add PARSER "--${cur_opt}-o1" --type $cur
        zerg_add PARSER "--${cur_opt}-o2" --$cur_opt --dest result_${cur}_o1
        #[ -n $ZERG_V ] && typeset -p PARSER__${cur}_o1
        is_zergtypename $cur || warn "Type didn't pass: '$cur'."
        #is_of_zerg_type -q $cur 99
        #(( $? > 1 )) && warn "is_of_zerg_type problem for type '$cur'."
        #is_$cur -q 99
        #(( $? > 1 )) && warn "is_$cur problem."
    done
fi

if [ $TEST_ACTIONS ]; then
    for cur in ${(ko)zerg_actions}; do
        [[ $cur == switches ]] && continue  # test separately
        local cur_opt=$cur:gs/_/-/
        #warn 1 "*** Adding arg via --action '$cur' as --${cur_opt}-o1."
        zerg_add PARSER "--${cur_opt}-o1" --action $cur
        #warn 1 "    And short way --$cur_opt, as --${cur_opt}-o2"
        if [[ $cur != help ]]; then
            zerg_add PARSER "--${cur_opt}-o2" "--$cur_opt" --dest "result_${cur}_o1"
            #[ $ZERG_V ] && typeset -p PARSER__${cur}_o1
        fi
    done
fi

if [ $TEST_TOGGLE ]; then
fi


###############################################################################
### Test re-use

warn "====Testing parse again"
zerg_new PAR2 --var-style assoc
zerg_add PAR2 "--verbose -v" --count
zerg_add PAR2 "--category" --type str --choices "aardvark basilisk catoblepus dog" \
    --help "List stuff in the specified category."
zerg_add PAR2 "--uchar" --hexint --default 0x2002

aa_export PAR2

zerg_parse PAR2 -v -v -v --category basilisk --uchar 0xBEEf hello.txt

aa_export PAR2__results

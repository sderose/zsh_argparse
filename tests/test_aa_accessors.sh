#!/bin/zsh
#

FAILCT=0
v=0  # verbose
[[ $1 == "-v" ]] && v=1


###############################################################################
#
source test_funcs.sh
source ../zerg_setup.sh

# Test general shell variable (sv_) functions.


tHead "Testing zsh_type"
if [ ${(t)aav_x} ] || [ ${(t)NOBODY_HOME} ]; then
    #warn 0 "aav_x already exists, cancelling $0...."
    #return 99
fi

unset NOBODY_HOME aav_x aav_y aav_phi aav_arr aav_asc aav_colors

testOutput 'undef' zsh_type NOBODY_HOME
local aav_x="foo"
testOutput 'scalar' zsh_type aav_x
local -i aav_y=134217727
testOutput 'integer' zsh_type aav_y
local -x -F aav_phi=1.6180338
testOutput 'float' zsh_type aav_phi
local -a aav_arr=(1 2 3 d e f 3.14)
testOutput 'array' zsh_type aav_arr
local -A aav_asc=( [green]=2 [magenta]="a mixture" [red]=1 )
testOutput 'assoc' zsh_type aav_asc


###############################################################################
# Test the associative array stuff.

#set -x

unset VN AAA
VN="AAA"

tHead "Testing init/set/etc."
testRC FAIL aa_get -q $VN no_var

testRC 0 aa_init $VN
testOutput 0 aa_len $VN

testRC 0 aa_set $VN foo 1
testOutput "1" aa_get AAA foo

testRC 0 aa_set $VN pi 3.14159
warn 1 "\$VN is set to var name '$VN', typeset gives:"
testOutput "3.14159" aa_get AAA pi

testRC 0 aa_set $VN greet "hello, there"
testOutput "hello, there" aa_get AAA greet

#typeset -p $VN
testOutput 3 aa_len $VN


tHead "Testing Lengths"
#testOutput 2 ${(P)#VN}
testOutput 3 aa_len $VN

testOutput "hello, there" aa_get $VN greet

testOutput "dval" aa_get -d dval $VN not_a_key


tHead "Getting non-item"
testRC FAIL aa_get -q $VN nope
#echo "Did we see em?"


tHead "Testing has/unset"
#typeset -p $VN
testRC 0 aa_has $VN greet
#echo "unsetting 'greet'"
testRC 0 aa_unset $VN greet
#typeset -p $VN

testRC FAIL aa_has -q $VN greet
testRC FAIL aa_get -q $VN greet
#typeset -p $VN


tHead "Testing keys/values/clear"
testRC PASS aa_keys $VN
testRC PASS aa_values $VN
testRC PASS aa_clear $VN
testOutput "0"  aa_len $VN
#typeset -p $VN


###############################################################################
#
tHead "Testing sv_quote"
testRC FAIL sv_quote -q NOBODY_HOME
testOutput "'foo'" sv_quote aav_x
testOutput "134217727" sv_quote aav_y
testOutput "1.6180338000" sv_quote aav_phi
testOutput "1 2 3 'd' 'e' 'f' 3.14" sv_quote aav_arr
testOutput "'a mixture' 1 2" sv_quote aav_asc

local -A aav_colors=( [magenta]="a mixture" [red]=1 [green]="2" )
testRC PASS aa_eq aav_asc aav_colors


tHead "Testing sv_tostring"
testRC FAIL sv_tostring -q NOBODY_HOME
testOutput "foo" sv_tostring aav_x
testOutput "134217727" sv_tostring aav_y
testOutput "1.6180338000" sv_tostring aav_phi
testOutput "( 1 2 3 d e f 3.14 )" sv_tostring aav_arr

local aa_ascStr=`typeset -p aav_asc | sed 's/^[^=]*=//'`
#echo "\$aa_ascStr is: $aa_ascStr"
testOutput "$aa_ascStr" sv_tostring aav_asc


tHead "Testing str_escape"
s="A \"string\" with 'apos', &, <, ]]>, and \\."
testRC FAIL str_escape -q -f xyzzy
testOutput "A &quot;string&quot; with 'apos', &amp;, &lt;, ]]&gt;, and \\." str_escape "$s"
testOutput "A &quot;string&quot; with 'apos', &amp;, &lt;, ]]&gt;, and \." str_escape -f html -- "$s"
testOutput "A \\\"string\\\" with 'apos', &, <, ]]>, and \\." str_escape -q -f json "$s"
testOutput "A \\\"string\\\" with 'apos', &, <, ]]>, and \\." str_escape -q -f python "$s"

unset ap q bs
local ap="\\'"
local q='"'
local bs="\\"
testOutput 'A\ \"string\"\ with\ '"\\'apos\\'"',\ \&,\ \<,\ \]\]\>,\ and\ '"\\." str_escape -f zsh -- "$s"
testOutput "A+%22string%22+with+%27apos%27%2C+%26%2C+%3C%2C+%5D%5D%3E%2C+and+%5C." str_escape -f url -- "$s"

# TODO utf8

tHead "Testing find_key"

typeset -A spam=( b 1 bat 3 bath 4 bathySPHere 11 cat 3 catoblepus 10 )
testOutput b aa_find_key spam b
testOutput "" aa_find_key spam ba
testOutput bat aa_find_key spam bat
testOutput bath aa_find_key spam bath
testOutput bathySPHere aa_find_key spam bathy
testOutput "" aa_find_key spam bathysphere
testOutput catoblepus aa_find_key spam catoblepus
testOutput "" aa_find_key spam doppleganger

testOutput b aa_find_key -i spam B
testOutput "" aa_find_key -i spam bA
testOutput bat aa_find_key -i spam BAT
testOutput bath aa_find_key -i spam bath
testOutput bathySPHere aa_find_key -i spam baThy
testOutput bathySPHere aa_find_key -i spam bathysphere
testOutput catoblepus aa_find_key -i spam catoblepus
testOutput "" aa_find_key -i spam DoppleGanger



tHead "Testing aa_export"

unset htmltableForm htmldlForm jsonForm pythonForm zshForm
htmltableForm='<table id="aav_asc">
    <thead><tr><th>Key</th><th>Value</th></tr></thead>
    <tbody>
    <tr><td>magenta</td><td>a mixture</td></tr>
    <tr><td>red</td><td>1</td></tr>
    <tr><td>green</td><td>2</td></tr>
    </tbody>
</table>'
testOutput "$htmltableForm" aa_export -f htmltable --lines aav_asc

htmldlForm='<dl id="aav_asc">
    <dt>magenta</dt><dd>a mixture</dd>
    <dt>red</dt><dd>1</dd>
    <dt>green</dt><dd>2</dd>
</dl>'
testOutput "$htmldlForm" aa_export --format htmldl --lines aav_asc

jsonForm='{"magenta": "a mixture", "red": "1", "green": "2"}'
testOutput "$jsonForm" aa_export -f json aav_asc

pythonForm='aav_asc = {"magenta": "a mixture", "red": "1", "green": "2"}'
testOutput "$pythonForm" aa_export -f python aav_asc

zshForm="( [magenta]=\"a mixture\" [red]=1 [green]=2 )"
testOutput "$zshForm" aa_export -f zsh aav_asc


tHead "Total fails: $FAILCT."

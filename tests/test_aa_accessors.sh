#!/bin/zsh
#

FAILCT=0
v=0  # verbose
[[ $1 == "-v" ]] && v=1


###############################################################################
#
source test_funcs.sh
tHead "Testing setup"
source ../zerg_setup.sh


# Test general shell variable (sv_) functions.

tHead "Testing sv_type"
if [ ${(t)x} ] || [ ${(t)NOBODY_HOME} ]; then
    tMsg 0 "x already exists...."
    return 99
fi
testOutput 'undef' sv_type NOBODY_HOME
local x="foo"
testOutput 'scalar' sv_type x
local -i y=134217727
testOutput 'integer' sv_type y
local -x -F phi=1.6180338
testOutput 'float' sv_type phi
local -a arr=(1 2 3 d e f 3.14)
testOutput 'array' sv_type arr
local -A asc=( [green]=2 [magenta]="a mixture" [red]=1 )
testOutput 'assoc' sv_type asc


tHead "Testing sv_quote"
testRC FAIL sv_quote NOBODY_HOME
testOutput "foo" sv_quote x
testOutput "134217727" sv_quote y
testOutput "1.6180338000" sv_quote phi
testOutput "1 2 3 d e f 3.14" sv_quote arr
testOutput "a\ mixture 1 2" sv_quote asc

local -A colors=( [magenta]="a mixture" [red]=1 [green]="2" )
testRC PASS aa_eq asc colors

tHead "Testing sv_tostring"
testRC FAIL sv_tostring NOBODY_HOME
testOutput "foo" sv_tostring x
testOutput "134217727" sv_tostring y
testOutput "1.6180338000" sv_tostring phi
testOutput "( 1 2 3 d e f 3.14 )" sv_tostring arr

local ascStr=`typeset -p asc | sed 's/^[^=]*=//'`
#echo "\$ascStr is: $ascStr"
testOutput "$ascStr" sv_tostring asc

tHead "Testing str_escape"
s="A \"string\" with 'apos', &, <, ]]>, and \\."
testRC FAIL str_escape -f xyzzy
testOutput "A &quot;string&quot; with 'apos', &amp;, &lt;, ]]&gt;, and \\." str_escape "$s"
testOutput "A &quot;string&quot; with 'apos', &amp;, &lt;, ]]&gt;, and \." str_escape -f html "$s"
testOutput "A \\\"string\\\" with 'apos', &, <, ]]>, and \\." str_escape -f json "$s"
testOutput "A \\\"string\\\" with 'apos', &, <, ]]>, and \\." str_escape -f python "$s"
local ap="\\'" q='"' bs="\\"
testOutput 'A\ \"string\"\ with\ '"\\'apos\\'"',\ \&,\ \<,\ \]\]\>,\ and\ '"\\." str_escape -f typeset "$s"
testOutput "A+%22string%22+with+%27apos%27%2C+%26%2C+%3C%2C+%5D%5D%3E%2C+and+%5C." str_escape -f url "$s"

# TODO utf8

tHead "Testing aa_export"
htmltableForm='<table id="asc">
<thead><tr><th>Key</th><th>Value</th></tr></thead>
<tbody>
<tr><td>magenta</td><td>a mixture</td></tr>
<tr><td>red</td><td>1</td></tr>
<tr><td>green</td><td>2</td></tr>
</tbody>
</table>'

htmldlForm='<dl id="asc">
<dt>magenta</dt>
<dd>a mixture</dd>
<dt>red</dt>
<dd>1</dd>
<dt>green</dt>
<dd>2</dd>
</dl>'

jsonForm='{"magenta": "a mixture", "red": "1", "green": "2"}'

pythonForm='asc = {"magenta": "a mixture", "red": "1", "green": "2"}'

typesetForm="( [magenta]=a\ mixture [red]=1 [green]=2 )"

testOutput "$htmltableForm" aa_export -f htmltable asc
testOutput "$htmldlForm" aa_export -f htmldl asc
testOutput "$jsonForm" aa_export -f json asc
testOutput "$pythonForm" aa_export -f python asc
testOutput "$typesetForm" aa_export -f typeset asc


###############################################################################
# Test the assoc array stuff.

#set -x

VN="AAA"

tHead "Testing init/set/etc."
testRC FAIL aa_get $VN no_var

testRC 0 aa_init $VN
testOutput 0 aa_len $VN
testRC 0 aa_set $VN foo 1
testRC 0 aa_set $VN greet "hello, there"
testRC 0 aa_set $VN pi 3.14159
tMsg 1 "\$VN is set to var name '$VN', typeset gives:"
typeset -p $VN
testOutput 3 aa_len $VN

tHead "Testing Lengths"
#testOutput 2 ${(P)#VN}
testOutput 3 aa_len $VN

testOutput "hello,\\ there" aa_get $VN greet

testOutput "dval" aa_get -d dval $VN not_a_key

tHead "Getting non-item"
testRC 1 aa_get $VN nope
echo "Did we see em?"

tHead "Testing has/unset"
typeset -p $VN
testRC 0 aa_has $VN greet
echo "unsetting 'greet'"
testRC 0 aa_unset $VN greet
typeset -p $VN

testRC FAIL aa_has $VN greet
testRC FAIL aa_get $VN greet

typeset -p $VN

tHead "Testing keys/values/clear"
testRC PASS aa_keys $VN
testRC PASS aa_values $VN
testRC PASS aa_clear $VN
testOutput "0"  aa_len $VN
typeset -p $VN

tHead "Total fails: $FAILCT."

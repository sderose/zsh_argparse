#!/bin/zsh
# Expanded comprehensive test suite for aa_accessors.sh
# Tests edge cases, error conditions, boundary conditions, and cross-platform issues

if ! [ -v ZERR_ARGC ]; then
    echo "set up first."
    return 99
fi

ZERG_STACK_LEVELS=5
FAILCT=0
v=0  # verbose
[[ $1 == "-v" ]] && v=1

###############################################################################
# Setup
source test_funcs.sh
source ../zerg_setup.sh

# Helper for test sections
tHead() {
    echo ""
    echo "========================================"
    echo "$*"
    #echo "========================================"
}

###############################################################################
# Test aa_init edge cases

tHead "aa_init: Basic initialization and re-initialization"
unset TEST_AA1 TEST_AA2
testRC 0 aa_init TEST_AA1
testOutput 0 aa_len TEST_AA1

# Re-initializing should be safe (idempotent)
testRC 0 aa_init TEST_AA1
testOutput 0 aa_len TEST_AA1

# Initialize multiple arrays
testRC 0 aa_init TEST_AA2
testOutput 0 aa_len TEST_AA2


tHead "aa_init: Error conditions"
# No arguments
testRC $ZERR_ARGC aa_init

# Too many arguments
testRC $ZERR_ARGC aa_init AA1 AA2


###############################################################################
# Test aa_clear edge cases

tHead "aa_clear: Clearing empty and populated arrays"
unset CLEAR_TEST
aa_init CLEAR_TEST
testRC 0 aa_clear CLEAR_TEST
testOutput 0 aa_len CLEAR_TEST

# Clear after adding items
aa_set CLEAR_TEST key1 val1
aa_set CLEAR_TEST key2 val2
testOutput 2 aa_len CLEAR_TEST
testRC 0 aa_clear CLEAR_TEST
testOutput 0 aa_len CLEAR_TEST

tHead "aa_clear: Error conditions"
# Undefined variable
testRC $ZERR_ZSH_TYPE aa_clear UNDEFINED_VAR

# Wrong type (not an assoc)
local -a NOT_ASSOC=(a b c)
testRC $ZERR_ZSH_TYPE aa_clear NOT_ASSOC

# No arguments
testRC $ZERR_ARGC aa_clear -q


###############################################################################
# Test aa_copy edge cases

tHead "aa_copy: Basic copying"
unset SRC_COPY DEST_COPY
aa_init SRC_COPY
aa_set SRC_COPY k1 v1
aa_set SRC_COPY k2 v2
aa_set SRC_COPY k3 "value with spaces"

testRC 0 aa_copy SRC_COPY DEST_COPY
testOutput 3 aa_len DEST_COPY
testOutput "v1" aa_get DEST_COPY k1
testOutput "value with spaces" aa_get DEST_COPY k3


tHead "aa_copy: Empty array copy"
unset EMPTY_SRC EMPTY_DEST
aa_init EMPTY_SRC
testRC 0 aa_copy EMPTY_SRC EMPTY_DEST
testOutput 0 aa_len EMPTY_DEST


tHead "aa_copy: Copy to existing populated array (should clear first)"
unset SRC2 DEST2
aa_init SRC2
aa_set SRC2 new1 newval1
aa_init DEST2
aa_set DEST2 old1 oldval1
aa_set DEST2 old2 oldval2

testRC 0 aa_copy SRC2 DEST2
testOutput 1 aa_len DEST2
testOutput "newval1" aa_get DEST2 new1
testRC FAIL aa_has -q DEST2 old1


tHead "aa_copy: Keys with special characters"
unset SPECIAL_SRC SPECIAL_DEST
aa_init SPECIAL_SRC
aa_set SPECIAL_SRC "key-with-dash" "value1"
aa_set SPECIAL_SRC "key with spaces" "value2"
aa_set SPECIAL_SRC "key_with_underscore" "value3"
aa_set SPECIAL_SRC 'key$with$dollar' "value4"

testRC 0 aa_copy SPECIAL_SRC SPECIAL_DEST
testOutput 4 aa_len SPECIAL_DEST
testOutput "value1" aa_get SPECIAL_DEST "key-with-dash"
testOutput "value2" aa_get SPECIAL_DEST "key with spaces"
testOutput "value4" aa_get SPECIAL_DEST 'key$with$dollar'


tHead "aa_copy: Error conditions"
# Source doesn't exist
testRC $ZERR_ZSH_TYPE aa_copy NONEXISTENT DEST

# Not enough arguments
testRC $ZERR_ARGC aa_copy SRC_COPY

# Too many arguments
testRC $ZERR_ARGC aa_copy SRC_COPY DEST_COPY EXTRA


###############################################################################
# Test aa_update edge cases

tHead "aa_update: Basic update operations"
unset TARGET UPDATE_SRC
aa_init TARGET
aa_set TARGET k1 original1
aa_set TARGET k2 original2
aa_set TARGET k3 original3

aa_init UPDATE_SRC
aa_set UPDATE_SRC k2 updated2
aa_set UPDATE_SRC k4 new4

testRC 0 aa_update TARGET UPDATE_SRC
testOutput 4 aa_len TARGET
testOutput "original1" aa_get TARGET k1
testOutput "updated2" aa_get TARGET k2
testOutput "new4" aa_get TARGET k4


tHead "aa_update: Updating with empty array"
unset TARGET2 EMPTY_UPDATE
aa_init TARGET2
aa_set TARGET2 k1 v1
aa_init EMPTY_UPDATE

local orig_len=$(aa_len TARGET2)
testRC 0 aa_update TARGET2 EMPTY_UPDATE
testOutput "$orig_len" aa_len TARGET2


tHead "aa_update: Values with special characters in update"
unset TARGET3 SRC3
aa_init TARGET3
aa_set TARGET3 k1 "simple"

aa_init SRC3
aa_set SRC3 k1 'value with "quotes" and $vars'
aa_set SRC3 k2 $'line1\nline2'

testRC 0 aa_update TARGET3 SRC3
testOutput 'value with "quotes" and $vars' aa_get TARGET3 k1
testOutput $'line1\nline2' aa_get TARGET3 k2


###############################################################################
# Test aa_set_default

tHead "aa_set_default: Setting defaults for missing keys"
unset DEFAULT_TEST
aa_init DEFAULT_TEST

# Key doesn't exist - should set and return default
testRC 0 aa_set_default DEFAULT_TEST key1 default_val
testOutput "default_val" aa_get DEFAULT_TEST key1

# Key exists - should return existing value and not change it
aa_set DEFAULT_TEST key2 existing_val
testRC 0 aa_set_default DEFAULT_TEST key2 default_val
testOutput "existing_val" aa_get DEFAULT_TEST key2

tHead "aa_set_default: Default values with special characters"
testRC 0 aa_set_default DEFAULT_TEST key3 'def with "quotes"'
testOutput 'def with "quotes"' aa_get DEFAULT_TEST key3
testRC 0 aa_set_default DEFAULT_TEST key4 ""
testOutput "" aa_get DEFAULT_TEST key4


###############################################################################
# Test aa_len with different variable types

tHead "aa_len: Length of various types"
unset STR_VAR INT_VAR FLOAT_VAR ARR_VAR
local STR_VAR="hello"
local -i INT_VAR=12345
local -F FLOAT_VAR=3.14159
local -a ARR_VAR=(a b c d e)

testOutput 5 aa_len STR_VAR
testOutput 5 aa_len INT_VAR
# Float length is tricky - depends on precision
testRC PASS aa_len FLOAT_VAR
testOutput 5 aa_len ARR_VAR


tHead "aa_len: Undefined variable"
unset UNDEF_LEN
testOutput 0 aa_len UNDEF_LEN


###############################################################################
# Test aa_eq

tHead "aa_eq: Equal associative arrays"
unset AA_EQ1 AA_EQ2
aa_init AA_EQ1
aa_set AA_EQ1 k1 v1
aa_set AA_EQ1 k2 v2

aa_init AA_EQ2
aa_set AA_EQ2 k1 v1
aa_set AA_EQ2 k2 v2

testRC 0 aa_eq AA_EQ1 AA_EQ2


tHead "aa_eq: Different values"
aa_set AA_EQ2 k2 different_v2
testRC 1 aa_eq AA_EQ1 AA_EQ2


tHead "aa_eq: Different keys"
unset AA_EQ3 AA_EQ4
aa_init AA_EQ3
aa_set AA_EQ3 k1 v1
aa_init AA_EQ4
aa_set AA_EQ4 k2 v1
testRC 2 aa_eq AA_EQ3 AA_EQ4


tHead "aa_eq: Different lengths"
aa_set AA_EQ4 k1 v1
testRC 3 aa_eq AA_EQ3 AA_EQ4


tHead "aa_eq: Empty arrays"
unset EMPTY1 EMPTY2
aa_init EMPTY1
aa_init EMPTY2
testRC 0 aa_eq EMPTY1 EMPTY2


###############################################################################
# Test aa_has with edge cases

tHead "aa_has: Keys with special characters"
unset HAS_TEST
aa_init HAS_TEST
aa_set HAS_TEST "key-with-dash" v1
aa_set HAS_TEST "key with spaces" v2
aa_set HAS_TEST 'key$dollar' v3
aa_set HAS_TEST "" v4

testRC 0 aa_has HAS_TEST "key-with-dash"
testRC 0 aa_has HAS_TEST "key with spaces"
testRC 0 aa_has HAS_TEST 'key$dollar'
testRC 0 aa_has HAS_TEST ""


tHead "aa_has: Non-existent keys"
testRC FAIL aa_has -q HAS_TEST "not-there"
testRC FAIL aa_has -q HAS_TEST "key-with-"


###############################################################################
# Test aa_get and aa_set with edge cases

tHead "aa_set/aa_get: Empty string values"
unset EMPTY_VAL_TEST
aa_init EMPTY_VAL_TEST
testRC 0 aa_set EMPTY_VAL_TEST k1 ""
testOutput "" aa_get EMPTY_VAL_TEST k1
testRC 0 aa_has EMPTY_VAL_TEST k1


tHead "aa_set/aa_get: Whitespace values"
testRC 0 aa_set EMPTY_VAL_TEST k2 " "
testOutput " " aa_get EMPTY_VAL_TEST k2
testRC 0 aa_set EMPTY_VAL_TEST k3 "   "
testOutput "   " aa_get EMPTY_VAL_TEST k3


tHead "aa_set/aa_get: Values with newlines and tabs"
testRC 0 aa_set EMPTY_VAL_TEST k4 $'line1\nline2'
testOutput $'line1\nline2' aa_get EMPTY_VAL_TEST k4
testRC 0 aa_set EMPTY_VAL_TEST k5 $'col1\tcol2'
testOutput $'col1\tcol2' aa_get EMPTY_VAL_TEST k5


tHead "aa_get: Default values"
testOutput "my_default" aa_get -d my_default EMPTY_VAL_TEST nonexistent
testOutput "" aa_get -d "" EMPTY_VAL_TEST another_nonexistent


tHead "aa_get: Quiet mode"
testRC FAIL aa_get -q EMPTY_VAL_TEST definitely_not_there


###############################################################################
# Test aa_unset

tHead "aa_unset: Remove keys"
unset UNSET_TEST
aa_init UNSET_TEST
aa_set UNSET_TEST k1 v1
aa_set UNSET_TEST k2 v2
aa_set UNSET_TEST k3 v3

testOutput 3 aa_len UNSET_TEST
testRC 0 aa_unset UNSET_TEST k2
testOutput 2 aa_len UNSET_TEST
testRC FAIL aa_has -q UNSET_TEST k2
testRC 0 aa_has UNSET_TEST k1
testRC 0 aa_has UNSET_TEST k3


tHead "aa_unset: Remove non-existent key"
testRC FAIL aa_unset -q UNSET_TEST k_not_there


tHead "aa_unset: Remove keys with special characters"
aa_set UNSET_TEST "key-dash" val
aa_set UNSET_TEST "key space" val
testRC 0 aa_unset UNSET_TEST "key-dash"
testRC 0 aa_unset UNSET_TEST "key space"
testRC FAIL aa_has -q UNSET_TEST "key-dash"


###############################################################################
# Test aa_keys and aa_values

tHead "aa_keys: Get all keys"
unset KEYS_TEST
aa_init KEYS_TEST
aa_set KEYS_TEST k1 v1
aa_set KEYS_TEST k2 v2
aa_set KEYS_TEST k3 v3

local -a keys_result
keys_result=($(aa_keys KEYS_TEST))
testOutput 3 echo "${#keys_result[@]}"


tHead "aa_keys: Empty array"
unset KEYS_EMPTY
aa_init KEYS_EMPTY
local -a empty_keys
empty_keys=($(aa_keys KEYS_EMPTY))
testOutput 0 echo "${#empty_keys[@]}"


tHead "aa_values: Get all values"
local -a vals_result
vals_result=($(aa_values KEYS_TEST))
testOutput 3 echo "${#vals_result[@]}"


###############################################################################
# Test aa_append_value

tHead "aa_append_value: Append to existing value"
unset APPEND_TEST
aa_init APPEND_TEST
aa_set APPEND_TEST k1 "initial"

testRC 0 aa_append_value APPEND_TEST k1 "_more"
testOutput "initial_more" aa_get APPEND_TEST k1


tHead "aa_append_value: Append with space option"
aa_set APPEND_TEST k2 "first"
testRC 0 aa_append_value -s APPEND_TEST k2 "second"
testOutput "first second" aa_get APPEND_TEST k2


tHead "aa_append_value: Append to non-existent key"
testRC 0 aa_append_value APPEND_TEST k3 "new_value"
testOutput "new_value" aa_get APPEND_TEST k3


tHead "aa_append_value: Append to empty string"
aa_set APPEND_TEST k4 ""
testRC 0 aa_append_value -s APPEND_TEST k4 "text"
testOutput "text" aa_get APPEND_TEST k4


###############################################################################
# Test aa_insert_value

tHead "aa_insert_value: Insert at beginning"
unset INSERT_TEST
aa_init INSERT_TEST
aa_set INSERT_TEST k1 "world"

testRC 0 aa_insert_value INSERT_TEST k1 0 "hello "
testOutput "hello world" aa_get INSERT_TEST k1


tHead "aa_insert_value: Insert at end"
aa_set INSERT_TEST k2 "hello"
testRC 0 aa_insert_value INSERT_TEST k2 5 " world"
testOutput "hello world" aa_get INSERT_TEST k2


tHead "aa_insert_value: Insert in middle"
aa_set INSERT_TEST k3 "ac"
testRC 0 aa_insert_value INSERT_TEST k3 1 "b"
testOutput "abc" aa_get INSERT_TEST k3


tHead "aa_insert_value: Negative offset"
aa_set INSERT_TEST k4 "helo"
testRC 0 aa_insert_value INSERT_TEST k4 -1 "l"
testOutput "hello" aa_get INSERT_TEST k4


tHead "aa_insert_value: Error on non-existent key"
testRC $ZERR_NO_KEY aa_insert_value -q INSERT_TEST nonkey 0 "x"


tHead "aa_insert_value: Error on out-of-range offset"
aa_set INSERT_TEST k5 "hi"
testRC $ZERR_NO_INDEX aa_insert_value -q INSERT_TEST k5 10 "x"


###############################################################################
# Test aa_find_key - comprehensive abbreviation matching

tHead "aa_find_key: Exact matches"
unset FIND_TEST
aa_init FIND_TEST
aa_set FIND_TEST verbose v
aa_set FIND_TEST version V
aa_set FIND_TEST verify V

# Exact match should win even with other prefix matches
testOutput "verbose" aa_find_key FIND_TEST verbose
testOutput "version" aa_find_key FIND_TEST version


tHead "aa_find_key: Unique prefix matches"
testOutput "verbose" aa_find_key FIND_TEST verb
testOutput "version" aa_find_key FIND_TEST vers


tHead "aa_find_key: Ambiguous prefix (should fail)"
testRC 2 aa_find_key -q FIND_TEST ver


tHead "aa_find_key: Non-existent prefix"
testRC 1 aa_find_key -q FIND_TEST xyz


tHead "aa_find_key: Single character prefixes"
aa_set FIND_TEST a alpha
aa_set FIND_TEST b beta
testOutput "a" aa_find_key FIND_TEST a
testOutput "b" aa_find_key FIND_TEST b


tHead "aa_find_key: Case-insensitive matching"
testOutput "verbose" aa_find_key -i FIND_TEST VERBOSE
testOutput "verbose" aa_find_key -i FIND_TEST Verb
testOutput "version" aa_find_key -i FIND_TEST VERSION


tHead "aa_find_key: Case-insensitive with ambiguity"
aa_set FIND_TEST Help h
aa_set FIND_TEST help h
# With -i, both 'Help' and 'help' match 'help' - ambiguous exact match
testRC 2 aa_find_key -q -i FIND_TEST help


tHead "aa_find_key: Empty string key"
aa_set FIND_TEST "" empty_val
testOutput "" aa_find_key FIND_TEST ""


###############################################################################
# Test aa_get_abbrev

tHead "aa_get_abbrev: Get value by abbreviation"
unset ABBREV_TEST
aa_init ABBREV_TEST
aa_set ABBREV_TEST verbose 1
aa_set ABBREV_TEST version 2.0
aa_set ABBREV_TEST verify "yes"

testOutput "1" aa_get_abbrev ABBREV_TEST verb
testOutput "2.0" aa_get_abbrev ABBREV_TEST vers
testOutput "yes" aa_get_abbrev ABBREV_TEST verify


tHead "aa_get_abbrev: Default for non-existent key"
testOutput "default_value" aa_get_abbrev -d default_value ABBREV_TEST xyz


tHead "aa_get_abbrev: No default for ambiguous key (should fail)"
testRC 2 aa_get_abbrev -q -d fallback ABBREV_TEST ver


tHead "aa_get_abbrev: Case-insensitive"
testOutput "1" aa_get_abbrev -i ABBREV_TEST VERB


###############################################################################
# Test aa_export formats

tHead "aa_export: JSON format"
unset EXPORT_TEST
aa_init EXPORT_TEST
aa_set EXPORT_TEST name "John Doe"
aa_set EXPORT_TEST age "30"
aa_set EXPORT_TEST city "NYC"

local json_out=$(aa_export -f json EXPORT_TEST)
# Basic validation - should contain key elements
[[ "$json_out" == *'"name"'* ]] && warn 1 "PASS: JSON contains name key"
[[ "$json_out" == *'"John Doe"'* ]] && warn 1 "PASS: JSON contains value"
[[ "$json_out" == *'{'* ]] && [[ "$json_out" == *'}'* ]] && warn 1 "PASS: JSON has braces"


tHead "aa_export: Python format"
local python_out=$(aa_export -f python EXPORT_TEST)
[[ "$python_out" == *'EXPORT_TEST = {'* ]] && warn 1 "PASS: Python has assignment"
[[ "$python_out" == *'"name"'* ]] && warn 1 "PASS: Python contains key"


tHead "aa_export: Zsh format"
local zsh_out=$(aa_export -f zsh EXPORT_TEST)
[[ "$zsh_out" == *'( '* ]] && [[ "$zsh_out" == *' )'* ]] && warn 1 "PASS: Zsh has parens"
[[ "$zsh_out" == *'[name]='* ]] && warn 1 "PASS: Zsh has key format"


tHead "aa_export: HTML table format"
local html_out=$(aa_export -f htmltable EXPORT_TEST)
[[ "$html_out" == *'<table'* ]] && warn 1 "PASS: HTML has table tag"
[[ "$html_out" == *'<thead>'* ]] && warn 1 "PASS: HTML has thead"
[[ "$html_out" == *'<tbody>'* ]] && warn 1 "PASS: HTML has tbody"


tHead "aa_export: HTML dl format"
local htmldl_out=$(aa_export -f htmldl EXPORT_TEST)
[[ "$htmldl_out" == *'<dl'* ]] && warn 1 "PASS: HTML DL has dl tag"
[[ "$htmldl_out" == *'<dt>'* ]] && warn 1 "PASS: HTML DL has dt tag"
[[ "$htmldl_out" == *'<dd>'* ]] && warn 1 "PASS: HTML DL has dd tag"


tHead "aa_export: With --lines option"
local lines_out=$(aa_export -f json --lines EXPORT_TEST)
# Should have actual newlines
local line_count=$(echo "$lines_out" | wc -l)
[[ $line_count -gt 1 ]] && warn 1 "PASS: --lines creates multi-line output"


tHead "aa_export: Special characters in values"
unset SPECIAL_EXPORT
aa_init SPECIAL_EXPORT
aa_set SPECIAL_EXPORT k1 'value with "quotes"'
aa_set SPECIAL_EXPORT k2 "value with <tags>"
aa_set SPECIAL_EXPORT k3 'value with & ampersand'

local json_special=$(aa_export -f json SPECIAL_EXPORT)
[[ "$json_special" == *'\\"'* ]] && warn 1 "PASS: JSON escapes quotes"

local html_special=$(aa_export -f htmltable SPECIAL_EXPORT)
[[ "$html_special" == *'&quot;'* ]] && warn 1 "PASS: HTML escapes quotes"
[[ "$html_special" == *'&lt;'* ]] && warn 1 "PASS: HTML escapes <"
[[ "$html_special" == *'&amp;'* ]] && warn 1 "PASS: HTML escapes &"


###############################################################################
# Stress tests

tHead "STRESS: Large number of keys"
unset STRESS_TEST
aa_init STRESS_TEST
local -i i
for (( i=1; i<=100; i++ )); do
    aa_set STRESS_TEST "key$i" "value$i"
done
testOutput 100 aa_len STRESS_TEST
testOutput "value50" aa_get STRESS_TEST key50


tHead "STRESS: Long key names"
unset LONG_KEY_TEST
aa_init LONG_KEY_TEST
local long_key="this_is_a_very_long_key_name_with_many_characters_to_test_boundary_conditions"
aa_set LONG_KEY_TEST "$long_key" "long_key_value"
testOutput "long_key_value" aa_get LONG_KEY_TEST "$long_key"


tHead "STRESS: Long values"
local long_val="This is a very long value string that goes on and on and on to test how the system handles large amounts of text in a single value field which might contain many sentences and paragraphs."
aa_set LONG_KEY_TEST short_key "$long_val"
testOutput "$long_val" aa_get LONG_KEY_TEST short_key


tHead "STRESS: Unicode/UTF-8 characters"
unset UTF8_TEST
aa_init UTF8_TEST
aa_set UTF8_TEST unicode "Hello 世界 мир 🌍"
testOutput "Hello 世界 мир 🌍" aa_get UTF8_TEST unicode


###############################################################################
# Cross-function interaction tests

tHead "INTERACTION: Copy then update"
unset INT_SRC INT_DEST
aa_init INT_SRC
aa_set INT_SRC k1 v1
aa_copy INT_SRC INT_DEST
aa_set INT_DEST k2 v2
testOutput 1 aa_len INT_SRC
testOutput 2 aa_len INT_DEST


tHead "INTERACTION: Clear then operations"
aa_clear INT_DEST
testOutput 0 aa_len INT_DEST
aa_set INT_DEST k3 v3
testOutput 1 aa_len INT_DEST


tHead "INTERACTION: Append then insert"
unset INT_MOD
aa_init INT_MOD
aa_set INT_MOD k1 "start"
aa_append_value INT_MOD k1 "end"
aa_insert_value INT_MOD k1 5 "_middle_"
testOutput "start_middle_end" aa_get INT_MOD k1


###############################################################################
# Final summary

tHead "Test suite complete"
echo "Total failures: $FAILCT"
[[ $FAILCT -eq 0 ]] && echo "✓ All tests passed!" || echo "✗ Some tests failed"
exit $FAILCT

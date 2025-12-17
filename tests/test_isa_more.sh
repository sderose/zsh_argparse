#!/bin/zsh
#
# Stress test for zerg type system
# Tests edge cases, boundary conditions, Unicode, and error handling

if [ -z "$zerg_types" ]; then
    source zerg_setup.sh || { warn "Could not source zerg_setup.sh."; exit 99 }
fi

warn "====STRESS TESTING ZERG TYPE SYSTEM"

local -i total_tests=0 failed_tests=0

# Helper to track test results
run_test() {
    local sep
    if [[ "$1" == "--" ]]; then
        sep=1
        shift
    fi
    local expect_pass=$1  # "pass" or "fail"
    if ! [[ $expect_pass =~ (pass|fail) ]]; then
        warn "Bad pass/fail arg '$expect_pass' in $*."
    fi
    local type_name=$2
    local desc=$@[-1]
    #echo "Desc: $desc. Rest: $@[3,-2]."
    ((total_tests++))
    local test_func="is_$type_name"
    local -a arg_list=($@[3,-2])
    if [ $sep ]; then
        $test_func -q -- "${arg_list[@]}"
    else
        $test_func -q "${arg_list[@]}"
    fi
    local rc=$?
    if [[ $expect_pass == "pass" ]]; then
        if [[ $rc -eq 0 ]]; then
            warn 1 "  ✓ $type_name: $arg_list  # $desc"
            return 0
        else
            warn "  ✗ FAIL: $type_name should accept $arg_list  # $desc (got rc $rc)"
            ((failed_tests++))
            return 1
        fi
    else
        if [[ $rc -ne 0 ]]; then
            warn 1 "  ✓ $type_name rejects: $arg_list  # $desc (got rc $rc)"
            return 0
        else
            warn "  ✗ FAIL: $type_name should reject $arg_list  # $desc"
            ((failed_tests++))
            return 1
        fi
    fi
}


###############################################################################
# INTEGER TYPES - Edge cases and boundaries
###############################################################################

warn "====INTEGER TYPES: Boundary and edge cases"

# Basic int - extremes
run_test pass int "0" "(zero)"
run_test pass int "-2147483648" "(32-bit min)"
run_test pass int "2147483647" "(32-bit max)"
run_test pass int "-9223372036854775808" "(64-bit min)"
run_test pass int "9223372036854775807" "(64-bit max)"
run_test pass int "+42" "(explicit plus)"
run_test fail int "- 5" "(space after sign)"
run_test fail int "1.0" "(has decimal)"
run_test fail int "1e5" "(exponential)"
run_test fail int "" "(empty string)"
run_test fail int "0x10" "(hex without hexint)"
run_test fail int "123abc" "(trailing chars)"

# Hexint - case and format variations
run_test pass hexint "0x0" "(minimal)"
run_test pass hexint "0X0" "(uppercase X)"
run_test pass hexint "0xDEADBEEF" "(mixed case)"
run_test pass hexint "0xffffffff" "(all f)"
run_test pass hexint "0x123456789ABCDEF0" "(long hex)"
run_test fail hexint "0x" "(no digits)"
run_test fail hexint "0xG" "(invalid hex digit)"
run_test fail hexint "DEADBEEF" "(missing 0x prefix)"
run_test fail hexint "0x-FF" "(negative hex)"
run_test fail hexint "0x FF" "(space in hex)"

# Octint - edge cases
run_test pass octint "0o0" "(minimal)"
run_test pass octint "0O777" "(max 3-digit)"
run_test pass octint "0o7777777" "(long octal)"
run_test fail octint "0o8" "(invalid octal digit)"
run_test fail octint "0o" "(no digits)"
run_test fail octint "0777" "(old-style octal)"
run_test fail octint "0o-7" "(negative octal)"

# Binint - edge cases
run_test pass binint "0b0" "(minimal)"
run_test pass binint "0B1" "(uppercase B)"
run_test pass binint "0b11111111" "(8 bits)"
run_test pass binint "0b1111111111111111111111111111111111111111111111111111111111111111" "(64 bits)"
run_test fail binint "0b" "(no digits)"
run_test fail binint "0b2" "(invalid binary digit)"
run_test fail binint "11110000" "(missing 0b prefix)"
run_test fail binint "0b-1" "(negative binary)"

# Anyint - accepts any base
run_test pass anyint "42" "(decimal)"
run_test pass anyint "0xFF" "(hex)"
run_test pass anyint "0o77" "(octal)"
run_test pass anyint "0b1010" "(binary)"
run_test fail anyint "not_a_number" "(text)"

# Unsigned - only non-negative
run_test pass unsigned "0" "(zero)"
run_test pass unsigned "18446744073709551615" "(64-bit unsigned max)"
run_test fail unsigned "-1" "(negative)"
run_test fail unsigned "-0" "(negative zero)"


###############################################################################
# FLOAT TYPES - Precision and special cases
###############################################################################

warn "====FLOAT TYPES: Precision and special cases"

# Basic floats
run_test pass float "0.0" "(zero with decimal)"
run_test pass float "0" "(integer zero)"
run_test pass float ".5" "(leading decimal point)"
run_test pass float "5." "(trailing decimal point)"
run_test pass float "+3.14159" "(explicit plus)"
run_test pass float "-2.71828" "(negative)"
run_test pass float "1.23e10" "(scientific notation)"
run_test pass float "1.23E-10" "(negative exponent)"
run_test pass float "6.022E+23" "(Avogadro)"
run_test pass float "1e100" "(googol)"
run_test pass float "NaN" "(not a number literal)"
run_test pass float "Inf" "(infinity literal)"
run_test pass float "-Inf" "(negative infinity literal)"
run_test fail float "." "(just decimal point)"
run_test fail float "e10" "(missing mantissa)"
run_test fail float "1.2.3" "(two decimal points)"
run_test fail float "1e" "(incomplete exponent)"

# Probability - range constraints
run_test pass prob "0" "(minimum)"
run_test pass prob "1" "(maximum)"
run_test pass prob "0.5" "(middle)"
run_test pass prob "0.0" "(zero with decimal)"
run_test pass prob "1.0" "(one with decimal)"
run_test pass prob "0.000001" "(very small)"
run_test pass prob "0.999999" "(very large)"
run_test fail prob "-0.1" "(negative)"
run_test fail prob "1.1" "(over one)"
run_test fail prob "2" "(integer over one)"

# Log probability - must be non-positive
run_test pass logprob "0" "(zero)"
run_test pass logprob "0.0" "(zero with decimal)"
run_test pass logprob "-1" "(negative)"
run_test pass logprob "-100" "(very negative)"
run_test pass logprob "-1.5e-10" "(scientific notation)"
run_test fail logprob "0.1" "(positive)"
run_test fail logprob "1" "(positive one)"

###############################################################################
# COMPLEX NUMBERS - Format variations
###############################################################################

warn "====COMPLEX NUMBERS: Format variations"

run_test pass complex "3+4j" "(basic)"
run_test pass complex "3+4i" "(i notation)"
run_test pass complex "3+4I" "(uppercase I)"
run_test pass complex "3+4J" "(uppercase J)"
run_test pass complex "-1.5+2.7j" "(negative real)"
run_test pass complex "0+1j" "(purely imaginary)"
run_test pass complex "5+0j" "(purely real)"
run_test pass complex "5" "(real number)"
run_test pass complex "-3.14E-2+1.59E+3j" "(scientific notation)"
run_test pass complex "0-5j" "(subtraction form)"
run_test fail complex "3 + 4j" "(spaces)"
run_test fail complex "3+4" "(missing imaginary unit)"
run_test fail complex "j" "(just imaginary unit)"
run_test fail complex "3+4k" "(wrong imaginary unit)"

###############################################################################
# STRING TYPES - Unicode and special characters
###############################################################################

warn "====STRING TYPES: Unicode and special characters"

# Char - Unicode awareness
run_test pass char "a" "(ASCII)"
run_test pass char "é" "(Latin extended)"
run_test pass char "中" "(CJK)"
run_test pass char "😀" "(emoji)"
run_test pass char "א" "(Hebrew)"
run_test pass char "Ω" "(Greek)"
run_test pass char $'\n' "(newline)"
run_test pass char $'\t' "(tab)"
run_test fail char "ab" "(two ASCII)"
run_test fail char "你好" "(two CJK)"
run_test fail char "" "(empty)"

# Ident - ASCII identifier rules
run_test pass ident "foo" "(simple)"
run_test pass ident "_" "(underscore only)"
run_test pass ident "_private" "(leading underscore)"
run_test pass ident "var123" "(with numbers)"
run_test pass ident "CamelCase" "(mixed case)"
run_test pass ident "CONSTANT_NAME" "(uppercase with underscores)"
run_test fail ident "123var" "(leading number)"
run_test fail ident "my-var" "(hyphen)"
run_test fail ident "my.var" "(dot)"
run_test fail ident "" "(empty)"
#run_test fail ident "if" "(reserved word - but ident doesn't check that)"

# Idents - space-separated identifiers
run_test pass idents "foo bar baz" "(three idents)"
run_test pass idents "a" "(single ident)"
run_test pass idents "x y" "(two idents)"
run_test pass idents "var1 var2 var3 var4 var5" "(many idents)"
run_test fail idents "foo 27 bar" "(bad #2)"
run_test fail idents " foo" "(leading space)"
run_test fail idents "foo " "(trailing space)"
run_test fail idents "" "(empty)"

# Uident - Unicode identifiers
run_test pass uident "café" "(Latin extended)"
run_test pass uident "naïve" "(diaeresis)"
run_test pass uident "resumé" "(acute accent)"
run_test pass uident "Москва" "(Cyrillic)"
run_test pass uident "中文" "(CJK)"
run_test pass uident "_ελληνικά" "(Greek with underscore)"
run_test fail uident "hello-world" "(hyphen)"
run_test fail uident "123abc" "(leading number)"

# Uidents - space-separated Unicode identifiers
run_test pass uidents "café naïve" "(two Unicode idents)"
run_test pass uidents "hello мир 世界" "(mixed scripts)"
run_test fail uidents "café a• naïve" "(bad #2)"

###############################################################################
# IDENTIFIER TYPES - Shell-specific
###############################################################################

warn "====IDENTIFIER TYPES: Shell-specific"

# Argname - command-line option names
run_test -- pass argname "-q" "(short option)"
run_test -- pass argname "-v" "(another short)"
run_test -- pass argname "--quiet" "(long option)"
run_test -- pass argname "--ignore-case" "(long with hyphen)"
run_test -- pass argname "--very-long-option-name" "(very long)"
run_test -- pass argname "+x" "(plus option)"
run_test -- fail argname "q" "(no hyphen)"
run_test -- fail argname "--" "(double hyphen only)"
run_test -- fail argname "-" "(single hyphen only)"
run_test -- fail argname "---bad" "(triple hyphen)"
run_test -- fail argname "--9bad" "(starts with number)"
run_test -- fail argname "--bad_option" "(underscore)"
run_test -- fail argname "-ab" "(multi-char short option)"
run_test -- fail argname "==quiet" "(bad punctuation)"
run_test -- fail argname "--this#aint#one" "(bad chars)"
run_test -- fail argname "--not_underscore" "(bad chars)"

# Cmdname - existing commands
run_test pass cmdname "ls" "(standard command)"
run_test pass cmdname "cd" "(builtin)"
run_test pass cmdname "print" "(zsh builtin)"
run_test fail cmdname "not_a_real_command_xyz123" "(nonexistent)"
run_test fail cmdname "" "(empty)"

# Reserved words
run_test pass reserved "if" "(if keyword)"
run_test pass reserved "then" "(then keyword)"
run_test pass reserved "fi" "(fi keyword)"
run_test pass reserved "while" "(while keyword)"
run_test pass reserved "do" "(do keyword)"
run_test pass reserved "done" "(done keyword)"
run_test pass reserved "case" "(case keyword)"
run_test pass reserved "[[" "(double bracket)"
run_test fail reserved "grep" "(regular command)"
run_test fail reserved "notakeyword" "(not reserved)"

# Varname - shell variable names
run_test pass varname "PATH" "(existing env var)"
run_test pass varname "HOME" "(another env var)"
run_test fail varname "NOT_A_VAR_XYZ999" "(nonexistent)"
run_test fail varname "" "(empty)"

# Zergtypename - zerg type names
run_test pass zergtypename "int" "(basic type)"
run_test pass zergtypename "float" "(another basic)"
run_test pass zergtypename "datetime" "(complex type)"
run_test pass zergtypename "tensor" "(array type)"
run_test fail zergtypename "integer" "(not a zerg type)"
run_test fail zergtypename "dict" "(Python type, not zerg)"
run_test fail zergtypename "" "(empty)"

###############################################################################
# ZSH ENTITY TYPES - Reified shell constructs
###############################################################################

warn "====ZSH ENTITY TYPES: Reified shell constructs"

# Builtin - shell builtins
run_test pass builtin "cd" "(cd builtin)"
run_test pass builtin "echo" "(echo builtin)"
run_test pass builtin "alias" "(alias builtin)"
run_test pass builtin "setopt" "(zsh-specific)"
run_test fail builtin "ls" "(external command)"
run_test fail builtin "not_a_builtin" "(nonexistent)"

# Function - shell functions
run_test pass function "is_int" "(type checker function)"
run_test pass function "is_of_zerg_type" "(dispatcher function)"
run_test fail function "not_a_function_xyz" "(nonexistent)"
run_test fail function "cd" "(builtin, not function)"

# Alias - shell aliases
# Note: These tests depend on what aliases are defined
# run_test pass alias "ll" "(if ll is defined)"
# run_test fail alias "not_an_alias" "(nonexistent)"

###############################################################################
# PATTERN AND FORMAT TYPES
###############################################################################

warn "====PATTERN AND FORMAT TYPES"

# Regex - basic validation
run_test pass regex ".*" "(any string)"
run_test pass regex "^[a-z]+$" "(lowercase only)"
run_test pass regex "\\d{3}-\\d{4}" "(phone pattern)"
run_test pass regex "[A-Z][a-z]*" "(capitalized)"
run_test pass regex "a|b|c" "(alternation)"
# Most strings are valid regexes, hard to find invalid ones

# URL - various formats
run_test pass url "https://example.com" "(basic HTTPS)"
run_test pass url "http://localhost:8080" "(with port)"
run_test pass url "https://example.com/path/to/resource" "(with path)"
run_test pass url "https://example.com?key=value" "(with query)"
run_test pass url "https://example.com#anchor" "(with fragment)"
run_test pass url "ftp://ftp.example.com/file.txt" "(FTP protocol)"
run_test pass url "https://user:pass@example.com" "(with auth)"
run_test pass url "https://example.com/foo+bar.zap#id1" "(special chars)"
run_test fail url "not a url" "(plain text)"
run_test fail url "" "(empty)"

# Lang - language codes
run_test pass lang "en" "(English)"
run_test pass lang "es" "(Spanish)"
run_test pass lang "zh" "(Chinese)"
run_test pass lang "en-US" "(English US)"
run_test pass lang "en-GB" "(English GB)"
run_test fail lang "" "(empty)"
#run_test fail lang "xyz" "(invalid code)"
run_test fail lang "123" "(numeric)"

# Encoding - character encodings
run_test pass encoding "UTF-8" "(UTF-8)"
run_test pass encoding "ASCII" "(ASCII)"
run_test pass encoding "ISO-8859-1" "(Latin-1)"
run_test pass encoding "UTF-16" "(UTF-16)"
run_test fail encoding "NOT-AN-ENCODING" "(invalid)"
run_test fail encoding "" "(empty)"

# Locale - system locales
run_test pass locale "C" "(C locale)"
run_test pass locale "C.UTF-8" "(C with UTF-8)"
run_test pass locale "en_US.UTF-8" "(US English UTF-8)"
run_test pass locale "en_GB.ISO8859-1" "(UK English Latin-1 no hyphen)"
run_test fail locale "en_GB.ISO-8859-1" "(UK English Latin-1)"
run_test fail locale "invalid_locale" "(invalid)"
run_test fail locale "" "(empty)"

# Format - printf-style format strings
run_test pass format "%s" "(string)"
run_test pass format "%d" "(integer)"
run_test pass format "%f" "(float)"
run_test pass format "%.2f" "(float with precision)"
run_test pass format "%10s" "(width specifier)"
run_test pass format "%-10s" "(left-align)"
run_test pass format "%+d" "(show sign)"
run_test pass format "%#x" "(alternate form)"
run_test pass format "%5.2f" "(width and precision)"
run_test fail format "%z" "(width and precision)"
run_test fail format "%" "(width and precision)"
# Hard to find invalid format strings - most chars are valid


###############################################################################
# TIME AND DATE TYPES
###############################################################################

warn "====TIME AND DATE TYPES"

# Time - HH:MM:SS format
run_test pass time "00:00:00" "(midnight)"
run_test pass time "12:00:00" "(noon)"
run_test pass time "23:59:59" "(end of day)"
run_test pass time "01:30:45" "(arbitrary time)"
run_test pass time "12:00" "(without seconds)"
run_test pass time "23:59:59.999" "(with milliseconds)"
run_test pass time "12:00:00Z" "(with UTC timezone)"
run_test pass time "12:00:00+05:30" "(with timezone offset)"
run_test pass time "12:00:00-08:00" "(negative timezone)"
run_test fail time "1:1:1" "(single digits)"
run_test fail time "24:01:00" "(invalid hour)"
run_test fail time "12:60:00" "(invalid minute)"
run_test fail time "12:00:60" "(invalid second)"
run_test fail time "1:2:3:4" "(too many components)"
run_test fail time "" "(empty)"

# Date - ISO 8601 format
run_test pass date "2025-01-01" "(new year)"
run_test pass date "1970-01-01" "(Unix epoch)"
run_test pass date "9999-12-31" "(far future)"
run_test pass date "2024-02-29" "(leap day)"
run_test pass date "2025-12" "(year-month only)"
run_test pass date "2025" "(year only)"
run_test pass date "0001-01-01" "(year 1)"
run_test fail date "2025-00-01" "(invalid month zero)"
run_test fail date "2025-13-01" "(invalid month 13)"
run_test fail date "2025-01-32" "(invalid day 32)"
run_test fail date "2025-02-30" "(invalid Feb 30)"
run_test fail date "2025-04-31" "(invalid Apr 31)"
run_test fail date "2023-02-29" "(non-leap Feb 29)"
run_test fail date "25-01-01" "(2-digit year)"
run_test fail date "2025/01/01" "(slash separator)"
run_test fail date "0000-01-01" "(year 0)"
run_test fail date "-0004-01-01" "(negative year)"
run_test fail date "19999-01-01" "(big year)"
run_test fail date "1976-0z-ab" "(non-digits)"
run_test fail date "" "(empty)"

# Datetime - ISO 8601 combined
run_test pass datetime "2025-01-01T00:00:00" "(epoch datetime)"
run_test pass datetime "2025-12-31T23:59:59" "(end of year)"
run_test pass datetime "2025-06-15T12:30:45" "(arbitrary)"
run_test pass datetime "2025-01-01T00:00:00Z" "(with UTC)"
run_test pass datetime "2025-01-01T00:00:00+05:30" "(with timezone)"
run_test pass datetime "2025-01-01T00:00:00.123-08:00" "(with milliseconds and tz)"
run_test fail datetime "2025-01-01 12:00:00" "(space separator)"
run_test fail datetime "2025-01-01" "(date only)"
run_test fail datetime "12:00:00" "(time only)"
run_test fail datetime "" "(empty)"

# Duration - ISO 8601 duration
run_test pass duration "P1D" "(one day)"
run_test pass duration "PT1H" "(one hour)"
run_test pass duration "PT1M" "(one minute)"
run_test pass duration "PT1S" "(one second)"
run_test pass duration "P1Y2M3D" "(years, months, days)"
run_test pass duration "PT4H5M6S" "(hours, minutes, seconds)"
run_test pass duration "P1Y2M3DT4H5M6S" "(full duration)"
run_test pass duration "P0D" "(zero duration)"
run_test pass duration "PT0S" "(zero time)"
run_test fail duration "1D" "(missing P prefix)"
run_test fail duration "P" "(P only)"
run_test fail duration "P1W" "(weeks not standard)"
run_test fail duration "PT" "(T without time components)"
run_test fail duration "" "(empty)"

# Epoch - Unix timestamp
run_test pass epoch "0" "(Unix epoch)"
run_test pass epoch "1609459200" "(2021-01-01)"
run_test pass epoch "-1" "(before epoch)"
run_test pass epoch "2147483647" "(32-bit max)"
run_test pass epoch "1609459200.123" "(with fractional seconds)"
run_test fail epoch "not_a_number" "(text)"
run_test fail epoch "" "(empty)"

###############################################################################
# STRESS TESTS - Extreme inputs
###############################################################################

warn "====STRESS TESTS: Extreme inputs"

# Very long strings
local -r long_int="123456789012345678901234567890123456789012345678901234567890"
run_test pass int "$long_int" "(very long integer)"

local -r long_ident="x_$(printf 'a%.0s' {1..200})" # 200+ char identifier
run_test pass ident "$long_ident" "(very long identifier)"

# Empty and whitespace
run_test fail int "" "(empty string for int)"
run_test fail float "" "(empty string for float)"
run_test fail ident "" "(empty string for ident)"
run_test fail char "" "(empty string for char)"
run_test pass str "" "(empty string is valid str)"
run_test fail ident "   " "(whitespace-only ident)"

# Special characters and escaping
run_test pass str "\\n\\t\\r" "(escape sequences)"
run_test pass str '$PATH' "(dollar sign)"
run_test pass str '`echo hi`' "(backticks)"
run_test pass str "a'b\"c" "(mixed quotes)"

# Unicode edge cases
run_test pass char "•" "(rainbow flag emoji - might be multi-codepoint)"
run_test pass uident "café" "(NFC normalization)"
run_test pass uident "café" "(NFD normalization - if different)"

# Number edge cases
run_test pass int "+0" "(positive zero)"
run_test pass int "-0" "(negative zero)"
run_test pass float "0.0" "(float zero)"
run_test pass float "-0.0" "(negative float zero)"
run_test pass float "NaN" "(IEEE special)"
run_test pass float "Inf" "(IEEE special)"
run_test pass float "-Inf" "(IEEE special)"
run_test pass float "1e-324" "(smallest positive float)"
run_test pass float "1.7976931348623157e+308" "(largest float)"
run_test fail float "1.0xy" "(non-digits)"
run_test fail float "e**iπ" "(non-digits)"

# Boundary mixing
run_test fail hexint "0xZZZ" "(invalid hex)"
run_test fail octint "0o999" "(invalid octal)"
run_test fail binint "0b222" "(invalid binary)"


###############################################################################
# TENSOR TYPES - Multi-dimensional array structures
###############################################################################

warn "====TENSOR TYPES: Structure and shape validation"

# Basic tensor structures - no shape validation
run_test pass tensor "( 1 2 3 )" "(1D tensor)"
run_test pass tensor "( (1 2) (3 4) )" "(2x2 tensor)"
run_test pass tensor "( ( (1 2) (3 4) ) ( (5 6) (7 8) ) )" "(2x2x2 tensor)"
run_test pass tensor "( 1.5 2.7 -3.14 )" "(1D with floats)"
run_test pass tensor "( (0.1 0.2 0.3) (0.4 0.5 0.6) )" "(2D with floats)"
run_test pass tensor "( (-1 -2) (3 4) )" "(negative values)"
run_test pass tensor "( (1e5 2e-3) (3.14e2 -1.5e-10) )" "(scientific notation)"

# Edge cases - structure
run_test fail tensor "1 2 3" "(missing outer parens)"
run_test fail tensor "( 1 2 3" "(unclosed parens)"
run_test fail tensor "1 2 3 )" "(unmatched close paren)"
run_test fail tensor "( ( 1 2 ) ( 3 4 )" "(nested unclosed)"
run_test fail tensor "( ( 1 2 ) ) ( 3 4 ) )" "(extra close paren)"
run_test fail tensor "( 1 2 ) ( 3 4 )" "(unenclosed)"
run_test fail tensor "( )" "(empty tensor)"
run_test fail tensor "( ( ) )" "(empty nested)"

# Non-numeric values
run_test fail tensor "( 1 2 abc )" "(text in tensor)"
run_test fail tensor "( (1 2) (3 x) )" "(text in 2D)"
run_test pass tensor "( 1 2 NaN )" "(NaN)"
run_test fail tensor "( 1+2j 3 )" "(complex in tensor - should fail)"

# Shape validation - 1D tensors
run_test pass tensor --shape "3" "( 1 2 3 )" "(1d)"
run_test pass tensor --shape "5" "( 1 2 3 4 5 )" "(1d)"
run_test fail tensor --shape "3" "( 1 2 )" "(wrong length)"
run_test fail tensor --shape "2" "( 1 2 3 )" "(too many elements)"
run_test pass tensor --shape "*" "( 1 2 3 4 5 6 7 )" "(wildcard accepts any)"

# Shape validation - 2D tensors
run_test pass tensor --shape "2 3" "( (1 2 3) (4 5 6) )" "(2x3)"
run_test pass tensor --shape "3 2" "( (1 2) (3 4) (5 6) )" "(3x2)"
run_test fail tensor --shape "2 3" "( (1 2) (3 4) )" "(wrong inner dim)"
run_test fail tensor --shape "2 2" "( (1 2 3) (4 5 6) )" "(wrong inner size)"
run_test fail tensor --shape "3 2" "( (1 2) (3 4) )" "(wrong outer dim)"

# Shape validation - wildcard dimensions
run_test pass tensor --shape "* 3" "( (1 2 3) (4 5 6) )" "(*x3)"
run_test pass tensor --shape "* 3" "( (1 2 3) (4 5 6) (7 8 9) )" "(*x3)"
run_test pass tensor --shape "2 *" "( (1 2 3 4 5) (6 7 8 9 10) )" "(2x*)"
run_test pass tensor --shape "* *" "( (1 2) (3 4 5 6) )" "(*x*)"
run_test fail tensor --shape "* 3" "( (1 2) (4 5 6) )" "(wildcard but wrong inner)"

# Shape validation - 3D tensors
run_test pass tensor --shape "2 2 2" "( ( (1 2) (3 4) ) ( (5 6) (7 8) ) )" "()"
run_test pass tensor --shape "2 3 2" "( ( (1 2) (3 4) (5 6) ) ( (7 8) (9 10) (11 12) ) )"  "()"
run_test fail tensor --shape "2 2 2" "( ( (1 2 3) (4 5 6) ) ( (7 8 9) (10 11 12) ) )" "(wrong innermost)"
run_test fail tensor --shape "2 2 2" "( ( (1 2) (3 4) ) )" "(missing outer group)"

# Shape validation - deep nesting
run_test pass tensor --shape "2 2 2 2" "( ( ( (1 2) (3 4) ) ( (5 6) (7 8) ) ) ( ( (9 10) (11 12) ) ( (13 14) (15 16) ) ) )" "()"
run_test fail tensor --shape "2 2" "( ( (1 2) (3 4) ) ( (5 6) (7 8) ) )" "(too deep for shape)"

# Whitespace and formatting variations
run_test pass tensor "(1 2 3)" "(no spaces around parens)"
run_test pass tensor "(  1  2  3  )" "(extra internal spaces)"
run_test pass tensor "( ( 1 2 ) ( 3 4 ) )" "(spaces everywhere)"
run_test pass tensor --shape "2 2" "((1 2)(3 4))" "(minimal whitespace)"

# Mixed valid/invalid shapes
run_test pass tensor --shape "* 2 *" "( ( (1 2 3) (4 5 6) ) ( (7 8) (9 10) ) )" "()"
run_test fail tensor --shape "2 * 2" "( ( (1 2) (3 4 5) ) ( (6 7) (8 9) ) )" "(middle wildcard but inconsistent)"

# Invalid shape specifications (should fail during shape parsing)
run_test fail tensor --shape "0" "( 1 2 3 )" "(zero dimension)"
run_test fail tensor --shape "-1" "( 1 2 3 )" "(negative dimension)"
run_test fail tensor --shape "2.5" "( 1 2 )" "(float dimension)"
run_test fail tensor --shape "abc" "( 1 2 3 )" "(non-numeric dimension)"

# Real-world-ish examples
run_test pass tensor --shape "3 3" "( (1 0 0) (0 1 0) (0 0 1) )" "(identity matrix)"
run_test pass tensor --shape "2 3" "( (1.5 2.7 3.14) (-0.5 0 1e-10) )" "(float matrix)"
run_test pass tensor --shape "* * *" "( ( (1 2) (3 4) ) ( (5 6 7) (8 9 10 11) ) )" "(ragged tensor)"


###############################################################################
# Summary
###############################################################################

warn "
========================================
STRESS TEST SUMMARY
========================================
Total tests: $total_tests
Passed: $((total_tests - failed_tests))
Failed: $failed_tests
Success rate: $(( (total_tests - failed_tests) * 100 / total_tests ))%
========================================
"

if (( failed_tests > 0 )); then
    warn "⚠️  Some tests failed. Review output above."
    return 1
else
    warn 1 "✅ All stress tests passed!"
    return 0
fi

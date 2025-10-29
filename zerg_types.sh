#!/bin/zsh
# Type-related functions for zerg: a zsh port of Python argparse.

if ! [ $ZERG_SETUP ]; then
    echo "Source zerg_setup.sh first." >&2
    return 99
fi

# Known argument types/forms (distinguishes typed forms like hexint).
# TODO: See help re. possible additions.
# NOTE: I tried to generate a case pattern from this dynamically, but
# the case statement appears not to allow the variable ref. So instead, run:
#     echo ${(k)zerg_types} | sed 's/ /|--/g'
# and "--" to the front, and paste it into the case in zerg_add literally.
# Likewise for actions.
#
typeset -A zerg_types=(
    [int]=int [hexint]=int [octint]=int [anyint]=int
    [bool]=bool
    [float]=float [prob]=float [logprob]=float [complex]=complex
    [str]=str [char]=str [ident]=str [uident]=str [idents]=str [uidents]=str
    [regex]=str [path]=str [url]=str [lang]=str [format]=str
    [time]=time [date]=date [datetime]=datetime
    [duration]=timedelta [epoch]=float
)

is_type_name() {
    if [[ "$1" == "-h" ]]; then
        cat <<EOF
Usage: is_type_name name
Test if the argument is a known zerg datatype name, namely:
    ${(k)zerg_types}
Returns: 0 if valid, 1 if not
EOF
        return
    fi
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    [[ " ${(k)zerg_types[@]} " =~ " $1 " ]] && return 0
    [ $quiet ] || tMsg 0 "is_type_name: '$1' is not a recognized zerg type name."
    return 1
}

# Dispatcher function - calls the appropriate is_* function for a type
is_of_zerg_type() {
    if [[ "$1" == "-h" ]]; then
        cat <<EOF
Usage: is_of_zerg_type typename value
Test if the value matches the given zerg datatype name, one of:
    ${(k)zerg_types}
Returns: 0 if valid, 1 if not
EOF
        return
    fi
    if ! is_type_name "$1"; then
        tMsg 0 "is_of_zerg_type: '$1' is not a recognized zerg type name."
        return 99
    fi
    local testName="is_${(L)1}"
    $testName "$2"
}


###############################################################################
# Type name validation
# Each function validates that a value conforms to a specific type.
# All validators support a -q (quiet) flag to suppress error messages.

# String type validation functions

is_str() {
    return 0
}

is_char() {
    local quiet="" value
    [[ "$1" == "-q" ]] && quiet=1 && shift
    value="$1"
    if [[ ${#value} -ne 1 ]]; then
        [ $quiet ] || tMsg 0 "is_char: '$value' is not a single character"
        return 1
    fi
}

# Identifier patterns
ident_main="[a-zA-Z_][a-zA-Z0-9_]*"
ident_expr="^$ident_main\$"
idents_expr="^$ident_main( +$ident_main)*\$"

is_ident() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    if [[ -z "$1" || ! "$1" =~ $ident_expr ]]; then
        [ $quiet ] || tMsg 0 "is_ident: '$1' is not a valid identifier"
        return 1
    fi
}

is_idents() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    if [[ -z "$1" || ! "$1" =~ $idents_expr ]]; then
        [ $quiet ] || tMsg 0 "is_idents: '$1' is not valid space-separated identifiers"
        return 1
    fi
}

check_re() {
    # Is this a legit regex?
    local regex="$1"
    echo "" | grep -E "$regex" 2>/dev/null
    [[ $? == 0 ]] || [[ $? == 1 ]] || return 1
}

is_regex() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    if ! check_re "$1"; then
        [ $quiet ] || tMsg 0 "is_regex: '$1' is not a valid regular expression"
        return 1
    fi
}

is_path() {
    # TODO Distinguish -e -f -d -r -w -x and (!-e && -d :h && -w :h).
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    # Basic path validation - no null bytes, reasonable characters
    local pathExpr='^/?[._\-$~#a-zA-Z0-9]*(/[._\-$~#a-zA-Z0-9]*)*$'
    if [[ ! "$1" =~ $pathExpr ]]; then
        [ $quiet ] || tMsg 0 "is_path: '$1' does not appear to be a valid path"
        return 1
    fi
}

is_url() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    # Basic url validation: scheme:rest
    if [[ ! "$1" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:.+ ]]; then
        [ $quiet ] || tMsg 0 "is_url: '$1' is not a valid url"
        return 1
    fi
}

is_lang() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    if [[ ! "$1" =~ ^[a-zA-Z][a-zA-Z][a-zA-Z]?(-[a-zA-Z])* ]]; then
        [ $quiet ] || tMsg 0 "is_url: '$1' is not a valid lang code"
        return 1
    fi
}

is_format() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    local expr="^%[-+0 #]*(\\*|\\d+)?(?:\\.(\\*|\\d+))?"
    expr+="[hlLqjzt]*[diouxXeEfFgGaAcspn%]"
    if [[ ! "$1" =~ ($expr) ]]; then
        [ $quiet ] || tMsg 0 "is_url: '$1' is not a valid % format code"
        return 1
    fi
}


# Numeric type validation functions.

is_int() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    if [[ ! "$1" =~ ^-?[0-9]+$ ]]; then
        [ $quiet ] || tMsg 0 "is_int: '$1' is not a valid integer"
        return 1
    fi
}

is_octint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    if [[ ! "$1" =~ ^(0)?[0-7]+$ ]]; then
        [ $quiet ] || tMsg 0 "is_octint: '$1' is not a valid octal integer"
        return 1
    fi
}

is_hexint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    if [[ ! "$1" =~ ^(0x)?[0-9a-fA-F]+$ ]]; then
        [ $quiet ] || tMsg 0 "is_hexint: '$1' is not a valid hexadecimal integer"
        return 1
    fi
}

is_binint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
   if [[ ! "$1" =~ ^(0b)?[01]+$ ]]; then
        [ $quiet ] || tMsg 0 "is_binint: '$1' is not a valid binary integer"
        return 1
    fi
}

is_anyint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    # Try decimal, hex, octal, binary
    if is_int -q "$1" || is_octint -q "$1" ||
       [[ "$1" =~ ^0x[0-9a-fA-F]+$ ]] || [[ "$1" =~ ^0b[01]+$ ]]; then
        return 0
    else
        [ $quiet ] || tMsg 0 "is_anyint: '$1' is not a valid integer (decimal/hex/octal/binary)"
        return 1
    fi
}

is_float() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    if [[ ! "$1" =~ ^-?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$ ]]; then
        [ $quiet ] || tMsg 0 "is_float: '$1' is not a valid float"
        return 1
    fi
}

is_prob() {
    local quiet="" floatexpr="[0-9]*\\.?[0-9]+([eE][+-]?[0-9]+)?"
    [[ "$1" == "-q" ]] && quiet=1 && shift
    if [[ ! "$1" =~ (^${floatexpr}$) ]]; then
        [ $quiet ] || tMsg 0 "is_prob: '$1' is not a valid probability"
        return 1
    elif ! (( $(echo "$1 >= 0.0 && $1 <= 1.0" | bc -l) )); then
        [ $quiet ] || tMsg 0 "is_prob: '$1' must be between 0.0 and 1.0"
        return 1
    fi
}

is_logprob() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    # Log probability must be <= 0 (since log(p) where 0 < p <= 1)
    if ! is_float -q "$1"; then
        [ $quiet ] || tMsg 0 "is_logprob: '$1' is not a valid float"
        return 1
    elif ! (( $(echo "$1 <= 0.0" | bc -l) )); then
        [ $quiet ] || tMsg 0 "is_logprob: '$1' must be <= 0.0"
        return 1
    fi
}

is_complex() {
    local quiet="" floatexpr="[0-9]*\\.?[0-9]+([eE][+-]?[0-9]+)?"
    [[ "$1" == "-q" ]] && quiet=1 && shift
    if [[ ! "$1" =~ (^${floatexpr}(\+${floatexpr}[ij])?$) ]]; then
        [ $quiet ] || tMsg 0 "is_prob: '$1' is not a valid complex"
        return 1
    fi
}

is_bool() {
    local quiet="" value abbrev_ok=""
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: is_bool [value] [alts?]
Test whether the value is a recogized boolean.
By default, only 1 for true and "" for 0.
If alts is set, these are also accepted (ignoring case):
    1 true yes on y
    0 false no off n
TODO Switch [alts] to be a real option.
EOF
        return
    fi
    [[ "$1" == "-q" ]] && quiet=1 && shift
    value="$1"
    alts_ok="$2"
    if [[ -z "$value" || "$value" == "1" ]]; then
        return 0
    fi
    if [ $alts_ok ]; then
        local lower_value="${value:l}"
        case "$lower_value" in
            1|true|yes|on|y) return 0 ;;
            0|false|no|off|n) return 0 ;;
        esac
    fi
    [ $quiet ] || tMsg 0 "is_bool: '$value' is not a valid boolean"
    return 1
}


# Time/date type validation functions
# TODO Add locale forms? locale forms: %c datetime, %x date, %X time
# if strftime -s timestamp -r '%c' "$datestring" 2>/dev/null; then
#     tMsg info "Valid date/time: $datestring -> $timestamp"
#     return 0
# else
#     tMsg error "Invalid date/time: $datestring"
#     return 1
# fi
#
is_time() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    # Basic time format: HH:MM or HH:MM:SS
    if [[ ! "$1" =~ ^[0-2][0-9]:[0-5][0-9](:[0-5][0-9])?$ ]]; then
        [ $quiet ] || tMsg 0 "is_time: '$1' is not a valid time (HH:MM or HH:MM:SS)"
        return 1
    fi
}

is_date() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    # Validate ISO8601 date format
    if ! date -d "$1" "+%s" &>/dev/null 2>&1 &&
       ! date -j -f "%Y-%m-%d" "$1" "+%s" &>/dev/null 2>&1; then
        [ $quiet ] || tMsg 0 "is_date: '$1' is not a valid ISO8601 date"
        return 1
    fi
}

is_datetime() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    # Validate ISO8601 datetime format
    if ! date -d "$1" "+%s" &>/dev/null 2>&1 &&
       ! date -j -f "%Y-%m-%dT%H:%M:%S" "$1" "+%s" &>/dev/null 2>&1; then
        [ $quiet ] || tMsg 0 "is_datetime: '$1' is not a valid ISO8601 datetime"
        return 1
    fi
}

is_duration() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    # Simple duration: number followed by unit (s, m, h, d) TODO: beef it up.
    if [[ ! "$1" =~ ^[0-9]+(\.[0-9]+)?[smhd]$ ]]; then
        [ $quiet ] || tMsg 0 "is_duration: '$1' is not a valid duration (e.g., 5s, 2.5h, 3d)"
        return 1
    fi
}

is_epoch() {
    # Unix epoch time is basically float
    local quiet=""
    [[ "$1" == "-q" ]] && quiet=1 && shift
    if ! is_float "$1"; then
        [ $quiet ] || tMsg 0 "is_epoch: '$1' is not a valid epoch timestamp"
        return 1
    fi
}

# Warn if being run directly vs sourced
if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
    echo "${(%):-%x} is a library file. Source it, don't execute it."
fi

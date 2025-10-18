#!/bin/zsh
# Type validation functions for zsh_argparse
# Each function validates that a value conforms to a specific type.
# All validators support a -q (quiet) flag to suppress error messages.


###############################################################################
# Type name validation
#
is_type_name() {
    if [[ "$1" == "-h" ]]; then
        cat <<EOF
Usage: is_type_name typename
Test if this is a known zsh_argparse type name.
Returns: 0 if valid, 1 if not
EOF
        return
    fi
    [[ " ${zap_types[@]} " =~ " $1 " ]] && return 0
    return 1
}

# Helper to check if a regex is valid
check_re() {
    local regex="$1"
    echo "" | grep -E "$regex" 2>/dev/null
    [[ $? == 0 ]] || [[ $? == 1 ]] || return 1
    return 0
}

# Dispatcher function - calls the appropriate is_* function for a type
is_of_type() {
    if [[ "$1" == "-h" ]]; then
        cat <<EOF
Usage: is_of_type typename value
Test if the value is of the given zap typename, namely:
   $zap_types
Returns: 0 if valid, 1 if not
EOF
        return
    fi

    if ! is_type_name "$1"; then
        tMsg 0 "is_of_type: '$1' is not a recognized zap type name."
        return 99
    fi

    local testName="is_${(L)1}"
    $testName "$2"
}


###############################################################################
# String type validation functions
#
is_str() {
    # String: accepts any value
    return 0
}

is_char() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    if [[ ${#value} -ne 1 ]]; then
        [ $quiet ] || tMSg 0 "is_char: '$value' is not a single character"
        return 1
    fi
    return 0
}

# Identifier patterns
ident_main="[a-zA-Z_][a-zA-Z0-9_]*"
ident_expr="^$ident_main\$"
idents_expr="^$ident_main( +$ident_main)*\$"

is_ident() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    if [[ -z "$value" || ! "$value" =~ $ident_expr ]]; then
        [ $quiet ] || tMSg 0 "is_ident: '$value' is not a valid identifier"
        return 1
    fi
    return 0
}

is_idents() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    if [[ -z "$value" || ! "$value" =~ $idents_expr ]]; then
        [ $quiet ] || tMSg 0 "is_idents: '$value' is not valid space-separated identifiers"
        return 1
    fi
    return 0
}

is_regex() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    if ! check_re "$value"; then
        [ $quiet ] || tMSg 0 "is_regex: '$value' is not a valid regular expression"
        return 1
    fi
    return 0
}

is_path() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    # Basic path validation - no null bytes, reasonable characters
    local pathExpr='^/?[._\-$~#a-zA-Z0-9]*(/[._\-$~#a-zA-Z0-9]*)*$'
    if [[ ! "$value" =~ $pathExpr ]]; then
        [ $quiet ] || tMSg 0 "is_path: '$value' does not appear to be a valid path"
        return 1
    fi
    return 0
}

is_url() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    # Basic URL validation: scheme:rest
    if [[ ! "$value" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:.+ ]]; then
        [ $quiet ] || tMSg 0 "is_url: '$value' is not a valid URL"
        return 1
    fi
    return 0
}

is_lang() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    if [[ ! "$value" =~ ^[a-zA-Z][a-zA-Z][a-zA-Z]?(-[a-zA-Z])*; then
        [ $quiet ] || tMSg 0 "is_url: '$value' is not a valid lang code"
        return 1
    fi
    return 0
}


###############################################################################
# Numeric type validation functions
#
is_int() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
        [ $quiet ] || tMSg 0 "is_int: '$value' is not a valid integer"
        return 1
    fi
    return 0
}

is_octint() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    if [[ ! "$value" =~ ^(0)?[0-7]+$ ]]; then
        [ $quiet ] || tMSg 0 "is_octint: '$value' is not a valid octal integer"
        return 1
    fi
    return 0
}

is_hexint() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    if [[ ! "$value" =~ ^(0x)?[0-9a-fA-F]+$ ]]; then
        [ $quiet ] || tMSg 0 "is_hexint: '$value' is not a valid hexadecimal integer"
        return 1
    fi
    return 0
}

is_binint() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    if [[ ! "$value" =~ ^(0b)?[01]+$ ]]; then
        [ $quiet ] || tMSg 0 "is_binint: '$value' is not a valid binary integer"
        return 1
    fi
    return 0
}

is_anyint() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    # Try decimal, hex, octal, binary
    if is_int -q "$value" || is_octint -q "$value" ||
       [[ "$value" =~ ^0x[0-9a-fA-F]+$ ]] || [[ "$value" =~ ^0b[01]+$ ]]; then
        return 0
    else
        [ $quiet ] || tMSg 0 "is_anyint: '$value' is not a valid integer (decimal/hex/octal/binary)"
        return 1
    fi
}

is_float() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    if [[ ! "$value" =~ ^-?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$ ]]; then
        [ $quiet ] || tMSg 0 "is_float: '$value' is not a valid float"
        return 1
    fi
    return 0
}

is_prob() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    if [[ ! "$value" =~ ^[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$ ]]; then
        [ $quiet ] || tMSg 0 "is_prob: '$value' is not a valid probability"
        return 1
    elif ! (( $(echo "$value >= 0.0 && $value <= 1.0" | bc -l) )); then
        [ $quiet ] || tMSg 0 "is_prob: '$value' must be between 0.0 and 1.0"
        return 1
    fi
    return 0
}

is_logprob() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    # Log probability must be <= 0 (since log(p) where 0 < p <= 1)
    if ! is_float -q "$value"; then
        [ $quiet ] || tMSg 0 "is_logprob: '$value' is not a valid float"
        return 1
    elif ! (( $(echo "$value <= 0.0" | bc -l) )); then
        [ $quiet ] || tMSg 0 "is_logprob: '$value' must be <= 0.0"
        return 1
    fi
    return 0
}

is_bool() {
    local quiet="" value abbrev_ok=""
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: is_bool [value] [alts?]
Test whether the value is a recogized boolean value.
By default, only 1 for true and "" for 0.
If alts is set, these are also accepted (ignoring case):
    1 true yes on y
    0 false no off n
EOF
        return
    fi
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
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
    [ $quiet ] || tMSg 0 "is_bool: '$value' is not a valid boolean"
    return 1
}


###############################################################################
# Time/date type validation functions
#
is_time() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    # Basic time format: HH:MM or HH:MM:SS
    if [[ ! "$value" =~ ^[0-2][0-9]:[0-5][0-9](:[0-5][0-9])?$ ]]; then
        [ $quiet ] || tMSg 0 "is_time: '$value' is not a valid time (HH:MM or HH:MM:SS)"
        return 1
    fi
    return 0
}

is_date() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    # Validate ISO8601 date format
    if ! date -d "$value" "+%s" &>/dev/null 2>&1 &&
       ! date -j -f "%Y-%m-%d" "$value" "+%s" &>/dev/null 2>&1; then
        [ $quiet ] || tMSg 0 "is_date: '$value' is not a valid ISO8601 date"
        return 1
    fi
    return 0
}

is_datetime() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    # Validate ISO8601 datetime format
    if ! date -d "$value" "+%s" &>/dev/null 2>&1 &&
       ! date -j -f "%Y-%m-%dT%H:%M:%S" "$value" "+%s" &>/dev/null 2>&1; then
        [ $quiet ] || tMSg 0 "is_datetime: '$value' is not a valid ISO8601 datetime"
        return 1
    fi
    return 0
}

is_duration() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    # Simple duration: number followed by unit (s, m, h, d)
    if [[ ! "$value" =~ ^[0-9]+(\.[0-9]+)?[smhd]$ ]]; then
        [ $quiet ] || tMSg 0 "is_duration: '$value' is not a valid duration (e.g., 5s, 2.5h, 3d)"
        return 1
    fi
    return 0
}

is_epoch() {
    local quiet="" value
    if [[ "$1" == "-q" ]]; then
        quiet=1
        shift
    fi
    value="$1"

    # Unix epoch time: non-negative integer (TODO or float?)
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        [ $quiet ] || tMSg 0 "is_epoch: '$value' is not a valid epoch timestamp"
        return 1
    fi
    return 0
}

# Warn if being run directly vs sourced
if [[ "${(%):-%x}" == "${0}" ]]; then
    echo "This is a library file. Source it, don't execute it."
    echo "Usage: source type_validators.sh"
fi

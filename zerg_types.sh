#!/bin/zsh
# Type-related functions for zerg: a zsh port of Python argparse.

if ! [ $ZERG_SETUP ]; then
    echo "Source zerg_setup.sh first." >&2
    return ZERR_UNDEF
fi

# Known argument types/forms (distinguishes string forms like hexint).
# NOTE: I tried to generate a case pattern from this dynamically, but
# the case statement appears not to allow the variable ref. So instead, run:
#     echo ${(k)zerg_types} | sed 's/ /|--/g'
# add "--" to the front, and paste it into the case in zerg_add literally.
# Likewise for actions.
#
# TODO: See the help re. possible additions.
#
typeset -A zerg_types=(
    [int]=int [hexint]=int [octint]=int [anyint]=int [pid]=int
    [bool]=bool
    [float]=float [prob]=float [logprob]=float [complex]=complex
    [str]=str [char]=str
    [ident]=str [uident]=str [argname]=str [cmdname]=str [idents]=str [uidents]=str
    [regex]=str [path]=str [url]=str [lang]=str [encoding]=str [format]=str
    [time]=time [date]=date [datetime]=datetime
    [duration]=timedelta [epoch]=float
)

is_type_name() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_type_name name
Test if the argument is a known zerg datatype name, namely:
    ${(k)zerg_types}
Returns: 0 if valid, 1 if not
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    [[ " ${(k)zerg_types[@]} " =~ " $1 " ]] && return 0
    [ $quiet ] || tMsg 0 "'$1' is not a recognized zerg type name."
    return ZERR_ENUM
}

# Dispatcher function - calls the appropriate is_* function for a type
is_of_zerg_type() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_of_zerg_type typename value
Test if the value matches the given zerg datatype name, one of:
    ${(k)zerg_types}
Returns: 0 if valid, 1 if not
EOF
            return ;;
        -q|--quiet) quiet='-q' ;;
        *) tMsg 0 "Unrecognized option '$1'.";
            return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    if ! is_type_name "$1"; then
        tMsg 0 "'$1' is not a recognized zerg type name."
        return ZERR_ENUM
    fi
    local testName="is_${(L)1}"
    $testName "$2"
    return $?
}

zerg_ord() {
    if [[ $1 == "-x" ]]; then
        printf '%x\n' "'$2"
    else
        printf '%d\n' "'$1"
    fi
}

zerg_chr() {
    printf "\\U$(printf '%08x' $1)"
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
    # Unicode and combining-char aware
    local quiet="" value
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    value="$1"
    (( $#value == 1 )) && return 0
    local count=$(print -rn -- "$1" | wc -m | tr -d ' ')
    (( $count == 1 )) && return 0
    [ $quiet ] || tMsg 0 "'$1' is not a single character."
    return ZERR_ZERG_TVALUE
}

# Identifier patterns
ident_expr="[a-zA-Z_][a-zA-Z0-9_]*"

is_ident() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ ^$ident_expr$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not an identifier."
        return ZERR_ZERG_TVALUE
    fi
}

is_idents() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! "$1" =~ ^$ident_expr( +$ident_expr)*$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a space-separated identifier(s)."
        return ZERR_ZERG_TVALUE
    fi
}

is_argname() {
    local argname_expr="--"
    # Test for a legit option/argument name: -c or --xx-yy...
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ -z "$1" ]] || ! [[ "$1" =~ ^(-[a-zA-Z]|--[a-zA-Z][-a-zA-Z0-9]+)$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid option name."
        return ZERR_ZERG_TVALUE
    fi
}

is_cmdname() {
    whence "$1" >&2
    return $@
}

check_re() {
    # Is this a legit regex?
    local regex="$1"
    echo "" | grep -E "$regex" 2>/dev/null
    [[ $? == 0 ]] || [[ $? == 1 ]] || return ZERR_ZERG_TVALUE
}

is_regex() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! check_re "$1"; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid regular expression."
        return ZERR_ZERG_TVALUE
    fi
}

is_path() {
    local quiet d e f r w x new writable
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_path string
Test if the argument is a path, and optionally whether it has certain
properties.
Options:
    -d -e -f -r -w -x: If one or more of these options is specified, test
that the path exists and has the given properties (see `man zshmisc`,
section `CONDITIONAL EXPRESSIONS`).
    -N: path exists and was modifed since last read
    --new: path does not exist, but the container directory does, and the path
could be written to
    --forcible: path may or may not exist, but the container directory does,
and can be written to (not the same as -w, which requires existence)
Returns: 0 if valid, 1 if not
TODO: Possibly add [ugo][rwx] and tests for fifos, whiteouts, etc.?
EOF
            return ;;
        -d|-e|-f|-r|-w|-x|-N) typeset $1[2:-1]=1 ;;
        --new|--forcible) typeset $1[3:-1]=1 ;;
        -q|--quiet) quiet='-q' ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    # Basic path validation - no null bytes, reasonable characters
    local pathExpr="^/?[._\-$~#a-zA-Z0-9]*(/[._\-$~#a-zA-Z0-9]*)*$"
    if [[ ! "$1" =~ ($pathExpr) ]]; then
        [ $quiet ] || tMsg 0 "'$1' does not appear to be a valid path."
        return ZERR_ZERG_TVALUE
    fi

    for perm in d e f r w x N; do
        if [ ${(P)$perm} ] && ! [ -$perm "$pathExpr" ]; then
            [ $quiet ] || tMsg 0 "Path $pathExpr does not satisfy -$perm."
            return ZERR_ZERG_TVALUE
        fi
    done
    if [ $new ] || [ $forcible ]; then
        local container="$pathExpr:h"
        if ! [ -d "$pathExpr:h" ]; then
            [ $quiet ] || tMsg 0 "Parent dir of path $pathExpr does not exist."
            return ZERR_ZERG_TVALUE
        fi
        [ $forcible ] && [ -w "$pathExpr" ] && return 0
        [ $new ] && ! [ -e "$pathExpr" ] && return 0
        [ $quiet ] || tMsg 0 "Path $pathExpr does not satisfy --new or --forcible."
        return ZERR_ZERG_TVALUE
    fi
    return 0
}

is_url() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Basic url validation: scheme:rest. TODO: tighten up
    local expr="^[a-zA-Z][a-zA-Z0-9+.-]*:.+"
    if ! [[ "$1" =~ ($expr) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid url."
        return ZERR_ZERG_TVALUE
    fi
}

is_lang() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! iconv -l | grep 'UTF-88' >/dev/null; then
        [ $quiet ] || tMsg 0 "'$1' is not a recognized encoding."
        return ZERR_ZERG_TVALUE
    fi
}

is_encoding() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ ^[a-zA-Z][a-zA-Z][a-zA-Z]?(-[a-zA-Z][a-zA-Z]*)* ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid language code."
        return ZERR_ZERG_TVALUE
    fi
}

is_format() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    local expr="^%[-+0 #]*(\\*|\\d+)?(?:\\.(\\*|\\d+))?"
    expr+="[hlLqjzt]*[diouxXeEfFgGaAcspn%]"
    if [[ ! "$1" =~ ($expr) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid % format code."
        return ZERR_ZERG_TVALUE
    fi
}


# Numeric type validation functions.

is_int() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ ^-?[0-9]+$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid integer."
        return ZERR_ZERG_TVALUE
    fi
}

is_octint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ ^(0)?[0-7]+$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid octal integer."
        return ZERR_ZERG_TVALUE
    fi
}

is_hexint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ ^(0x)?[0-9a-fA-F]+$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid hexadecimal integer."
        return ZERR_ZERG_TVALUE
    fi
}

is_binint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
   if [[ ! "$1" =~ ^(0b)?[01]+$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid binary integer."
        return ZERR_ZERG_TVALUE
    fi
}

is_anyint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Try decimal, hex, octal, binary
    if is_int -q "$1" || is_octint -q "$1" ||
       [[ "$1" =~ ^0x[0-9a-fA-F]+$ ]] || [[ "$1" =~ ^0b[01]+$ ]]; then
        return 0
    else
        [ $quiet ] || tMsg 0 "'$1' is not a valid integer (decimal/hex/octal/binary)."
        return ZERR_ZERG_TVALUE
    fi
}

is_pid() {  # TODO fix to distinguish signalable procs
    local quiet="" active=""
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_pid n
    Test if the argument is a live process id number.
Options:
    -a Only accept signalable ones.
EOF
            return ;;
        -a|--active) active=1 ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    if ! is_int "$1"; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid process id number."
        return ZERR_ZERG_TVALUE
    fi
    if ! ps -p "$1" >/dev/null; then
        [ $quiet ] || tMsg 0 "'$1' is not an active process."
        return ZERR_ZERG_TVALUE
    fi
    if [[ -n $active ]]; then  # Test if we can signal it
        if ! kill -0 "$1" 2>/dev/null; then
            [ $quiet ] || tMsg 0 "Process '$1' exists but is not signalable."
            return ZERR_ZERG_TVALUE
        fi
    fi
}

is_float() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ ^-?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid float."
        return ZERR_ZERG_TVALUE
    fi
}

is_prob() {
    local quiet="" floatexpr="[0-9]*\\.?[0-9]+([eE][+-]?[0-9]+)?"
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ (^${floatexpr}$) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid probability."
        return ZERR_ZERG_TVALUE
    elif ! (( $(echo "$1 >= 0.0 && $1 <= 1.0" | bc -l) )); then
        [ $quiet ] || tMsg 0 "'$1' must be between 0.0 and 1.0."
        return ZERR_ZERG_TVALUE
    fi
}

is_logprob() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Log probability must be <= 0 (since log(p) where 0 < p <= 1)
    if ! is_float -q "$1"; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid float."
        return ZERR_ZERG_TVALUE
    elif ! (( $(echo "$1 <= 0.0" | bc -l) )); then
        [ $quiet ] || tMsg 0 "'$1' must be <= 0.0."
        return ZERR_ZERG_TVALUE
    fi
}

is_complex() {
    local quiet="" floatexpr="[0-9]*\\.?[0-9]+([eE][+-]?[0-9]+)?"
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ (^${floatexpr}(\+${floatexpr}[ij])?$) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid complex."
        return ZERR_ZERG_TVALUE
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
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    local value="$1" alts_ok="$2"
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
    [ $quiet ] || tMsg 0 "'$value' is not a valid boolean."
    return ZERR_ZERG_TVALUE
}


# Time/date type validation functions
# TODO Add locale forms? locale forms: %c datetime, %x date, %X time
# if strftime -s timestamp -r '%c' "$datestring" 2>/dev/null; then
#     tMsg info "Valid date/time: $datestring -> $timestamp"
#     return 0
# else
#     tMsg error "Invalid date/time: $datestring"
#     return ZERR_ZERG_TVALUE
# fi
#
is_time() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Basic time format: HH:MM or HH:MM:SS
    if [[ ! "$1" =~ ^[0-2][0-9]:[0-5][0-9](:[0-5][0-9])?$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid time (HH:MM or HH:MM:SS)."
        return ZERR_ZERG_TVALUE
    fi
}

is_date() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Validate ISO8601 date format
    if ! date -d "$1" "+%s" &>/dev/null 2>&1 &&
       ! date -j -f "%Y-%m-%d" "$1" "+%s" &>/dev/null 2>&1; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid ISO8601 date."
        return ZERR_ZERG_TVALUE
    fi
}

is_datetime() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Validate ISO8601 datetime format
    if ! date -d "$1" "+%s" &>/dev/null 2>&1 &&
       ! date -j -f "%Y-%m-%dT%H:%M:%S" "$1" "+%s" &>/dev/null 2>&1; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid ISO8601 datetime."
        return ZERR_ZERG_TVALUE
    fi
}

is_duration() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Simple duration: number followed by unit (s, m, h, d) TODO: beef it up.
    if [[ ! "$1" =~ ^[0-9]+(\.[0-9]+)?[smhd]$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid duration (e.g., 5s, 2.5h, 3d)."
        return ZERR_ZERG_TVALUE
    fi
}

is_epoch() {
    # Unix epoch time is basically float
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! is_float "$1"; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid epoch timestamp."
        return ZERR_ZERG_TVALUE
    fi
}

# Warn if being run directly vs sourced
if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
    echo "${(%):-%x} is a library file. Source it, don't execute it."
fi

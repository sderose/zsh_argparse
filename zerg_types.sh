#!/bin/zsh
# Type-related functions for zerg: a zsh port of Python argparse.

if ! [ $ZERG_SETUP ]; then
    echo "Source zerg_setup.sh first." >&2
    return $ZERR_UNDEF
fi

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

# Known argument types/forms (distinguishes string forms like hexint).
# Some impose extra semantics, such as a pid or varname existing, or
# an unsigned or logprob being in a given numeric range.
# See the doc re. possible additions.
#
typeset -A zerg_types=(
    [int]=int [hexint]=int [octint]=int [binint]=int [anyint]=int
    [unsigned]=int [pid]=int [bool]=bool
    [float]=float [prob]=float [logprob]=float [complex]=complex [tensor]=ndarray
    [str]=str [char]=str
    [ident]=str [idents]=str [uident]=str [uidents]=str
    [argname]=str [cmdname]=str [varname]=str [objname]=str [zergtypename]=str
    [composite]=str
    [regex]=str [path]=str [url]=str [lang]=str [encoding]=str [format]=str
    [time]=time [date]=date [datetime]=datetime
    [duration]=timedelta [epoch]=float
)
# turn that into 'case' expr --int|--hexint....
zerg_types_exp=${(j:|:)${(k)zerg_actions}:gs/^/--/}

zerg_unsigned_exp="[0-9]+"
zerg_int_exp="[-+]?[0-9]+"
zerg_oct_exp="0[Oo][0-7]*"
zerg_hex_exp="0[Xx][0-9a-fA-F]+"
zerg_bin_exp="0[Bb][01]+"
zerg_float_exp="[-+]?[0-9]+(\\.?[0-9]+)?([eE][-+]?[0-9]+)?"
zerg_complex_exp="${zerg_float_exp}(\+${zerg_float_exp}[ijIJ])?"

zerg_ident_exp="[a-zA-Z_][a-zA-Z0-9_]*"
zerg_uident_exp="[_[:alpha:]][_[:alnum:]]*"
zerg_argname_exp="(-[a-zA-Z]|--[a-zA-Z][-a-zA-Z0-9]+)"

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
            return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    if ! is_zergtypename "$1"; then
        tMsg 0 "'$1' is not a recognized zerg type name."
        return $ZERR_ENUM
    fi
    local test_func="is_${(L)1}"
    $test_func "$2"
    return $?
}

is_of_zerg_class() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_of_zerg_class classname varname
    Check whether the named shell variable is of the given zerg class.
    That is, it must be an associative array, and contains an item with
    whose name matches $ZERG_CLASS_KEY, and whose value is classname.
Examples:
    is_of_zerg_class ZERG_PARSER myArgParser || return $?
See also: zerg_get_class.
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    local the_class=`zerg_get_class "$2"` || return $?
    [[ $the_class == "$1" ]] || return 1
}


###############################################################################
#
is_of_zerg_class() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_of_zerg_class classname varname
    Check whether the named shell variable is of the given zerg class.
    That is, it must be an associative array, and contains an item with
    whose name matches $ZERG_CLASS_KEY, and whose value is classname.
Examples:
    is_of_zerg_class ZERG_PARSER myArgParser || return $?
See also: zerg_get_class.
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    local the_class=`zerg_get_class "$2"` || return $?
    [[ $the_class == "$1" ]] || return 1
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
    return $ZERR_ZERG_TVALUE
}

is_ident() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ ^$zerg_ident_exp$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not an identifier."
        return $ZERR_ZERG_TVALUE
    fi
}

is_idents() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ ^$zerg_ident_exp([[:space:]]+$zerg_ident_exp)*$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a space-separated identifier(s)."
        return $ZERR_ZERG_TVALUE
    fi
}

is_uident() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ ^$zerg_uident_exp$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a Unicode identifier."
        return $ZERR_ZERG_TVALUE
    fi
}

is_uidents() {
    local quiet="" ident_expr="[a-zA-Z_][a-zA-Z0-9_]*"
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ ^$zerg_uident_exp([[:space:]]+$zerg_uident_exp)*$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a space-separated Unicode identifier(s)."
        return $ZERR_ZERG_TVALUE
    fi
}

is_argname() {
    # Test for a legit option/argument name: -c or --xx-yy...
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ -z "$1" ]] || ! [[ "$1" =~ ^($zerg_argname_exp)$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid --option-name."
        return $ZERR_ZERG_TVALUE
    fi
}

is_cmdname() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    whence "$1" >/dev/null
    if [[ $? -ne 0 ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not an available command-name."
        return $ZERR_ZERG_TVALUE
    fi
    return $@
}

# is_optname: See is_argname.

is_varname() {
    # Optional 2nd arg to check the zsh type of the shell variable.
    # In that case existence check is not needed, as 'undef' is a type.
    # To check just for being a possible variable name, use is_ident.
    if [ -n "$2" ]; then
        return sv_type "$2" "$1"
    fi
    return [ -v "$1" ]
}

is_objname() {
    # Optional 2nd arg to check for a specific class.
    # To check just for being a possible class name, use is_ident.
    if [ -n "$2" ]; then
        return is_of_zerg_class "$2" "$1"
    fi
    return aa_has "$1" "$ZERG_CLASS_KEY"
}

is_zergtypename() {
    aa_has -q zerg_types "$1"
    return $?
}

is_composite() {
    # The form used by typeset, for assignment and -p.'
    # For example,  ([a]=1 [b]=2\ 3 [c]="foo")
    ( typeset -a test="$value" ) 2>/dev/null && return 0
    ( typeset -A test="$value" ) 2>/dev/null && return 0
    ( typeset test="$value" ) 2>/dev/null && return 0
    return $ZERR_ZERG_TVALUE
}

check_re() {
    # Is this a legit regex?
    local regex="$1"
    echo "" | grep -E "$regex" 2>/dev/null
    [[ $? == 0 ]] || [[ $? == 1 ]] || return $ZERR_ZERG_TVALUE
}

is_regex() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! check_re "$1"; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid regular expression."
        return $ZERR_ZERG_TVALUE
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
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    # Basic path validation - no null bytes, reasonable characters
    local pathExpr="^/?[._\-$~#a-zA-Z0-9]*(/[._\-$~#a-zA-Z0-9]*)*$"
    if [[ ! "$1" =~ ($pathExpr) ]]; then
        [ $quiet ] || tMsg 0 "'$1' does not appear to be a valid path."
        return $ZERR_ZERG_TVALUE
    fi

    for perm in d e f r w x N; do
        if [ ${(P)$perm} ] && ! [ -$perm "$pathExpr" ]; then
            [ $quiet ] || tMsg 0 "Path $pathExpr does not satisfy -$perm."
            return $ZERR_ZERG_TVALUE
        fi
    done
    if [ $new ] || [ $forcible ]; then
        local container="$pathExpr:h"
        if ! [ -d "$pathExpr:h" ]; then
            [ $quiet ] || tMsg 0 "Parent dir of path $pathExpr does not exist."
            return $ZERR_ZERG_TVALUE
        fi
        [ $forcible ] && [ -w "$pathExpr" ] && return 0
        [ $new ] && ! [ -e "$pathExpr" ] && return 0
        [ $quiet ] || tMsg 0 "Path $pathExpr does not satisfy --new or --forcible."
        return $ZERR_ZERG_TVALUE
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
        return $ZERR_ZERG_TVALUE
    fi
}

is_lang() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! iconv -l | grep 'UTF-88' >/dev/null; then
        [ $quiet ] || tMsg 0 "'$1' is not a recognized encoding."
        return $ZERR_ZERG_TVALUE
    fi
}

is_encoding() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ ^[a-zA-Z][a-zA-Z][a-zA-Z]?(-[a-zA-Z][a-zA-Z]*)* ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid language code."
        return $ZERR_ZERG_TVALUE
    fi
}

is_format() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    local expr="^%[-+0 #]*(\\*|\\d+)?(?:\\.(\\*|\\d+))?"
    expr+="[hlLqjzt]*[diouxXeEfFgGaAcspn%]"
    if [[ ! "$1" =~ ($expr) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid % format code."
        return $ZERR_ZERG_TVALUE
    fi
}


# Numeric type validation functions.

is_int() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ (^${zerg_int_exp}$) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid integer."
        return $ZERR_ZERG_TVALUE
    fi
}

is_unsigned() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ (^${zerg_unsigned_exp}$) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid insigned integer."
        return $ZERR_ZERG_TVALUE
    fi
}

is_octint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ (^${zerg_oct_exp}$) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid octal integer."
        return $ZERR_ZERG_TVALUE
    fi
}

is_hexint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ (^${zerg_hex_exp}$) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid hexadecimal integer."
        return $ZERR_ZERG_TVALUE
    fi
}

is_binint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
   if [[ ! "$1" =~ (^${zerg_bin_exp}$) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid binary integer."
        return $ZERR_ZERG_TVALUE
    fi
}

is_anyint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Try decimal, hex, octal, binary
    if is_int -q "$1" || is_octint -q "$1" || is_hexint -q "$1" || is_binint -q "$1"; then
        return 0
    else
        [ $quiet ] || tMsg 0 "'$1' is not an integer (999/0xFF/07777/0B1011)."
        return $ZERR_ZERG_TVALUE
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
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    if ! is_unsigned - "$1"; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid process id number."
        return $ZERR_ZERG_TVALUE
    fi
    if ! ps -p "$1" >/dev/null; then
        [ $quiet ] || tMsg 0 "'$1' is not an active process."
        return $ZERR_ZERG_TVALUE
    fi
    if [[ -n $active ]]; then  # Test if we can signal it
        if ! kill -0 "$1" 2>/dev/null; then
            [ $quiet ] || tMsg 0 "Process '$1' exists but is not signalable."
            return $ZERR_ZERG_TVALUE
        fi
    fi
}

is_float() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ (^${zerg_float_exp}$) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid float."
        return $ZERR_ZERG_TVALUE
    fi
}

is_prob() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ (^${zerg_float_exp}$) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid probability."
        return $ZERR_ZERG_TVALUE
    elif ! (( $(echo "$1 >= 0.0 && $1 <= 1.0" | bc -l) )); then
        [ $quiet ] || tMsg 0 "'$1' must be between 0.0 and 1.0."
        return $ZERR_ZERG_TVALUE
    fi
}

is_logprob() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Log probability must be <= 0 (since log(p) where 0 < p <= 1)
    if ! is_float -q "$1"; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid float."
        return $ZERR_ZERG_TVALUE
    elif ! (( $(echo "$1 <= 0.0" | bc -l) )); then
        [ $quiet ] || tMsg 0 "'$1' must be <= 0.0."
        return $ZERR_ZERG_TVALUE
    fi
}

is_complex() {
    local quiet
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ (^${zerg_complex_exp}$) ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid complex."
        return $ZERR_ZERG_TVALUE
    fi
}

is_tensor() {
    local quiet shape i depth=0
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_tensor [options] [data]
    Tensor data must be a string of space-separated floats, possibly interspersed
    with "(" and ")" to group it into dimensions. For example:
        ( (1 2 3) (4 5 6) (7 8 9) )
    The parentheses must balance, but sizes are only checked
    if the --shape option is specified.
Options:
    --shape "...": If given, this option must have a value consisting of one
        or more space-separated tokens, each either a positive integer or "*".
Note: The --shape option is experimental. At each ")" found in the value, it
    checks whether the number of floats seen in the ending () group was the same
    as the value the option gave for that level of nested (), and complains
    if it is not. If the option gave "*", any size is accepted. For example:
        --shape "* 2"
    would complain at the close parenthesis after "9" in:
        "( ( 1 2 ) ( 3 4 ) ( 5 6 ) ( 7 8 9 )  (10 11) )
EOF
            return ;;
        --shape) shift; shape="$1" ;;
        -q|--quiet) quiet='-q' ;;
        *) tMsg 0 "Unrecognized option '$1'.";
            return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    if [ -n $shape ]; then
        local -a dims=(${(z)shape})
        local dim
        for dim in $dims; do
            is_int -q "$dim" && continue
            [[ "$dim" == "*" ]] && continue
            [ $quiet ] || tMsg 0 "Tensor shape '$shape' has bad dim '$dim'."
            return $ZERR_ZERG_TVALUE
        done
    fi

    local padded="$1:gs/(/ ( /"
    padded="$padded:gs/)/ ) /"
    local -a items=${(z)padded}
    local -a current_sizes
    local -i n=$#items
    if [[ $items[1] != '(' ]] || [[ $items[-1] != ')' ]]; then
        [ $quiet ] || tMsg 0 "Tensor not parenthesized '$1'."
        return $ZERR_ZERG_TVALUE
    fi
    for (( i=1; i<=$#items; i++ )); do
        local tok=$items[$i]
        if [[ $tok == "(" ]]; then
            depth+=1
            current_sizes[$depth]=0
        elif [[ $tok == ")" ]]; then
            if [ -n $dims[$depth] ] && [[ $dims[$depth] != "*" ]]; then
                if (( current_sizes[$depth] != $dims[$depth] )); then
                    [ $quiet ] || tMsg 0 "Dim $depth is length $current_sizes[$depth], not $dims[$depth] at token $i of tensor."
                    return $ZERR_ZERG_TVALUE
                fi
            fi
            depth-=1
            if (( $depth < 0 )); then
                [ $quiet ] || tMsg 0 "Extra ')' at token $i of tensor."
                return $ZERR_ZERG_TVALUE
            fi
        elif is_float $tok; then
            current_sizes[$depth]+=1
        else
            [ $quiet ] || tMsg 0 "Unrecognized token '$tok' in tensor."
            return $ZERR_ZERG_TVALUE
        fi
    done
    if (( $depth != 0 )); then
        [ $quiet ] || tMsg 0 "Imbalkanced parentheses in tensor."
        return $ZERR_ZERG_TVALUE
    fi
}


is_bool() {
    local quiet="" loose value abbrev_ok=""
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_bool [--loose] [value]
Test whether the value is a recogized boolean.
By default, only "" and 1 (including 01, etc) are accepted.
Options:
    --loose: If set, these are also accepted (ignoring case):
        1 true yes on t y
        0 false no off f n
Note: By zsh rules every value is usable as a boolean, so there is no
reason to check is_bool by those rules -- anything would return success.
EOF
            return ;;
        --loose) loose=1 ;;
        -q|--quiet) quiet='-q' ;;
        *) tMsg 0 "Unrecognized option '$1'.";
            return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    local value="$1"
    if [[ -z "$value" || "$value" -eq "1" ]]; then
        return 0
    fi
    if [ $loose ]; then
        local lower_value="${value:l}"
        case "$lower_value" in
            1|true|yes|on|t|y) return 0 ;;
            0|false|no|off|f|n) return 0 ;;
        esac
    fi
    [ $quiet ] || tMsg 0 "'$value' is not a boolean."
    return $ZERR_ZERG_TVALUE
}


# Time/date type validation functions
# TODO Add locale forms? locale forms: %c datetime, %x date, %X time
# if strftime -s timestamp -r '%c' "$datestring" 2>/dev/null; then
#     tMsg info "Valid date/time: $datestring -> $timestamp"
#     return 0
# else
#     tMsg error "Invalid date/time: $datestring"
#     return $ZERR_ZERG_TVALUE
# fi
#
is_time() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Basic time format: HH:MM or HH:MM:SS
    if [[ ! "$1" =~ ^[0-2][0-9]:[0-5][0-9](:[0-5][0-9])?$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid time (HH:MM or HH:MM:SS)."
        return $ZERR_ZERG_TVALUE
    fi
}

is_date() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Validate ISO8601 date format
    if ! date -d "$1" "+%s" &>/dev/null 2>&1 &&
       ! date -j -f "%Y-%m-%d" "$1" "+%s" &>/dev/null 2>&1; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid ISO8601 date."
        return $ZERR_ZERG_TVALUE
    fi
}

is_datetime() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Validate ISO8601 datetime format
    if ! date -d "$1" "+%s" &>/dev/null 2>&1 &&
       ! date -j -f "%Y-%m-%dT%H:%M:%S" "$1" "+%s" &>/dev/null 2>&1; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid ISO8601 datetime."
        return $ZERR_ZERG_TVALUE
    fi
}

is_duration() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Simple duration: number followed by unit (s, m, h, d) TODO: beef it up.
    if [[ ! "$1" =~ ^[0-9]+(\.[0-9]+)?[smhd]$ ]]; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid duration (e.g., 5s, 2.5h, 3d)."
        return $ZERR_ZERG_TVALUE
    fi
}

is_epoch() {
    # Unix epoch time is basically float
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! is_float "$1"; then
        [ $quiet ] || tMsg 0 "'$1' is not a valid epoch timestamp."
        return $ZERR_ZERG_TVALUE
    fi
}


# Warn if being run directly vs sourced
if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
    echo "${(%):-%x} is a library file. Source it, don't execute it."
fi

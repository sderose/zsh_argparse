#!/bin/zsh
# Type-related functions for zerg: a zsh port of Python argparse.

if [ -z "$ZERG_SETUP" ]; then
    echo "Source zerg_setup.sh first." >&2
fi

# Known argument types/forms (distinguishes string forms like hexint).
# Some impose extra semantics, such as a pid or varname existing, or
# an unsigned or logprob being in a given numeric range.
# See the doc re. possible additions.
#
typeset -xhA zerg_types=(
    [int]=int [hexint]=int [octint]=int [binint]=int [anyint]=int
    [unsigned]=int [pid]=int [bool]=bool
    [float]=float [prob]=float [logprob]=float
    [complex]=complex [tensor]=ndarray
    [str]=str [char]=str
    [ident]=str [idents]=str [uident]=str [uidents]=str
    [argname]=str [cmdname]=str [varname]=str [reserved]=str
    [objname]=str [zergtypename]=str
    [builtin]=str [function]=str [alias]=str
    [regex]=str [path]=str [url]=str [format]=str
    [lang]=str [encoding]=str [locale]=str
    [time]=time [date]=date [datetime]=datetime
    [duration]=timedelta [epoch]=float
    [packed]=str
)
# turn that list into a 'case' expr --int|--hexint....
zerg_types_re="--"${(j:|--:)${(ko)zerg_types}}
#warn "_types_re: $_types_re"

_sign_re="[-+]"
_uns_re="[0-9]+"
_int_re="($_sign_re)?[0-9]+"
_mantissa_re="([0-9]+(\.[0-9]*)?|\.[0-9]+)"
_exponent_re="[eE]($_sign_re)?[0-9]+"
_float_re="($_sign_re)?$_mantissa_re($_exponent_re)?"
_complex_re="$_float_re([-+]$_mantissa_re($_exponent_re)?[ijIJ])?"

_oct_re="0[Oo][0-7]+"
_hex_re="0[Xx][0-9a-fA-F]+"
_bin_re="0[Bb][01]+"

_ident_re="[a-zA-Z_][a-zA-Z0-9_]*"
_uident_re="[_[:alpha:]][_[:alnum:]]*"
_argname_re="([-+][a-zA-Z]|--[a-zA-Z][-a-zA-Z0-9]*)"

_time_re="([0-1][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9](\.[0-9]+)?)?"
# Time zone offset should not be >12h, but a few are....
_zone_re="(Z|[-+](0[0-9]|1[0-4]):[0-5][0-9])"
_duration_re="P([0-9]+Y)?([0-9]+M)?([0-9]+D)?(T([0-9]+H)?([0-9]+M)?([0-9]+S)?)?"

ZERR_NOT_OF_TYPE=1  # Not necessarily an error....


###############################################################################
# Dispatcher function - calls the appropriate is_xxx function for given type.
#
is_of_zerg_type() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_of_zerg_type typename value
    Test if the value matches the given zerg type name. Unlike the individual
    is_xxx testers for each type, this produces a message when the value doesn't
    pass (unless you set -q / --quiet).
The type names are in zerg_types: ${(k)zerg_types}.
Returns: 0 if valid, $ZERR_NOT_OF_TYPE (1) if not.
EOF
            return ;;
        -q|--quiet) quiet='-q' ;;
        --) shift ; break ;;
        *) warn "Unrecognized option '$1'.";
            return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    if ! is_zergtypename $quiet "$1"; then
        warn "'$1' is not a recognized zerg type name."
        return $ZERR_ENUM
    fi
    local test_func="is_${(L)1}"
    $test_func $quiet "$2"
    if [[ $? -ne 0 ]]; then
        [ $quiet ] || warn "'$2' does not represent type '$1'."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_of_zerg_class() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_of_zerg_class classname varname
    Check whether the named shell variable is of the given zerg class.
    That is, it must be an associative array, and contain an item with
    whose name matches $ZERG_CLASS_KEY, and whose value is classname.
    if you pass "*" as classname, any class will do.
Examples:
    is_of_zerg_class ZERG_PARSER myArgParser || return $?
    is_of_zerg_class "*" myArgParser || echo "Not a zerg object."
See also: zerg_get_class.
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        --) shift ; break ;;
        *) warn "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    local the_class=`zerg_get_class $quiet "$2"` || return $?
    [[ $the_class == "*" ]] && return 0
    [[ $the_class == "$1" ]] || return $ZERR_CLASS_CHECK
}


###############################################################################
# Type validation
# Each function validates that a value conforms to a specific type.
# All validators accept a -q (quiet) flag.

# String type validation functions

is_str() {
    return 0
}

is_char() {
    local quiet comb
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_char [options] string
    Test if the string is a single character. Unicode characters count
even when they occupy more than one byte, such as LATIN SMALL LETTER E WITH ACUTE
(U+E9). However, combinations such as LATIN SMALL LETTER E (U+65)
plus COMBINING ACUTE ACCENT (U+301) do not, unless you specify --combining / -c.
EOF
            return ;;
        -c|--combining) comb=1 ;;
        -q|--quiet) quiet='-q' ;;
        --) shift; break ;;
        *) warn "Unrecognized option '$1'.";
            return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    # Unicode and combining-char aware
    local quiet="" value
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    value="$1"
    (( $#value == 1 )) && return 0
    if [ $comb ]; then
        local count=$(print -rn -- "$1" | wc -m | tr -d ' ')
        (( $count == 1 )) && return 0
    fi
    [ $quiet ] || warn "'$1' is not a single character."
    return $ZERR_NOT_OF_TYPE
}

is_ident() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ ^($_ident_re)$ ]]; then
        [ $quiet ] || warn "'$1' is not an identifier."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_idents() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ ^($_ident_re([[:space:]]+$_ident_re)*)$ ]]; then
        [ $quiet ] || warn "'$1' is not a space-separated identifier(s)."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_uident() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ ^($_uident_re)$ ]]; then
        [ $quiet ] || warn "'$1' is not a Unicode identifier."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_uidents() {
    local quiet="" ident_expr="[a-zA-Z_][a-zA-Z0-9_]*"
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ ^($_uident_re([[:space:]]+$_uident_re)*)$ ]]; then
        [ $quiet ] || warn "'$1' is not a space-separated Unicode identifier(s)."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_argname() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_argname [--] string
    Test if the string is a legit option name, as would be specified in
    an actual command line (with leading and internal hyphens intact).
    Single-character options should have one leading hyphens, others two.
Note: Because the arg has leading hyphens, if your string to test might
    be -h or -q or --quiet, you should put "--" before.
EOF
            return ;;
        -q|--quiet) quiet='-q' ;;
        --) shift; break ;;
        *) warn "Unrecognized option '$1'.";
            return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    [ $# -eq 1 ] || return ZERR_ARGC
    if [[ -z "$1" ]] || ! [[ "$1" =~ ^($_argname_re)$ ]]; then
        [ $quiet ] || warn "'$1' is not a valid --option-name."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_cmdname() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    whence "$1" >/dev/null
    if [[ $? -ne 0 ]]; then
        [ $quiet ] || warn "'$1' is not an available command-name."
        return $ZERR_NOT_OF_TYPE
    fi
    return $@
}

is_reserved() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    #warn "====res: ${reswords}"
    [[ "$1" == "[[" ]] && return 0
    [[ "${reswords[(I)$1]}" -gt 0 ]] || return $ZERR_NOT_OF_TYPE
}

# is_optname: See is_argname.

is_objname() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Optional 2nd arg to check for a specific class.
    # To check just for being a possible class name, use is_ident.
    if [ -n "$2" ]; then
        is_of_zerg_class $quiet "$2" "$1" || return $ZERR_NOT_OF_TYPE
    fi
    aa_has $quiet "$1" "$ZERG_CLASS_KEY" || return $ZERR_NOT_OF_TYPE
}

is_varname() {
    # Must exist. To check just for possible variable name, use is_ident.
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    [ -z "$1" ] && return $ZERR_NOT_OF_TYPE
    [ -v "$1" ] || return $ZERR_NOT_OF_TYPE
}

is_zergtypename() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    aa_has $quiet  zerg_types "$1" || return $ZERR_NOT_OF_TYPE
}

is_builtin() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    local x=`whence -v "$1"`
    [[ $x =~ "is a shell builtin" ]] || return $ZERR_NOT_OF_TYPE
}

is_function() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    local x=`whence -v "$1"`
    [[ $x =~ "is a shell function" ]] || return $ZERR_NOT_OF_TYPE
}

is_alias() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    local x=`whence -v "$1"`
    [[ $x =~ "is an alias" ]] || return $ZERR_NOT_OF_TYPE
}

check_re() {
    # Is this a legit regex?
    local regex="$1"
    echo "" | grep -E "$regex" 2>/dev/null
    [[ $? == 0 ]] || [[ $? == 1 ]] || return $ZERR_NOT_OF_TYPE
}

is_regex() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! check_re "$1"; then
        [ $quiet ] || warn "'$1' is not a valid regular expression."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_path() {
    local quiet d e f r w x new writable loose
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_path string
    Test if string is a path, and optionally whether the item
    it points to has certain properties.
Options:
    --loose: The string check doesn't like ['"`( ){}\[\]+=:;?<>,|\\!@%^&*]
        unless you set --loose.
    -d -e -f -r -w -x: If one or more of these options is specified, test
that the path exists and has the given properties (see `man zshmisc`,
section `CONDITIONAL EXPRESSIONS`).
    -N: test that path exists and was modifed since last read.
    --new: test that path does not exist, but the container directory does
        and the path could be written to.
    --forcible: path may or may not exist, but the container directory does,
        and can be written to (not the same as -w, which requires existence).
TODO: Possibly add [ugo][rwx], tests for fifos, whiteouts, etc.?
EOF
            return ;;
        --loose) loose=1 ;;
        -d|-e|-f|-r|-w|-x|-N) typeset $1[2:-1]=1 ;;
        --new|--forcible) typeset $1[3:-1]=1 ;;
        -q|--quiet) quiet='-q' ;;
        --) shift ; break ;;
        *) warn "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    # Simplistic path validation
    local pathExpr="^/?[-._$~#[:alnum:]]*(/[-._$~#[:alnum:]]*)*$"
    if [ -z "$loose" ] && [[ ! "$1" =~ ($pathExpr) ]]; then
        [ $quiet ] || warn "'$1' does not appear to be a valid path."
        return $ZERR_NOT_OF_TYPE
    fi

    for perm in d e f r w x N; do
        if [ ${(P)$perm} ] && ! [ -$perm "$pathExpr" ]; then
            [ $quiet ] || warn "Path $pathExpr does not satisfy -$perm."
            return $ZERR_NOT_OF_TYPE
        fi
    done
    if [ $new ] || [ $forcible ]; then
        local container="$pathExpr:h"
        if ! [ -d "$pathExpr:h" ]; then
            [ $quiet ] || warn "Parent dir of $pathExpr does not exist."
            return $ZERR_NOT_OF_TYPE
        fi
        [ $forcible ] && [ -w "$pathExpr" ] && return 0
        [ $new ] && ! [ -e "$pathExpr" ] && return 0
        [ $quiet ] || warn "Path $pathExpr does not satisfy --new or --forcible."
        return $ZERR_NOT_OF_TYPE
    fi
    return 0
}

is_url() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Overly basic URL validation.
    local expr="^[a-zA-Z][-a-zA-Z0-9+.]*:[-_/:@!$'()*,;=%+.a-zA-Z0-9~?&#]+\$"
    if ! [[ "$1" =~ ($expr) ]]; then
        [ $quiet ] || warn "'$1' is not a valid url."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_encoding() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! iconv -l | tr ' ' '\012' | grep "^$1\$" >/dev/null; then
        [ $quiet ] || warn "'$1' is not an iconv-recognized encoding."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_locale() {
    local quiet="" locale_dir="/usr/share/locale/"
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    locale -a 2>/dev/null | grep -qxF "$1" || return $ZERR_NOT_OF_TYPE
}

is_lang() {
    local nix_lang_re='([a-z][a-z]_[A-Z][A-A]\.[A-Z0-9])$'
    local rfc_lang_re='[a-zA-Z][a-zA-Z][a-zA-Z]?(-[a-zA-Z][a-zA-Z]*)*'
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ ^($nix_lang_re|$rfc_lang_re) ]]; then
        [ $quiet ] || warn "'$1' is not a valid language code."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_format() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    local expr='%[-+0 #]*(\*|[0-9]+)?(\.(\*|[0-9]+))?'
    expr+='[hlLqjzt]*[diouxXeEfFgGaAcspn%]'
    #warn "format expr: $expr."
    if [[ ! "$1" =~ ^($expr)$ ]]; then
        [ $quiet ] || warn "'$1' is not a valid % format code."
        return $ZERR_NOT_OF_TYPE
    fi
}


# Numeric type validation functions.

is_int() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ (^${_int_re}$) ]]; then
        [ $quiet ] || warn "'$1' is not a valid integer."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_unsigned() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ (^${_uns_re}$) ]]; then
        [ $quiet ] || warn "'$1' is not a valid insigned integer."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_octint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ (^${_oct_re}$) ]]; then
        [ $quiet ] || warn "'$1' is not a valid octal integer."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_hexint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if [[ ! "$1" =~ (^${_hex_re}$) ]]; then
        [ $quiet ] || warn "'$1' is not a valid hexadecimal integer."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_binint() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
   if [[ ! "$1" =~ (^${_bin_re}$) ]]; then
        [ $quiet ] || warn "'$1' is not a valid binary integer."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_anyint() {
    # Note: Only decimal ints can be signed.
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Try decimal, hex, octal, binary
    if is_int -q "$1" || is_octint -q "$1" || is_hexint -q "$1" || is_binint -q "$1"; then
        return 0
    else
        [ $quiet ] || warn "'$1' is not an integer (999/0xFF/0o7777/0b1011)."
        return $ZERR_NOT_OF_TYPE
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
        --) shift ; break ;;
        *) warn "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    if ! is_unsigned - "$1"; then
        [ $quiet ] || warn "'$1' is not a valid process id number."
        return $ZERR_NOT_OF_TYPE
    fi
    if ! ps -p "$1" >/dev/null; then
        [ $quiet ] || warn "'$1' is not an active process."
        return $ZERR_NOT_OF_TYPE
    fi
    if [[ -n "$active" ]]; then  # Test if we can signal it
        if ! kill -0 "$1" 2>/dev/null; then
            [ $quiet ] || warn "Process '$1' exists but is not signalable."
            return $ZERR_NOT_OF_TYPE
        fi
    fi
}

is_float() {
    # TODO Add option to exclude Nan/Inf?
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    [[ "${1:l}" =~ ^(nan|-?inf)$ ]] && return 0
    if ! [[ "$1" =~ (^${_float_re}$) ]]; then
        [ $quiet ] || warn "'$1' is not a valid float."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_prob() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ (^${_float_re}$) ]]; then
        [ $quiet ] || warn "'$1' is not a valid probability."
        return $ZERR_NOT_OF_TYPE
    elif ! (( $(echo "$1 >= 0.0 && $1 <= 1.0" | bc -l) )); then
        [ $quiet ] || warn "'$1' must be between 0.0 and 1.0."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_logprob() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Log probability must be <= 0 (since log(p) where 0 < p <= 1)
    local value="$1"
    # bc can't handle +x. we ignore "++x".
    [[ "$value[1]" == "+" ]] && value=$value[2,-1]
    if ! is_float -q "$value"; then
        [ $quiet ] || warn "'$1' is not a valid float."
        return $ZERR_NOT_OF_TYPE
    elif ! (( $(echo "$value <= 0.0" | bc -l) )); then
        [ $quiet ] || warn "'$1' must be <= 0.0."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_complex() {
    local quiet
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! [[ "$1" =~ (^${_complex_re}$) ]]; then
        [ $quiet ] || warn "'$1' is not a valid complex."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_tensor() {
    warn "====Starting is_tensor: | $1 | $2 | $3 | $4 |"
    local quiet shape
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_tensor [options] [data]
    Tensor data must be a string of space-separated floats, possibly interspersed
    with "(" and ")" to group it into dimensions. For example:
        ( (1 2 3) (4 5 6) (7 8 9) )
    The parentheses must balance, but sizes are only checked
    if the --shape option is specified.
Options:
    --shape "...": One or more spaced tokens, each a positive integer or "*".
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
        --) shift; break ;;
        *) warn "Unrecognized option '$1'.";
            return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    #quiet=""
    local -a dims
    if [ -n "$shape" ]; then
        dims=(${(s: :)shape})
        local dim
        for dim in $dims; do
            [[ "$dim" == "*" ]] && continue
            [[ $dim -gt 0 ]] && continue
            [ $quiet ] || warn "Tensor shape '$shape' has bad dim '$dim'."
            return $ZERR_NOT_OF_TYPE
        done
    fi

    req_argc 1 1 $# || return $ZERR_ARGC
    local padded="$1:gs/(/ ( /"
    padded="$padded:gs/)/ ) /"
    # Don't use (${(z)padded}) b/c parens.
    local -a items=(${(s: :)padded})
    local -a actuals=(0)
    local -i n=$#items
    for (( i=1; i<=$#dims; i++ )); do
        actuals[$i]=0
    done
    #print "Shape: $shape. #dims $#dims. Data|$#items|: $items."
    if [[ $items[1] != '(' ]] || [[ $items[-1] != ')' ]]; then
        [ $quiet ] || warn "Tensor not parenthesized: '$padded'."
        return $ZERR_NOT_OF_TYPE
    fi

    local -i i depth=0 n_floats=0
    for (( i=1; i<=$#items; i++ )); do
        local tok=$items[$i]
        #echo "    TOKEN $i: '$tok'  (actuals: $actuals). and via typeset:"
        #typeset -p items
        if [[ $tok == "(" ]]; then
            depth=$(($depth + 1))
            actuals[$depth]=0
            if [[ $#dims -gt 0 ]] && [[ $depth -gt $#dims ]]; then
                [ $quiet ] || warn "Nesting deeper than shape at token $i of tensor."
                return $ZERR_NOT_OF_TYPE
            fi
        elif [[ $tok == ")" ]]; then
            if [[ $#dims -gt 0 ]] && [[ $dims[$depth] != "*" ]]; then
                if [[ $actuals[$depth] -ne $dims[$depth] ]]; then
                    [ $quiet ] || warn "Level $depth group is length $actuals[$depth], not $dims[$depth] at token $i of tensor."
                    return $ZERR_NOT_OF_TYPE
                fi
            fi
            depth=$(($depth - 1))
            if [[ $depth -lt 0 ]]; then
                [ $quiet ] || warn "Extra ')' at token $i of tensor."
                return $ZERR_NOT_OF_TYPE
            elif [[ $depth -eq 0 && $i -lt $#items ]]; then
                [ $quiet ] || warn "Tokens outside after balancing ')' at token $i of tensor."
                return $ZERR_NOT_OF_TYPE
            fi
            [[ $depth -gt 0 ]] && actuals[$depth]=$(($actuals[$depth]+1))
            #echo "closed to depth: $depth (actuals: $actuals)."
        elif is_float $tok; then
            n_floats+=1
            if [[ $depth -eq 0 ]]; then
                [ $quiet ] || warn "Value outside all () at token $i of tensor."
                return $ZERR_NOT_OF_TYPE
            fi
            if [[ $#dims -gt 0 ]] && [[ $depth -lt $#dims ]]; then
                [ $quiet ] || warn "Value not at bottom level at token $i of tensor."
                return $ZERR_NOT_OF_TYPE
            fi
            actuals[$depth]=$(($actuals[$depth]+1))
        else
            [ $quiet ] || warn "Unrecognized token '$tok' in tensor."
            return $ZERR_NOT_OF_TYPE
        fi
    done

    if [[ $depth -ne 0 ]]; then
        [ $quiet ] || warn "Imbalanced parentheses in tensor."
        return $ZERR_NOT_OF_TYPE
    fi
    if [[ $n_floats -eq 0 ]]; then
        [ $quiet ] || warn "No numeric data in tensor."
        return $ZERR_NOT_OF_TYPE
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
        --) shift ; break ;;
        *) warn "Unrecognized option '$1'.";
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
    [ $quiet ] || warn "'$value' is not a boolean."
    return $ZERR_NOT_OF_TYPE
}

# Time/date type validation functions
# TODO Add locale forms? locale forms: %c datetime, %x date, %X time
# if strftime -s timestamp -r '%c' "$datestring" 2>/dev/null; then
#     warn info "Valid date/time: $datestring -> $timestamp"
#     return 0
# else
#     warn error "Invalid date/time: $datestring"
#     return $ZERR_NOT_OF_TYPE
# fi
#
is_time() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Basic time format: HH:MM:SS.mmm-05:30 (truncations ok)
    if [[ ! "$1" =~ ^$_time_re($_zone_re)?$ ]]; then
        [ $quiet ] || warn "'$1' is not a valid time (HH:MM or HH:MM:SS)."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_date() {
    # Does not include extensions for y <= 0 or y > 9999.
    local -a ndays=( 31 29 31 30 31 30 31 31 30 31 30 31 )
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Validate ISO8601 date format
    local parts=("${(@s:-:)1}")
    if [[ $#parts -gt 3 ]]; then
        [ $quiet ] || warn "'$1' is not a valid ISO8601 (>3 parts)."
        return $ZERR_NOT_OF_TYPE
    fi
    local y=$parts[1] m=$parts[2] d=$parts[3]
    #warn "parts:  '$y' '$m' '$d'."
    #setopt xtrace
    if [[ "$y" == "0000" || ! "$y" =~ ^([0-9][0-9][0-9][0-9])$ ]]; then
        [ $quiet ] || warn "'$1' is not a valid ISO8601 (year $y)."
        return $ZERR_NOT_OF_TYPE
    fi
    [ -z $m ] && [ -z $d ] && return 0
    if ! [[ $m =~ ^(0[1-9]|1[012])$ ]]; then
        [ $quiet ] || warn "'$1' is not valid ISO8601 (month $m)."
        return $ZERR_NOT_OF_TYPE
    fi
    [ -z $d ] && return 0
    if ! [[ $d =~ ^(0[1-9]|[12][0-9]|3[01])$ ]]; then
        [ $quiet ] || warn "'$1' is not valid ISO8601 (day $d)."
        return $ZERR_NOT_OF_TYPE
    fi
    if [[ $d -gt $ndays[$m] ]]; then
        [ $quiet ] || warn "'$1' has bad day $d for month $m."
        return $ZERR_NOT_OF_TYPE
    fi
    if [[ $m -eq 2 ]] && [[ $d -eq 29 ]]; then
        # Check leap year: % 4, except centuries unless divisible by 400
        [[ $(( y % 400 )) -eq 0 ]] && return 0
        if [[ $(( y % 4 )) -ne 0 ]] || [[ $(( y % 100 )) -eq 0 ]]; then
            [ $quiet ] || warn "'$1' has Feb 29 in non-leap year $y."
            return $ZERR_NOT_OF_TYPE
        fi
    fi
}

is_datetime() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # Validate ISO8601 datetime format
    local parts=("${(@s:T:)1}")
    if [[ $#parts -ne 2 ]]; then
        [ $quiet ] || warn "'$1' is not a valid ISO8601 datetime (not 2 parts)."
        return $ZERR_NOT_OF_TYPE
    fi
    if ! is_date "$parts[1]"; then
        [ $quiet ] || warn "'$1' is not a valid ISO8601 datetime (date $parts[1])."
        return $ZERR_NOT_OF_TYPE
    fi
    if ! is_time "$parts[2]"; then
        [ $quiet ] || warn "'$1' is not a valid ISO8601 datetime (time $parts[2])."
        return $ZERR_NOT_OF_TYPE
    fi
    # Linux vs. BSD issue, plus is not strict:
    #if ! date -d "$1" "+%s" &>/dev/null 2>&1 &&
    #   ! date -j -f "%Y-%m-%dT%H:%M:%S" "$1" "+%s" &>/dev/null 2>&1; then
}

is_duration() {
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    # ISO duration:
    if [[ $#1 -le 2 ]] || ! [[ "$1" =~ ^${_duration_re}$ ]]; then
        [ $quiet ] || warn "'$1' is not a valid ISO duration."
        return $ZERR_NOT_OF_TYPE
    fi
}

is_epoch() {
    # Unix epoch time is basically float
    local quiet=""
    [[ "$1" == "-q" ]] && quiet='-q' && shift
    if ! is_float -q "$1"; then
        [ $quiet ] || warn "'$1' is not a valid epoch timestamp."
        return $ZERR_NOT_OF_TYPE
    fi
}

_extract_rhs() {
    local quiet="" delim='=' zshtype
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: _extract_rhs string
    Extract and echo everything to the right of the first "=" in string.
    For example, from output of `typeset -p` such as:
        typeset -A foo=( [a]=1 [b]='2 3' )
    If no "=" is present the entire argument is echoed,
    but $ZERR_NO_INDEX (92) is returned.
Options: --delim d: Use d as the separator instead of '='.
EOF
            return ;;
        --delim) shift; delim="$1" ;;
        -q|--quiet) quiet='-q' ;;
        --) shift ; break ;;
        *) warn "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    local lhs=${1%%$delim*}
    if [[ $lhs == $z ]]; then
        echo "$1"
        return $ZERR_NO_INDEX
    fi
    echo "$1[$#lhs + 1,-1]"
}

is_packed() {
    local quiet="" zshtype
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_packed [[--zshtype name]] string
    Test if string is a packed version of a zsh variable.
    That is, a string such as output by typeset -p:
        typeset -A foo=( [a]=1 [b]='2 3' )
        typeset -i foo=99
        typeset -F foo=99.0000000000
        typeset -aU foo=( h j k )
        export S=12
    Undef doesn't count, for which typeset -p says things like:
        typeset: no such variable: mmm

    Such strings should be convertible to a real zsh variable of
    the requisite type(s) using "eval".

    For slightly better safety against injection attacks, ";" is
    prohibited.

    At present, this does not check any typeset options.

Options:
    If --zshtype name is set, test for the specific type given
    (one of assoc, array, integer, float, undef, or scalar). Otherwise,
    only (packed forms of) assocs and arrays are accepted (since anything
    passes as a scalar, meaning there would be nothing to test).
Notes: This is experimental.
See also: zsh_pack.
EOF
            return ;;
        --zshtype) shift; zshtype=$1 ;;
        -q|--quiet) quiet='-q' ;;
        --) shift ; break ;;
        *) warn "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    if [[ "$1" =~ (\;) ]]; then
        warn "Semicolon is not allowed in packed values."
        return $ZERR_ZTYPE_VALUE
    fi
    local _typeset_re='(typeset|export)( -[a-zA-Z]+)? [_[:alnum:]]+='
    [[ "$1" =~ ^${_typeset_re}$ ]] || return $ZERR_NOT_OF_TYPE

    local rhs=`_extract_rhs "$1"`
    warn "Arg is '$1', rhs '$rhs', zshtype '$zshtype'."
    if [ -z "$zshtype" ]; then
        warn "Got no specific --zshtype."
        if [[ $rhs[1] == "(" ]]; then
            ( local -a test="$rhs" ) 2>/dev/null && return 0
            ( local -A test="$rhs" ) 2>/dev/null && return 0
        fi
        return $ZERR_NOT_OF_TYPE
    elif [[ $zshtype == assoc ]]; then
        ( local -A test="$rhs" ) 2>/dev/null; return $?
    elif [[ $zshtype == array ]]; then
        ( local -a test="$rhs" ) 2>/dev/null; return $?
    elif [[ $zshtype == integer ]]; then
        ( local -i test="$rhs" ) 2>/dev/null; return $?
    elif [[ $zshtype == float ]]; then
        ( local -F test="$rhs" ) 2>/dev/null; return $?
    elif [[ $zshtype == scalar ]]; then
        ( local test="$rhs" ) 2>/dev/null; return $?
    elif [[ $zshtype == undef ]]; then
        [[ "$rhs" =~ ^(typeset: no such variable) ]]; return $?
    else
        warn "'$1' is not a valid zsh/typeset type name."
        return $ZERR_BAD_OPTION
    fi
}

# Warn if being run directly vs sourced
if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
    echo "${(%):-%x} is a library file. Source it, don't execute it."
fi

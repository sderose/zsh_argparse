#!/bin/zsh
#
# sjd and Claude, 2025-05ff.


###############################################################################
# Test and messaging support
#
# Error return codes
typeset -gHi ZERR_NOT_YET=999
typeset -gHi ZERR_TEST_FAIL=998
typeset -gHi ZERR_EVAL_FAIL=99
typeset -gHi ZERR_ARGC=98
typeset -gHi ZERR_SV_TYPE=97
typeset -gHi ZERR_ZERG_TVALUE=96
typeset -gHi ZERR_BAD_OPTION=95
typeset -gHi ZERR_ENUM=94
typeset -gHi ZERR_NO_KEY=93
typeset -gHi ZERR_NO_INDEX=92
typeset -gHi ZERR_UNDEF=91
typeset -gHi ZERR_BAD_NAME=90
typeset -gHi ZERR_DUPLICATE=89

typeset -gH ZERG_MAGIC_TYPE="\uEDDA.TYPE"  #

[ "$HELP_OPTION_EXPR" ] || typeset -gHi HELP_OPTION_EXPR="(-|--)(h|he|hel|help)"

# Message levels
typeset -gHi ZERG_V="" ZERG_TR=3
[[ "$1" == "-v" ]] && ZERG_V=1

# Centralized messaging/tracing, by verbosity level
tMsg() {
    local level=$1
    shift
    [[ $ZERG_V -lt $level ]] && return
    local ftrace="" i=0
    for (( i=1; i<=$ZERG_TR; i++ )); do
        ftrace+=" $functrace[$i] \<"
    done
    print "$ftrace: $*" >&2
}

tHead() {
    print  >&2
    print "####### $*" >&2
}


###############################################################################
# "req_" are basically assertions for common errors. They test the condition,
# print a message (unless -q), and return a ZERR_ code.
req_sv_type() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage syntax:
    req_sv_type [-q] typename varname

Check whether the named shell variable (no dollar sign!)
is of the actual typeset-declared zsh type. That is,
one of undef, scalar, integer, float, array, or assoc). If so, return 0.
Otherwise (unless `-q` is set) print a message with
the caller name, variable name, and type, and return code ZERR_SV_TYPE.

Typical use:
    req_sv_type assoc $1 || return ZERR_SV_TYP

This function does not recognize a variable as an int, float, etc. if it's
value just currently looks like one. To truly be a different zsh variable type
the variable must be declared, for example with `typeset` (or similar
commands such as `local` and `export`):
    Integer:  typeset -i X  [or integer X)
    Float:    typeset -F X  [or float X)
    Array:    typeset -a X  [or typeset X=(...)]
    Assoc:    typeset -A X  [no shorthand]
    Scalar:   typeset X

Note: zsh types should not be confused with zerg types, which
are used to test the form of strings (such as option values), such as that
an int consists of one or more decimal digits (and maybe a sign prefix).
For testing zerg types, see `req_zerg_type [type] [value]`.
EOF
            return ;;
        -q|--quiet) quiet=1;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    local typ=`sv_type $2`
    if [[ $typ != "$1" ]]; then
        [ $quiet ] || tMsg 0 "Variable '$2' is $typ, not $1."
        return ZERR_SV_TYPE
    fi
}

req_zerg_type() {
    local quiet ic
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage:
    req_zerg_type [-q] typename string
    req_zerg_type date "2005-01-01" || return ZERR_ZERG_TVALUE
Check whether the string (not a merely named shell variable) satisfies the
named zerg type (see \$zerg_types). Return 0 iff so;
otherwise print a message with the caller name, string, and type.
Options:
    -q|--quiet: Suppress messages.
    -i|--ignore-case: Disregard case distinctions.
    -- Mark end of options
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        -i|--ignore-case) ic=1 ;;
        --) break ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    if ! is_of_zerg_type $1 $2; then
        [ $quiet ] || tMsg 0 "String '$2' does not match type $1."
        return ZERR_SV_TYPE
    fi
}

req_argc() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage:
    req_argc [-q] minArgs maxArgs value
    req_argc 2 2 $# || return ZERR_ARGC

Check whether the value passed in is between min and max inclusive.
Typically, a caller would use "$#" as the value, making the test be that
the caller's argument list is of appropriate length. Return 0 if correct,
otherwise print a message with the caller name, and the 3 arguments.
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    if [[ $# -ne 3 ]]; then
        [ $quiet ] || tMsg 0 "req_argc expected 3 args, but got $#."
        return ZERR_ARGC
    fi
    if [[ $3 -lt "$1" ]] || [[ $3 -gt "$2" ]]; then
        [ $quiet ] || tMsg 0 "Expected from $1 to $2 arg(s), but got $3."
        return ZERR_ARGC
    fi
}


###############################################################################
#
# A few general shell variable handlers (move to zerg_setup.sh)
#
sv_type() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: sv_type varname
Echo the zsh datatype of the named shell variable, as one of:
    undef, scalar, integer, float, array, assoc.
Example:
    if [[ `sv_type path` == "undef" ]]; then...
See also:  ${(t)name} or ${(tP)name}, which return a hyphen-separated list of
    keywords, which may also include `special`, `tied`, `export`, etc.
Note: These are not the same as the type names that can be passed to
    add_argument via the --type option. Those are enumerated in $aa_types,
    defined in bootstrap_defs.sh, and validated by functions in parse_args.sh.
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    #tMSg 1 "*** sv_type: '${(tP)1}' for '$1'."
    case "${(tP)1}" in
        "")           echo "undef" ;;
        scalar*)      echo "scalar" ;;
        integer*)     echo "integer" ;;
        float*)       echo "float" ;;
        array*)       echo "array" ;;
        association*) echo "assoc" ;;
        *) [ $quiet ] || tMsg 0 "Error, (tP) said '${(tP)1}'.";
            return 99 ;;
    esac
}

sv_quote() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: sv_quote varname
Echo the value of the named shell variable, escaped and quoted.
* undefined variable
    A message is displayed and RC is 1.
* integer and float variable, or string that passes is_int or is_float.
    No quotes added.
* array
    Treats each member separately, quoting all strings (including ''),
    but not numerics, and separating them by single spaces.
    Parentheses are not added.
* associative array
    Like zsh, extract just the values (not the keys), in undefined order,
    and treat them like an array (see above).
* scalar/string
    Put it in single quotes (unless it's a single token).
    Backslash any internal single quotes and backslashes.
    This uses zsh ${(qq)...}.
See also:  ${(q)name} (and qq, qqq, and qqqq); sv_tostring
TODO: Add like Python csv QUOTE_NONNUMERIC, MINIMAL, ALL, NONE?
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return ZERR_ARGC
    local typ=`sv_type $1`
    if [[ $typ == undef ]]; then
        [ $quiet ] || tMsg 0 "sv_quote: Variable not defined: '$1'."
        return ZERR_UNDEF
    fi
    local val=${(P)1}
    if [[ $typ == integer ]] || is_int -q $val; then
        echo $val
    elif [[ $typ == float ]] || is_float -q $val; then
        echo $val
    elif [[ $typ == array ]]; then
        local -a result
        for val in ${(P@)1}; do
            if is_float -q "$val"; then result+="$val"
            else result+="${(qq)val}"; fi
        done
        echo ${(j: :)result}
    elif [[ $typ == assoc ]]; then
        local -a result
        for val in ${(Pv@)1}; do
            if is_float -q "$val"; then result+="$val"
            else result+="${(qq)val}"; fi
        done
        echo ${(j: :)result}
    else  # scalar: quoting, not backslashes, please.
        echo ${(Pqq)1}
    fi
}

sv_tostring() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: sv_tostring varname
Echo the value of the named shell variable, in the form that can be used
    to re-create it via `typeset`.
See also: sv_quote; typeset -p
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return ZERR_ARGC
    local typ=`sv_type $1`
    if [[ $typ == "undef" ]]; then
        [ $quiet ] || tMsg 0 "sv_tostring: Variable not defined: '$1'."
        return ZERR_UNDEF
    fi
    local decl=$(typeset -p "$1" 2>/dev/null) || return ZERR_UNDEF
    echo "${decl#*=}"
}


###############################################################################
#
str_escape() {
    local format="html" quiet=""
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: str_escape [-f formatname] string
Escape the string as needed for the given format (default: html).
Options:
    -q | --quiet: Suppress error messages
    -f html: < to &lt;, & to &amp;, " to &quot;, and ]]> to ]]&gt;.
        This should suffice in content and in attribute values.
    -f xml: same as --html
    -f json: dquotes, backslashes, \n\r\t
    -f python: dquotes, backslashes, \n\r\t
    -f zsh: Use ${(q)}
    -f url: Various characters to UTF-8 and %xx encoding
    -- Mark end of options (say, if string to escape may start with "-")
See also: sv_quote; sv_tostring; sv_export
EOF
            return ;;
        -q|--quiet) quiet=1;;
        -f|--format) shift; format=$1 ;;
        --) break ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    local buf="$*"
    if [[ $format == html ]] || [[ $format == xml ]]; then
        buf="${buf//&/&amp;}"
        buf="${buf//</&lt;}"
        buf="${buf//\"/&quot;}"
        buf="${buf//]]>/]]&gt;}"
        echo "$buf"
    elif [[ $format == json ]]; then
        buf="${buf//\\/\\\\}"
        buf="${buf//\"/\\\"}"
        buf="${buf//$'\n'/\\n}"
        buf="${buf//$'\r'/\\r}"
        buf="${buf//$'\t'/\\t}"
        echo "$buf"
    elif [[ $format == python ]]; then
        buf="${buf//\\/\\\\}"
        buf="${buf//\"/\\\"}"
        buf="${buf//$'\n'/\\n}"
        buf="${buf//$'\r'/\\r}"
        buf="${buf//$'\t'/\\t}"
        echo "$buf"
    elif [[ $format == zsh ]]; then
        echo "${(q)buf}"
    elif [[ $format == url ]]; then
        local encoded=""
        local i
        for ((i=1; i<=${#buf}; i++)); do
            local c="${buf:$((i-1)):1}"
            if [[ "$c" =~ [A-Za-z0-9._~-] ]]; then
                encoded+="$c"
            elif [[ "$c" == ' ' ]]; then
                encoded+='+'
            else
                # Everything else needs encoding. TODO Check UTF-8
                local hex=$(printf '%%%02X' "'$c")
                encoded+="$hex"
            fi
        done
        echo "$encoded"
    else
        [ $quiet ] || tMsg 0 "str_escape: Unknown format '$format'"
        return ZERR_ENUM
    fi
}


###############################################################################
#
zerg_opt_to_var() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage zerg_opt_to_var [string]
    Remove leading hyphens, and turn any others to underscores.
    Then make sure the result is a legit variable name (is_ident)
EOF
        return
    fi
    local x=${${1#-}#-}
    x="$x:gs/-/_/"
    if ! is_ident "$x"; then
        tMsg 0 "Invalid identifier '$x' (original: '$1')."
        return ZERR_BAD_NAME
    fi
    echo $x
}


###############################################################################
#
export ZERG_SETUP=1

source 'aa_accessors.sh' || echo "aa_accessors.sh failed, code $?"
source 'zerg_types.sh' || echo "zerg_types.sh failed, code $?"
source 'zerg_new.sh' || echo "zerg_new.sh failed, code $?"
source 'zerg_add.sh' || echo "zerg_add.sh failed, code $?"
source 'zerg_parse.sh' || echo "zerg_parse.sh failed, code $?"

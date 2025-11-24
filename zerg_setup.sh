#!/bin/zsh
#
# Steven J. DeRose, 2025-05ff.


[ "$HELP_OPTION_EXPR" ] || typeset -gHi HELP_OPTION_EXPR="(-|--)(h|he|hel|help)"

###############################################################################
# Error return codes
#
typeset -gHi ZERR_NOT_YET=249
typeset -gHi ZERR_TEST_FAIL=248

typeset -gHi ZERR_EVAL_FAIL=99
typeset -gHi ZERR_ARGC=98
typeset -gHi ZERR_SV_TYPE=97
typeset -gHi ZERR_ZTYPE_VALUE=96
typeset -gHi ZERR_BAD_OPTION=95
typeset -gHi ZERR_ENUM=94
typeset -gHi ZERR_NO_KEY=93
typeset -gHi ZERR_NO_INDEX=92
typeset -gHi ZERR_UNDEF=91
typeset -gHi ZERR_BAD_NAME=90
typeset -gHi ZERR_DUPLICATE=89

typeset -gHi ZERR_NO_CLASS=79
typeset -gHi ZERR_NO_CLASS_DEF=78
typeset -gHi ZERR_CLASS_CHECK=77


###############################################################################
# Messaging
#
typeset -gHi ZERG_V=""
typeset -gH ZERG_STACK_LEVELS="10"
[[ "$1" == "-v" ]] && ZERG_V=1

# Centralized messaging/tracing, by verbosity level
tMsg() {
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        local level=$1; shift
    else
        local level=0
    fi
    [[ $ZERG_V -lt $level ]] && return
    local ftrace="" i=0
    for (( i=1; i<=$ZERG_STACK_LEVELS; i++ )); do
        [[ $functrace[$i] =~ zsh: ]] && break;
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

req_argc() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage:
    req_argc [-q] min max value
    req_argc 2 2 $# || return $ZERR_ARGC

Check whether the value passed in is between min and max inclusive.
Typically, a caller would use "$#" as the value, making the test be that
the caller's argument list is of appropriate length. Return 0 if correct,
otherwise print a message with the caller name, and the 3 arguments.

This can check any integer range, for example array bounds:
    req_argc 1 $#theArray $index...
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    if [[ $# -ne 3 ]]; then
        [ $quiet ] || tMsg 0 "req_argc expected 3 args, but got $#."
        return $ZERR_ARGC
    fi
    if [[ $3 -lt "$1" ]] || [[ $3 -gt "$2" ]]; then
        [ $quiet ] || tMsg 0 "Expected from $1 to $2 arg(s), but got $3."
        return $ZERR_ARGC
    fi
}

req_sv_type() {
    local quiet i
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage:
    req_sv_type [-q] typename varname [typename varname]*

For each typename/varname pair, check whether the named shell variable
is of the actual typeset-declared zsh type. That is,
one of undef, scalar, integer, float, array, or assoc). If so, return 0.
Otherwise  print a message with the caller name, variable name, and type
(unless `-q` is set), and return code ZERR_SV_TYPE.

Typical use:
    req_sv_type assoc $1 || return $ZERR_SV_TYPE

This function does not recognize a variable as an int, float, etc. if it's
value just currently looks like one (see is_int, etc. for such lexical tests).
To be considered a different zsh variable type the variable must be declared,
for example with `typeset` (or similar commands such as `local` and `export`)..
Undeclared plain assignment can only create scalars or arrays:
    Integer:  typeset -i X
              integer X
    Float:    typeset -F X
              float X
    Array:    typeset -a X
              typeset X=(...)
              X=(...)
    Assoc:    typeset -A X [no shorthand]
    Scalar:   typeset X
              X='some text'
              X=99 [this is still a scalar string, not an integer]

See also: is_sv_type, req_zerg_type, req_zerg_class.

Note: zsh types should not be confused with zerg types, which
interpret strings (such as option values). For example, a zerg "int"
consists of one or more decimal digits (and maybe a sign prefix).
A zerg "pid" must be an unsigned decimal int, but also be an active process id,
To test zerg types, see `is_of_zerg_type` or `is_` plus a type name.
EOF
            return ;;
        -q|--quiet) quiet="-q" ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done


    while (($# > 1)); do
        local typ=`sv_type $2`
        if [[ $typ != "$1" ]]; then
            [ $quiet ] || tMsg 0 "Variable '$2' is $typ, not $1."
            return $ZERR_SV_TYPE
        fi
        shift 2
    done
}

req_zerg_type() {
    local quiet ic
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage:
    req_zerg_type [-q] typename string [typename string]*
    req_zerg_type date "2005-01-01" || return $ZERR_ZTYPE_VALUE
Check whether the string satisfies the named zerg type (see \$zerg_types).
Return 0 iff so; otherwise print a message with the caller name, string, and type.
Typically the string should be quoted:
    req_zerg_type idents "$myData"
Note: This checks values, not variables as such. So to test a variable,
    reference it with "$" (as just shown), don't just name it.
Options:
    -q|--quiet: Suppress messages.
    -i|--ignore-case: Disregard case distinctions.
    -- Mark end of options.
See also: is_of_zerg_type, req_zerg_class, req_sv_type.
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        -i|--ignore-case) ic=1 ;;
        --) break ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    while (($# > 1)); do
        if ! is_of_zerg_type $1 $2; then
            [ $quiet ] || tMsg 0 "String '$2' does not match type $1."
            return $ZERR_ZTYPE_VALUE
        fi
        shift 2
    done
}

req_zerg_class() {
    local quiet ic
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage:
    req_zerg_class [-q] classname varname
Check whether the named variable (not a value) is of the
named zerg class (see \$ZERG_CLASS_KEY). Return 0 iff so;
otherwise print a message and return non-zero rc.
Options:
    -q|--quiet: Suppress messages.
See also: is_of_zerg_class.
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 2 $# || return $ZERR_ARGC
    req_zerg_type ident "$1" || return $ZERR_ARGC
    req_sv_type assoc "$2" || return $ZERR_ARGC

    while (($# > 1)); do
        if ! [[ `zerg_get_class "$2"` == "$1" ]]; then
            [ $quiet ] || tMsg 0 "Assoc '$2' is not of zerg class '$1'."
            return $ZERR_SV_TYPE
        fi
        shift 2
    done
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
Examples:
    if [[ `sv_type path` == "undef" ]]; then...
See also:  ${(t)name} or ${(tP)name}, which return a hyphen-separated list of
    keywords, which may also include `special`, `tied`, `export`, etc.
Notes:
    * "x=99" makes a scalar string, vs. "local -i x=00" which makes an integer.
    * zsh types are not the same as zerg types, which are used to constrain
      the strings accepted as option/argument values with `zerg_parse`.
See also: is_of_zerg_type, zerg_get_class.
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
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

is_of_sv_type() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: is_of_sv_type svtype varname
    Check whether the named shell variable is of the given zsh type, one of
    undef, scalar, integer, float, array, assoc.
Examples:
    is_of_sv_type undef path || return $?
See also: is_of_zerg_type.
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    local the_type=`sv_type "$2"` || return $?
    [[ $the_type == "$1" ]] || return 1
}

sv_quote() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
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
    and treat them like an array (see above). See also aa_export.
* scalar/string
    Put it in single quotes (unless it's a single token).
    Backslash any internal single quotes and backslashes.
    This uses zsh ${(qq)...}.
See also: ${(q)name} (and qq, qqq, and qqqq); sv_tostring; aa_export.
TODO: Add like Python csv QUOTE_NONNUMERIC, MINIMAL, ALL, NONE?
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return $ZERR_ARGC
    local typ=`sv_type $1`
    if [[ $typ == undef ]]; then
        [ $quiet ] || tMsg 0 "sv_quote: Variable not defined: '$1'."
        return $ZERR_UNDEF
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
    to re-create it via `typeset` or store it as a packed (q.v.).
See also: sv_quote, typeset -p.
EOF
            return ;;
        -q|--quiet) quiet='-q';;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return $ZERR_ARGC
    local typ=`sv_type $1`
    if [[ $typ == "undef" ]]; then
        [ $quiet ] || tMsg 0 "sv_tostring: Variable not defined: '$1'."
        return $ZERR_UNDEF
    fi
    local decl=$(typeset -p "$1" 2>/dev/null) || return $ZERR_UNDEF
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
    -- Mark end of options (say, if a string to escape may start with "-")
See also: sv_quote; sv_tostring; sv_export
EOF
            return ;;
        -q|--quiet) quiet="-q" ;;
        -f|--format) shift; format=$1 ;;
        --) break ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
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
        return $ZERR_ENUM
    fi
}


###############################################################################
#
zerg_opt_to_var() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage zerg_opt_to_var [string]
    Remove leading hyphens, and turn any others to underscores.
    Then make sure the result is a legit variable name (is_ident).
See also: is_argname, is_varname.
EOF
        return
    fi
    local x=${${1#-}#-}
    x="$x:gs/-/_/"
    if ! is_ident "$x"; then
        tMsg 0 "Invalid identifier '$x' (original: '$1')."
        return $ZERR_BAD_NAME
    fi
    echo $x
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
#
export ZERG_SETUP=1

source 'aa_accessors.sh' || echo "aa_accessors.sh failed, code $?"
source 'zerg_objects.sh' || echo "zerg_objects.sh failed, code $?"
source 'zerg_types.sh' || echo "zerg_types.sh failed, code $?"
source 'zerg_new.sh' || echo "zerg_new.sh failed, code $?"
source 'zerg_add.sh' || echo "zerg_add.sh failed, code $?"
source 'zerg_parse.sh' || echo "zerg_parse.sh failed, code $?"

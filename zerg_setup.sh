#!/bin/zsh
#
# sjd and Claude, 2025-05-31


###############################################################################
# Test and messaging support
#
export ZERG_V=""
[[ "$1" == "-v" ]] && ZERG_V=1

tMsg() {
    local level=$1
    shift
    [[ $ZERG_V -lt $level ]] && return
    print "z.tMsg: $functrace[1] < $functrace[2]: $*" >&2
}

tHead() {
    print  >&2
    print "####### $*" >&2
}

req_sv_type() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage:
    req_sv_type [-q] typename varname
    req_sv_type assoc MYVAR || return 97
    req_sv_type assoc MYVAR || typeset -A MYVAR

Check whether the named shell variable is of the actual zsh type,
one of (undef, scalar, integer, float, array, assoc). Return 0 iff so;
otherwise print a message with the caller name, variable name, and type.

Note: A scalar (string) variable is not an int or float, even if it
looks like one. To be something else, the variable must have been declared with
`typeset` or its kind as '-i` for int,
`-F` for float, `-a` for array, or `-A` for associative array (aka assoc).

Note 2: zsh types are not the same as zerg types (for which see req_zerg_type()).
EOF
        return
    fi
    local quiet=""
    if [[ "$1" == "-q" ]]; then
        quiet=1; shift;
    fi
    local typ=`sv_type $2`
    if [[ $typ != "$1" ]]; then
        [ $quiet ] || tMsg 0 "Variable '$2' is $typ, not $1."
        return 1
    fi
}

req_zerg_type() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage:
    req_zerg_type [-q] typename string
    req_zerg_type date "2005-01-01" || return 96

Check whether the string (not a merely named shell variable) satisfies the
named zerg type (see \$zerg_types). Return 0 iff so;
otherwise print a message with the caller name, string, and type.
EOF
        return
    fi
    local quiet=""
    if [[ "$1" == "-q" ]]; then
        quiet=1; shift;
    fi
    if ! is_of_zerg_type $1 $2; then
        [ $quiet ] || tMsg 0 "String '$2' does not match $1."
        return 1
    fi
}

req_aa_has() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage:
    req_aa_has assocname key
    req_aa_has zerg_types \$4 || return 96

Check whether the named shell associative array has an entry with the
key (without case-folding or abbreviation). Return 0 iff so;
otherwise print a message with the caller varname, and failed key.

To do: Rename or alias 'contains'?
EOF
        return
    fi
    local quiet=""
    if [[ "$1" == "-q" ]]; then
        quiet=1; shift;
    fi
    if ! aa_has $1 "$2"; then
        [ $quiet ] || tMsg 0 "Assoc '$1' does not have key $2."
        return 1
    fi
}

req_argc() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage:
    req_argc [-q] minArgs maxArgs value
    req_argc 2 2 $# || return 98

Check whether the value passed in between min and max inclusive.
Typically, a caller would use "$#" as the value, making the test be that
the caller's argument list is of appropriate length. Return 0 if correct,
otherwise print a message with the caller name, and the 3 arguments.
EOF
        return
    fi
    local quiet=""
    if [[ "$1" == "-q" ]]; then
        quiet=1; shift;
    fi
    if [[ $# -ne 3 ]]; then
        [ $quiet ] || tMsg 0 "req_argc expected 3 args, but got $#."
        return 99
    fi

    if [[ $3 -lt "$1" ]] || [[ $3 -gt "$2" ]]; then
        [ $quiet ] || tMsg 0 "Expected from $1 to $2 arg(s), but got $3."
        return 1
    fi
}


###############################################################################
#
# A few general shell variable handlers (move to zerg_setup.sh)
#
sv_type() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
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
        return
    fi
    #tMSg 1 "*** sv_type: '${(tP)1}' for '$1'."
    case "${(tP)1}" in
        "")           echo "undef" ;;
        scalar*)      echo "scalar" ;;
        integer*)     echo "integer" ;;
        float*)       echo "float" ;;
        array*)       echo "array" ;;
        association*) echo "assoc" ;;
        *) tMsg 0 "Error, (tP) said '${(tP)1}'."; return 99 ;;
    esac
}

sv_quote() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: sv_quote varname
Echo the value of the named shell variable, escaped and quoted.
* undefined variable
    A message is display and RC is 1.
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
EOF
        return
    fi
    req_argc 1 1 $# || return 98
    local typ=`sv_type $1`
    if [[ $typ == undef ]]; then
        tMsg 0 "sv_quote: Variable not defined: '$1'."
        return 1
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
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: sv_tostring varname
Echo the value of the named shell variable, in the form that can be used
    to re-create it via `typeset`.
See also: sv_quote; typeset -p
EOF
        return
    fi
    req_argc 1 1 $# || return 98
    local typ=`sv_type $1`
    if [[ $typ == "undef" ]]; then
        tMsg 0 "sv_tostring: Variable not defined: '$1'."
        return 1
    fi
    local decl=$(typeset -p "$1" 2>/dev/null) || return 1
    echo "${decl#*=}"
}


###############################################################################
#
str_escape() {
    local format="html" quiet=""
    while [[ $# -gt 0 ]]; do case "$1" in
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
See also: sv_quote; sv_tostring; sv_export
EOF
            return ;;
        -q|--quiet) quiet=1;;
        -f|--format) shift; format=$1 ;;
        -*) tMsg 0 "Unrecognized option '$1'."; return 99 ;;
        *) break ;;
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
        return 90
    fi
}


###############################################################################
#
export ZERG_SETUP=1

source 'aa_accessors.sh' || echo "aa_accessors.sh failed, code $?"
source 'zerg_types.sh' || echo "zerg_types.sh failed, code $?"
source 'zerg_new.sh' || echo "zerg_new.sh failed, code $?"
source 'zerg_add.sh' || echo "zerg_add.sh failed, code $?"
source 'zerg_parse.sh' || echo "zerg_parse.sh failed, code $?"

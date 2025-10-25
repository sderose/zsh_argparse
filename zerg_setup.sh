#!/bin/zsh
#
# sjd and Claude, 2025-05-31


###############################################################################
# Test and messaging support
#
tMsg() {
    local level=$1
    shift
    [[ $v -lt $level ]] && return
    print "tMsg: $*" >&2
}

tHead() {
    print  >&2
    print "####### $*" >&2
}

req_sv_type() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage:
    req_sv_type typename varname
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
    local typ=`sv_type $2`
    if [[ $typ != "$1" ]]; then
        tMsg 0 "$funcstack[2] < $funcstack[3]: Variable '$2' is $typ, not $1."
        return 1
    fi
}

req_zerg_type() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage:
    req_zerg_type typename string
    req_zerg_type date "2005-01-01" || return 96

Check whether the string (not a merely named shell variable) satisfies the
named zerg type (see \$zerg_types). Return 0 iff so;
otherwise print a message with the caller name, string, and type.
EOF
        return
    fi
    if ! is_of_zerg_type $1 $2; then
        tMsg 0 "$funcstack[2] < $funcstack[3]: String '$2' does not match $1."
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
    if ! aa_has $1 "$2"; then
        tMsg 0 "$funcstack[2] < $funcstack[3]: Assoc '$1' does not have key $2."
        return 1
    fi
}

req_argc() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage:
    req_argc minArgs maxArgs value
    req_argc 2 2 $# || return 98

Check whether the value passed in between min and max inclusive.
Typically, a caller would use "$#" as the value, making the test be that
the caller's argument list is of appropriate length. Return 0 if correct,
otherwise print a message with the caller name, and the 3 arguments.
EOF
        return
    fi
    if [[ $# -ne 3 ]]; then
        tMsg 0 "$funcstack[2]: req_argc expected 3 args, but got $#."
        return 99
    fi

    if [[ $3 -lt "$1" ]] || [[ $3 -gt "$2" ]]; then
        tMsg 0 "$funcstack[2]: Expected from $1 to $2 arg(s), but got $3."
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
For undefined variables, a message is display and RC is 1.
For int and float values, this won't have any net effect.
For strings, it will put them in single quotes (unless they're a single
    token), backslash any internal single quotes and backslashes.
For arrays it will quote each member as a string, separate them by single
    spaces, but not parenthesize.
For assocs it extracts just the values (not the keys), in undefined order,
    and treats them like an array.
See also:  ${(q)name} (and qq, qqq, and qqqq); sv_tostring
EOF
        return
    fi
    req_argc 1 1 $# || return 98
    local typ=`sv_type $1`
    if [[ $typ == "undef" ]]; then
        tMsg 0 "sv_quote: Variable not defined: '$1'."
        return 1
    fi
    #local varname="$1"
    echo ${(Pq)1}
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
    local format="html"
    while [[ $# -gt 0 ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: str_escape [-f formatname] string
Escape the string as needed for the given format (default: html).
Options:
    -f html: < to &lt;, & to &amp;, " to &quot;, and ]]> to ]]&gt;.
        This should suffice in content and in attribute values.
    -f xml: same as --html
    -f json: dquotes, backslashes, \n\r\t
    -f python: dquotes, backslashes, \n\r\t
    -f typeset: Let zsh do it
    -f url: Various characters to UTF-8 and %xx encoding
See also: sv_quote; sv_tostring; sv_export
EOF
            return ;;
        -f|--format) shift; format=$1 ;;
        -*) tMsg 0 "Unrecognized option '$1'."; return 99 ;;
        *) break ;;
      esac
      shift
    done

    local buf="$*"
    if [[ $format == html ]]; then
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
    elif [[ $format == typeset ]]; then
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
        tMsg 0 "str_escape: Unknown format '$format'"
        return 90
    fi
}


###############################################################################
# Bootstrap definitions for add_argument's own parameters
# Define the options for def_argument itself (which is very much like
# Python argparse.add_argument().
# Normally this would be done via def_argument itself, but this works even
# before it exists.
#
# Each arg definition is stored as a zsh associative array of its options.
# "Refname" is for functions to refer to it when assembling an actual parser,
# and defaults to the same name as the first name given.
#
# TODO Probably don't need an option def for the refname.
# TODO Predefine stable of common attrs such as
#     ignore-case, iencoding, oencoding, verbose, help, field-separator,
#     version, quiet, force, recursive, dry-run/no-act/test, output, count,
#     grep etc: expr, ignore-case, extended-regex, invert-match
#     number, bytes, characters, fields, lines, human-readable
#     field-sep, iformat, oformat, key

#
typeset -A _zerg_names=(
    type        str
    required    ""
    pattern     "^-[-\w]+( +-[-\w]+)$"
    help        "Name of associative array to store argument definition"
)

typeset -A _zerg_action=(
    names       "-a --action"
    type        str
    choices     "${(k)zerg_actions}"
    default     STORE
    pattern     "^("${(kj:|:)zerg_actions}")$"
    help        "Action to take when argument is encountered"
)

typeset -A _zerg_choices=(
    names       "-c --choices"
    type        str
    help        "Space-separated list of valid choices"
)

typeset -A _zerg_const=(
    names       "-k --const"
    type        str
    help        "Constant value for store_const action"
)

typeset -A _zerg_default=(
    names       "-d --default"
    type        str
    help        "Default value if argument not provided"
)

typeset -A _zerg_dest=(
    names       "-v --dest"
    type        str
    pattern     "^\w+$"
    help        "Variable name to store result (defaults to option name)"
)

typeset -A _zerg_fold=(
    names       "--fold"
    type        str
    choices     "${(k)aa_folds}"
    default     NONE
    pattern     "^("${(kj:|:)aa_folds}")$"
    help        "Case folding: ${(k)aa_folds}"
)

typeset -A _zerg_force=(
    names       "--force"
    type        bool
    action      store_true
    help        "Overwrite existing argument definition"
)

typeset -A _zerg_format=(
    names       "--format"
    type        str
    pattern     "^.*%.*$"
    help        "sprintf-style format string for display"
)

typeset -A _zerg_help=(
    names       "-h --help"
    type        str
    help        "Help text for this argument"
)

typeset -A _zerg_nargs=(
    names       "-n --nargs"
    type        str
    pattern     "^(\?|\*|\+|[0-9]+)$"
    help        "Number of arguments (?, *, +, or integer)"
)

typeset -A _zerg_pattern=(
    names       "-x --pattern"
    type        regex
    help        "Regex pattern that string values must match"
)

typeset -A _zerg_required=(
    names       "-r --required"
    type        bool
    action      store_true
    help        "Argument is required"
)

typeset -A _zerg_type=(
    names       "-t --type"
    type        str
    choices     "${(k)zerg_types}"
    default     str
    pattern     "^(${(kj:|:)zerg_types})$"
    help        "Argument data type"
)


###############################################################################
#
export ZERG_SETUP=1


source 'aa_accessors.sh' || echo "aa_accessors.sh failed, code $?"
source 'zerg_types.sh' || echo "zerg_types.sh failed, code $?"
source 'zerg_new.sh' || echo "zerg_new.sh failed, code $?"
source 'zerg_add.sh' || echo "zerg_add.sh failed, code $?"
source 'zerg_parse.sh' || echo "zerg_parse.sh failed, code $?"
#source 'test_funcs.sh' ||  echo "test_funcs.sh failed, code $?"

#!/bin/zsh
# Simplified, Python-like interface for zsh associative arrays.
#
# Copyright 2025, Steven J. DeRose.
# May be used under the terms of the Creative Commons Attribution-Sharealike
# license (for which see https://creativecommons.org/licenses/by-sa/3.0).


###############################################################################
# A few general shell variable handlers (move to separate file?)
#
req_sv_type() {
    local typ=`sv_type $2`
    if [[ $typ != "$1" ]]; then
        tMsg 0 "Variable '$2' is $typ, not $1."
        return 1
    fi
}

req_args() {
    if [[ $1 != "$2" ]]; then
        tMsg 0 "Expected $1' are, but got $2."
        return 1
    fi
}

sv_type() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: sv_type varname
Echo the zsh datatype of the named shell variable, as one of:
    undef, scalar, integer, float, array, assoc.
Example:
    if [[ `sv_type PATH` == "undef" ]]; then...
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
    req_args 1 $# || return 98
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
    req_args 1 $# || return 98
    local typ=`sv_type $1`
    if [[ $typ == "undef" ]]; then
        tMsg 0 "sv_tostring: Variable not defined: '$1'."
        return 1
    fi
    local decl=$(typeset -p "$1" 2>/dev/null) || return 1
    echo "${decl#*=}"
}

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
    -f json: dquotes and backslashes
    -f python: dquotes and backslashes
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
# Functions to ease management of shell variables by name.
# Most of the things can be done by variations on ${(...)name}, but
# some may not be practical without eval.
#
# Overview: set, get, has, len, keys. values, unset/del, init, clear, copy,
#     update, set_default, eq, export.
# Also: find_key and get_abbrev, which support unique abbreviations.
#     This is needed for parse_args.

# Set a key-value pair in a named associative array
#
aa_set() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_set arrayname key value
Set a key-value pair in a named associative array.
This is equivalent to: arrayname[key]=value
EOF
        return
    fi

    req_args 3 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" key="$2" value="$3"

    # Use parameter expansion to set the value indirectly
    eval "${arrayname}[${(q)key}]='${(q)value}'"
}

# Get a value from a named associative array
aa_get() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_get [-d default_value] arrayname key
Get a value from a named associative array.
If it is not present, issue a warning (unless -q) and return code 1.
Options:
  -d default_value  Return this value if key does not exist
See also: aa_find_key, aa_get_abbrev
Returns: value via stdout
This is equivalent to: echo ${arrayname[key]}
EOF
        return
    fi

    local default_value="" use_default="" quiet=""

    # Parse options
    while [[ "$1" == -* ]]; do
        case "$1" in
            -q|--quiet) quiet=1 ;;
            -d|--default) default_value="$2"
                use_default=1
                shift ;;
            *) tMsg 0 "aa_get: Unknown option $1"
                return 99 ;;
        esac
        shift
    done

    req_args 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" key="$2"

    if aa_has "$arrayname" "$key"; then
        echo "${${(P)arrayname}[$key]}"
    elif [[ -n "$use_default" ]]; then
        echo "$default_value"
    else
        [ "$quiet" ] || tMsg 0 "aa_get: Key '$key' not found in $arrayname."
        return 1
    fi
}

aa_has() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_has arrayname key
Check if a key exists in a named associative array.
Returns: 0 if key exists, 1 if not
EOF
        return
    fi

    req_args 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" key="$2"

    #(( ${(P)arrayname[(I)$key]} )) && return 0
    #[[ -n ${(P)arrayname[(I)$key]} ]] && return 0
    #(( ${(P)+${arrayname}[${key}]} )) && return 0

    keys=("${(@Pk)arrayname}")
    [[ ${keys[(ie)$key]} -le ${#keys} ]] && return 0
    return 1
}

aa_len() {  # TODO rename sv
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_len varname
Return the number of items in the variable.

Note: This can be used on any type, not just associative arrays.
It is just here for convenience, and it works the same as zsh's
built-in ${(P)#varname}. That means that
what it returns is different for different zsh types:
    * arrays (-a): the number of items
    * associative arrays (-A): the number of items
    * strings: the length in characters
    * ints (-i): the number of decimal digits (no leading zeros)
    * floats (-F): apparently the length of the decimal expansion
    * undefined: display nothing, return code 0
EOF
        return
    fi

    echo "${(P)#1}"
}

aa_keys() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_keys arrayname [target_array]
Get all keys from a named associative array.
If target_array is provided, store keys in that array.
Otherwise, print a space-separated list of keys.

Note: Keys containing spaces will be properly quoted.

TODO: Add sort option(s)?
EOF
        return
    fi

    if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
        tMsg 0 "aa_keys: Expected 1-2 arguments (arrayname tgtvar?), got $#"
        return 98
    fi
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" target_array="$2"

    # Use (k) flag to get keys -- TODO ???
    local -a keys
    keys=(${(k)${(P)arrayname}})

    if [[ -n "$target_array" ]]; then
        eval "${target_array}=(\${keys[@]})"
    else
        printf '%q ' "${keys[@]}"
    fi
}

aa_values() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_values arrayname [target_array]
Get all values from a named associative array.
If target_array is provided, store values in that array.
Otherwise, print a space-separated list of values to stdout.

Note: Values containing spaces will be properly quoted.
EOF
        return
    fi

    if [[ $# -lt 1 || $# -gt 2 ]]; then
        tMsg 0 "aa_values: Expected 1-2 arguments (arrayname tgtvar?), got $#"
        return 98
    fi
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" target_array="$2"

    local -a values
    values=(${(v)${(P)arrayname}})

    if [[ -n "$target_array" ]]; then
        eval "${target_array}=(\${values[@]})"
    else
        printf '%q ' "${values[@]}"
    fi
}

aa_unset() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_unset arrayname key
Delete a key from a named associative array.
EOF
        return
    fi

    req_args 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" key="$2"
    unset "${arrayname}[${(q)key}]"
}
alias aa_del=aa_unset

aa_init() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_init arrayname
Initialize a new associative array (if it does not exist)
with the given name.
EOF
        return
    fi

    req_args 1 $# || return 98

    # Only initialize if it does not exist  TODO or not assoc?
    if ! typeset -p "$1" &>/dev/null; then
        typeset -gA "$1"
    fi
}

aa_clear() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_clear arrayname
Clear all entries from the named associative array.
The array itself remains defined but becomes empty.
EOF
        return
    fi

    req_args 1 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1"

    # Get all keys and unset them
    local -a keys
    keys=(${(k)${(P)arrayname}})
    for key in "${keys[@]}"; do
        unset "${arrayname}[${(q)key}]"
    done
}

aa_find_key() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_find_key [-i] arrayname partial_key
Find minimum unique key matches in the named associative array.
Arguments:
  arrayname        - name of the associative array
  partial_key      - partial key to match against
Option:
  -i               - case insensitive
Returns:
  0 = not found
  1 = unique match (sets global _aa_matched_key)
  2 = multiple matches
EOF
        return
    fi

    local case_insensitive=""
    if [[ $1 == "-i" ]]; then
        case_insensitive=1; shift
    fi
    req_args 2 $# || return 98
    req_sv_type assoc "$1" || return 97

    local arrayname="$1" partial_key="$2"
    local -a matches
    local -a all_keys
    local search_key="$partial_key"

    # Get all keys
    all_keys=(${(k)${(P)arrayname}})

    # Convert to lowercase for case-insensitive matching
    if [[ "$case_insensitive" == "1" ]]; then
        search_key="${partial_key:l}"
    fi

    # Find matches that start with partial_key
    for key in "${all_keys[@]}"; do
        local compare_key="$key"
        if [[ "$case_insensitive" == "1" ]]; then
            compare_key="${key:l}"
        fi

        if [[ "$compare_key" == "$search_key"* ]]; then
            matches+=("$key")
        fi
    done

    case ${#matches} in
        0) unset _aa_matched_key
           return 0 ;;  # NOT FOUND
        1) _aa_matched_key="${matches[1]}"
           return 1 ;;  # UNIQUE
        *) unset _aa_matched_key
           return 2 ;;  # NOT UNIQUE
    esac
}

aa_get_abbrev() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_get_abbrev [-i] arrayname partial_key
Get an entry's value from the named associative array, allowing
abbreviations of keys (so long as they are long enough to be unique).
Arguments:
  arrayname        - name of the associative array
  partial_key      - partial key to match against
Option:
  -i               - case_insensitive
Output: value via stdout if unique match, error message to stderr otherwise
Return codes: 0=success, 1=not found, 2=not unique
EOF
        return
    fi

    local case_insensitive=""
    if [[ $1 == "-i" ]]; then
        case_insensitive=1; shift
    fi
    req_args 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" partial_key="$2"

    aa_find_key "$arrayname" "$partial_key" "$case_insensitive"
    local result=$?
    case $result in
        0) tMsg 0 "Key '$partial_key' not found in $arrayname"; return 1 ;;
        1) aa_get "$arrayname" "$_aa_matched_key"; return 0 ;;
        2) tMsg 0 "Key '$partial_key' is ambiguous in $arrayname"; return 2 ;;
    esac
}

aa_copy() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_copy source_array target_array
Create a shallow copy of an associative array.
Initialize the target array if it does not exist already.
EOF
        return
    fi

    req_args 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local source_array="$1" target_array="$2"

    aa_init "$target_array"
    aa_clear "$target_array"
    local -a keys
    keys=(${(k)${(P)source_array}})
    for key in "${keys[@]}"; do
        local value
        value=$(aa_get "$source_array" "$key")
        aa_set "$target_array" "$key" "$value"
    done
}

aa_update() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_update target_array source_array
Update target_array with key-value pairs from source_array.
Existing keys in target_array will be overwritten.
EOF
        return
    fi

    req_args 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local target_array="$1" source_array="$2"
    local -a keys
    keys=(${(k)${(P)source_array}})

    for key in "${keys[@]}"; do
        local value
        value=$(aa_get "$source_array" "$key")
        aa_set "$target_array" "$key" "$value"
    done
}

aa_setdefault() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_setdefault arrayname key default_value
Set key to default_value if key does not already exist in the array.
Returns: the existing value or the default value that was set
EOF
        return
    fi

    req_args 3 $# || return 98
    req_sv_type assoc "$1" || return 97
    if aa_has "$1" "$2"; then
        aa_get "$1" "$2"
    else
        aa_set "$1" "$2" "$3"
        echo "$3"
    fi
}

aa_eq() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_eq array1 array2
Compare two associative arrays for equality.
Returns: 0 if equal, 1 if different
EOF
        return
    fi

    req_args 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local array1="$1" array2="$2"

    local -a keys1 keys2
    aa_keys "$array1" keys1
    aa_keys "$array2" keys2

    [[ ${#keys1[@]} -eq ${#keys2[@]} ]] || return 3

    for key in "${keys1[@]}"; do
        #echo "k: $key."
        aa_has "$array2" "$key" || return 2
        local val1=$(aa_get "$array1" "$key")
        local val2=$(aa_get "$array2" "$key")
        [[ "$val1" == "$val2" ]] || return 1
    done
    return 0
}

aa_export() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_export [-f format] arrayname
Export associative array to various formats.
Formats:
  python     - Python dict syntax: {"key": "value", ...}
  json       - JSON object syntax: {"key": "value", ...}
  htmltable  - HTML table with key/value columns
  htmldl     - HTML definition list
  typeset    - zsh typeset format: ( [key]=value [key2]=value2 )
Default: python.
TODO Integrate str_escape
EOF
        return
    fi

    local format="python"
    while [[ "$1" == -* ]]; do
        case "$1" in
            -f|--format) format="$2"; shift 2 ;;
            *) tMsg 0 "aa_export: Unknown option $1"; return 99 ;;
        esac
    done

    req_args 1 $# || return 98
    req_sv_type assoc "$1" || return 97
    local -a keys
    keys=(${(k)${(P)1}})

    case "$format" in
        htmltable)
            echo "<table id=\"$1\">"
            echo "<thead><tr><th>Key</th><th>Value</th></tr></thead>"
            echo "<tbody>"
            for key in "${keys[@]}"; do
                local ekey=$(str_escape -f html "$key")
                local value=$(aa_get -q "$1" "$key")
                local evalue=$(str_escape -f html "$value")
                echo "<tr><td>$ekey</td><td>$evalue</td></tr>"
            done
            echo "</tbody>"
            echo "</table>" ;;
        htmldl)
            echo "<dl id=\"$1\">"
            for key in "${keys[@]}"; do
                local value=$(aa_get -q "$1" "$key")
                local escaped_key=$(str_escape -f html "$key")
                local escaped_value=$(str_escape -f html "$value")
                echo "<dt>$escaped_key</dt>"
                echo "<dd>$escaped_value</dd>"
            done
            echo "</dl>" ;;
        json)
            echo -n "{"
            local first=1
            for key in "${keys[@]}"; do
                [[ $first -eq 0 ]] && echo -n ", "
                first=0
                local value=$(aa_get -q "$1" "$key")
                local escaped_key=$(str_escape -f json "$key")
                local escaped_value=$(str_escape -f json "$value")
                echo -n "\"$escaped_key\": \"$escaped_value\""
            done
            echo "}" ;;
        python)
            echo -n "$1 = {"
            local first=1
            for key in "${keys[@]}"; do
                [[ $first -eq 0 ]] && echo -n ", "
                first=0
                local value=$(aa_get -q "$1" "$key")
                local escaped_key=$(str_escape -f python "$key")
                local escaped_value=$(str_escape -f python "$value")
                echo -n "\"$escaped_key\": \"$escaped_value\""
            done
            echo "}" ;;
        typeset)
            echo -n "( "
            for key in "${keys[@]}"; do
                local value=$(aa_get -q "$1" "$key")
                local quoted_key=$(str_escape -f typeset "$key")
                local quoted_value=$(str_escape -f typeset "$value")
                echo -n "[${quoted_key}]=${quoted_value} "
            done
            echo ")" ;;
        *)
            tMsg 0 "aa_export: Unknown format '$format'"
            return 93 ;;
    esac
}

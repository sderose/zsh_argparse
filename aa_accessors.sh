#!/bin/zsh
# Simplified, Python-like interface for zsh associative arrays.
#
# Copyright 2025, Steven J. DeRose.
# May be used under the terms of the Creative Commons Attribution-Sharealike
# license (for which see https://creativecommons.org/licenses/by-sa/3.0).

if ! [ $ZERG_SETUP ]; then
    echo "Source zerg_setup.sh first." >&2
    return 99
fi


###############################################################################
# Functions to ease management of shell associative arrays by name.
# Most of the things can be done by variations on ${(P)...)name}, but
# the syntax can get subtle.
#
# Overview: The functions are pretty close to those of Python `dict`.
# However, this package also supports item lookups by abbreviations of keys
# (as desired for option-name matching for commands).
#     Basics: init, clear, copy, update, set_default
#     Predicates: len, eq, has (=contains)
#     Item access: set, get, unset (=del)
#     Extractors: keys, values, export
# Also:
#     append_value, insert_value, find_key, and get_abbrev


###############################################################################
# Basics: init, clear, copy, update, set_default
#
aa_init() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_init arrayname
Initialize a new associative array (if it does not exist)
with the given name.
EOF
        return
    fi

    req_argc 1 1 $# || return 98

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

    req_argc 1 1 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1"

    # Get all keys and unset them
    local -a keys
    keys=(${(k)${(P)arrayname}})
    for key in "${keys[@]}"; do
        unset "${arrayname}[${(q)key}]"
    done
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

    req_argc 2 2 $# || return 98
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

    req_argc 2 2 $# || return 98
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

aa_set_default() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_setdefault arrayname key default_value
Set key to default_value if key does not already exist in the array.
Returns: the existing value or the default value that was set
EOF
        return
    fi

    req_argc 3 3 $# || return 98
    req_sv_type assoc "$1" || return 97
    if aa_has "$1" "$2"; then
        aa_get "$1" "$2"
    else
        aa_set "$1" "$2" "$3"
        echo "$3"
    fi
}


###############################################################################
# Predicates: len, eq, has (=contains)
#
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

aa_eq() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_eq assoc1 assoc2
Compare two associative arrays for equality.
Returns: 0 if equal, 1 if different
EOF
        return
    fi

    req_argc 2 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local array1="$1" array2="$2"

    local -a keys1 keys2
    aa_keys "$array1" keys1
    aa_keys "$array2" keys2

    #typeset -p keys1
    #typeset -p keys2

    [[ ${#keys1[@]} -eq ${#keys2[@]} ]] || return 3

    for key in "${keys1[@]}"; do
        #echo "aa_eq $1 vs $2: key '$key'."
        aa_has "$array2" "$key" || return 2
        local val1=$(aa_get "$array1" "$key")
        local val2=$(aa_get "$array2" "$key")
        [[ "$val1" == "$val2" ]] || return 1
    done
    return 0
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
    req_argc 2 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" key="$2"

    local keys=("${(@Pk)arrayname}")
    [[ ${keys[(ie)$key]} -le ${#keys} ]] && return 0
    return 1
}


###############################################################################
# Item access: set, get, unset (=del)
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

    req_argc 3 3 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" key="$2" value="$3"

    # Use parameter expansion to set the value indirectly
    # Single-q the key, b/c qq would store the quotes.
    # But double-q the value, so we don't store backslashes.
    #tMsg 0 "Evaluating 1: ${arrayname}[${(q)key}]='${(qq)value}'"
    local evalString="${arrayname}[${(q)key}]=${(qq)value}"
    eval $evalString
    local rc=$?
    if [ $? != 0 ]; then
        tMsg 0 "aa_set $1 $2 $3 failed (rc $rc) on eval of $evalString"
        return 90
    fi
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

    #setopt xtrace
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

    req_argc 2 2 $# || return 98
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
    #unsetopt xtrace
}

aa_unset() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_unset arrayname key
Delete the item with the given key from a named associative array.
Note: To unset an entire associative array, just use `unset [name]`.
EOF
        return
    fi

    req_argc 2 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" key="$2"
    unset "${arrayname}[${(q)key}]"
}
alias aa_del=aa_unset



###############################################################################
# Extractors: keys, values, export
#
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

    req_argc 1 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" target_array="$2"

    # Use (k) flag to get keys -- TODO ???
    local -a keys
    keys=(${(k)${(P)arrayname}})

    #echo "keys:  $keys[@]"
    if [[ -n "$target_array" ]]; then
        #tMsg 0 "Evaluating 2: typeset -ga $target_array=($keys[@])"
        eval "typeset -ga $target_array=($keys[@])"
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

    req_argc 1 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    local arrayname="$1" target_array="$2"

    local -a values
    values=(${(v)${(P)arrayname}})

    if [[ -n "$target_array" ]]; then
        #tMsg 0 "Evaluating 3: ${target_array}=(\${values[@]})"
        eval "${target_array}=(\${values[@]})"
    else
        printf '%q ' "${values[@]}"
    fi
}

aa_export() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_export [options] arrayname
Export associative array to various formats.
Options:
    -q | --quiet: Suppress error messages
    -f | --format: What form to export to. Default: python.
Formats:
  python     - Python dict syntax: {"key": "value", ...}
  json       - JSON object syntax: {"key": "value", ...}
  htmltable  - HTML table with key/value columns
  htmldl     - HTML definition list
  zsh        - zsh (qq)) format: ( [key]=value [key2]=value2 )
  view       - pretty-printed
EOF
        return
    fi

    local format="python" quiet=""
    while [[ "$1" == -* ]]; do
        case "$1" in
            -q|--quiet) quiet=1 ;;
            -f|--format) format="$2"; shift 2 ;;
            *) tMsg 0 "aa_export: Unknown option $1"; return 99 ;;
        esac
    done

    req_argc 1 1 $# || return 98
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
                local escvalue=$(str_escape -f html "$value")
                echo "<tr><td>$ekey</td><td>$escvalue</td></tr>"
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
                local quoted_key=$(str_escape -f zsh "$key")
                local quoted_value=$(str_escape -f zsh "$value")
                echo -n "[${quoted_key}]=${quoted_value} "
            done
            echo ")" ;;
        view)
            echo "assoc '$1':"
            local varname=$1
            for key in "${keys[@]}"; do
                printf "  %-16s  %s\n" $key ${${(P)1}[$key]}
            done;;
        *)
            tMsg 0 "aa_export: Unknown format '$format'"
            return 93 ;;
    esac
}


###############################################################################
# Additions for easier modifying of values in place
#
aa_append_value() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_append_value arrayname key value
Concatenate the given value (as a string) to the value of the
entry with the given key, in the named associative array.
If no such entry exists, create it and set it to the value.
EOF
        return
    fi
    aa_insert_value "$1" "$2" ${#${(P)1}[$2]} "$3"
}

aa_insert_value() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: aa_insert_value arrayname key offset value
Insert the given value (as a string) at the given character offset,
in the value of the entry with the given key, in the named associative array.
If no such entry exists, create it and set it to the value.
If the (signed) offset is out of range, show a message and fail.
EOF
        return
    fi
    req_argc 4 4 $# || return 98
    req_sv_type assoc "$1" || return 97
    if ! aa_has $1 $2; then
        tMsg 0 "Associative array $1 has no item '$2'."
        return 95
    fi
    local orig=${${(P)1}[$2]}
    if [[ $3 -ge 0 ]]; then
        local offset=$3
    else
        local offset=$(( ${#orig} + $3 + 1 ))
    fi
    if [[ $offset -gt $#orig ]]; then
        tMsg 0 "Offset $3 is out of range for item $2 of $1."
        return 94
    fi
    local changed=$orig[1,$offset]$4$orig[$offset+1,-1]
    aa_set $1 $2 "$changed"
}


###############################################################################
# Additions to supported abbreviated keys
#
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
See also: aa_get_abbrev.
EOF
        return
    fi

    local case_insensitive=""
    if [[ $1 == "-i" ]]; then
        case_insensitive=1; shift
    fi
    req_argc 2 2 $# || return 98
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
See also: aa_find_key.
EOF
        return
    fi

    local case_insensitive=""
    if [[ $1 == "-i" ]]; then
        case_insensitive=1; shift
    fi
    req_argc 2 2 $# || return 98
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

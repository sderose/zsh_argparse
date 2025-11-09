#!/bin/zsh
# Simplified, Python-like interface for zsh associative arrays.
#
# Copyright 2025, Steven J. DeRose.
# May be used under the terms of the Creative Commons Attribution-Sharealike
# license (for which see https://creativecommons.org/licenses/by-sa/3.0).

[ $ZERG_SETUP ] || source zerg_setup.sh


###############################################################################
# Functions to ease management of shell associative arrays by name.
# Most of the things can be done by variations on ${(P)...)name}, but
# the syntax can get subtle.
#
# Overview:
# The functions are pretty close to those of Python `dict`.
# However, this package also supports item lookups by abbreviations of keys
# (as desired for option-name matching for commands).
#
#     Basics: init, clear, copy, update, set_default
#     Predicates: len, eq, has (=contains)
#     Item access: set, get, unset (=del)
#     Extractors: keys, values, export
#     Additional: append_value, insert_value, find_key, get_abbrev
# This is heavily used by my `zerg` argument parser, but does not use it,
# in order to stay independent.


###############################################################################
# Basics: init, clear, copy, update, set_default
#
aa_init() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_init assocname
    Initialize a new associative array (if it does not exist)
    with the given name.
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return ZERR_ARGC

    # Only initialize if it does not exist  # TODO or not assoc?
    if ! typeset -p "$1" &>/dev/null; then
        typeset -gA "$1"
    fi
}

aa_clear() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_clear assocname
    Clear all entries from the named associative array.
    The array itself remains defined but becomes empty.
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 1 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local assocname="$1"

    # Get all keys and unset them
    local -a keys
    keys=(${(k)${(P)assocname}})
    for key in "${keys[@]}"; do
        unset "${assocname}[${(q)key}]"
    done
}

aa_copy() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_copy source_assoc target_assoc
    Create a shallow copy of an associative array.
    Initialize the target assoc if it does not exist already.
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local source_assoc="$1" target_assoc="$2"

    aa_init "$target_assoc"
    aa_clear "$target_assoc"
    local -a keys
    keys=(${(k)${(P)source_assoc}})
    for key in "${keys[@]}"; do
        local value
        value=$(aa_get "$source_assoc" "$key")
        aa_set "$target_assoc" "$key" "$value"
    done
}

aa_update() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_update target_assoc source_assoc
    Update target_assoc with key-value pairs from source_assoc.
    Existing keys in target_assoc will be overwritten.
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local target_assoc="$1" source_assoc="$2"
    local -a keys
    keys=(${(k)${(P)source_assoc}})

    for key in "${keys[@]}"; do
        local value
        value=$(aa_get "$source_assoc" "$key")
        aa_set "$target_assoc" "$key" "$value"
    done
}

aa_set_default() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_setdefault assocname key default_value
    Set key to default_value if key does not already exist in the assoc.
Returns: the existing value or the default value that was set
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 3 3 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
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
aa_len() {  # TODO rename sv?
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_len varname
    Return the number of items in the variable
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
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    echo "${(P)#1}"
}

aa_eq() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_eq assoc1 assoc2
    Compare two associative arrays for equality.
Returns: 0 if equal, 1 if different
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local assoc1="$1" assoc2="$2"

    local -a keys1 keys2
    aa_keys "$assoc1" keys1
    aa_keys "$assoc2" keys2

    #typeset -p keys1
    #typeset -p keys2

    [[ ${#keys1[@]} -eq ${#keys2[@]} ]] || return 3

    for key in "${keys1[@]}"; do
        #echo "aa_eq $1 vs $2: key '$key'."
        aa_has "$assoc2" "$key" || return 2
        local val1=$(aa_get "$assoc1" "$key")
        local val2=$(aa_get "$assoc2" "$key")
        [[ "$val1" == "$val2" ]] || return 1
    done
    return 0
}

aa_has() {
    local quiet=""
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_has assocname key
    Check if a key exists in a named associative array.
Returns: 0 if key exists, 1 if not
Cf:  (( $x[(Ik)key] ))
EOF
            return ;;
        -q|--quiet) quiet='-q' ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local assocname="$1" key="$2"

    local -a keys=("${(@Pk)assocname}")
    [[ ${keys[(ie)$key]} -le ${#keys} ]] && return 0
    return 1
}


###############################################################################
# Item access: set, get, unset (=del)
#
aa_set() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_set assocname key value
    Set a key-value pair in a named associative array.
    This is equivalent to: assocname[key]=value
EOF
            return ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done


    req_argc 3 3 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local assocname="$1" key="$2" value="$3"

    # Use parameter expansion to set the value indirectly
    # (q) the key, b/c (qq) would store the quotes.
    # But (qq) the value so we don't store backslashes.
    #tMsg 0 "Evaluating 1: ${assocname}[${(q)key}]='${(qq)value}'"
    local evalString="${assocname}[${(q)key}]=${(qq)value}"
    eval $evalString
    local rc=$?
    if [ $? != 0 ]; then
        tMsg 0 "aa_set $1 $2 $3 failed (rc $rc) on eval of $evalString"
        return 50
    fi
}

aa_get() {
    local default="" use_default="" quiet=""
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_get [-d default_value] assocname key
    Get a value from a named associative array.
    If it is not present, issue a warning (unless -q) and return code 1.
    This is equivalent to: echo ${assocname[key]}
Options:
    -d|--default default_value: Return this value if key does not exist
    -q|--quiet Suppress messages
See also: aa_find_key, aa_get_abbrev
Returns: value via stdout
EOF
            return ;;
        -q|--quiet) quiet='-q' ;;
        -d|--default) shift; default="$1"; use_default=1 ;;
            *) tMsg 0 "Unknown option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local assocname="$1" key="$2"

    if aa_has $quiet "$assocname" "$key"; then
        echo "${${(P)assocname}[$key]}"
    elif [[ -n "$use_default" ]]; then
        echo "$default"
    else
        [ "$quiet" ] || tMsg 0 "Key '$key' not found in $assocname."
        return ZERR_NO_KEY
    fi
    #unsetopt xtrace
}

aa_unset() {
    local quiet=""
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_unset assocname key
    Delete the item with the given key from a named associative array.
Note: To unset an entire associative array, just use `unset [name]`.
EOF
                return ;;
            -q|--quiet) quiet='-q' ;;
            *) tMsg 0 "Unknown option '$1'."; return ZERR_BAD_OPTION ;;
        esac
        shift
    done

    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local assocname="$1" key="$2"
    unset "${assocname}[${(q)key}]"
}
alias aa_del=aa_unset



###############################################################################
# Extractors: keys, values, export
#
aa_keys() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_keys assocname [target_assoc]
    Get all keys from a named associative assoc.
    If target_assoc is provided, store keys in that assoc.
    Otherwise, print a space-separated list of keys.
Note: Keys containing spaces will be properly quoted.
TODO: Add sort option(s)?
EOF
                return ;;
            *) tMsg 0 "Unknown option '$1'."; return ZERR_BAD_OPTION ;;
        esac
        shift
    done

    req_argc 1 2 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local assocname="$1" target_assoc="$2"

    local -a keys=(${(k)${(P)assocname}})

    #echo "keys:  $keys[@]"
    if [[ -n "$target_assoc" ]]; then
        #tMsg 0 "Evaluating 2: typeset -ga $target_assoc=($keys[@])"
        eval "typeset -ga $target_assoc=($keys[@])"
    else
        printf '%q ' "${keys[@]}"
    fi
}

aa_values() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_values assocname [target_assoc]
    Get all values from a named associative array.
    If target_assoc is provided, store values in that assoc.
    Otherwise, print a space-separated list of values to stdout.
Note: Values containing spaces will be properly quoted.
EOF
                return ;;
            *) tMsg 0 "Unknown option '$1'."; return ZERR_BAD_OPTION ;;
        esac
        shift
    done

    req_argc 1 2 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local assocname="$1" target_assoc="$2"

    local -a values
    values=(${(v)${(P)assocname}})

    if [[ -n "$target_assoc" ]]; then
        #tMsg 0 "Evaluating 3: ${target_assoc}=(\${values[@]})"
        eval "${target_assoc}=(\${values[@]})"
    else
        printf '%q ' "${values[@]}"
    fi
}

aa_export() {
    local format="python" lines="" no_nil="" quiet="" sort=""
    local -i width=20
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_export [options] assocname
Export an associative array to various formats.
Options:
    -f|--format: What form to export to. Default: python
    --lines: Pretty-print with newlines
    --no-nil: Do not include items with value ''
    -q|--quiet: Suppress messages
    --sort: Alphabetize items
    --width N: Allow this many columns for keys
Formats:
  htmltable  - HTML table with key/value columns
  htmldl     - HTML definition list
  python     - Python dict syntax: {"key": "value", ...}
  json       - JSON object syntax: {"key": "value", ...}
  zsh        - zsh (qq)) format: ( [key]=value [key2]=value2 )
  view       - pretty-printed
TODO: Add quoting options.
EOF
                return ;;
            -f|--format) format="$2"; shift ;;
            --lines) lines=1 ;;
            --no-nil) no_nil=1 ;;
            -q|--quiet) quiet='-q' ;;
            --sort) sort=1 ;;
            --width) shift; width=$1 ;;
            *) tMsg 0 "Unknown option '$1'."; return ZERR_BAD_OPTION ;;
        esac
        shift
    done

    req_argc 1 1 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local -a keys=(${(k)${(P)1}})
    local lb="" ind="" sep=""
    if [ $lines ]; then lb="\\n"; ind="    "; fi
    local -a keySeq
    if [[ -n "$sort" ]]; then
        keySeq=("${(@koi)${(P)1}}")
    else
        keySeq=("${(@k)${(P)1}}")
    fi
    local key
    case "$format" in
        htmltable)
            print -n "<table id=\"$1\">$lb"
            print -n "$ind<thead><tr><th>Key</th><th>Value</th></tr></thead>$lb"
            print -n "$ind<tbody>$lb"
            for key in $keySeq; do
                local val=$(aa_get -q "$1" "$key")
                [ -z "$val" ] && [ $no_nil ] && continue
                local ekey=$(str_escape -f html "$key")
                local eval=$(str_escape -f html "$val")
                print -n "$ind<tr><td>$ekey</td><td>$eval</td></tr>$lb"
            done
            print -n "$ind</tbody>$lb</table>$lb" ;;
        htmldl)
            print -n "<dl id=\"$1\">$lb"
            for key in $keySeq; do
                local val=$(aa_get -q "$1" "$key")
                [ -z "$val" ] && [ $no_nil ] && continue
                local ekey=$(str_escape -f html "$key")
                local eval=$(str_escape -f html "$val")
                print -n "$ind<dt>$ekey</dt><dd>$eval</dd>$lb"
            done
            print -n "</dl>$lb" ;;
        python)
            print -n "$1 = {$lb"
            for key in $keySeq; do
                local val=$(aa_get -q "$1" "$key")
                [ -z "$val" ] && [ $no_nil ] && continue
                local ekey=$(str_escape -f python "$key")
                local eval=$(str_escape -f python "$val")
                print -n "$sep$lb$ind\"$ekey\": \"$eval\""
                sep=", "
            done
            print -n "$lb}$lb" ;;
        json)
            print -n "{$lb"
            local first=1
            for key in $keySeq; do
                [[ $first -eq 0 ]] && print -n ", "
                local val=$(aa_get -q "$1" "$key")
                [ -z "$val" ] && [ $no_nil ] && continue
                #setopt xtrace
                local ekey=$(str_escape -f json "$key")
                local eval=$(str_escape -f json "$val")
                print -n "$sep$lb$ind\"$ekey\": \"$eval\""
                #unsetopt xtrace
                sep=", "
            done
            print -n "$lb}$lb" ;;
        zsh)
            print -n "( $lb"
            for key in $keySeq; do
                local val=$(aa_get -q "$1" "$key")
                [ -z "$val" ] && [ $no_nil ] && continue
                is_float -q "$val" || val="\"$val\""
                print -n "$lb$ind""[${(q)key}]=${(q)val} "
            done
            print -n "$lb)$lb" ;;
        view)
            print "assoc '$1':$lb"
            for key in $keySeq; do
                local val=$(aa_get -q "$1" "$key")
                [[ -z "$val" || "$val" == *\ * ]] && val="\"$val\""
                [ -z "$val" ] && [ $no_nil ] && continue
                printf "  %-$width""s  %s\n" ${(q)key} $val
            done;;
        *)
            tMsg 0 "Unknown format '$format'"
            return ZERR_BAD_OPTION ;;
    esac
}


###############################################################################
# Additions for easier modifying of values in place
#
aa_append_value() {
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_append_value assocname key value
    Concatenate the given value (as a string) to the value of the
    entry with the given key, in the named associative array.
    If no such entry exists, create it and set it to the value.
EOF
                return ;;
            *) tMsg 0 "Unknown option '$1'."; return ZERR_BAD_OPTION ;;
        esac
        shift
    done

    aa_insert_value "$1" "$2" ${#${(P)1}[$2]} "$3"
}

aa_insert_value() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_insert_value assocname key offset value
    Insert the given value (as a string) at the given character offset,
    in the value of the entry with the given key, in the named associative array.
    If no such entry exists, create it and set it to the value.
    If the (signed) offset is out of range, show a message and fail.
Options:
    -q|--quiet:  Suppress messages
EOF
                return ;;
            -q|--quiet) quiet='-q' ;;
            *) tMsg 0 "Unknown option '$1'."; return ZERR_BAD_OPTION ;;
        esac
        shift
    done

    req_argc 4 4 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    if ! aa_has $quiet $1 $2; then
        [ $quiet ] || tMsg 0 "Associative array $1 has no item '$2'."
        return ZERR_NO_KEY
    fi
    local orig=${${(P)1}[$2]}
    if [[ $3 -ge 0 ]]; then
        local offset=$3
    else
        local offset=$(( ${#orig} + $3 + 1 ))
    fi
    if [[ $offset -gt $#orig ]]; then
        [ $quiet ] || tMsg 0 "Offset $3 is out of range for item $2 of $1."
        return ZERR_NO_INDEX
    fi
    local changed=$orig[1,$offset]$4$orig[$offset+1,-1]
    aa_set $quiet $1 $2 "$changed"
}


###############################################################################
# Additions to supported abbreviated keys
#
aa_find_key() {
    local quiet ic
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: aa_find_key [options] assocname partial_key
    Find minimum unique key matches in the named associative array.
Arguments:
    assocname         - name of the associative array
    partial_key       - partial key to match against
Options:
    -i|--ignore-case  - case insensitive
    -q|--quiet        - suppress messages
Returns:
    0 = not found
    1 = unique match (sets global _aa_matched_key)
    2 = multiple matches
See also: aa_get_abbrev.
EOF
                return ;;
            -i|--ignore-case) ic=1 ;;
            -q|--quiet) quiet='-q' ;;
            *) tMsg 0 "Unknown option '$1'."; return ZERR_BAD_OPTION ;;
        esac
        shift
    done

    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE

    local assocname="$1" partial_key="$2"
    local -a matches all_keys
    local search_key="$partial_key"

    # Get all keys
    all_keys=(${(k)${(P)assocname}})

    # Convert to lowercase for case-insensitive matching
    if [[ "$ic" == "1" ]]; then
        search_key="${partial_key:l}"
    fi

    # Find matches that start with partial_key
    for key in "${all_keys[@]}"; do
        local compare_key="$key"
        if [[ "$ic" == "1" ]]; then
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
    local default use_default ic quiet
    while [[ "$1" == -* ]]; do
        case "$1" in
            -h|--help)
                cat <<'EOF'
Usage: aa_get_abbrev [options] assocname partial_key
    Get an entry's value from the named associative array, allowing
    abbreviations of keys (so long as they are long enough to be unique).
Arguments:
    assocname        - name of the associative array
    partial_key      - partial key to match against
Option:
    -d|--default d   - if the key is not found, return this value.
        If the key is ambiguous it's still an error; the default is not used.
    -i|--ignore-case - case_insensitive
    -q|--quiet       - Suppress messages
Output: value via stdout if unique match (or a default is applied).
Error message to stderr otherwise.
Return codes: 0=success, 1=not found, 2=not unique.
See also: aa_find_key.
EOF
                return ;;
            -d|--default) shift; default_value="$1"; use_default=1 ;;
            -i|--ignore-case) ic=1 ;;
            -q|--quiet) quiet='-q' ;;
            *) tMsg 0 "Unknown option '$1'."; return ZERR_BAD_OPTION ;
                return ZERR_BAD_OPTION ;;
        esac
        shift
    done

    req_argc 2 2 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE
    local assocname="$1" partial_key="$2"

    aa_find_key $quiet "$assocname" "$partial_key" "$ic"
    local result=$?
    case $result in
        0) [ $use_default ] && echo "$default" && return 0
            [ $quiet ] || tMsg 0 "Key '$partial_key' not found in $assocname";
            return ZERR_NO_KEY ;;
        1) echo `aa_get "$assocname" "$_aa_matched_key"`
            return 0 ;;
        2) [ $quiet ] || tMsg 0 "Key '$partial_key' is ambiguous in $assocname"
            return ZERR_NO_KEY ;;
    esac
}

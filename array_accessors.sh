#!/.bin/zsh
# Associative array support functions
# Copyright 2025, Steven J. DeRose.
# May be used under the terms of the Creative Commons Attribution-Sharealike
# license (for which see https://creativecommons.org/licenses/by-sa/3.0).

# Set a key-value pair in a named associative array
# Usage: arg_set arrayname key value
arg_set() {
    local arrayname="$1" key="$2" value="$3"

    # Use parameter expansion to set the value indirectly
    # This is equivalent to: arrayname[key]=value
    eval "${arrayname}[${(q)key}]=${(q)value}"
}

# Get a value from a named associative array
# Usage: arg_get arrayname key
# Returns: value via stdout
arg_get() {
    local arrayname="$1" key="$2"

    # Use parameter expansion to get the value indirectly
    # This is equivalent to: echo ${arrayname[key]}
    local varref="${arrayname}[${key}]"
    echo "${(P)varref}"
}

# Check if a key exists in a named associative array
# Usage: arg_has arrayname key
# Returns: 0 if key exists, 1 if not
arg_has() {
    local arrayname="$1" key="$2"

    # Check if the key exists using (k) flag
    local varref="${arrayname}"
    [[ -n "${(P)varref[(k)${key}]}" ]]
}

# Get all keys from a named associative array
# Usage: arg_keys arrayname
# Returns: space-separated list of keys via stdout
# TODO Quoting?
arg_keys() {
    local arrayname="$1"

    # Use (k) flag to get keys
    local varref="${arrayname}"
    echo "${(k)${(P)varref}}"
}

# Get all values from a named associative array
# Usage: arg_values arrayname
# Returns: space-separated list of values via stdout
# TODO Quoting?
arg_values() {
    local arrayname="$1"

    # Use (v) flag to get values
    local varref="${arrayname}"
    echo "${(v)${(P)varref}}"
}

# Delete a key from a named associative array
# Usage: arg_unset arrayname key
arg_unset() {
    local arrayname="$1" key="$2"

    # Use unset with indirect reference
    unset "${arrayname}[${(q)key}]"
}

# Initialize a new associative array (if it doesn't exist)
# Usage: arg_init arrayname
arg_init() {
    local arrayname="$1"

    # Only initialize if it doesn't exist
    if ! typeset -p "$arrayname" &>/dev/null; then
        typeset -gA "$arrayname"
    fi
}

arg_clear() {
    local arrayname="$1"  # TODO finish
}

# Find minimum unique key matches in a named associative array
# Usage: arg_find_key arrayname partial_key [case_insensitive]
# Returns: 0=not found, 1=unique match, 2=multiple matches
# Sets global _argparse_matched_key with the unique match (if any)  TODO?
arg_find_key() {
    local arrayname="$1" partial_key="$2" case_insensitive="${3:-0}"
    local -a matches
    local varref="$arrayname"
    local -a all_keys
    local search_key="$partial_key"

    # Get all keys
    all_keys=(${(k)${(P)varref}})

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
        0)
            unset _argparse_matched_key
            return 0  # NOTFOUND
            ;;
        1)
            _argparse_matched_key="${matches[1]}"
            return 1  # UNIQUE
            ;;
        *)
            unset _argparse_matched_key
            return 2  # NOTUNIQUE
            ;;
    esac
}

# Get value using minimum unique key matching
# Usage: arg_get_abbrev arrayname partial_key [case_insensitive]
# Returns: value via stdout if unique match, error message to stderr otherwise
# Exit codes: 0=success, 1=not found, 2=not unique
arg_get_abbrev() {
    local arrayname="$1" partial_key="$2" case_insensitive="${3:-0}"

    arg_find_key "$arrayname" "$partial_key" "$case_insensitive"
    local result=$?

    case $result in
        0)
            echo "Error: Key '$partial_key' not found in $arrayname" >&2
            return 1
            ;;
        1)
            arg_get "$arrayname" "$_argparse_matched_key"
            return 0
            ;;
        2)
            echo "Error: Key '$partial_key' is ambiguous in $arrayname" >&2
            return 2
            ;;
    esac
}

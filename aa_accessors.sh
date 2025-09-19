#!/bin/zsh
# Associative array support functions
# Copyright 2025, Steven J. DeRose.
# May be used under the terms of the Creative Commons Attribution-Sharealike
# license (for which see https://creativecommons.org/licenses/by-sa/3.0).

# Set a key-value pair in a named associative array
aa_set() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_set arrayname key value
Set a key-value pair in a named associative array.
This is equivalent to: arrayname[key]=value
EOF
        return
    fi

    local arrayname="$1" key="$2" value="$3"

    if [[ $# -ne 3 ]]; then
        tMsg error "aa_set: Expected 3 arguments, got $#"
        return 99
    fi

    # Use parameter expansion to set the value indirectly
    eval "${arrayname}[${(q)key}]=${(q)value}"
}

# Get a value from a named associative array
aa_get() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_get [-d default_value] arrayname key
Get a value from a named associative array.
Options:
  -d default_value  Return this value if key doesn't exist
Returns: value via stdout
This is equivalent to: echo \${arrayname[key]}
EOF
        return
    fi

    local default_value="" arrayname key use_default=0

    # Parse options
    while [[ "$1" == -* ]]; do
        case "$1" in
            -d)
                default_value="$2"
                use_default=1
                shift 2 ;;
            *)
                tMsg error "aa_get: Unknown option $1"
                return 98 ;;
        esac
    done

    arrayname="$1"
    key="$2"

    if [[ $# -ne 2 ]]; then
        tMsg error "aa_get: Expected 2 arguments after options, got $#"
        return 98
    fi

    # Use parameter expansion to get the value indirectly
    local varref="${arrayname}[${key}]"
    local value="${(P)varref}"

    if [[ -z "$value" ]] && ! aa_has "$arrayname" "$key"; then
        if [[ "$use_default" == "1" ]]; then
            echo "$default_value"
        else
            return 1
        fi
    else
        echo "$value"
    fi
}

# Check if a key exists in a named associative array
aa_has() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_has arrayname key
Check if a key exists in a named associative array.
Returns: 0 if key exists, 1 if not
EOF
        return
    fi

    local arrayname="$1" key="$2"

    if [[ $# -ne 2 ]]; then
        tMsg error "aa_has: Expected 2 arguments, got $#"
        return 97
    fi

    # Check if the key exists using (k) flag
    local varref="${arrayname}"
    [[ -n "${(P)varref[(k)${key}]}" ]]
}

# Get all keys from a named associative array
aa_keys() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_keys arrayname [target_array]
Get all keys from a named associative array.
If target_array is provided, stores keys in that array.
Otherwise, prints space-separated list of keys to stdout.
Note: Keys containing spaces will be properly quoted when printed.
EOF
        return
    fi

    local arrayname="$1" target_array="$2"

    if [[ $# -lt 1 || $# -gt 2 ]]; then
        tMsg error "aa_keys: Expected 1-2 arguments, got $#"
        return 96
    fi

    # Use (k) flag to get keys
    local varref="${arrayname}"
    local -a keys
    keys=(${(k)${(P)varref}})

    if [[ -n "$target_array" ]]; then
        # Store keys in the target array
        eval "${target_array}=(\${keys[@]})"
    else
        # Print quoted keys
        printf '%q\n' "${keys[@]}"
    fi
}

# Get all values from a named associative array
aa_values() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_values arrayname [target_array]
Get all values from a named associative array.
If target_array is provided, stores values in that array.
Otherwise, prints space-separated list of values to stdout.
Note: Values containing spaces will be properly quoted when printed.
EOF
        return
    fi

    local arrayname="$1" target_array="$2"

    if [[ $# -lt 1 || $# -gt 2 ]]; then
        tMsg error "aa_values: Expected 1-2 arguments, got $#"
        return 95
    fi

    # Use (v) flag to get values
    local varref="${arrayname}"
    local -a values
    values=(${(v)${(P)varref}})

    if [[ -n "$target_array" ]]; then
        # Store values in the target array
        eval "${target_array}=(\${values[@]})"
    else
        # Print quoted values
        printf '%q\n' "${values[@]}"
    fi
}

# Delete a key from a named associative array
aa_unset() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_unset arrayname key
Delete a key from a named associative array.
EOF
        return
    fi

    local arrayname="$1" key="$2"

    if [[ $# -ne 2 ]]; then
        tMsg error "aa_unset: Expected 2 arguments, got $#"
        return 94
    fi

    # Use unset with indirect reference
    unset "${arrayname}[${(q)key}]"
}

# Initialize a new associative array (if it doesn't exist)
aa_init() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_init arrayname
Initialize a new associative array (if it doesn't exist).
Creates a global associative array with the given name.
EOF
        return
    fi

    local arrayname="$1"

    if [[ $# -ne 1 ]]; then
        tMsg error "aa_init: Expected 1 argument, got $#"
        return 93
    fi

    # Only initialize if it doesn't exist
    if ! typeset -p "$arrayname" &>/dev/null; then
        typeset -gA "$arrayname"
    fi
}

# Clear all entries from a named associative array
aa_clear() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_clear arrayname
Clear all entries from a named associative array.
The array itself remains defined but becomes empty.
EOF
        return
    fi

    local arrayname="$1"

    if [[ $# -ne 1 ]]; then
        tMsg error "aa_clear: Expected 1 argument, got $#"
        return 92
    fi

    # Get all keys and unset them
    local varref="${arrayname}"
    local -a keys
    keys=(${(k)${(P)varref}})

    for key in "${keys[@]}"; do
        unset "${arrayname}[${(q)key}]"
    done
}

# Find minimum unique key matches in a named associative array
aa_find_key() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_find_key arrayname partial_key [case_insensitive]
Find minimum unique key matches in a named associative array.
Arguments:
  arrayname        - name of the associative array
  partial_key      - partial key to match against
  case_insensitive - 1 for case-insensitive matching, 0 for case-sensitive (default)
Returns:
  0 = not found
  1 = unique match (sets global _aa_matched_key)
  2 = multiple matches
Case-insensitive matching converts both the partial key and all array keys
to lowercase before comparison.
EOF
        return
    fi

    local arrayname="$1" partial_key="$2" case_insensitive="${3:-0}"
    local -a matches
    local varref="$arrayname"
    local -a all_keys
    local search_key="$partial_key"

    if [[ $# -lt 2 || $# -gt 3 ]]; then
        tMsg error "aa_find_key: Expected 2-3 arguments, got $#"
        return 91
    fi

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
            unset _aa_matched_key
            return 0  # NOTFOUND ;;
        1)
            _aa_matched_key="${matches[1]}"
            return 1  # UNIQUE ;;
        *)
            unset _aa_matched_key
            return 2  # NOTUNIQUE ;;
    esac
}

# Get value using minimum unique key matching
aa_get_abbrev() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_get_abbrev arrayname partial_key [case_insensitive]
Get value using minimum unique key matching.
Arguments:
  arrayname        - name of the associative array
  partial_key      - partial key to match against
  case_insensitive - 1 for case-insensitive matching, 0 for case-sensitive (default)
Returns: value via stdout if unique match, error message to stderr otherwise
Exit codes: 0=success, 1=not found, 2=not unique
EOF
        return
    fi

    local arrayname="$1" partial_key="$2" case_insensitive="${3:-0}"

    if [[ $# -lt 2 || $# -gt 3 ]]; then
        tMsg error "aa_get_abbrev: Expected 2-3 arguments, got $#"
        return 90
    fi

    aa_find_key "$arrayname" "$partial_key" "$case_insensitive"
    local result=$?

    case $result in
        0)
            tMsg error "Key '$partial_key' not found in $arrayname"
            return 1 ;;
        1)
            aa_get "$arrayname" "$_aa_matched_key"
            return 0 ;;
        2)
            tMsg error "Key '$partial_key' is ambiguous in $arrayname"
            return 2 ;;
    esac
}

aa_copy() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_copy source_array target_array
Create a shallow copy of an associative array.
The target array will be initialized if it doesn't exist.
EOF
        return
    fi

    local source_array="$1" target_array="$2"

    if [[ $# -ne 2 ]]; then
        tMsg error "aa_copy: Expected 2 arguments, got $#"
        return 89
    fi

    # Initialize target array
    aa_init "$target_array"

    # Clear target array first
    aa_clear "$target_array"

    # Copy all key-value pairs
    local varref="$source_array"
    local -a keys
    keys=(${(k)${(P)varref}})

    for key in "${keys[@]}"; do
        local value
        value=$(aa_get "$source_array" "$key")
        aa_set "$target_array" "$key" "$value"
    done
}

aa_update() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_update target_array source_array
Update target_array with key-value pairs from source_array.
Existing keys in target_array will be overwritten.
EOF
        return
    fi

    local target_array="$1" source_array="$2"

    if [[ $# -ne 2 ]]; then
        tMsg error "aa_update: Expected 2 arguments, got $#"
        return 88
    fi

    # Copy all key-value pairs from source to target
    local varref="$source_array"
    local -a keys
    keys=(${(k)${(P)varref}})

    for key in "${keys[@]}"; do
        local value
        value=$(aa_get "$source_array" "$key")
        aa_set "$target_array" "$key" "$value"
    done
}

aa_setdefault() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_setdefault arrayname key default_value
Set key to default_value if key doesn't exist in the array.
Returns: the existing value or the default value that was set
EOF
        return
    fi

    local arrayname="$1" key="$2" default_value="$3"

    if [[ $# -ne 3 ]]; then
        tMsg error "aa_setdefault: Expected 3 arguments, got $#"
        return 87
    fi

    if aa_has "$arrayname" "$key"; then
        aa_get "$arrayname" "$key"
    else
        aa_set "$arrayname" "$key" "$default_value"
        echo "$default_value"
    fi
}

aa_equals() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_equals array1 array2
Compare two associative arrays for equality.
Returns: 0 if equal, 1 if different
EOF
        return
    fi

    local array1="$1" array2="$2"

    if [[ $# -ne 2 ]]; then
        tMsg error "aa_equals: Expected 2 arguments, got $#"
        return 86
    fi

    # Get keys from both arrays
    local -a keys1 keys2
    aa_keys "$array1" keys1
    aa_keys "$array2" keys2

    # Check if same number of keys
    if [[ ${#keys1[@]} -ne ${#keys2[@]} ]]; then
        return 1
    fi

    # Check if all keys and values match
    for key in "${keys1[@]}"; do
        if ! aa_has "$array2" "$key"; then
            return 1
        fi
        local val1 val2
        val1=$(aa_get "$array1" "$key")
        val2=$(aa_get "$array2" "$key")
        if [[ "$val1" != "$val2" ]]; then
            return 1
        fi
    done

    return 0
}

aa_export() {
    if [[ "$1" == "-h" ]]; then
        echo <<EOF
Usage: aa_export [-f format] arrayname
Export associative array to various formats.
Formats:
  python     - Python dict syntax: {'key': 'value', ...}
  json       - JSON object syntax: {"key": "value", ...}
  html-table - HTML table with key/value columns
  html-dl    - HTML definition list
  typeset    - zsh typeset format: ( [key]=value [key2]=value2 )
Default format is python.
EOF
        return
    fi

    local format="python" arrayname

    # Parse options
    while [[ "$1" == -* ]]; do
        case "$1" in
            -f)
                format="$2"
                shift 2 ;;
            *)
                tMsg error "aa_export: Unknown option $1"
                return 85 ;;
        esac
    done

    arrayname="$1"

    if [[ $# -ne 1 ]]; then
        tMsg error "aa_export: Expected 1 argument after options, got $#"
        return 85
    fi

    local varref="$arrayname"
    local -a keys
    keys=(${(k)${(P)varref}})

    case "$format" in
        python)
            echo -n "{"
            local first=1
            for key in "${keys[@]}"; do
                [[ $first -eq 0 ]] && echo -n ", "
                first=0
                local value
                value=$(aa_get "$arrayname" "$key")
                # Basic Python string escaping
                local escaped_key="${key//\'/\\\'}"
                local escaped_value="${value//\'/\\\'}"
                echo -n "'$escaped_key': '$escaped_value'"
            done
            echo "}" ;;
        json)
            echo -n "{"
            local first=1
            for key in "${keys[@]}"; do
                [[ $first -eq 0 ]] && echo -n ", "
                first=0
                local value
                value=$(aa_get "$arrayname" "$key")
                # Basic JSON string escaping
                local escaped_key="${key//\"/\\\"}"
                escaped_key="${escaped_key//\\/\\\\}"
                local escaped_value="${value//\"/\\\"}"
                escaped_value="${escaped_value//\\/\\\\}"
                echo -n "\"$escaped_key\": \"$escaped_value\""
            done
            echo "}" ;;
        html-table)
            echo "<table>"
            echo "<thead><tr><th>Key</th><th>Value</th></tr></thead>"
            echo "<tbody>"
            for key in "${keys[@]}"; do
                local value
                value=$(aa_get "$arrayname" "$key")
                # Basic HTML escaping
                local escaped_key="${key//&/&amp;}"
                escaped_key="${escaped_key//</&lt;}"
                escaped_key="${escaped_key//>/&gt;}"
                local escaped_value="${value//&/&amp;}"
                escaped_value="${escaped_value//</&lt;}"
                escaped_value="${escaped_value//>/&gt;}"
                echo "<tr><td>$escaped_key</td><td>$escaped_value</td></tr>"
            done
            echo "</tbody>"
            echo "</table>" ;;
        html-dl)
            echo "<dl>"
            for key in "${keys[@]}"; do
                local value
                value=$(aa_get "$arrayname" "$key")
                # Basic HTML escaping
                local escaped_key="${key//&/&amp;}"
                escaped_key="${escaped_key//</&lt;}"
                escaped_key="${escaped_key//>/&gt;}"
                local escaped_value="${value//&/&amp;}"
                escaped_value="${escaped_value//</&lt;}"
                escaped_value="${escaped_value//>/&gt;}"
                echo "<dt>$escaped_key</dt>"
                echo "<dd>$escaped_value</dd>"
            done
            echo "</dl>" ;;
        typeset)
            echo -n "( "
            for key in "${keys[@]}"; do
                local value
                value=$(aa_get "$arrayname" "$key")
                local quoted_key quoted_value
                quoted_key=$(aa_quote "$key")
                quoted_value=$(aa_quote "$value")
                echo -n "[${quoted_key}]=${quoted_value} "
            done
            echo ")" ;;
        *)
            tMsg error "aa_export: Unknown format '$format'"
            return 84 ;;
    esac
}

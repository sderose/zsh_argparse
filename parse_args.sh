#!/bin/bash

# parse_args function - processes command line arguments using argument defs

is_type() {
    if [[ "$1" == "-h" ]]; then
        cat <<EOF
is_type [name]: test if this is a known zsh_argparse type name.
EOF
        return
    fi
    local nums="INT|HEXINT|OCTINT|ANYINT|FLOAT|BOOL|PROB|LOGPROB"
    local strs="STR|IDENT|UIDENT|CHAR|REGEX|PATH|URL"
    lical tims="TIME|DATE|DATETIME|DURATION|EPOCH"
    # TODO: TENSOR LANG COMPLEX ENUM
    [[ "${parsed_args[type]}" =~ ($nums|$strs|$tims) ]] && return 0
    return 99
}

check_re() {
    # Test if the arg is a legit regex.
    # If grep supports -P, use that for PCRE.
    local regex="$1"
    echo "" | grep -E "$regex" 2>/dev/null;
    [[ $? == 0 ]] || [[ $? == 1 ]] || return 99
    return 0
}

# Type validation functions
is_str() {
    # String: accepts any value
    return 0
}

is_ident() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    # Identifier: non-empty, alphanumeric and underscore only
    if [[ -z "$value" || ! "$value" =~ ^[a-zA-Z0-9_]+$ ]]; then
        $quiet || echo "Error: '$value' is not a valid identifier (must be non-empty [a-zA-Z0-9_] only)" >&2
        return 1
    fi
}

is_char() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    if [[ ${#value} -ne 1 ]]; then
        $quiet || echo "Error: '$value' is not a single character" >&2
        return 1
    fi
}

is_int() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
        $quiet || echo "Error: '$value' is not a valid integer" >&2
        return 1
    fi
}

is_octint() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    if [[ ! "$value" =~ ^(0)?[0-7]+$ ]]; then
        $quiet || echo "Error: '$value' is not a valid octal integer" >&2
        return 1
    fi
}

is_hexint() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    if [[ ! "$value" =~ ^(0x)?[0-9a-fA-F]+$ ]]; then
        $quiet || echo "Error: '$value' is not a valid hexadecimal integer" >&2
        return 1
    fi
}

is_binint() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    if [[ ! "$value" =~ ^(0b)?[01]+$ ]]; then
        $quiet || echo "Error: '$value' is not a valid hexadecimal integer" >&2
        return 1
    fi
}

is_anyint() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    # Try octal first (corrected order), then decimal, hex, binary
    if is_octint -q "$value" || is_int -q "$value" ||
       [[ "$value" =~ ^0x[0-9a-fA-F]+$ ]] || [[ "$value" =~ ^0b[01]+$ ]]; then
        return 0
    else
        $quiet || echo "Error: '$value' is not a valid integer (decimal/hex/octal/binary)" >&2
        return 1
    fi
}

is_float() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    if [[ ! "$value" =~ ^-?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$ ]]; then
        $quiet || echo "Error: '$value' is not a valid float" >&2
        return 1
    fi
}

is_prob() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    if [[ ! "$value" =~ ^[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$ ]]; then
        $quiet || echo "Error: '$value' is not a valid probability" >&2
        return 1
    elif ! (( $(echo "$value >= 0.0 && $value <= 1.0" | bc -l) )); then
        $quiet || echo "Error: '$value' is not a valid probability (must be between 0.0 and 1.0)" >&2
        return 1
    fi
}

is_bool() {
    local quiet value abbrev_ok
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"; abbrev_ok="$3"
    else quiet=""; value="$1"; abbrev_ok="$2"; fi

    if [[ "$1" == "" ]] || "$1" == "1" ]]; return 0

    # Convert various boolean representations
    local lower_value="${value:l}"
    case "$lower_value" in
        1|true|yes|on|y) return 0 ;;
        0|false|no|off|n) return 0 ;;
        *)
            if [[ "$abbrev_ok" == "1" ]]; then
                # Try abbreviation matching
                local -A bool_choices=(
                    true "1" yes "1" on "1"
                    false "" no "" off ""
                )
                aa_find_key bool_choices "$lower_value" 1
                case $? in
                    1) return 0 ;;
                esac
            fi
            $quiet || echo "Error: '$value' is not a valid boolean (1/0, true/false, yes/no, on/off)" >&2
            return 1 ;;
    esac
}

is_regex() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    # Test for a valid regex pattern (TODO: PCRE vs. grep vs. -E vs zsh)
    if ! check_re "$value"; then
        $quiet || echo "Error: '$value' is not a valid regular expression" >&2
        return 1
    fi
}

is_path() {
    # TODO Something to say if exists, writable, exists but for last step, ...
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    # Basic path validation - no null bytes, reasonable length
    local pathExpr='/?[._-$~#a-zA-Z0-9]*(/[._-$~#a-zA-Z0-9]*)*'
    if [[ ! "$value" =~ "$pathExpr" ]]; then
        $quiet || echo "Error: '$value' seems not to be a valid path" >&2
        return 1
    fi
}

is_url() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    # Basic URL validation (TODO buff)
    if [[ ! "$value" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:.* ]]; then
        $quiet || echo "Error: '$value' is not a valid URL" >&2
        return 1
    fi
}

is_time_date() {
    local quiet value
    if [[ "$1" == "-q" ]]; then quiet=1; value="$2"
    else quiet=""; value="$1"; fi

    # Validate ISO8601 format using date command
    # Try both GNU date (Linux) and BSD date (macOS) approaches
    if ! date -d "$value" "+%s" &>/dev/null 2>&1 &&
       ! date -j -f "%Y-%m-%dT%H:%M:%S" "$value" "+%s" &>/dev/null 2>&1 &&
       ! date -j -f "%Y-%m-%d" "$value" "+%s" &>/dev/null 2>&1; then
        $quiet || echo "Error: '$value' is not a valid ISO8601 date/time format" >&2
        return 1
    fi
}

# Helper function to process an option that takes a value
_argparse_process_option() {
    local refname="$1" option_name="$2"
    local -n cmdline_ref="$3"  # Array reference
    local -n index_ref="$4"    # Index reference
    local enum_case_ignore="$5" enum_abbrevs="$6"

    local action type nargs choices pattern dest
    action=$(aa_get "$refname" "action" 2>/dev/null || echo "STORE")
    type=$(aa_get "$refname" "type" 2>/dev/null || echo "STR")
    nargs=$(aa_get "$refname" "nargs" 2>/dev/null)
    choices=$(aa_get "$refname" "choices" 2>/dev/null)
    pattern=$(aa_get "$refname" "pattern" 2>/dev/null)
    dest=$(aa_get "$refname" "dest" 2>/dev/null)

    if [[ -z "$dest" ]]; then
        local names
        names=$(aa_get "$refname" "names")
        local -a name_list
        name_list=(${=names})
        dest="${name_list[1]#-#-}"
    fi

    local result_array="${refname}_results"

    case "$action" in
        STORE_TRUE)
            aa_set "$result_array" "$dest" "1"
            return 0 ;;
        STORE_FALSE)
            aa_set "$result_array" "$dest" ""
            return 0 ;;
        STORE_CONST)
            local const_val
            const_val=$(aa_get "$refname" "const" 2>/dev/null)
            aa_set "$result_array" "$dest" "$const_val"
            return 0 ;;
        COUNT)
            local current
            current=$(aa_get "$result_array" "$dest" 2>/dev/null || echo "0")
            aa_set "$result_array" "$dest" "$((current + 1))"
            return 0 ;;
        TOGGLE)
            local current
            current=$(aa_get "$result_array" "$dest" 2>/dev/null)
            if [[ -n "$current" ]]; then
                aa_set "$result_array" "$dest" ""
            else
                aa_set "$result_array" "$dest" "1"
            fi
            return 0 ;;
        STORE|APPEND|EXTEND)
            # These actions need argument values
            local -a values
            local num_args=1

            case "$nargs" in
                ""|1) num_args=1 ;;
                "?") num_args=0 ;;  # Optional argument
                "*") num_args=-1 ;; # Zero or more
                "+") num_args=-2 ;; # One or more
                [0-9]*) num_args="$nargs" ;;
                *) echo "Error: Invalid nargs value: $nargs" >&2; return 1 ;;
            esac

            # Collect argument values
            if [[ $num_args -eq 0 ]]; then
                # Optional argument - check if next arg looks like a value
                if [[ $((index_ref + 1)) -le ${#cmdline_ref} && "${cmdline_ref[$((index_ref + 1))]}" != -* ]]; then
                    (( index_ref++ ))
                    values+=("${cmdline_ref[$index_ref]}")
                fi
            elif [[ $num_args -gt 0 ]]; then
                # Fixed number of arguments
                local j
                for (( j=1; j<=num_args; j++ )); do
                    if [[ $((index_ref + j)) -le ${#cmdline_ref} ]]; then
                        values+=("${cmdline_ref[$((index_ref + j))]}")
                    else
                        echo "Error: Option $option_name requires $num_args arguments" >&2
                        return 1
                    fi
                done
                index_ref=$((index_ref + num_args))
            else
                # Variable number of arguments
                local j=$((index_ref + 1))
                while [[ $j -le ${#cmdline_ref} && "${cmdline_ref[$j]}" != -* ]]; do
                    values+=("${cmdline_ref[$j]}")
                    (( j++ ))
                done
                if [[ $num_args -eq -2 && ${#values} -eq 0 ]]; then
                    echo "Error: Option $option_name requires at least one argument" >&2
                    return 1
                fi
                index_ref=$((j - 1))
            fi

            # Validate and store values
            local -a validated_values
            for value in "${values[@]}"; do
                local validated
                if ! validated=$(_argparse_validate_type "$value" "$type" "$choices" "$pattern" "$enum_case_ignore" "$enum_abbrevs"); then
                    return 1
                fi
                validated_values+=("$validated")
            done

            case "$action" in
                STORE)
                    if [[ ${#validated_values} -eq 1 ]]; then
                        aa_set "$result_array" "$dest" "${validated_values[1]}"
                    else
                        # Multiple values - store as space-separated string
                        aa_set "$result_array" "$dest" "${validated_values[*]}"
                    fi ;;
                APPEND)
                    echo "Warning: APPEND action not yet implemented" >&2
                EXTEND)
                    # TODO: Implement append/extend logic
                    echo "Warning: EXTEND action not yet implemented" >&2
                    aa_set "$result_array" "$dest" "${validated_values[*]}" ;;
            esac ;;
        *)
            echo "Error: Unknown action '$action' for option $option_name." >&2
            return 1 ;;
    esac

    return 0
}

# Helper function to process flag-only options (for bundled short options)
_argparse_process_flag_option() {
    local refname="$1" option_name="$2"

    local action
    action=$(aa_get "$refname" "action" 2>/dev/null || echo "STORE")

    case "$action" in
        STORE_TRUE|STORE_FALSE|STORE_CONST|COUNT|TOGGLE)
            _argparse_process_option "$refname" "$option_name" "" "" 0 0
            return $? ;;
        *)
            echo "Error: Option $option_name in bundle cannot take arguments for action: $action" >&2
            return 1 ;;
    esac
}

parse_args() {
    local -A parse_options
    local -a refnames
    local option_case_ignore=1
    local enum_case_ignore=1
    local enum_abbrevs=1
    local i=1

    # Parse parse_args options first
    while [[ $i -le $# ]]; do
        local arg="${@[i]}"
        case "$arg" in
            --option-case-ignore)
                option_case_ignore=1 ;;
            --no-option-case-ignore)
                option_case_ignore=0 ;;
            --enum-case-ignore)
                enum_case_ignore=1 ;;
            --no-enum-case-ignore)
                enum_case_ignore=0 ;;
            --enum-abbrevs)
                enum_abbrevs=1 ;;
            --no-enum-abbrevs)
                enum_abbrevs=0 ;;
            --)
                # End of parse_args options, rest are refnames
                (( i++ ))
                break ;;
            -*)
                echo "Error: Unknown parse_args option: $arg" >&2
                return 1 ;;
            *)
                # Start of refnames
                break ;;
        esac
        (( i++ ))
    done

    # Collect refnames
    while [[ $i -le $# ]]; do
        refnames+=("${@[i]}")
        (( i++ ))
    done

    # If no refnames specified, use all registered argument definitions
    if [[ ${#refnames} -eq 0 ]]; then
        if ! typeset -p _argparse_registry &>/dev/null; then
            echo "Error: No argument definitions found" >&2
            return 1
        fi
        refnames=(${(v)_argparse_registry})
    fi

    # Build option lookup table from all argument definitions
    local -A option_to_refname option_to_argdef
    for refname in "${refnames[@]}"; do
        if ! typeset -p "$refname" &>/dev/null; then
            echo "Error: Argument definition '$refname' not found" >&2
            return 1
        fi

        # Get the names for this argument
        local names
        names=$(aa_get "$refname" "names")
        if [[ -z "$names" ]]; then
            continue
        fi

        # Register each option name
        local -a name_list
        name_list=(${=names})  # Split on whitespace
        for name in "${name_list[@]}"; do
            if [[ -n "${option_to_refname[$name]}" ]]; then
                echo "Error: Option '$name' defined multiple times" >&2
                return 1
            fi
            option_to_refname["$name"]="$refname"
            option_to_argdef["$name"]="$refname"
        done
    done

    # Initialize result arrays for each refname
    for refname in "${refnames[@]}"; do
        local result_array="${refname}_results"
        aa_init "$result_array"

        # Set defaults
        local default_val
        default_val=$(aa_get "$refname" "default" 2>/dev/null)
        if [[ -n "$default_val" ]]; then
            local dest
            dest=$(aa_get "$refname" "dest" 2>/dev/null)
            if [[ -z "$dest" ]]; then
                # Extract dest from first option name
                local names
                names=$(aa_get "$refname" "names")
                local -a name_list
                name_list=(${=names})
                dest="${name_list[1]#-#-}"  # Strip leading dashes
            fi
            aa_set "$result_array" "$dest" "$default_val"
        fi
    done

    echo "parse_args: Found ${#refnames} argument definitions, ${#option_to_refname} total options"
    echo "Options configured: ${(k)option_to_refname}"

    # Main command-line parsing loop.
    # Parse the actual command line arguments passed to the script.
    # Access the original command line - this is a placeholder.
    # In real usage, this would be called with the command line to parse.
    #
    local -a cmdline_args
    cmdline_args=("$@")  # This is wrong - we need the actual script args, not parse_args args

    # TODO: Fix this - need a way to pass the actual command line to parse
    echo "Warning: parse_args needs to be called with actual command line arguments"
    return 0
}

# Main command-line argument parsing function
# Usage: parse_command_line [parse_options] -- [command_line_args...]
#
parse_command_line() {
    local -A parse_options
    local option_case_ignore=1
    local enum_case_ignore=1
    local enum_abbrevs=1
    local -a refnames
    local -a cmdline_args
    local i=1

    # Parse parse_args options first
    while [[ $i -le $# ]]; do
        local arg="${@[i]}"
        case "$arg" in
            --option-case-ignore)
                option_case_ignore=1
                ;;
            --no-option-case-ignore)
                option_case_ignore=0
                ;;
            --enum-case-ignore)
                enum_case_ignore=1
                ;;
            --no-enum-case-ignore)
                enum_case_ignore=0
                ;;
            --enum-abbrevs)
                enum_abbrevs=1
                ;;
            --no-enum-abbrevs)
                enum_abbrevs=0
                ;;
            --)
                # Everything after -- are the command line args to parse
                (( i++ ))
                break
                ;;
            -*)
                echo "Error: Unknown parse option: $arg" >&2
                return 1
                ;;
            *)
                # Refnames
                refnames+=("$arg")
                ;;
        esac
        (( i++ ))
    done

    # Collect command line arguments
    while [[ $i -le $# ]]; do
        cmdline_args+=("${@[i]}")
        (( i++ ))
    done

    # If no refnames specified, use all registered
    if [[ ${#refnames} -eq 0 ]]; then
        if ! typeset -p _argparse_registry &>/dev/null; then
            echo "Error: No argument definitions found" >&2
            return 1
        fi
        refnames=(${(v)_argparse_registry})
    fi

    # Build option lookup tables and required list
    local -A option_to_refname option_to_argdef long_options short_options
    local -A required_options  # dest -> refname mapping for required args
    for refname in "${refnames[@]}"; do
        if ! typeset -p "$refname" &>/dev/null; then
            echo "Error: Argument definition '$refname' not found" >&2
            return 1
        fi

        local names
        names=$(aa_get "$refname" "names")
        if [[ -z "$names" ]]; then
            continue
        fi

        # Check if this argument is required
        local required
        required=$(aa_get "$refname" "required" 2>/dev/null)
        if [[ -n "$required" ]]; then
            local dest
            dest=$(aa_get "$refname" "dest" 2>/dev/null)
            if [[ -z "$dest" ]]; then
                local -a name_list
                name_list=(${=names})
                dest="${name_list[1]#-#-}"
            fi
            required_options["$dest"]="$refname"
        fi

        local -a name_list
        name_list=(${=names})
        for name in "${name_list[@]}"; do
            if [[ -n "${option_to_refname[$name]}" ]]; then
                echo "Error: Option '$name' defined multiple times" >&2
                return 1
            fi
            option_to_refname["$name"]="$refname"

            # Categorize as short (-x) or long (--xyz) option
            if [[ "$name" =~ ^--[a-zA-Z] ]]; then
                long_options["$name"]="$refname"
            elif [[ "$name" =~ ^-[a-zA-Z]$ ]]; then
                short_options["$name"]="$refname"
            fi
        done
    done

    # Initialize result arrays
    for refname in "${refnames[@]}"; do
        local result_array="${refname}_results"
        aa_init "$result_array"

        # Set defaults
        local default_val
        default_val=$(aa_get "$refname" "default" 2>/dev/null)
        if [[ -n "$default_val" ]]; then
            local dest
            dest=$(aa_get "$refname" "dest" 2>/dev/null)
            if [[ -z "$dest" ]]; then
                local names
                names=$(aa_get "$refname" "names")
                local -a name_list
                name_list=(${=names})
                dest="${name_list[1]#-#-}"
            fi
            aa_set "$result_array" "$dest" "$default_val"
        fi
    done

    # Parse command line arguments
    local -a positional_args
    i=1
    while [[ $i -le ${#cmdline_args} ]]; do
        local arg="${cmdline_args[i]}"

        case "$arg" in
            --)
                # End of options, rest are positional
                (( i++ ))
                while [[ $i -le ${#cmdline_args} ]]; do
                    positional_args+=("${cmdline_args[i]}")
                    (( i++ ))
                done
                break
                ;;
            --*)
                # Long option
                local option_name="$arg"
                local matched_refname=""

                # Try exact match first
                if [[ -n "${long_options[$option_name]}" ]]; then
                    matched_refname="${long_options[$option_name]}"
                elif [[ $option_case_ignore -eq 1 ]]; then
                    # Try case-insensitive abbreviation matching
                    aa_find_key long_options "$option_name" 1
                    case $? in
                        1) matched_refname="${long_options[$_argparse_matched_key]}" ;;
                        0) echo "Error: Unknown option: $option_name" >&2; return 1 ;;
                        2) echo "Error: Ambiguous option: $option_name" >&2; return 1 ;;
                    esac
                else
                    echo "Error: Unknown option: $option_name" >&2
                    return 1
                fi

                # Process the matched option
                if ! _argparse_process_option "$matched_refname" "$option_name" cmdline_args i $enum_case_ignore $enum_abbrevs; then
                    return 1
                fi

                # Mark as provided for required checking
                local dest
                dest=$(aa_get "$matched_refname" "dest" 2>/dev/null)
                if [[ -z "$dest" ]]; then
                    local names
                    names=$(aa_get "$matched_refname" "names")
                    local -a name_list
                    name_list=(${=names})
                    dest="${name_list[1]#-#-}"
                fi
                unset "required_options[$dest]"
                ;;
            -*)
                # Short option(s)
                local short_opts="${arg#-}"
                local j=1
                while [[ $j -le ${#short_opts} ]]; do
                    local short_opt="-${short_opts[j]}"
                    local matched_refname=""

                    if [[ -n "${short_options[$short_opt]}" ]]; then
                        matched_refname="${short_options[$short_opt]}"
                    else
                        echo "Error: Unknown option: $short_opt" >&2
                        return 1
                    fi

                    # For short options, only the last one can take an argument
                    if [[ $j -eq ${#short_opts} ]]; then
                        if ! _argparse_process_option "$matched_refname" "$short_opt" cmdline_args i $enum_case_ignore $enum_abbrevs; then
                            return 1
                        fi
                        # Mark as provided for required checking
                        local dest
                        dest=$(aa_get "$matched_refname" "dest" 2>/dev/null)
                        if [[ -z "$dest" ]]; then
                            local names
                            names=$(aa_get "$matched_refname" "names")
                            local -a name_list
                            name_list=(${=names})
                            dest="${name_list[1]#-#-}"
                        fi
                        unset "required_options[$dest]"
                    else
                        # Middle short options must be flags (store_true, store_false, etc.)
                        if ! _argparse_process_flag_option "$matched_refname" "$short_opt"; then
                            return 1
                        fi
                        # Also mark flags as provided for required checking
                        local dest
                        dest=$(aa_get "$matched_refname" "dest" 2>/dev/null)
                        if [[ -z "$dest" ]]; then
                            local names
                            names=$(aa_get "$matched_refname" "names")
                            local -a name_list
                            name_list=(${=names})
                            dest="${name_list[1]#-#-}"
                        fi
                        unset "required_options[$dest]"
                    fi
                    (( j++ ))
                done
                ;;
            *)
                # Positional argument
                positional_args+=("$arg")
                ;;
        esac
        (( i++ ))
    done

    # Check for missing required arguments
    if [[ ${#required_options} -gt 0 ]]; then
        echo "Error: Missing required arguments: ${(k)required_options}" >&2
        return 1
    fi

    # TODO: Handle positional arguments and required argument validation
    echo "Parsing complete. Positional args: ${positional_args[*]}"
    return 0
}

# Helper function to validate and convert a value based on type
_argparse_validate_type() {
    local value="$1" type="$2" choices="$3" pattern="$4"
    local case_ignore="$5" abbrev_ok="$6"

    # First check choices if provided
    if [[ -n "$choices" ]]; then
        local -A choices_map
        local -a choice_list
        choice_list=(${=choices})  # Split on whitespace

        # Build choices lookup
        for choice in "${choice_list[@]}"; do
            choices_map["$choice"]="$choice"
        done

        # Try exact match first
        if [[ -n "${choices_map[$value]}" ]]; then
            echo "$value"
            return 0
        fi

        # Try abbreviation/case-insensitive matching if enabled
        if [[ "$abbrev_ok" == "1" || "$case_ignore" == "1" ]]; then
            aa_find_key choices_map "$value" "$case_ignore"
            local result=$?
            case $result in
                1)
                    echo "$_argparse_matched_key"
                    return 0
                    ;;
                0)
                    echo "Error: '$value' is not a valid choice. Options: ${choice_list[*]}" >&2
                    return 1
                    ;;
                2)
                    echo "Error: '$value' is ambiguous. Could match: ${choice_list[*]}" >&2
                    return 1
                    ;;
            esac
        else
            echo "Error: '$value' is not a valid choice. Options: ${choice_list[*]}" >&2
            return 1
        fi
    fi

    # Check pattern if provided
    if [[ -n "$pattern" ]]; then
        if ! [[ "$value" =~ $pattern ]]; then
            echo "Error: '$value' does not match required pattern: $pattern" >&2
            return 1
        fi
    fi

    # Type-specific validation and conversion using new functions TODO ????
    case "$type" in
        STR) is_str "$value" ;;
        IDENT) is_ident "$value" ;;
        CHAR) is_char "$value" ;;
        INT) is_int "$value" ;;
        HEXINT) is_hexint "$value" ;;
        OCTINT) is_octint "$value" ;;
        ANYINT) is_anyint "$value" ;;
        FLOAT) is_float "$value" ;;
        PROB) is_prob "$value" ;;
        LOGPROB) is_logprob "$value" ;;
        BOOL) is_bool "$value" "$abbrev_ok" ;;
        REGEX) is_regex "$value" ;;
        PATH) is_path "$value" ;;
        URL) is_url "$value" ;;
        TIME|DATE|DATETIME) is_time_date "$value" ;;
        *) echo "Error: Unknown type '$type'" >&2; return 1 ;;
    esac
}

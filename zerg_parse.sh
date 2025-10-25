#!/bin/zsh
# Main argument parsing functions for zerg (zsh argument parser)
#
# TODO Add export to Python argparse, zsh case, zsh autocomplete.

if ! [ $ZERG_SETUP ]; then
    echo "Source zerg_setup.sh first." >&2
    return 99
fi


###############################################################################
# Helper function to validate and convert a value based on type
# Applies case folding, checks choices/patterns, validates type
#
_zerg_validate_type() {
    local value="$1" type="$2" choices="$3" pattern="$4"
    local case_ignore="$5" abbrev_ok="$6" fold="${7:-NONE}"

    # Apply case folding first
    case "$fold:l" in
        upper) value="${value:l}" ;;
        lower) value="${value:l}" ;;
        none) ;;
    esac

    # Check choices if provided
    if [[ -n "$choices" ]]; then
        local -A choices_map
        local -a choice_list
        choice_list=(${=choices})

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
            aa_find_key -x '__*' choices_map "$value" "$case_ignore"
            local result=$?
            case $result in
                1)
                    echo "$_aa_matched_key"
                    return 0 ;;
                0)
                    tMsg 0 "_zerg_validate_type: '$value' is not valid. Options: ${choice_list[*]}"
                    return 1 ;;
                2)
                    tMsg 0 "_zerg_validate_type: '$value' is ambiguous. Could match: ${choice_list[*]}"
                    return 1 ;;
            esac
        else
            tMsg 0 "_zerg_validate_type: '$value' is not valid. Options: ${choice_list[*]}"
            return 1
        fi
    fi

    # Check pattern if provided (for idents, applies to each token)
    if [[ -n "$pattern" ]]; then
        if [[ "$type" == "idents" ]]; then
            # Split and validate each token
            local -a tokens
            tokens=(${=value})
            for token in "${tokens[@]}"; do
                if ! [[ "$token" =~ $pattern ]]; then
                    tMsg 0 "_zerg_validate_type: Token '$token' does not match pattern: $pattern"
                    return 1
                fi
            done
        else
            # Single value - check pattern
            if ! [[ "$value" =~ $pattern ]]; then
                tMsg 0 "_zerg_validate_type: '$value' does not match pattern: $pattern"
                return 1
            fi
        fi
    fi

    # Type-specific validation  TODO Switch to is_of_zerg_type
    case "$type" in
        str) is_str "$value" ;;
        char) is_char -q "$value" ;;
        ident) is_ident -q "$value" ;;
        idents) is_idents -q "$value" ;;
        int) is_int -q "$value" ;;
        hexint) is_hexint -q "$value" ;;
        octint) is_octint -q "$value" ;;
        binint) is_binint -q "$value" ;;
        anyint) is_anyint -q "$value" ;;
        float) is_float -q "$value" ;;
        prob) is_prob -q "$value" ;;
        logprob) is_logprob -q "$value" ;;
        bool) is_bool -q "$value" "$abbrev_ok" ;;
        regex) is_regex -q "$value" ;;
        path) is_path -q "$value" ;;
        url) is_url -q "$value" ;;
        time) is_time -q "$value" ;;
        date) is_date -q "$value" ;;
        datetime) is_datetime -q "$value" ;;
        duration) is_duration -q "$value" ;;
        epoch) is_epoch -q "$value" ;;
        *)
            tMsg 0 "_zerg_validate_type: Unknown type '$type'"
            aa_has zerg_type $type && tMsg 0 "***** Unhandled type '$type' *****"
            return 1 ;;
    esac

    if [[ $? -eq 0 ]]; then
        echo "$value"
        return 0
    else
        return 1
    fi
}

_zerg_help() {
}

_zerg_usage() {
}


###############################################################################
# Process an option that takes a value
# Handles all action types and nargs variations
#
_zerg_process_option() {
    local parser_name="$1" def_name="$2" option_name="$3"
    local -n cmdline_ref="$4"
    local -n index_ref="$5"
    local enum_case_ignore="$6" enum_abbrevs="$7"

    # Get metadata from definition
    local action=$(aa_get -q "$def_name" "action")
    local type=$(aa_get -q "$def_name" "type")
    local nargs=$(aa_get -q "$def_name" "nargs")
    local choices=$(aa_get -q "$def_name" "choices")
    local pattern=$(aa_get -q "$def_name" "pattern")
    local dest=$(aa_get -q "$def_name" "dest")
    local fold=$(aa_get -q "$def_name" "fold")

    [[ -z "$action" ]] && action="store"
    [[ -z "$type" ]] && type="str"
    [[ -z "$fold" ]] && fold="none"

    # Get var_style from parser settings
    local var_style=$(aa_get -q "$parser_name" "__var_style")
    [[ -z "$var_style" ]] && var_style="separate"

    # Determine result storage location
    local result_array="${parser_name}__results"

    case "$action" in
        store_true)
            if [[ "$var_style" == "assoc" ]]; then
                aa_set "$result_array" "$dest" "1"
            else
                typeset -g "$dest"="1"
            fi
            return 0 ;;
        store_false)
            if [[ "$var_style" == "assoc" ]]; then
                aa_set "$result_array" "$dest" ""
            else
                typeset -g "$dest"=""
            fi
            return 0 ;;
        store_const)
            local const_val=$(aa_get -q "$def_name" "const")
            if [[ "$var_style" == "assoc" ]]; then
                aa_set "$result_array" "$dest" "$const_val"
            else
                typeset -g "$dest"="$const_val"
            fi
            return 0 ;;
        count)
            local current
            if [[ "$var_style" == "assoc" ]]; then
                current=$(aa_get -q -d "0" "$result_array" "$dest")
                aa_set "$result_array" "$dest" "$((current + 1))"
            else
                current="${(P)dest}"
                [[ -z "$current" ]] && current=0
                typeset -g "$dest"="$((current + 1))"
            fi
            return 0 ;;
        toggle)
            local current
            if [[ "$var_style" == "assoc" ]]; then
                current=$(aa_get -q "$result_array" "$dest")
                if [[ -n "$current" && "$current" != "0" ]]; then
                    aa_set "$result_array" "$dest" ""
                else
                    aa_set "$result_array" "$dest" "1"
                fi
            else
                current="${(P)dest}"
                if [[ -n "$current" && "$current" != "0" ]]; then
                    typeset -g "$dest"=""
                else
                    typeset -g "$dest"="1"
                fi
            fi
            return 0 ;;
        store|append|extend)
            # These actions need argument values
            local -a values
            local num_args=1

            case "$nargs" in
                ""|1) num_args=1 ;;
                "?") num_args=0 ;;
                "*") num_args=-1 ;;
                "+") num_args=-2 ;;
                [0-9]*) num_args="$nargs" ;;
                *)
                    tMsg 0 "_zerg_process_option: Invalid nargs value: $nargs"
                    return 97 ;;
            esac

            # Collect argument values
            if [[ $num_args -eq 0 ]]; then
                # Optional argument
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
                        tMsg 0 "_zerg_process_option: Option $option_name requires $num_args arguments"
                        return 96
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
                    tMsg 0 "_zerg_process_option: Option $option_name requires at least one argument"
                    return 95
                fi
                index_ref=$((j - 1))
            fi

            # Validate and store values
            local -a validated_values
            for value in "${values[@]}"; do
                local validated
                if ! validated=$(_zerg_validate_type "$value" "$type" "$choices" "$pattern" "$enum_case_ignore" "$enum_abbrevs" "$fold"); then
                    return 94
                fi
                validated_values+=("$validated")
            done

            case "$action" in
                store)
                    if [[ ${#validated_values} -eq 1 ]]; then
                        if [[ "$var_style" == "assoc" ]]; then
                            aa_set "$result_array" "$dest" "${validated_values[1]}"
                        else
                            typeset -g "$dest"="${validated_values[1]}"
                        fi
                    else
                        if [[ "$var_style" == "assoc" ]]; then
                            aa_set "$result_array" "$dest" "${validated_values[*]}"
                        else
                            # TODO Offer int and float?
                            typeset -g "$dest"="${validated_values[*]}"
                        fi
                    fi ;;
                append|extend)
                    tMsg 1 "_zerg_process_option: APPEND/EXTEND not yet implemented"
                    if [[ "$var_style" == "assoc" ]]; then
                        aa_set "$result_array" "$dest" "${validated_values[*]}"
                    else
                        typeset -g "$dest"="${validated_values[*]}"
                    fi ;;
            esac ;;
        *)
            tMsg 0 "_zerg_process_option: Unknown action '$action'"
            return 93 ;;
    esac

    return 0
}

###############################################################################
# Helper for bundled short options that don't take arguments
#
_zerg_process_flag_option() {
    local parser_name="$1" def_name="$2" option_name="$3"

    local action=$(aa_get -q "$def_name" "action")
    [[ -z "$action" ]] && action="store"

    case "$action" in
        store_true|store_false|store_const|count|toggle)
            local dummy_array dummy_index
            _zerg_process_option "$parser_name" "$def_name" "$option_name" dummy_array dummy_index 0 0
            return $? ;;
        *)
            tMsg 0 "_zerg_process_flag_option: Option $option_name cannot take arguments in bundle"
            return 92 ;;
    esac
}

###############################################################################
# Main parsing function
# Usage: zerg_parse parser_name [options] -- [command_line_args...]
#
zerg_parse() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: zerg_parse parser_name [options] -- [command_line_args...]
Parse command line arguments using the specified parser.

Options:
  --option-case-ignore      Enable case-insensitive option matching (default)
  --no-option-case-ignore   Disable case-insensitive option matching
  --enum-case-ignore        Enable case-insensitive enum matching (default)
  --no-enum-case-ignore     Disable case-insensitive enum matching
  --enum-abbrevs            Allow abbreviated enum values (default)
  --no-enum-abbrevs         Disable abbreviated enum values

The -- separator is required before command line arguments.

Example:
  zerg_parse MYPARSER -- "$@"
  zerg_parse MYPARSER --no-option-case-ignore -- "$@"
EOF
        return
    fi

    req_argc 1 99 $# || return 98
    local parser_name="$1"
    shift

    # Verify parser exists
    if ! typeset -p "$parser_name" &>/dev/null; then
        tMsg 0 "zerg_parse: Parser '$parser_name' does not exist"
        return 98
    fi

    # Get parser settings
    local option_case_ignore=$(aa_get -q -d "1" "$parser_name" "__ignore_case")
    local abbrev=$(aa_get -q -d "1" "$parser_name" "__abbrev")
    local var_style=$(aa_get -q -d "separate" "$parser_name" "__var_style")

    # Parse-time overrides
    local enum_case_ignore=1
    local enum_abbrevs=1
    local -a cmdline_args

    # Parse zerg_parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --option-case-ignore) option_case_ignore=1; shift ;;
            --no-option-case-ignore) option_case_ignore=0; shift ;;
            --enum-case-ignore) enum_case_ignore=1; shift ;;
            --no-enum-case-ignore) enum_case_ignore=0; shift ;;
            --enum-abbrevs) enum_abbrevs=1; shift ;;
            --no-enum-abbrevs) enum_abbrevs=0; shift ;;
            --)
                shift
                break ;;
            -*)
                tMsg 0 "zerg_parse: Unknown option: $1"
                return 97 ;;
            *)
                tMsg 0 "zerg_parse: Unexpected argument before '--': $1"
                return 96 ;;
        esac
    done

    # Collect command line arguments
    cmdline_args=("$@")

    # Build option lookup tables
    local -A long_options short_options
    local -a required_dests

    # Get registered refnames for defined arguments
    local registered=$(aa_get -q "$parser_name" "__arg_names")
    if [[ -z "$registered" ]]; then
        tMsg 0 "zerg_parse: No arguments registered in parser '$parser_name'"
        return 95
    fi

    local -a refnames
    refnames=(${=registered})

    # Build lookup tables for all aliases
    for refname in "${refnames[@]}"; do
        local def_name="${parser_name}__${refname}"

        if ! typeset -p "$def_name" &>/dev/null; then
            tMsg 0 "zerg_parse: Definition '$def_name' not found"
            return 94
        fi

        # Get all aliases for this argument
        local aliases=$(aa_get -q "$def_name" "aliases")
        if [[ -z "$aliases" ]]; then
            continue
        fi

        # Check if required
        local required=$(aa_get -q "$def_name" "required")
        if [[ -n "$required" ]]; then
            local dest=$(aa_get -q "$def_name" "dest")
            [[ -n "$dest" ]] && required_dests+=("$dest")
        fi

        local -a alias_list
        alias_list=(${=aliases})

        for alias in "${alias_list[@]}"; do
            if [[ "$alias" =~ ^--[a-zA-Z] ]]; then
                long_options["$alias"]="$def_name"
            elif [[ "$alias" =~ ^-[a-zA-Z]$ ]]; then
                short_options["$alias"]="$def_name"
            fi
        done
    done

    # Initialize result storage
    if [[ "$var_style" == "assoc" ]]; then
        local result_array="${parser_name}__results"
        typeset -gA "$result_array"
    fi

    # Set defaults
    for refname in "${refnames[@]}"; do
        local def_name="${parser_name}__${refname}"
        local default_val=$(aa_get -q "$def_name" "default")
        local dest=$(aa_get -q "$def_name" "dest")

        if [[ -n "$default_val" && -n "$dest" ]]; then
            if [[ "$var_style" == "assoc" ]]; then
                aa_set "${parser_name}__results" "$dest" "$default_val"
            else
                typeset -g "$dest"="$default_val"
            fi
        fi
    done

    # Parse command line arguments
    local -a positional_args
    local -A provided_dests
    local i=1

    while [[ $i -le ${#cmdline_args} ]]; do
        local arg="${cmdline_args[i]}"

        case "$arg" in
            --)
                # End of options marker
                (( i++ ))
                while [[ $i -le ${#cmdline_args} ]]; do
                    positional_args+=("${cmdline_args[i]}")
                    (( i++ ))
                done
                break ;;
            --*)
                # Long option
                local option_name="$arg"
                local matched_def=""

                # Try exact match first
                if [[ -n "${long_options[$option_name]}" ]]; then
                    matched_def="${long_options[$option_name]}"
                elif [[ $abbrev -eq 1 ]]; then
                    # Try abbreviation matching
                    aa_find_key -x '__*' long_options "$option_name" "$option_case_ignore"
                    case $? in
                        1) matched_def="$_aa_matched_key" ;;
                        0)
                            tMsg 0 "zerg_parse: Unknown option: $option_name"
                            return 91 ;;
                        2)
                            tMsg 0 "zerg_parse: Ambiguous option: $option_name"
                            return 90 ;;
                    esac
                else
                    tMsg 0 "zerg_parse: Unknown option: $option_name"
                    return 91
                fi

                # Process the matched option
                if ! _zerg_process_option "$parser_name" "$matched_def" "$option_name" cmdline_args i $enum_case_ignore $enum_abbrevs; then
                    return 89
                fi

                # Mark as provided
                local dest=$(aa_get -q "$matched_def" "dest")
                [[ -n "$dest" ]] && provided_dests["$dest"]=1
                ;;
            -*)
                # Short option(s)
                local opt_string="${arg#-}"
                local j=1

                while [[ $j -le ${#opt_string} ]]; do
                    local short_opt="-${opt_string[j]}"
                    local matched_def=""

                    # Try exact match first
                    if [[ -n "${short_options[$short_opt]}" ]]; then
                        matched_def="${short_options[$short_opt]}"
                    else
                        tMsg 0 "zerg_parse: Unknown option: $short_opt"
                        return 91
                    fi

                    # Check if this is the last option in the bundle
                    if [[ $j -eq ${#opt_string} ]]; then
                        # Last option - can take arguments
                        if ! _zerg_process_option "$parser_name" "$matched_def" "$short_opt" cmdline_args i $enum_case_ignore $enum_abbrevs; then
                            return 88
                        fi
                    else
                        # Middle options must be flags
                        if ! _zerg_process_flag_option "$parser_name" "$matched_def" "$short_opt"; then
                            return 87
                        fi
                    fi

                    # Mark as provided
                    local dest=$(aa_get -q "$matched_def" "dest")
                    [[ -n "$dest" ]] && provided_dests["$dest"]=1

                    (( j++ ))
                done ;;
            *)
                # Positional argument
                positional_args+=("$arg") ;;
        esac

        (( i++ ))
    done

    # Check for missing required arguments
    for req_dest in "${required_dests[@]}"; do
        if [[ -z "${provided_dests[$req_dest]}" ]]; then
            tMsg 0 "zerg_parse: Missing required argument: $req_dest"
            return 86
        fi
    done

    # TODO: Handle positional arguments properly
    if [[ ${#positional_args} -gt 0 ]]; then
        tMsg 1 "zerg_parse: Positional arguments not yet supported: ${positional_args[*]}"
    fi

    return 0
}

# Detect if being run directly vs sourced
if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
    echo "${(%):-%x} is a library file. Source it, don't execute it."
    echo "Usage: source ${(%):-%x}"
fi

#!/bin/zsh
# Main argument parsing functions for zsh_argparse

###############################################################################
# Helper function to validate and convert a value based on type
# Applies case folding, checks choices/patterns, validates type
#
_argparse_validate_type() {
    local value="$1" type="$2" choices="$3" pattern="$4"
    local case_ignore="$5" abbrev_ok="$6" fold="${7:-NONE}"

    # Apply case folding first
    case "$fold" in
        UPPER) value="${value:u}" ;;
        LOWER) value="${value:l}" ;;
        NONE) ;;
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
                    tMsg 0 "_argparse_validate_type: '$value' is not valid. Options: ${choice_list[*]}"
                    return 1 ;;
                2)
                    tMsg 0 "_argparse_validate_type: '$value' is ambiguous. Could match: ${choice_list[*]}"
                    return 1 ;;
            esac
        else
            tMsg 0 "_argparse_validate_type: '$value' is not valid. Options: ${choice_list[*]}"
            return 1
        fi
    fi

    # Check pattern if provided (for IDENTS, applies to each token)
    if [[ -n "$pattern" ]]; then
        if [[ "$type" == "IDENTS" ]]; then
            # Split and validate each token
            local -a tokens
            tokens=(${=value})
            for token in "${tokens[@]}"; do
                if ! [[ "$token" =~ $pattern ]]; then
                    tMsg 0 "_argparse_validate_type: Token '$token' does not match pattern: $pattern"
                    return 1
                fi
            done
        else
            # Single value - check pattern
            if ! [[ "$value" =~ $pattern ]]; then
                tMsg 0 "_argparse_validate_type: '$value' does not match pattern: $pattern"
                return 1
            fi
        fi
    fi

    # Type-specific validation
    case "$type" in
        STR) is_str "$value" ;;
        CHAR) is_char -q "$value" ;;
        IDENT) is_ident -q "$value" ;;
        IDENTS) is_idents -q "$value" ;;
        INT) is_int -q "$value" ;;
        HEXINT) is_hexint -q "$value" ;;
        OCTINT) is_octint -q "$value" ;;
        BININT) is_binint -q "$value" ;;
        ANYINT) is_anyint -q "$value" ;;
        FLOAT) is_float -q "$value" ;;
        PROB) is_prob -q "$value" ;;
        LOGPROB) is_logprob -q "$value" ;;
        BOOL) is_bool -q "$value" "$abbrev_ok" ;;
        REGEX) is_regex -q "$value" ;;
        PATH) is_path -q "$value" ;;
        URL) is_url -q "$value" ;;
        TIME) is_time -q "$value" ;;
        DATE) is_date -q "$value" ;;
        DATETIME) is_datetime -q "$value" ;;
        DURATION) is_duration -q "$value" ;;
        EPOCH) is_epoch -q "$value" ;;
        *)
            tMsg 0 "_argparse_validate_type: Unknown type '$type'"
            return 1 ;;
    esac

    if [[ $? -eq 0 ]]; then
        echo "$value"
        return 0
    else
        return 1
    fi
}

###############################################################################
# Process an option that takes a value
# Handles all action types and nargs variations
#
_argparse_process_option() {
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

    [[ -z "$action" ]] && action="STORE"
    [[ -z "$type" ]] && type="STR"
    [[ -z "$fold" ]] && fold="NONE"

    # Get var_style from parser settings
    local var_style=$(aa_get -q "$parser_name" "__var_style")
    [[ -z "$var_style" ]] && var_style="separate"

    # Determine result storage location
    local result_array="${parser_name}__results"

    case "$action" in
        STORE_TRUE)
            if [[ "$var_style" == "assoc" ]]; then
                aa_set "$result_array" "$dest" "1"
            else
                typeset -g "$dest"="1"
            fi
            return 0 ;;
        STORE_FALSE)
            if [[ "$var_style" == "assoc" ]]; then
                aa_set "$result_array" "$dest" ""
            else
                typeset -g "$dest"=""
            fi
            return 0 ;;
        STORE_CONST)
            local const_val=$(aa_get -q "$def_name" "const")
            if [[ "$var_style" == "assoc" ]]; then
                aa_set "$result_array" "$dest" "$const_val"
            else
                typeset -g "$dest"="$const_val"
            fi
            return 0 ;;
        COUNT)
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
        TOGGLE)
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
        STORE|APPEND|EXTEND)
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
                    tMsg 0 "_argparse_process_option: Invalid nargs value: $nargs"
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
                        tMsg 0 "_argparse_process_option: Option $option_name requires $num_args arguments"
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
                    tMsg 0 "_argparse_process_option: Option $option_name requires at least one argument"
                    return 95
                fi
                index_ref=$((j - 1))
            fi

            # Validate and store values
            local -a validated_values
            for value in "${values[@]}"; do
                local validated
                if ! validated=$(_argparse_validate_type "$value" "$type" "$choices" "$pattern" "$enum_case_ignore" "$enum_abbrevs" "$fold"); then
                    return 94
                fi
                validated_values+=("$validated")
            done

            case "$action" in
                STORE)
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
                            typeset -g "$dest"="${validated_values[*]}"
                        fi
                    fi ;;
                APPEND|EXTEND)
                    tMsg 1 "_argparse_process_option: APPEND/EXTEND not yet implemented"
                    if [[ "$var_style" == "assoc" ]]; then
                        aa_set "$result_array" "$dest" "${validated_values[*]}"
                    else
                        typeset -g "$dest"="${validated_values[*]}"
                    fi ;;
            esac ;;
        *)
            tMsg 0 "_argparse_process_option: Unknown action '$action'"
            return 93 ;;
    esac

    return 0
}

###############################################################################
# Helper for bundled short options that don't take arguments
#
_argparse_process_flag_option() {
    local parser_name="$1" def_name="$2" option_name="$3"

    local action=$(aa_get -q "$def_name" "action")
    [[ -z "$action" ]] && action="STORE"

    case "$action" in
        STORE_TRUE|STORE_FALSE|STORE_CONST|COUNT|TOGGLE)
            local dummy_array dummy_index
            _argparse_process_option "$parser_name" "$def_name" "$option_name" dummy_array dummy_index 0 0
            return $? ;;
        *)
            tMsg 0 "_argparse_process_flag_option: Option $option_name cannot take arguments in bundle"
            return 92 ;;
    esac
}

###############################################################################
# Main parsing function
# Usage: zsh_parse_args parser_name [options] -- [command_line_args...]
#
zsh_parse_args() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: zsh_parse_args parser_name [options] -- [command_line_args...]
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
  zsh_parse_args MYPARSER -- "$@"
  zsh_parse_args MYPARSER --no-option-case-ignore -- "$@"
EOF
        return
    fi

    if [[ $# -lt 1 ]]; then
        tMsg 0 "zsh_parse_args: Expected parser_name as first argument"
        return 99
    fi

    local parser_name="$1"
    shift

    # Verify parser exists
    if ! typeset -p "$parser_name" &>/dev/null; then
        tMsg 0 "zsh_parse_args: Parser '$parser_name' does not exist"
        return 98
    fi

    # Get parser settings
    local option_case_ignore=$(aa_get -q -d "1" "$parser_name" "__ignore_case")
    local allow_abbrev=$(aa_get -q -d "1" "$parser_name" "__allow_abbrev")
    local var_style=$(aa_get -q -d "separate" "$parser_name" "__var_style")

    # Parse-time overrides
    local enum_case_ignore=1
    local enum_abbrevs=1
    local -a cmdline_args

    # Parse zsh_parse_args options
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
                tMsg 0 "zsh_parse_args: Unknown option: $1"
                return 97 ;;
            *)
                tMsg 0 "zsh_parse_args: Unexpected argument before '--': $1"
                return 96 ;;
        esac
    done

    # Collect command line arguments
    cmdline_args=("$@")

    # Build option lookup tables
    local -A long_options short_options
    local -a required_dests

    # Get registered canonical args
    local registered=$(aa_get -q
}

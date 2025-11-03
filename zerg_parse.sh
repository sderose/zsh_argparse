#!/bin/zsh
# Main argument parsing functions for zerg (zsh argument parser)
#
# TODO Add export to zsh case form, zsh autocomplete?

if ! [[ $ZERG_SETUP == 1 ]] || [[ "$1" == "-f" ]]; then
    echo "Source zerg_setup.sh first." >&2
    return ZERR_UNDEF
fi

#setopt xtrace


###############################################################################
_zerg_check_choices() {
    # Return normalized choice value
    local value="$1" choices="$2" case_ignore="$3" abbrs="$4"

    [[ -n "$choices" ]] || return 0

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
    if [ "$abbrs" || "$case_ignore" ]; then
        local chList="Choices: ${choice_list[*]}"
        local ic=
        aa_find_key -x $ic '__*' choices_map "$value" "$case_ignore"
        local result=$?
        case $result in
            1) echo "$_aa_matched_key"; return 0 ;;
            0) tMsg 0 "'$value' not recognized. $chList."; return ZERR_ENUM ;;
            2) tMsg 0 "'$value' is ambiguous. $chList."; return ZERR_ENUM ;;
        esac
    else
        tMsg 0 "'$value' is not a valid choice. $chList."; return ZERR_ENUM
    fi
}

_zerg_check_pattern() {
    local value="$1" type="$2" pattern="$3"
    [ "$pattern" ] || return 0

    if [[ "$type" == "idents" ]]; then
        # TODO Upgrade to handle plural types generally
        # Split and validate each token
        local -a tokens=(${=value})
        for token in "${tokens[@]}"; do
            if ! [[ "$token" =~ $pattern ]]; then
                tMsg 0 "Token '$token' does not match pattern: $pattern"
                return 1
            fi
        done
    elif ! [[ "$value" =~ $pattern ]]; then
        tMsg 0 "'$value' does not match pattern: $pattern"
        return 1
    fi
}

_zerg_check_type() {
    local value="$1" type="$2"
    if ! aa_has zerg_types $type; then
        tMsg 0 "Unknown type '$type'"
        return ZERR_ENUM
    elif ! is_of_zerg_type $type "$value"; then
        tMsg 0 "Argument : Value '$value' does not satisfy type '$type'"
        return ZERR_ZERG_TVALUE
    fi
}


###############################################################################
# Help support
#
_zerg_help() {
    # TODO Implement description_breaks
    sv_type $1 assoc || exit ZERR_SV_TYPE
    local help_file="${${(P)1}[help_file]}"
    if [ $help_file ]; then
        if ! [ -f "$help_file" ]; then
            tMsg 0 "Help file '$help_file' not found."; return 1
        fi
        local help_tool="${${(P)1}[help_tool]}"
        if [ $help_file ]; then
            cat $help_file | $help_tool
        else
            less $help_file
        fi
    else
        print ${${(P)1}[description]}
        print "Options:"
        _zerg_usage $1
    fi
}

_zerg_usage() {
    # Gather options and help strings
    sv_type $1 assoc || exit ZERR_SV_TYPE
    for key in "${(P)1)[@]}"; do
        [[ $key =~ --* ]] || continue
        local arg_def_name=${${(P)1}[$1__$key]}
        printf "    %-12s %s\n" $key ${${(Pqq)arg_def_name}[help]}
    done
}


###############################################################################
# Process an option that takes a value
# Handles all action types and nargs variations
#
_zerg_store_value() {
    local var_style="$1" result_array="$2" dest="$3" value="$4"
    if [[ "$var_style" == "assoc" ]]; then
        aa_set "$result_array" "$dest" "1"
    else
        typeset -g "$dest"="1"
    fi
}

_zerg_process_option() {
    local parser_name="$1" def_name="$2" option_name="$3"
    local -n cmdline_ref="$4"
    local -n index_ref="$5"
    local ic_choices="$6" abbrev_enums="$7"

    # Gather info on where to store option value
    local var_style=$(aa_get -q "$parser_name" "var_style")
    [ "$var_style" ] && var_style="separate"
    local result_array="${parser_name}__results"
    local dest=$(aa_get -q "$def_name" "dest")

    case "$action" in
        store_true)
            _zerg_store_value $var_style $result_array $dest 1
            return 0 ;;
        store_false)
            _zerg_store_value $var_style $result_array $dest ""
            return 0 ;;
        store_const)
            local val=$(aa_get -q "$def_name" "const")
            _zerg_store_value $var_style $result_array $dest "$val"
            return 0 ;;
        count)
            local -i val
            if [[ "$var_style" == "assoc" ]]; then
                val=$(aa_get -q -d "0" "$result_array" "$dest")
            else
                val="${(P)dest}"
            fi
            val+=1
            _zerg_store_value $var_style $result_array $dest "$val"
            return 0 ;;
        toggle)
            local val
            if [[ "$var_style" == "assoc" ]]; then
                val=$(aa_get -q "$result_array" "$dest")
            else
                current="${(P)dest}"
            fi
            [[ -z "$val" ]] && val=1
            _zerg_store_value $var_style $result_array $dest ="$val"
            return 0 ;;

        store|append|extend)
            # These actions need argument values
            _zerg_collectArgs $parser_name $def_name $cmdline_ref $index_ref ;;
        *) tMsg 0 "Unknown action '$action'"; return ZERR_ENUM ;;
    esac

    return 0
}


_zerg_collectArgs() {
    # Collect the argument's value(s), validate, and store.
    # Needs: option_name, cmdline_ref, index_ref, nargs, var_style
    # Returns: values, index_ref, validated_values -> result thing

    local parser_name=$1 def_name=$2 cmdline_ref=$3 index_ref=$4

    # Get items from parser and arg definition
    local action=$(aa_get -q --default "store" "$def_name" "action")
    local choices=$(aa_get -q "$def_name" "choices")
    local fold=$(aa_get -q --default "none" "$def_name" "fold")
    local nargs=$(aa_get -q --default 1 "$def_name" "nargs")
    local pattern=$(aa_get -q "$def_name" "pattern")
    local type=$(aa_get -q --default "str" "$def_name" "type")

    local -a values
    local num_args=1

    [[ "$nargs" == "?" ]] && nargs=0

    if [[ $nargs == "*" || $nargs == "+" ]]; then       # Variable number of args
        local j=$((index_ref + 1))
        while [[ $j -le ${#cmdline_ref} && "${cmdline_ref[$j]}" != -* ]]; do
            values+=("${cmdline_ref[$j]}")
            (( j++ ))
        done
        if [[ $nargs == "+" && ${#values} -eq 0 ]]; then
            tMsg 0 "Option '$option_name' requires at least one argument."
            return ZERR_ARGC
        fi
        index_ref=$((j - 1))
    elif [[ $nargs == *REMAINDER ]]; then               # All remaining args
        tMsg 0 "REMAINDER not yet implemented"  TODO
    elif ! aa_is_int "$nargs" || (( $nargs < 0 )); then
        tMsg 0 "Bad value '$nargs' for nargs for option $optname."
        return ZERR_BAD_OPTION
    else  # numeric (incl. erstwhile "?")
        local -i nargs=$nargs
        if [[ $n -eq 0 ]]; then                         # Optional arg
            if [[ $((index_ref + 1)) -le ${#cmdline_ref} ]]; then
                if [[ "${cmdline_ref[$((index_ref + 1))]}" != -* ]]; then
                    (( index_ref++ ))
                    values+=("${cmdline_ref[$index_ref]}")
                fi
            fi
        else                                            # Fixed number of args
            local j
            for (( j=1; j<=num_args; j++ )); do
                local curval="${cmdline_ref[$j]}"
                if [[ $((index_ref + j)) -le ${#cmdline_ref} ]]; then
                    values+=("${cmdline_ref[$((index_ref + j))]}")
                else
                    tMsg 0 "Option '$option_name' requires $num_args arguments"
                    return ZERR_ARGC
                fi
            done
            index_ref=$((index_ref + num_args))
        fi
    fi

    # Validate values via choices, pattern, and type constraints
    local -a validated_values
    for value in "${values[@]}"; do
        case "$fold:l" in
            upper) value="$value:u" ;;
            lower) value="$value:l" ;;
            none) ;;
        esac
        local choice=`_zerg_check_choices $value $choices $ic_choices $abbrev_enums`
        if ! [ $choice ]; then
            tMsg 0 "Value not among choices ($choices)."
            return ZERR_ZERG_TVALUE
        fi
        if ! $(_zerg_check_pattern $value $type $pattern); then
            tMsg 0 "Value does not match pattern for type $type: '$value'."
            return ZERR_ZERG_TVALUE
        fi
        if ! $(_zerg_check_type $value $type); then
            tMsg 0 "Value does not satisfy type $type: '$value'."
            return ZERR_ZERG_TVALUE
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
            tMsg 0 "APPEND/EXTEND not yet implemented"
            if [[ "$var_style" == "assoc" ]]; then
                aa_set "$result_array" "$dest" "${validated_values[*]}"
            else
                typeset -g "$dest"="${validated_values[*]}"
            fi ;;
    esac
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
            tMsg 0 "Option $option_name cannot take arguments in bundle"
            return ZERR_BAD_OPTION ;;
    esac
}


###############################################################################
#
zerg_parse() {
    local quiet parse_v
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_parse parser_name [command_line_args...]
Parse command line arguments using the specified parser.

Options: --quiet, --verbose (see also options on zerg_new)

Example:
    zerg_parse MYPARSER "$@"
EOF
            return ;;
        -q|--quiet) quiet=1 ;;
        -v|--verbose) parse_v=1 ;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 99 $# || return ZERR_ARGC
    local parser_name="$1"
    shift

    # Verify parser exists
    if ! typeset -p "$parser_name" &>/dev/null; then
        [ $quiet ] || tMsg 0 "Parser '$parser_name' does not exist"
        return ZERR_UNDEF
    elif [ parse_v ]; then
        echo "Parser is stored as:"
        typeset -p $parser_name
        echo ""
    fi

    # Get parser settings
    local abbrev_enums=$(aa_get -q -d "1" "$parser_name" "abbrev_enums")
    local abbrev_options=$(aa_get -q -d "1" "$parser_name" "allow_abbrev")
    local ic_choices=$(aa_get -q -d "1" "$parser_name" "ic_choices")
    local ignore_case=$(aa_get -q -d "1" "$parser_name" "ignore_case")
    local var_style=$(aa_get -q -d "separate" "$parser_name" "var_style")

    local -a cmdline_args
    cmdline_args=("$@")

    # Build option lookup tables
    local -A long_options short_options
    local -a required_dests

    # Get registered refnames for defined arguments
    local registered=$(aa_get -q "$parser_name" "arg_names_list")
    print ${${(P)parser_name}[arg_names_list]}
    if [[ -z "$registered" ]]; then
        [ $quiet ] || tMsg 0 "No arguments registered in parser '$parser_name'"
        return ZERR_UNDEF
    fi
    local -a refnames
    refnames=(${=registered})

    # Build lookup tables for all aliases
    for refname in "${refnames[@]}"; do
        local def_name="${parser_name}__${refname}"

        if ! typeset -p "$def_name" &>/dev/null; then
            [ $quiet ] || tMsg 0 "Definition '$def_name' not found"
            return ZERR_UNDEF
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
        tMsg 0 "Parsing cmdline option '$arg'"
        case "$arg" in
            --*)
                # Long option
                local option_name="$arg"
                local matched_def=""

                # Try exact match first
                if [[ -n "${long_options[$option_name]}" ]]; then
                    matched_def="${long_options[$option_name]}"
                elif [[ $abbrev -eq 1 ]]; then
                    # Try abbreviation matching
                    aa_find_key -x '__*' long_options "$option_name" "$ignore_case"
                    case $? in
                        1) matched_def="$_aa_matched_key" ;;
                        0) tMsg 0 "Unknown option: '$option_name'.";
                            tMSg 0 "    Known: $long_options."
                            return ZERR_BAD_OPTION ;;
                        2) tMsg 0 "Ambiguous option: $option_name";
                            return ZERR_BAD_OPTION ;;
                    esac
                else
                    tMsg 0 "Unknown option: $option_name"; return ZERR_BAD_OPTION
                fi

                # Process the matched option
                if ! _zerg_process_option "$parser_name" "$matched_def" "$option_name" cmdline_args i $ic_choices $abbrev_enums; then
                    # TODO ?
                    return 89
                fi

                # Mark as provided
                local dest=$(aa_get -q "$matched_def" "dest")
                [[ -n "$dest" ]] && provided_dests["$dest"]=1 ;;
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
                        [ $quiet ] || tMsg 0 "Unknown option: $short_opt"
                        return ZERR_BAD_OPTION
                    fi

                    # Check if this is the last option in the bundle
                    if [[ $j -eq ${#opt_string} ]]; then
                        # Last option - can take arguments
                        if ! _zerg_process_option "$parser_name" "$matched_def" "$short_opt" cmdline_args i $ic_choices $abbrev_enums; then
                            return ZERR_BAD_OPTION
                        fi
                    else
                        # Middle options must be flags
                        if ! _zerg_process_flag_option "$parser_name" "$matched_def" "$short_opt"; then
                            return ZERR_BAD_OPTION
                        fi
                    fi

                    # Mark as provided
                    local dest=$(aa_get -q "$matched_def" "dest")
                    [[ -n "$dest" ]] && provided_dests["$dest"]=1

                    (( j++ ))
                done ;;
            *) positional_args+=("$arg") ;;
        esac
        (( i++ ))
    done

    # Check for missing required arguments
    for req_dest in "${required_dests[@]}"; do
        if [[ -z "${provided_dests[$req_dest]}" ]]; then
            [ $quiet ] || tMsg 0 "Missing required argument: $req_dest"
            return ZERR_BAD_OPTION
        fi
    done

    # TODO: Handle positional arguments explicitly?
    if [[ ${#positional_args} -gt 0 ]]; then
        [ $quiet ] || tMsg 0 "Positional arguments not yet supported: ${positional_args[*]}"
    fi

    return 0
}

# Detect if being run directly vs sourced
if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
    echo "${(%):-%x} is a library file. Source it, don't execute it."
    echo "Usage: source ${(%):-%x}"
fi

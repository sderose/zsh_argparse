#!/bin/zsh
# Main argument parsing functions for zerg (zsh argument parser)
#
# TODO Add export to zsh case form, zsh autocomplete?

if ! [[ $ZERG_SETUP == 1 ]] || [[ "$1" == "-f" ]]; then
    echo "Source zerg_setup.sh first." >&2
    return $ZERR_UNDEF
fi


###############################################################################
_zerg_check_choices() {
    # Return normalized choice value
    local value="$1" choices="$2" icc="$3" abbrc="$4"

    [[ -n "$choices" ]] || return 0

    local -A choices_map
    local -a choice_list=(${(z)choices})

    # Build choices lookup
    for choice in $choice_list[@]; do
        choices_map["$choice"]="$choice"
    done

    # Try exact match first
    if [[ -n "${choices_map[$value]}" ]]; then
        echo "$value"
        return 0
    fi

    # Try abbreviation/case-insensitive matching if enabled
    if [ "$abbrc" || "$icc" ]; then
        local chList="Choices: ${choice_list[*]}"
        aa_find_key -q $icc '__*' choices_map "$value" "$icc"
        local result=$?
        case $result in
            1) echo "$_aa_matched_key"; return 0 ;;
            0) tMsg 0 "'$value' not recognized. $chList."; return $ZERR_ENUM ;;
            2) tMsg 0 "'$value' is ambiguous. $chList."; return $ZERR_ENUM ;;
        esac
    else
        tMsg 0 "'$value' is not a valid choice. $chList."; return $ZERR_ENUM
    fi
}

_zerg_check_pattern() {
    local value="$1" type="$2" pattern="$3"
    [ "$pattern" ] || return 0

    if [[ "$type" == "idents" ]]; then
        # TODO Upgrade to handle plural types generally
        # Split and validate each token
        local -a tokens=(${(z)value})
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
        return $ZERR_ENUM
    elif ! is_of_zerg_type $type "$value"; then
        tMsg 0 "Argument : Value '$value' does not satisfy type '$type'"
        return $ZERR_ZERG_TVALUE
    fi
}


###############################################################################
# Help support
#
_zerg_help() {
    # TODO Implement description_breaks. wrap via fmt?
    req_zerg_class ZERG_PARSER "$1" || return $?
    local help_file="${${(P)1}[help_file]}"
    if [ $help_file ]; then
        if ! [ -f "$help_file" ]; then
            tMsg 0 "Help file '$help_file' not found."; return 1
        fi
        local help_tool="${${(P)1}[help_tool]}"
        is_command -q "$help_tool" || help_tool="less"
        cat $help_file | $help_tool
    else
        print ${${(P)1}[description]}
        print "Options:"
        _zerg_usage $1
    fi
}

_zerg_version() {
    req_zerg_class ZERG_PARSER "$1" || return $?
    req_zerg_class ZERG_ARG_DEF "${1}__version" || return $?
    print "Version = "`aa_get "$1" "${1}__version"`
}

_zerg_usage() {
    # Gather options and help strings. wrap via fmt?
    for key in "${(P)1)[@]}"; do
        [[ $key =~ --* ]] || continue
        local arg_def_name=${${(P)1}[$1__$key]}
        local help=${${(Pqq)arg_def_name}[help]}
        local action=${${(Pqq)arg_def_name}[action]}
        local metavar=""
        if [[ $action == (store|append|extend) ]]; then
            metavar="${${(Pqq)arg_def_name}[metavar]}"
            [ $metavar ] || metavar=" "`zerg_opt_to_var "$metavar"`
        fi
        printf "    %-12s %s%s\n" $key $metavar $help
    done
}


###############################################################################
#
_zerg_store_value() {
    # Store the final value of an option, given dest, var_style, etc.
    local var_style="$1" result_dict_name="$2" dest="$3" value="$4"
    tMsg 0 "Store [$var_style, dict $result_dict_name], dest $dest, val $value"
    req_argc 4 4 $# || return $?
    if [[ "$var_style" == "assoc" ]]; then
        aa_set "$result_dict_name" "$dest" "1"
    else
        typeset "$dest"="1"
    fi
}

_zerg_process_option() {
    tHead "Processing option '$3'."
    # Process an option that takes a value (cover nargs, actions, etc.)
    local parser_name="$1" def_name="$2" opt_name="$3" index_ref="$4"
    req_zerg_class ZERG_PARSER "$1" || return $?
    req_zerg_class ZERG_ARG_DEF "$2" || return $?
    req_zerg_type argname "$3" || return $?
    req_zerg_type int "$4" || return $?
    req_sv_type array cmdline_args || return $?

    #tMsg 0 "def_name '$def_name' opt_name '$opt_name', cmdline_args '$cmdline_args', index_ref '$index_ref'."

    # Gather info on where to store option value
    local action=$(aa_get -q "$def_name" "action")
    local var_style=$(aa_get -q "$parser_name" "var_style")
    [ "$var_style" ] && var_style="separate"
    local result_dict_name="${parser_name}__results"
    local dest=`_zerg_find_dest $def_name`
    #tMsg 0 "####### def_name '$def_name', option '$opt_name', action '$action', dest '$dest'."

    case "$action" in
        store_true)
            _zerg_store_value $var_style $result_dict_name $dest 1
            return 0 ;;
        store_false)
            _zerg_store_value $var_style $result_dict_name $dest ""
            return 0 ;;
        store_const)
            local val=$(aa_get -q "$def_name" "const")
            _zerg_store_value $var_style $result_dict_name $dest "$val"
            return 0 ;;
        count)
            local -i val
            if [[ "$var_style" == "assoc" ]]; then
                val=$(aa_get -q -d "0" "$result_dict_name" "$dest")
            else
                val="${(P)dest}"
            fi
            val+=1
            tMsg 0 "calling _zerg_store_value '$var_style' '$result_dict_name' '$dest' '$val'."
            _zerg_store_value "$var_style" "$result_dict_name" "$dest" "$val"
            return 0 ;;
        toggle)  # Special for --foo / --no-foo pairs
            local val
            if [[ "$var_style" == "assoc" ]]; then
                val=$(aa_get -q "$result_dict_name" "$dest")
            else
                current="${(P)dest}"
            fi
            [[ -z "$val" ]] && val=1
            _zerg_store_value $var_style $result_dict_name $dest ="$val"
            return 0 ;;

        store|append|extend)  # These actions need argument values
            _zerg_collectArgs $parser_name $opt_name $def_name $index_ref ;;
        *) tMsg 0 "Unknown action '$action' for $opt_name."; return $ZERR_ENUM ;;
    esac
}

_zerg_collectArgs() {
    # Collect the argument's value(s) per nargs. Validate and store.
    # Returns: index_ref

    req_argc 4 4 $# || return $?
    local parser_name=$1 opt_name=$2 def_name=$3 index_ref=$4
    sv_type array $cmdline_args ||  return $?

    # Get items from parser and arg definition
    local action=$(aa_get -q --default "store" "$def_name" "action")
    local nargs=$(aa_get -q --default 1 "$def_name" "nargs")

    local -ax values
    local tot_args=$#cmdline_args

    # nargs can take these values (complicated by case of optional) ???
    #     int
    #     ?   -- one if poss, else default, or ??? const
    #     *   -- all available
    #     +   -- as "*" but must be at least one
    #     ""  -- determined by action

    tMsg 0 "Collecting def $def_name, action $action, nargs $nargs."
    if [ -z $nargs ]; then
        tMsg 0 "nargs nil."
    elif [[ "$nargs" == "?" ]] || [[ $n -eq 0 ]]; then  # Optional arg
        if [[ $((index_ref + 1)) -le $tot_args ]]; then
            if [[ "${cmdline_args[$((index_ref + 1))]}" != -* ]]; then
                (( index_ref++ ))
                values+=("${cmdline_args[$index_ref]}")
            fi
        fi
    elif [[ $nargs == "*" ]] || [[ $nargs == "+" ]]; then   # Variable # of args
        local j=$((index_ref + 1))
        while [[ $j -le $tot_args && "${cmdline_args[$j]}" != -* ]]; do
            values+=("${cmdline_args[$j]}")
            (( j++ ))
        done
        if [[ $nargs == "+" && ${#values} -eq 0 ]]; then
            tMsg 0 "Option '$opt_name' requires at least one argument."
            return $ZERR_ARGC
        fi
        index_ref=$((j - 1))
    elif [[ "$nargs" == "?" ]] || aa_is_int -q "$nargs"; then  # Fixed # args
        local -i nargs=$nargs  # "?" goes to 0.
        local j
        for (( j=1; j<=num_args; j++ )); do
            local curval="${cmdline_args[$j]}"
            if [[ $((index_ref + j)) -le $tot_args ]]; then
                values+=("${cmdline_args[$((index_ref + j))]}")
            else
                tMsg 0 "Option '$opt_name' requires $num_args arguments"
                return $ZERR_ARGC
            fi
        done
        index_ref=$((index_ref + num_args))
    elif [[ ${(U)nargs} == REMAINDER ]]; then               # All remaining args
        tMsg 0 "REMAINDER not yet implemented"  # TODO
    else
        tMsg 0 "Unrecognized nargs value '$nargs'."
        return $ZERR_ENUM
    fi
    _zerg_check_arg_values $def_name || return $?
    _zerg_store_arg_values $def_name $action
}

_zerg_check_arg_values() {
    # Validate value choices, pattern, and type
    local def_name=$1
    req_zerg_class ZERG_ARG_DEF "$def_name" || return $?
    sv_type array $values || return $?

    local fold=$(aa_get -q --default "" "$def_name" "fold")
    local pattern=$(aa_get -q "$def_name" "pattern")
    local type=$(aa_get -q --default "str" "$def_name" "type")

    for value in "${values[@]}"; do
        case "$fold:l" in
            upper) value="$value:u" ;;
            lower) value="$value:l" ;;
            *) ;;
        esac
        local choice=`_zerg_check_choices $value $choices $ignore_case_choices $allow_abbrev_choices`
        if ! [ $choice ]; then
            tMsg 0 "Value not among choices, use $choices."
            return $ZERR_ZERG_TVALUE
        fi
        if ! $(_zerg_check_pattern $value $type $pattern); then
            tMsg 0 "Value does not match pattern for type $type: '$value'."
            return $ZERR_ZERG_TVALUE
        fi
        if ! $(_zerg_check_type $value $type); then
            tMsg 0 "Value does not satisfy type $type: '$value'."
            return $ZERR_ZERG_TVALUE
        fi
    done
}

_zerg_store_arg_values() {  # TODO result_dict_name
    local def_name=$1
    req_zerg_class ZERG_ARG_DEF "$def_name" || return $?
    sv_type array $values || return $?
    local action=$(aa_get -q --default "" "$def_name" "action")
    local dest=`_zerg_find_dest $def_name`
    local var_style=$(aa_get -q --default "" "$def_name" "var_style")

    case "$action" in
        store)
            if [[ ${#values} -eq 1 ]]; then
                if [[ "$var_style" == "assoc" ]]; then
                    aa_set "$result_dict_name" "$dest" "${values[1]}"
                else
                    typeset "$dest"="${values[1]}"
                fi
            else
                if [[ "$var_style" == "assoc" ]]; then
                    aa_set "$result_dict_name" "$dest" "${values[*]}"
                else
                    # TODO Offer int and float?
                    typeset "$dest"="${values[*]}"
                fi
            fi ;;
        append|extend)
            tMsg 0 "APPEND/EXTEND not yet implemented"
            if [[ "$var_style" == "assoc" ]]; then
                aa_set "$result_dict_name" "$dest" "${values[*]}"
            else
                typeset "$dest"="${values[*]}"
            fi ;;
    esac
}


###############################################################################
# For bundled short options that don't take arguments
# TODO Unfinished
#
_zerg_process_flag_option() {
    local parser_name="$1" def_name="$2" opt_name="$3"
    if [[ $#3 -gt 2 ]] && ! aa_get -q "$def_name" "bundle"; then
        tMsg 0 "Found '$opt_name' but bundle is not enabled."
        return $ZERR_BAD_OPTION
    fi
    local action=${${(P)def_name}[action]}
    [[ -z "$action" ]] && action="store"
    case "$action" in
        store_true|store_false|store_const|count|toggle)
            local dummy_array dummy_index
            _zerg_process_option "$parser_name" "$def_name" "$opt_name" dummy_array dummy_index
            return $? ;;
        *)
            tMsg 0 "Option $opt_name cannot take arguments in bundle"
            return $ZERR_BAD_OPTION ;;
    esac
}


###############################################################################
#
zerg_parse() {
    local quiet parse_v
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_parse parser_name [command_line_args...]
    Parse command line arguments using the specified parser (from `zerg_new`).
Options:
    --quiet, --verbose (see also options on `zerg_new`).
Example:
    zerg_parse MYPARSER "$@"
EOF
            return ;;
        -q|--quiet) quiet='-q' ;;
        -v|--verbose) parse_v=1 ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 99 $# || return $?
    local parser_name="$1"
    shift

    # Verify parser exists
    if [[ `sv_type "$parser_name"` != assoc ]]; then
        [ $quiet ] || tMsg 0 "Parser '$parser_name' does not exist"
        return $ZERR_UNDEF
    elif [ parse_v ]; then
        #tMsg 1 "Parser stored as:"`typeset -p $parser_name | sed 's/\[/\n  [/g'`
        #aa_export --lines -f python --sort $parser_name
    fi

    # Get needed parser settings
    local abbr=$(aa_get -q -d "1" "$parser_name" "allow_abbrev")
    local abbrc=$(aa_get -q -d "1" "$parser_name" "allow_abbrev_choices")
    local ic=$(aa_get -q -d "1" "$parser_name" "ignore_case")
    local icc=$(aa_get -q -d "1" "$parser_name" "ignore_case_choices")
    local var_style=$(aa_get -q -d "separate" "$parser_name" "var_style")

    # Get names for defined arguments (including aliases)
    local all_arg_names=${${(P)parser_name}[all_arg_names]}
    #tMsg 0 "all_arg_names: $all_arg_names."
    if [[ -z "$all_arg_names" ]]; then
        [ $quiet ] || tMsg 0 "No arguments registered in parser '$parser_name'."
        return $ZERR_UNDEF
    fi

    #tMsg 0 "Args as is: '$@'."
    local -a cmdline_args=("$@")  # Inherits to called functions!
    #tMsg 0 "Tokens to parse: $cmdline_args."

    # Initialize result storage
    if [[ "$var_style" == "assoc" ]]; then
        local result_dict_name="${parser_name}__results"
        typeset -xA "$result_dict_name"
    fi

    # Set defaults
    tHead "Setting defaults early"
    local all_def_names="${${(P)parser_name}[all_def_names]}"
    tMsg 0 "all_def_names: '$all_def_names'."
    for def_name in "${(z)all_def_names}"; do
        #tMsg 0 "    def_name: '$def_name'."
        local default_val=$(aa_get -q "$def_name" "default")
        local dest=`_zerg_find_dest $def_name`

        if [[ -n "$default_val" && -n "$dest" ]]; then
            if [[ "$var_style" == "assoc" ]]; then
                aa_set $result_dict_name "$dest" "$default_val"
            else
                typeset "$dest"="$default_val"
            fi
        fi
    done

    # Parse command line arguments
    local -a positional_args
    local -A provided_dests
    local -i i=1
    local ic=""
    [ `aa_get $parser_name "ignore_case"` ] && ic="-i"

    tHead "Parsing '$cmdline_args' (${#cmdline_args} items)."
    while [[ $i -le ${#cmdline_args} ]]; do
        local arg="${cmdline_args[i]}"
        tHead "Parsing cmdline option #$i: '$arg'"
        case "$arg" in
            --help|-h)
                _zerg_help $parser_name
                return ;;
            --version)
                _zerg_version $parser_name
                return ;;
            --*)
                # Long option
                local opt_name="$arg"
                local def_name=`_zerg_find_arg_def $parser_name $opt_name $ic $abbr`
                #tMsg 0 " rc $?, Argdef at '$def_name'."
                if [ -z $def_name ]; then
                    tMsg 0 "Failed _zerg_find_arg_def."
                    return $ZERR_BAD_OPTION
                fi
                #tMsg 0 "  option '$arg', def_name '$def_name', opt_name '$opt_name'."
                if ! _zerg_process_option "$parser_name" "$def_name" "$opt_name"  $i; then
                    return 89  # TODO
                fi
                # Mark as provided ???
                local dest=`_zerg_find_dest $def_name`
                [[ -n "$dest" ]] && provided_dests["$dest"]=1 ;;
            -*)
                # Short option(s)
                local opt_string="${arg#-}"
                local j=1

                while [[ $j -le ${#opt_string} ]]; do
                    local short_opt="-${opt_string[j]}"
                    local def_name=""
                    local def_name=$(_zerg_find_arg_def $parser_name $short_opt $ic $abbr)
                    if [ -z $def_name ]; then
                        tMsg 0 "Could not find arg def for short opt $short_opt."
                        return $ZERR_BAD_OPTION
                    fi

                    # Check if this is the last option in the bundle
                    if [[ $j -eq ${#opt_string} ]]; then # Last can take values
                        _zerg_process_option "$parser_name" "$def_name" "$short_opt" $i || return $?
                    else  # Non-last options must be flags
                        _zerg_process_flag_option "$parser_name" "$matched_def" "$short_opt" || return $?
                    fi

                    # Mark as provided
                    local dest=`_zerg_find_dest $def_name`
                    [[ -n "$dest" ]] && provided_dests["$dest"]=1

                    (( j++ ))
                done ;;
            *) break;  # positional_args+=("$arg") ;;
        esac
        (( i++ ))
    done

    # Check for missing required arguments
    tMsg 0 "Checking for required dests (TODO)"
    local reqs=`aa_get $parser_name required_arg_names`
    for req in "${reqs[@]}"; do
        [ -z $req ] && continue
        if [[ -z "${provided_dests[$req]}" ]]; then
            [ $quiet ] || tMsg 0 "Missing required argument: '$req'"
            return $ZERR_BAD_OPTION
        fi
    done

    # TODO: Handle positional arguments explicitly??
    if [[ ${#positional_args} -gt 0 ]]; then
        [ $quiet ] || tMsg 1 "Positional arguments not yet supported, use $@."
    fi

    return 0
}

_zerg_find_dest() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: _zerg_find_dest argdefname
    Given the name of an associative array that represents a ZERG_ARG_DEF object,
    echo the name of where to store that argument's value. IF the argdef
    set an explicit --dest value, that is returned; otherwise the argument's
    reference name is extracted from the assoc name and returned.
Example: This returns "ignore_case" unless it was overridden by --dest:
    _zerg_find_dest MYPARSER__ignore_case

Options:
    --quiet, --verbose (see also options on `zerg_new`).
Example:
    zerg_parse MYPARSER "$@"
EOF
            return ;;
        -q|--quiet) quiet='-q' ;;
        *) tMsg 0 "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_zerg_class ZERG_ARG_DEF "$1" || return $ZERR_ZERG_TVALUE
    local dest=`aa_get $1 dest`
    [ -n "$dest" ] || dest=${1#*__}
    echo $dest
}

_zerg_find_arg_def() {
    # Find the actual variable storing this option, and return that name.
    # Find despite abbreviations, aliases, case, etc.
    # TODO Add ignore-hyphens support via zerg_opt_to_var().
    local parser_name=$1 opt_given=$2  # with hyphens
    local ic=$3 abbrev=$4
    req_zerg_class ZERG_PARSER "$1" || return $?
    is_argname "$opt_given" || return $?

    local def_name=${${(P)parser_name}[$opt_given]}
    if [ -n $def_name ]; then
        echo "$def_name"
        return 0
    fi
    if [[ $abbrev -eq 1 ]]; then
        tMsg 0 "Trying abbreviations"
        local def_name=`aa_find_key $ic $parser_name "$opt_given"`
        case $? in
            1) echo `aa_get $parser_name $def_name`; return 0 ;;
            0) tMsg 0 "Unknown option: '$opt_given'." ;;
            2) tMsg 0 "Ambiguous option: '$opt_given'." ;;
        esac
    fi
    return $ZERR_BAD_OPTION
}

# Detect if being run directly vs sourced
if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
    echo "${(%):-%x} is a library file. Source it, don't execute it."
    echo "Usage: source ${(%):-%x}"
fi

#!/bin/zsh
# Main argument parsing functions for zerg (zsh argument parser)
#
# TODO Add export to zsh case form, zsh autocomplete?

if ! [[ $ZERG_SETUP == 1 ]] || [[ "$1" == "-f" ]]; then
    warn "Source zerg_setup.sh first." >&2
    return $ZERR_UNDEF
fi


###############################################################################
_zerg_check_choices() {
    # Return normalized choice value
    local value="$1" choices="$2" ignore_case_choices="$3" abbrc="$4"

    [[ -n "$choices" ]] || return 0
    if [ $ignore_case_choices ]; then
        [[ " ${choices:l} " == *" ${value:l} "* ]] && return 0
    else
        [[ " ${choices} " == *" ${value} "* ]] && return 0
    fi

    # Build choices lookup
    local -A choices_map; local choice
    for choice in ${(z)choices}; do
        choices_map[$choice]="$choice"
    done

    # Try abbreviation/case-insensitive matching if enabled
    if [ "$abbrc" || "$ignore_case_choices" ]; then
        local icc_opt
        [ -n "$ignore_case_choices" ] && icc_opt=" -i"
        local found_key=`aa_find_key -q$icc_opt choices_map "$value"`
        local result=$?
        case $result in
            0) echo "$found_key"; return 0 ;;
            1) warn "'$value' not recognized. Choices: $choices."; return $ZERR_ENUM ;;
            2) warn "'$value' is ambiguous. Choices: $choices."; return $ZERR_ENUM ;;
        esac
    else
        warn "'$value' is not a valid choice. Choices: $choices."; return $ZERR_ENUM
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
                warn "Token '$token' does not match pattern: $pattern"
                return 1
            fi
        done
    elif ! [[ "$value" =~ $pattern ]]; then
        warn "'$value' does not match pattern: $pattern"
        return 1
    fi
}

_zerg_check_type() {
    local value="$1" type="$2"
    if ! aa_has zerg_types "$type"; then
        warn "Unknown type '$type'"
        return $ZERR_ENUM
    elif ! is_of_zerg_type $type "$value"; then
        warn "Argument : Value '$value' does not satisfy type '$type'"
        return $ZERR_ZTYPE_VALUE
    fi
}


###############################################################################
# Help support
#
_zerg_help() {
    # TODO Implement description_breaks. wrap via fmt? $PAGER?
    is_of_zerg_class ZERG_PARSER "$1" || return $?
    local help_file="${${(P)1}[help_file]}"
    if [ $help_file ]; then
        if ! [ -f "$help_file" ]; then
            warn "Help file '$help_file' not found."; return 1
        fi
        local help_tool="${${(P)1}[help_tool]}"
        is_command -q "$help_tool" || help_tool="$PAGER"
        [ -n "$help_tool" ] || help_tool="less"
        is_command -q "$help_tool" || help_tool="less"
        cat $help_file | $help_tool
    else
        print ${${(P)1}[description]}
        print "Options:"
        _zerg_usage $1
    fi
}

_zerg_version() {
    is_of_zerg_class ZERG_PARSER "$1" || return $?
    local vdef_name=`get_argdef_name $1 "version"` || return $?
    print "Version = "`aa_get -- "$1" "--version"`
}

_zerg_usage() {
    # Gather and display options and help strings.
    local parser_name="$1"
    local adns="${(P)parser_name)[all_def_names]}"
    for adn in ${(zi)adns}; do
        local help=${${(Pqq)adn}[help]}
        local action=${${(Pqq)adn}[action]}
        local metavar=""
        if [[ $action == (store|append|extend) ]]; then
            metavar="${${(Pqq)adn}[metavar]}"
            [ $metavar ] || metavar=" "`zerg_opt_to_var -- $metavar`
        fi
        printf "    %-12s %s%s\n" $key $metavar $help
        local choices=${${(Pqq)adn}[choices]}
        [ -n "$choices" ] ** print "    ($choices)\n"
    done
}


###############################################################################
# Result storage support
#
_zerg_clear_values() {
    local parser_name="$1" result_dict="$2"
    #warn "parser $parser_name, result_dict $result_dict."
    is_of_zerg_class ZERG_PARSER $parser_name
    local var_style=`aa_get $parser_name var_style`
    if [[ "$var_style" == assoc ]]; then
        req_zerg_type ident "$result_dict" || return $ZERR_ZTYPE_VALUE
        unset $result_dict
        typeset -Ag $result_dict
    else
        local def_names=`aa_get $parser_name all_def_names`
        for def_name in ${(z)def_names}; do
            local result_var_name=${def_name#*__}
            unset $result_var_name
        done
    fi
}

_zerg_store_value() {
    # Store the final value of an option, given dest, var_style, etc.
    local var_style="$1" result_dict="$2" dest="$3" value="$4"
    #warn "Store [$var_style, dict $result_dict], dest $dest, val $value"
    req_argc 4 4 $# || return $?
    if [[ "$var_style" == "assoc" ]]; then
        aa_set "$result_dict" "$dest" "$value" || warn "aa_set failed"
    else
        typeset "$dest"=$value
    fi
}

_zerg_get_value() {
    local var_style="$1" result_dict="$2" dest="$3"
    local value
    #warn "var_style=$var_style result_dict=$result_dict dest=$dest."
    req_argc 3 3 $# || return $?
    if [[ "$var_style" == "assoc" ]]; then
        aa_get -q "$result_dict" "$dest"
    else
        echo "${(P)dest}"
    fi
}

_zerg_store_arg_values() {  # TODO result_dict
    local def_name=$1
    is_of_zerg_class ZERG_ARG_DEF "$def_name" || return $?
    req_zsh_type array "values" || return $?
    local action=$(aa_get -q --default "" "$def_name" "action")
    local dest=`_zerg_find_dest $def_name`
    local var_style=$(aa_get -q --default "" "$def_name" "var_style")

    case "$action" in
        store)
            if [[ ${#values} -eq 1 ]]; then
                if [[ "$var_style" == "assoc" ]]; then
                    aa_set "$result_dict" "$dest" "${values[1]}"
                else
                    typeset "$dest"="${values[1]}"
                fi
            else
                if [[ "$var_style" == "assoc" ]]; then
                    aa_set "$result_dict" "$dest" "${values[*]}"
                else
                    # TODO Offer int and float?
                    typeset "$dest"="${values[*]}"
                fi
            fi ;;
        append|extend)
            warn "APPEND/EXTEND not yet implemented"
            if [[ "$var_style" == "assoc" ]]; then
                aa_set "$result_dict" "$dest" "${values[*]}"
            else
                typeset "$dest"="${values[*]}"
            fi ;;
    esac
}


###############################################################################
#
_zerg_process_option() {
    #tHead "Processing option '$3'."
    # Process an option that takes a value (cover nargs, actions, etc.)
    local parser_name="$1" def_name="$2" opt_name="$3" index_ref="$4"
    is_of_zerg_class ZERG_PARSER "$1" || return $?
    is_of_zerg_class ZERG_ARG_DEF "$2" || return $?
    is_argname -- "$3" || return $?
    is_of_zerg_type int "$4" || return $?
    is_of_zsh_type array "cmdline_args" || return $?

    #warn "def_name '$def_name' opt_name '$opt_name', cmdline_args '$cmdline_args', index_ref '$index_ref'."

    # Gather info on where to store option value
    local action=$(aa_get -q "$def_name" "action")
    local var_style=$(aa_get -q $parser_name var_style)
    [ "$var_style" ] || var_style="separate"
    local result_dict=`get_argdef_name $parser_name "results"`
    local dest=`_zerg_find_dest $def_name`
    #warn "####### def_name '$def_name', option '$opt_name', action '$action', dest '$dest'."

    case "$action" in
        store_true)
            _zerg_store_value $var_style $result_dict $dest 1
            return 0 ;;
        store_false)
            _zerg_store_value $var_style $result_dict $dest ""
            return 0 ;;
        store_const)
            local val=$(aa_get -q $def_name "const")
            _zerg_store_value $var_style $result_dict $dest "$val"
            return 0 ;;
        count)
            local val=`_zerg_get_value $var_style $result_dict $dest`
            let val="$val + 1"
            _zerg_store_value $var_style $result_dict $dest "$val"
            return 0 ;;
        toggle)  # Special for --foo / --no-foo pairs
            local val
            if [[ "$var_style" == "assoc" ]]; then
                val=$(aa_get -q $result_dict "$dest")
            else
                current="${(P)dest}"
            fi
            [[ -z "$val" ]] && val=1
            _zerg_store_value $var_style $result_dict $dest "$val"
            return 0 ;;

        store|append|extend)  # These actions need argument values
            _zerg_collectArgs $parser_name $opt_name $def_name $index_ref ;;
        *) warn "Unknown action '$action' for $opt_name."; return $ZERR_ENUM ;;
    esac
}

_zerg_collectArgs() {
    # Collect the argument's value(s) per nargs. Validate and store.
    # Returns: index_ref

    req_argc 4 4 $# || return $?
    local parser_name=$1 opt_name=$2 def_name=$3 index_ref=$4
    # Expects: (array) cmdline_args inherited
    req_zsh_type array "cmdline_args" ||  return $?
    local tot_args=$#cmdline_args

    # Get items from parser and arg definition
    local action=$(aa_get -q --default "store" "$def_name" "action")
    local nargs=$(aa_get -q --default 1 "$def_name" "nargs")
    local -ax values

    # nargs can take these values (complicated by case of optional) ???
    #     int
    #     ?   -- one if poss, else default, or ??? const
    #     *   -- all available
    #     +   -- as "*" but must be at least one
    #     ""  -- determined by action

    #warn "Collecting def $def_name, action $action, nargs $nargs."
    if [ -z "$nargs" ]; then
        warn "nargs nil."
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
            warn "Option '$opt_name' requires at least one argument."
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
                warn "Option '$opt_name' requires $num_args arguments"
                return $ZERR_ARGC
            fi
        done
        index_ref=$((index_ref + num_args))
    elif [[ ${(U)nargs} == REMAINDER ]]; then               # All remaining args
        warn "REMAINDER not yet implemented"  # TODO
    else
        warn "Unrecognized nargs value '$nargs' for $opt_name."
        return $ZERR_ENUM
    fi
    # Array 'values' just inherits
    _zerg_check_arg_values $def_name $opt_name || return $?
    _zerg_store_arg_values $def_name $action
}

_zerg_check_arg_values() {
    # Validate value choices, pattern, and type
    local def_name=$1 arg_given=$2
    is_of_zerg_class ZERG_ARG_DEF "$def_name" || return $?
    if ! is_of_zsh_type array "values"; then
        warn "_zerg_check_arg_values: values is not an array."
        return $ZERR_MISSING_VAR
    fi

    [ -v icc ] || return $ZERR_MISSING_VAR

    local fold=$(aa_get -q --default "" "$def_name" "fold"):l
    local pattern=$(aa_get -q "$def_name" "pattern")
    local type=$(aa_get -q --default "str" "$def_name" "type")
    local choices=$(aa_get -q "$def_name" "choices")
    #warn "def $def_name, arg_given $arg_given, type $type, values $values."
    for value in "${values[@]}"; do
        case "$fold" in
            upper) value="$value:u" ;;
            lower) value="$value:l" ;;
            *) ;;
        esac
        if [[ $choices ]]; then
            local choice=`_zerg_check_choices "$value" "$choices" $icc $allow_abbrev_choices`
            local rc=$?
            if ! [ $rc ]; then
                warn "$opt_name value '$value' is not among choices ($choices)."
                return $ZERR_ZTYPE_VALUE
            fi
            value=$choice
        fi
        if ! $(_zerg_check_pattern "$value" "$type" $pattern); then
            warn "$opt_name value '$value' does not match pattern for type '$type'."
            return $ZERR_ZTYPE_VALUE
        fi
        if [ $type ] && ! $(_zerg_check_type "$value" "$type"); then
            warn "$opt_name value '$value' does not satisfy type '$type'."
            return $ZERR_ZTYPE_VALUE
        fi
    done
}

###############################################################################
# For bundled short options that don't take arguments
# TODO Unfinished
#
_zerg_process_flag_option() {
    local parser_name="$1" def_name="$2" opt_name="$3"
    if [[ $#3 -gt 2 ]] && ! aa_get -q "$def_name" "bundle"; then
        warn "Found '$opt_name' but bundle is not enabled."
        return $ZERR_BAD_OPTION
    fi
    local action=${${(P)def_name}[action]}
    [[ -z "$action" ]] && action="store"
    warn "FLAG option $opt_name, action $action."
    case "$action" in
        store_true|store_false|store_const|count|toggle)
            local dummy_array dummy_index
            _zerg_process_option "$parser_name" "$def_name" "$opt_name" dummy_array dummy_index
            return $? ;;
        *)
            warn "Option $opt_name cannot take arguments in bundle"
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
        *) warn "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 1 99 $# || return $?
    local parser_name="$1"
    shift

    # Verify parser exists
    if [[ `zsh_type "$parser_name"` != assoc ]]; then
        [ $quiet ] || warn "Parser '$parser_name' does not exist"
        return $ZERR_UNDEF
    elif [ parse_v ]; then
        #warn 1 "Parser stored as:"`typeset -p $parser_name | sed 's/\[/\n  [/g'`
        #aa_export --lines -f python --sort $parser_name
    fi

    # Get needed parser settings
    local abbr=$(aa_get -q -d "1" "$parser_name" "allow_abbrev")
    local abbrc=$(aa_get -q -d "1" "$parser_name" "allow_abbrev_choices")
    local ignore_case=$(aa_get -q -d "1" "$parser_name" "ignore_case")
    local icc=$(aa_get -q -d "1" "$parser_name" "ignore_case_choices")
    local var_style=$(aa_get -q -d "separate" "$parser_name" "var_style")
    local result_dict=`get_argdef_name $parser_name "results"`

    # Initialize result storage
    #warn "*** par $parser_name, res $result_dict."
    _zerg_clear_values $parser_name $result_dict


    # Get names for defined arguments (including aliases)
    local all_arg_names=${${(P)parser_name}[all_arg_names]}
    #warn "all_arg_names: $all_arg_names."
    if [[ -z "$all_arg_names" ]]; then
        [ $quiet ] || warn "No arguments registered in parser '$parser_name'."
        return $ZERR_UNDEF
    fi

    #warn "Args as is: '$@'."
    local -a cmdline_args=("$@")  # Inherits to called functions!
    #warn "Tokens to parse: $cmdline_args."

    # Set defaults
    #tHead "Setting defaults early"
    local all_def_names="${${(P)parser_name}[all_def_names]}"
    #warn "all_def_names: '$all_def_names'."
    for def_name in "${(z)all_def_names}"; do
        #warn "    def_name: '$def_name'."
        local default_val=$(aa_get -q "$def_name" "default")
        local dest=`_zerg_find_dest $def_name`

        ### TODO Switch to use store function
        if [[ -n "$default_val" && -n "$dest" ]]; then
            #_zerg_store_value $var_style $result_dict $dest "$default_val"
            if [[ "$var_style" == "assoc" ]]; then
                aa_set "$result_dict" "$dest" "$default_val"
            else
                typeset "$dest"="$default_val"
            fi
        fi
    done

    # Parse command line arguments
    local -a positional_args
    local -A provided_dests
    local -i i=1
    local ignore_case=""
    [ `aa_get $parser_name "ignore_case"` ] && ignore_case="-i"

    #tHead "Parsing '$cmdline_args' ($#cmdline_args items)."
    while [[ $i -le $#cmdline_args ]]; do
        local arg="$cmdline_args[i]"
        #tHead "Parsing cmdline option #$i: '$arg'"
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
                local def_name=`_zerg_find_arg_def $parser_name $opt_name $ignore_case $abbr`
                #warn " rc $?, Argdef at '$def_name'."
                if [ -z "$def_name" ]; then
                    warn "Failed _zerg_find_arg_def for $parser_name option '$opt_name', def '$def_name'."
                    return $ZERR_BAD_OPTION
                fi
                #warn "  option '$arg', def_name '$def_name', opt_name '$opt_name'."
                _zerg_process_option "$parser_name" "$def_name" "$opt_name" $i
                [ $? ] || return $?
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
                    local def_name=$(_zerg_find_arg_def $parser_name $short_opt $ignore_case $abbr)
                    if [ -z "$def_name" ]; then
                        warn "Could not find arg def for short opt $short_opt."
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
    #warn "Checking for required dests (TODO)"
    local reqs=`aa_get $parser_name required_arg_names`
    for req in "${reqs[@]}"; do
        [ -z "$req" ] && continue
        if [[ -z "${provided_dests[$req]}" ]]; then
            [ $quiet ] || warn "Missing required argument: '$req'"
            return $ZERR_BAD_OPTION
        fi
    done

    # TODO: Handle positional arguments explicitly??
    if [[ ${#positional_args} -gt 0 ]]; then
        [ $quiet ] || warn 1 "Positional arguments not yet supported, use $@."
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
        *) warn "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    is_of_zerg_class ZERG_ARG_DEF "$1" || return $ZERR_ZTYPE_VALUE
    local dest=`aa_get -q $1 dest`
    [ -n "$dest" ] || dest=${1#*__}
    echo $dest
}

_zerg_find_arg_def() {
    local abbrev ignore_case quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: _zerg_find_arg_def [-q] [-i] parser_name option_name
    Find the actual variable storing the option (passed with hyphens),
    and return the name of that variable.
    Find despite abbreviations, aliases, case, etc.
To do: Add ignore-hyphens support?
EOF
            return ;;
        --abbrev) abbrev=1 ;;
        -i|--ignore-case) ignore_case="-i" ;;
        -q|--quiet) quiet="-q" ;;
        --) shift; break ;;
        *) warn "Unrecognized option '$1'."; return $ZERR_BAD_OPTION ;;
      esac
      shift
    done

    local parser_name=$1 opt_given=$2  # with hyphens
    is_of_zerg_class ZERG_PARSER "$1" || return $?
    is_argname -- "$opt_given" || return $?

    # Try for exact/full match first
    local def_name=`aa_get $parser_name $opt_given`
    if [ -n "$def_name" ]; then
        echo "$def_name"
        return 0
    fi
    if [[ $abbrev -eq 1 ]]; then
        warn "Trying abbreviations"
        local def_name=`aa_find_key $ignore_case $parser_name $opt_given`
        case $? in
            0) echo `aa_get $parser_name $def_name`; return 0 ;;
            1) warn "Unknown option: '$opt_given'." ;;
            2) warn "Ambiguous option: '$opt_given'." ;;
        esac
    fi
    return $ZERR_BAD_OPTION
}

# Detect if being run directly vs sourced
if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
    warn "${(%):-%x} is a library file. Source it, don't execute it."
    warn "Usage: source ${(%):-%x}"
fi

#!/usr/bin/env zsh

###############################################################################
# Generate zsh completion function for a given zerg parser
#
# Usage: zerg_generate_completion PARSER_NAME [OUTPUT_FILE]
#
# Creates a zsh completion function based on the parser's option definitions.
# The generated completion respects type information, providing appropriate
# completers for paths, PIDs, choices, shell entities, etc.
#
# Arguments:
#   PARSER_NAME  - Name of the zerg parser object
#   OUTPUT_FILE  - Optional output path (default: _${PARSER_NAME})
#
# Returns:
#   0            - Success
#   $ZERR_NO_CLASS - Parser doesn't exist
#
zerg_generate_completion() {
    local parser_name="$1"
    local output_file="${2:-_${parser_name}}"

    if ! is_of_zerg_class ZERG_PARSER "$parser_name"; then
        warn error "No such parser: $parser_name"
        return $ZERR_NO_CLASS
    fi

    local comp_func="_comp_${parser_name}"

    {
        print "#compdef ${parser_name}"
        print ""
        print "${comp_func}() {"
        print "  local -a args"
        print "  args=("

        _zerg_comp_generate_option_specs "$parser_name"

        print "  )"
        print "  _arguments -s -S \$args"
        print "}"
        print ""
        print "${comp_func} \"\$@\""
    } > "$output_file"

    warn info "Generated completion: $output_file"
}

###############################################################################
# Generate option specifications for all options in a parser
#
_zerg_comp_generate_option_specs() {
    local parser_name="$1"
    local all_names="${${parser_name}[all_def_names]}"
    local opt_ref

    for opt_ref in ${=all_names}; do
        _zerg_comp_emit_option_spec "$parser_name" "$opt_ref"
    done
}

###############################################################################
# Emit a single option's completion specification
#
_zerg_comp_emit_option_spec() {
    local parser_name="$1"
    local opt_ref="$2"

    local opt_type="${${opt_ref}[type]}"
    local opt_help="${${opt_ref}[help]}"
    local arg_names="${${opt_ref}[arg_names]}"
    local opt_choices comp_action

    local -a name_parts type_parts
    name_parts=( ${=arg_names} )
    type_parts=( ${=opt_type} )

    # Determine completion action based on type
    local base_type="${type_parts[1]}"

    case "$base_type" in
        path)
            # Check for path flags
            if [[ " ${type_parts[*]} " == *" -d "* ]]; then
                comp_action=":directory:_directories"
            elif [[ " ${type_parts[*]} " == *" -r "* ]]; then
                comp_action=":readable file:_files -g '*(-r)'"
            elif [[ " ${type_parts[*]} " == *" -w "* ]]; then
                comp_action=":writable file:_files -g '*(-w)'"
            elif [[ " ${type_parts[*]} " == *" -x "* ]]; then
                comp_action=":executable file:_files -g '*(-*)'"
            else
                comp_action=":file:_files"
            fi ;;
        dir)
            comp_action=":directory:_directories" ;;
        file)
            comp_action=":file:_files -g '*(-.)'  # regular files only" ;;
        pid)
            comp_action=":pid:_pids" ;;
        choice)
            opt_choices="${${opt_ref}[choices]}"
            comp_action=":choice:(${=opt_choices})" ;;

        # Numeric types
        int|anyint|binint|hexint|octint|unsigned)
            comp_action=":integer:" ;;
        uint|uinteger)
            comp_action=":unsigned integer:" ;;
        float|epoch|logprob|prob)
            comp_action=":float:" ;;
        ufloat)
            comp_action=":unsigned float:" ;;

        # String types with special completion
        locale)
            comp_action=":locale:_locales" ;;
        encoding)
            comp_action=":encoding:_encodings" ;;
        url)
            comp_action=":URL:_urls" ;;

        # Shell-specific types
        alias)
            comp_action=":alias:_aliases" ;;
        builtin)
            comp_action=":builtin:_builtins" ;;
        function)
            comp_action=":function:_functions" ;;
        cmdname)
            comp_action=":command:_command_names" ;;
        varname)
            comp_action=":variable:_parameters" ;;

        # Date/time types
        date|datetime|time|duration)
            comp_action=":${base_type}:" ;;

        # Boolean
        bool)
            comp_action=":boolean:(true false)" ;;

        # Actions without arguments
        store_true|store_false|count)
            comp_action="" ;;

        # Everything else gets generic value completion
        *)
            comp_action=":value:" ;;
    esac

    # Build spec with all option names
    if [[ ${#name_parts} -eq 1 ]]; then
        print "    '${name_parts[1]}[${opt_help}]${comp_action}'"
    else
        # Multiple names (long + short): use grouped syntax
        local names="${(j:,:)name_parts}"
        print "    '(${names})'{${names}}'[${opt_help}]${comp_action}'"
    fi
}

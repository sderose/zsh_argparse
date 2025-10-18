#!/bin/zsh
# add_argument function - add an argument definition to a parser
#
# Usage: add_argument parser_name "option_names" [options...]
#   parser_name: name of the parser to add to
#   option_names: space-separated list of aliases (first is canonical)
#   options: --type, --default, --help, etc.

add_argument() {
    if [[ $# -lt 2 ]]; then
        tMsg 0 "add_argument: Expected at least 2 arguments (parser_name option_names)"
        return 99
    fi

    local parser_name="$1"
    local option_names_str="$2"
    shift 2

    # Verify parser exists
    if ! typeset -p "$parser_name" &>/dev/null; then
        tMsg 0 "add_argument: Parser '$parser_name' does not exist. Use zsh_make_argparser first."
        return 98
    fi

    local -A pargs
    local -a option_names
    option_names=(${=option_names_str})  # split on whitespace
    local force_overwrite=0

    if [[ ${#option_names} -eq 0 ]]; then
        tMsg 0 "add_argument: No option names provided"
        return 97
    fi

    # Validate that all option names start with hyphen
    for name in "${option_names[@]}"; do
        if [[ "$name" != -* ]]; then
            tMsg 0 "add_argument: Option name must start with hyphen: '$name'"
            return 96
        fi
    done

    local lcTypeExpr="^--(${(j:|:)aa_types})\$"
    local lcActionExpr="^--(${(j:|:)aa_actions})\$"

    # Parse configuration options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            # Type as option or shorthand
            --type|-t)
                pargs[type]="$2"
                shift 2 ;;
            ($~lcTypeExpr)
                pargs[type]="${1#--}"
                shift ;;

            # Action as option or shorthand
            --action|-a)
                pargs[action]="$2"
                shift 2 ;;
            ($~lcActionExpr)
                pargs[action]="${1#--}"
                shift ;;

            # Convenient combo shorthands
            --flag)
                pargs[type]="BOOL"
                pargs[action]="STORE_TRUE"
                shift ;;
            --counter)
                pargs[type]="INT"
                pargs[action]="COUNT"
                shift ;;
            --toggle)
                pargs[type]="BOOL"
                pargs[reset]="1"
                shift ;;

            # Other options
            --choices|-c)
                pargs[choices]="$2"
                shift 2 ;;
            --const|-k)
                pargs[const]="$2"
                shift 2 ;;
            --default|-d)
                pargs[default]="$2"
                shift 2 ;;
            --dest|-v)
                pargs[dest]="$2"
                shift 2 ;;
            --fold)
                pargs[fold]="$2"
                shift 2 ;;
            --force)
                force_overwrite=1
                shift ;;
            --format)
                pargs[format]="$2"
                shift 2 ;;
            --help|-h)
                pargs[help]="$2"
                shift 2 ;;
            --nargs|-n)
                pargs[nargs]="$2"
                shift 2 ;;
            --pattern|-x)
                pargs[pattern]="$2"
                shift 2 ;;
            --required|-r)
                pargs[required]="1"
                shift ;;
            --reset)
                pargs[reset]="1"
                shift ;;
            -*)
                tMsg 0 "add_argument: Unknown option: $1"
                return 95 ;;
            *)
                tMsg 0 "add_argument: Unexpected positional argument: $1"
                return 94 ;;
        esac
    done

    # Apply defaults
    [[ -z "${pargs[type]}" ]] && pargs[type]="STR"
    [[ -z "${pargs[action]}" ]] && pargs[action]="STORE"
    [[ -z "${pargs[fold]}" ]] && pargs[fold]="NONE"

    # First option name is canonical (strip leading dashes)
    local canonical="${option_names[1]}"
    canonical="${canonical#-#}"

    # Destination variable defaults to canonical name
    [[ -z "${pargs[dest]}" ]] && pargs[dest]="$canonical"

    # Validate type
    if [[ ! " ${aa_types[@]} " =~ " ${pargs[type]} " ]]; then
        tMsg 0 "add_argument: Invalid type: ${pargs[type]}"
        return 93
    fi

    # Validate action
    if [[ ! " ${aa_actions[@]} " =~ " ${pargs[action]} " ]]; then
        tMsg 0 "add_argument: Invalid action: ${pargs[action]}"
        return 92
    fi

    # Check for existing definition
    local def_name="${parser_name}__${canonical}"
    if typeset -p "$def_name" &>/dev/null && [[ $force_overwrite -eq 0 ]]; then
        tMsg 0 "add_argument: Definition '$canonical' already exists in $parser_name. Use --force to overwrite."
        return 91
    fi

    # Create hidden definition assoc
    typeset -ghA "$def_name"

    # Store all metadata in the definition assoc
    aa_set "$def_name" "type" "${pargs[type]}"
    aa_set "$def_name" "action" "${pargs[action]}"
    aa_set "$def_name" "dest" "${pargs[dest]}"
    aa_set "$def_name" "fold" "${pargs[fold]}"
    aa_set "$def_name" "aliases" "$option_names_str"

    for key in required default help choices nargs const format pattern reset; do
        if [[ -n "${pargs[$key]}" ]]; then
            aa_set "$def_name" "$key" "${pargs[$key]}"
        fi
    done

    # Register all aliases in the parser (they all point to same def_name)
    for name in "${option_names[@]}"; do
        aa_set "$parser_name" "$name" "$def_name"
    done

    # Add canonical name to __registered_args list
    local existing_list=$(aa_get -q "$parser_name" "__registered_args")
    if [[ -n "$existing_list" ]]; then
        aa_set "$parser_name" "__registered_args" "$existing_list $canonical"
    else
        aa_set "$parser_name" "__registered_args" "$canonical"
    fi

    return 0
}

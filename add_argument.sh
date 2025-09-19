#!/bin/zsh
# add_argument function - zsh-like syntax: options -- option_names

add_argument() {
    local -A pargs
    local refname="" option_names=()
    local force_overwrite=0
    local i=1
    local separator_found=0

    # First pass: parse configuration options until we hit the separator
    while [[ $i -le $# ]]; do
        local arg="${@[i]}"

        if [[ "$arg" == "--" ]]; then
            separator_found=1
            (( i++ ))
            break
        fi

        case "$arg" in
            --refname)
                (( i++ ))
                refname="${@[i]}"
                ;;
            --reset) pargs[reset]="1" ;;
            # Type shorthands
            --int) pargs[type]="INT" ;;
            --hexint) pargs[type]="HEXINT" ;;
            --octint) pargs[type]="OCTINT" ;;
            --anyint) pargs[type]="ANYINT" ;;
            --float) pargs[type]="FLOAT" ;;
            --bool) pargs[type]="BOOL" ;;
            --str) pargs[type]="STR" ;;
            --token) pargs[type]="TOKEN" ;;
            --char) pargs[type]="CHAR" ;;
            --regex) pargs[type]="REGEX" ;;
            --path) pargs[type]="PATH" ;;
            --url) pargs[type]="URL" ;;
            --date) pargs[type]="DATE" ;;
            --time) pargs[type]="TIME" ;;
            --datetime) pargs[type]="DATETIME" ;;
            # Action shorthands
            --store) pargs[action]="STORE" ;;
            --store-true) pargs[action]="STORE_TRUE" ;;
            --store-false) pargs[action]="STORE_FALSE" ;;
            --store-const) pargs[action]="STORE_CONST" ;;
            --append) pargs[action]="APPEND" ;;
            --append-const) pargs[action]="APPEND_CONST" ;;
            --count) pargs[action]="COUNT" ;;
            --help-action) pargs[action]="HELP" ;;
            --version) pargs[action]="VERSION" ;;
            # Convenient combo shorthands
            --flag) pargs[type]="BOOL"; pargs[action]="STORE_TRUE" ;;
            --counter) pargs[type]="INT"; pargs[action]="COUNT" ;;
            --toggle) pargs[type]="BOOL"; pargs[reset]="1" ;;
            --force) force_overwrite=1 ;;
            --type|-t)
                (( i++ ))
                pargs[type]="${@[i]}"
                ;;
            --action|-a)
                (( i++ ))
                pargs[action]="${@[i]}"
                ;;
            --required|-r) pargs[required]="1" ;;
            --default|-d)
                (( i++ ))
                pargs[default]="${@[i]}"
                ;;
            --help|-h)
                (( i++ ))
                pargs[help]="${@[i]}"
                ;;
            --choices|-c)
                (( i++ ))
                pargs[choices]="${@[i]}"
                ;;
            --nargs|-n)
                (( i++ ))
                pargs[nargs]="${@[i]}"
                ;;
            --const|-k)
                (( i++ ))
                pargs[const]="${@[i]}"
                ;;
            --dest|-v)
                (( i++ ))
                pargs[dest]="${@[i]}"
                ;;
            --fold)
                (( i++ ))
                pargs[fold]="${@[i]}"
                ;;
            --format)
                (( i++ ))
                pargs[format]="${@[i]}"
                ;;
            --pattern|-x)
                (( i++ ))
                pargs[pattern]="${@[i]}"
                ;;
            -*)
                echo "Error: Unknown option: $arg" >&2
                return 1
                ;;
            *)
                echo "Error: Unexpected positional argument before separator: $arg" >&2
                return 1
                ;;
        esac
        (( i++ ))
    done

    # Second pass: collect option names after the separator
    while [[ $i -le $# ]]; do
        local arg="${@[i]}"
    done

    while [[ $i -le $# ]]; do
        local arg="${@[i]}"

        # Normalize option names - add hyphens if missing
        if [[ "$arg" == -* ]]; then
            # Already has hyphens, use as-is
            option_names+=("$arg")
        elif [[ "$arg" == +* ]]; then
            # Positional argument marker - strip the + and store as-is
            option_names+=("${arg#+}")
        elif [[ ${#arg} -eq 1 ]]; then
            # Single character, make it a short option
            option_names+=("-$arg")
        else
            # Multi-character, make it a long option
            option_names+=("--$arg")
        fi
        (( i++ ))
    done

    # If no separator found, everything was treated as configuration options
    if [[ $separator_found -eq 0 ]]; then
        echo "Error: No separator '--' found, no option names specified" >&2
        return 1
    fi

    # Apply defaults from bootstrap definitions
    [[ -z "${parsed_args[type]}" ]] && parsed_args[type]="STR"
    [[ -z "${parsed_args[action]}" ]] && parsed_args[action]="STORE"
    [[ -z "${parsed_args[fold]}" ]] && parsed_args[fold]="NONE"

    # Generate default refname if not provided: _aa_ + first option name
    if [[ -z "$refname" ]]; then
        if [[ ${#option_names} -gt 0 ]]; then
            local first_name="${option_names[1]}"
            # Strip leading dashes and use as refname
            refname="_aa_${first_name#-#-}"
        else
            echo "Error: No option names provided" >&2
            return 1
        fi
    fi

    # Validate required parameters
    if [[ ${#option_names} -eq 0 ]]; then
        echo "Error: No option names provided" >&2
        return 1
    fi

    # TODO: Validate against bootstrap definitions (type checking, pattern matching, etc.)
    # For now, basic validation:
    if ! [[ is_type "${parsed_args[type]}" ]]; then
        echo "Error: Invalid type: ${parsed_args[type]}" >&2
        return 1
   fi

    # Check for existing definition
    if ! typeset -p _argparse_registry &>/dev/null; then
        typeset -gA _argparse_registry
    fi

    if [[ -n "${_argparse_registry[$refname]}" && $force_overwrite -eq 0 ]]; then
        echo "Error: Argument definition '$refname' already exists. Use --force to overwrite." >&2
        return 1
    fi

    # Initialize the target array if it doesn't exist
    aa_init "$refname"

    # Store the parsed definition
    aa_set "$refname" "names" "${(j: :)option_names}"
    for key in type action required default help choices nargs const dest fold format pattern reset; do
        if [[ -n "${pargs[$key]}" ]]; then
            aa_set "$refname" "$key" "${pargs[$key]}"
        fi
    done

    # Store in global registry for parse_args to find
    _argparse_registry["$refname"]="$refname"

    if [[ $force_overwrite -eq 1 && -n "${_argparse_registry[$refname]}" ]]; then
        echo "Overwrote argument definition: ${option_names[1]} -> $refname"
    else
        echo "Defined argument: ${option_names[1]} -> $refname"
    fi
}

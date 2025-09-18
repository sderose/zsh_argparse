# add_argument function - can parse its own parameters using bootstrap definitions

add_argument() {
    local -A parsed_args
    local refname="" option_names=()
    local force_overwrite=0
    local i=1

    # Parse our own arguments using the bootstrap definitions
    while [[ $i -le $# ]]; do
        local arg="${@[i]}"

        case "$arg" in
            --force)
                force_overwrite=1
                ;;

            --type|-t)
                (( i++ ))
                parsed_args[type]="${@[i]}"
                ;;
            --action|-a)
                (( i++ ))
                parsed_args[action]="${@[i]}"
                ;;
            --required|-r)
                parsed_args[required]="1"
                ;;
            --default|-d)
                (( i++ ))
                parsed_args[default]="${@[i]}"
                ;;
            --help|-h)
                (( i++ ))
                parsed_args[help]="${@[i]}"
                ;;
            --choices|-c)
                (( i++ ))
                parsed_args[choices]="${@[i]}"
                ;;
            --nargs|-n)
                (( i++ ))
                parsed_args[nargs]="${@[i]}"
                ;;
            --const|-k)
                (( i++ ))
                parsed_args[const]="${@[i]}"
                ;;
            --dest|-v)
                (( i++ ))
                parsed_args[dest]="${@[i]}"
                ;;
            --fold)
                (( i++ ))
                parsed_args[fold]="${@[i]}"
                ;;
            --format)
                (( i++ ))
                parsed_args[format]="${@[i]}"
                ;;
            --pattern|-x)
                (( i++ ))
                parsed_args[pattern]="${@[i]}"
                ;;
            -*)
                echo "Error: Unknown option: $arg" >&2
                return 1
                ;;
            *)
                # Positional arguments: first is refname (if no options seen yet)
                # rest are option names
                if [[ -z "$refname" && ${#option_names} -eq 0 ]]; then
                    refname="$arg"
                else
                    option_names+=("$arg")
                fi
                ;;
        esac
        (( i++ ))
    done

    # Apply defaults from bootstrap definitions
    [[ -z "${parsed_args[type]}" ]] && parsed_args[type]="STR"
    [[ -z "${parsed_args[action]}" ]] && parsed_args[action]="STORE"
    [[ -z "${parsed_args[fold]}" ]] && parsed_args[fold]="NONE"

    # Generate default refname if not provided: _arg_ + first option name
    if [[ -z "$refname" ]]; then
        if [[ ${#option_names} -gt 0 ]]; then
            local first_name="${option_names[1]}"
            # Strip leading dashes and use as refname
            refname="_arg_${first_name#-#-}"
        else
            echo "Error: No refname or option names provided" >&2
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
    case "${parsed_args[type]}" in
        INT|HEXINT|OCTINT|ANYINT|FLOAT|BOOL|STR|TOKEN|CHAR|REGEX|PATH|URL|TIME|DATE|DATETIME)
            ;;
        *)
            echo "Error: Invalid type: ${parsed_args[type]}" >&2
            return 1
            ;;
    esac

    # Check for existing definition
    if ! typeset -p _argparse_registry &>/dev/null; then
        typeset -gA _argparse_registry
    fi

    if [[ -n "${_argparse_registry[$refname]}" && $force_overwrite -eq 0 ]]; then
        echo "Error: Argument definition '$refname' already exists. Use --force to overwrite." >&2
        return 1
    fi

    # Initialize the target array if it doesn't exist
    arg_init "$refname"

    # Store the parsed definition
    arg_set "$refname" "names" "${(j: :)option_names}"
    for key in type action required default help choices nargs const dest fold format pattern; do
        if [[ -n "${parsed_args[$key]}" ]]; then
            arg_set "$refname" "$key" "${parsed_args[$key]}"
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

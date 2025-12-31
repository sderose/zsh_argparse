#!/usr/bin/env zsh

zerg_parse_compact() {
    # Support compact syntax for adding an argument. E.g.:
    # parser_new MYPARSER -- \
    #   'quiet|q:store_true[Reduce messages]' \
    #   'format:choice(xml,json,yaml)[Output format]' \
    #   'out:path=foo.log[Where to write results]'
    # This dunction should just get parser_name and one packed definition.

    req_argc 2 2 $# || return $ZERR_ARGC
    local parser_name=$1
    local spec=$2
    local desc front names_str type default base_type choices_str
    typeset -a names choices cmd_args

    # Extract description from [...]
    if [[ ! $spec =~ '\[([^\]]+)\]$' ]]; then
        warn 1 "Missing description in [...]: '$spec'."
        return 99
    fi
    desc=$match[1]
    front=${spec%%\[*}

    # Parse: name(|name)*:type(=default)?
    if [[ ! $front =~ '^([^:]+):([^=]+)(=(.+))?$' ]]; then
        warn 1 "Invalid compact argument spec: '$spec'."
        return 98
    fi

    names_str=$match[1]
    type=$match[2]
    default=$match[4]

    # Split names on |
    names=("${(@s:|:)names_str}")

    # Check for choices: type(choice1,choice2,...)
    if [[ $type =~ '^([^(]+)\(([^)]+)\)$' ]]; then
        base_type=$match[1]
        choices_str=$match[2]
        choices=("${(@s:,:)choices_str}")
    else
        base_type=$type
    fi

    # Validate type/action exists
    if [[ -z "${zerg_types[$base_type]}" && -z "${zerg_actions[$base_type]}" ]]; then
        warn 1 "Unknown type or action: '$base_type'."
        return 97
    fi

    # Build zerg_add command arguments
    cmd_args=()

    # Add name arguments (single char gets -, others get --)
    local namebuf='"'
    for name in $names; do
        if [[ ${#name} -eq 1 ]]; then
            namebuf+=("-$name ")
        else
            namebuf+=("--$name ")
        fi
    done
    cmd_args+=($namebuf'"')

    if [[ -n "${zerg_types[$base_type]}" ]]; then
        cmd_args+=(--type $base_type)
    else
        cmd_args+=(--action $base_type)
    fi

    if [[ ${#choices} -gt 0 ]]; then
        cmd_args+=(--choices ${(j:,:)choices})
    fi

    if [[ -n "$default" ]]; then
        cmd_args+=(--default $default)
    fi

    cmd_args+=(--help $desc)

    # Call zerg_add with the constructed arguments
    echo "zerg_add" $parser_name "${cmd_args[@]}"
    zerg_add $parser_name ${cmd_args[@]
}

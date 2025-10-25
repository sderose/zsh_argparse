#!/bin/zsh
# zerg_add function -- add_argument for the zerg parser.
#
if ! [ $ZERG_SETUP ]; then
    echo "Source zerg_setup.sh first." >&2
    #return 99
fi

typeset -a zerg_actions=(
    store store_const store_false store_true
    toggle count help version
    append append_const extend
)

typeset -a aa_folds=(upper lower none)

zerg_fix_name() {
    local x="$1"
    x="${${x#-}#-}"
    x=${x//-/_}
    if [[ ! $x =~ '^[a-zA-Z][a-zA-Z0-9_]*$' ]]; then
        tMsg error "Invalid name: $x"
        return 99
    fi
    echo $x
}

###############################################################################
#
zerg_use() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: zerg_use parser_name "full_arg_name"
    parser_name: name of the parser to add to (see zerg_new)
    full_arg_name: another parser name, "__", and a refname from it, to re-use
an argument defined there, in the current parser.

Once all options have been added, use `zerg_parse` to parse the command line.
EOF
        return
    fi
    req_argc 2 2 $# || return 98
    req_sv_type assoc "$1" || return 97
    req_sv_type assoc "$2" || return 97

    tMsg 0 "zerg_use not yet supported."
    return 90
}

zerg_add() {
    if [[ "$1" == "-h" ]]; then
        cat <<'EOF'
Usage: zerg_add parser_name "arg_names" [options...]
    parser_name: name of the parser to add to (see zerg_new)
    arg_names: space-separated list of aliases (e.g. "--quiet -q")
        First one is the reference name.
    options: --type, --default, --help, etc.
        Most are the same as Python `argparse`.
To re-use an option already defined in another parser, see `zerg_use`.
Once all options have been added, use `zerg_parse` to parse the command line.
EOF
        return
    fi
    req_argc 2 99 $# || return 98

    local parser_name="$1"
    local option_names_str="$2"
    shift 2

    # Verify parser exists
    if [[ `sv_type "$parser_name"` != assoc ]]; then
        tMsg 0 "zerg_add: Parser '$parser_name' does not exist. Use zerg_new first."
        return 98
    fi

    local -a option_names
    option_names=(${=option_names_str})  # split on whitespace
    if [[ ${#option_names} -eq 0 ]]; then
        tMsg 0 "zerg_add: No option name(s) provided."
        return 97
    fi
    for name in "${option_names[@]}"; do
        if [[ "$name" != -* ]]; then
            tMsg 0 "zerg_add for '$name': Option name must start with hyphen."
            return 96
        fi
    done
    # First option name is refname (strip leading dashes)
    local refname=`zerg_fix_name "${option_names[1]}"`
    local msg0="zerg_add for '$refname':"
    if [[ $? -ne 0 ]]; then
        tMsg 0 "$msg0 Bad option name '${option_names[1]}'."
        return 93
    fi

    local types="${(k)zerg_types}"
    local lcTypeExpr="--""$types:gs/ /|--/"
    local acts="${zerg_actions}"
    local lcActionExpr="--""$acts:gs/ /|--/"
    #tMsg 0 "lcTypeExpr: $lcTypeExpr"

    # Parse options for this argument definition
    # NOTE: case appears not to accept a variable ref for the expr.
    # That's why the long literals for types and actions.
    local -A pargs=( [dest]="$refname" )
    while [[ $# -gt 0 ]]; do
        case "$1:l" in
            # Type as option or shorthand
            --type|-t)
                req_aa_has zerg_types "$2" || return 93
                pargs[type]="$2:l"
                shift 2 ;;
            --epoch|--idents|--anyint|--char|--logprob|--float|--hexint|--format|--prob|--path|--url|--int|--ident|--bool|--uident|--str|--datetime|--duration|--complex|--time|--date|--lang|--regex|--uidents|--octint)
                local tname=$1:l
                pargs[type]="$tname[3,-1]"
                shift ;;

            # Action as option or shorthand
            --action|-a)
                local aname=$1:l
                pargs[action]="$aname[3,-1]"
                shift 2 ;;
            --store|--store_const|--store_false|--store_true|--toggle|--count|--help|--version|--append|--append_const|--extend)
                pargs[action]="${1#--}"
                shift ;;

            # Convenient combo shorthands
            --flag)
                pargs[type]="bool"
                pargs[action]="store_true"
                shift ;;
            --counter)
                pargs[type]="int"
                pargs[action]="count"
                shift ;;

            # Other options
            --choices|-c)
                req_zerg_type idents "$2" || return 93
                pargs[choices]="$2"
                shift 2 ;;
            --const|-k)
                pargs[const]="$2"  # TODO Check
                shift 2 ;;
            --default|-d)
                pargs[default]="$2"  # TODO Check
                shift 2 ;;
            --dest|-v)
                req_zerg_type ident "$2" || return 93
                pargs[dest]="$2"
                shift 2 ;;
            --fold)
                #req_aa_has aa_folds "$2:l" || return 93  # TODO -a vs -A
                pargs[fold]="$2:l"
                shift 2 ;;
            --format)
                pargs[format]="$2"  # TODO Check
                shift 2 ;;
            --help|-h)
                pargs[help]="$2"
                shift 2 ;;
            --metavar)
                pargs[metavar]="$2"
                shift 2 ;;
            --nargs|-n)
                req_zerg_type int "$2" || return 93
                pargs[nargs]="$2"
                shift 2 ;;
            --pattern|-x)
                req_zerg_type regex "$2" || return 93
                pargs[pattern]="$2"
                shift 2 ;;
            --required|-r)
                pargs[required]="1"
                shift ;;
            -*)
                tMsg 0 "$msg0 Unknown option '$1'."
                return 95 ;;
            *)
                tMsg 0 "$msg0 Unexpected positional argument '$1'."
                return 94 ;;
        esac
    done

    # Apply defaults
    [[ -z "${pargs[type]}" ]] && pargs[type]="str"
    [[ -z "${pargs[action]}" ]] && pargs[action]="store"
    [[ -z "${pargs[fold]}" ]] && pargs[fold]="none"

    # Validate type
    if ! aa_has zerg_types ${pargs[type]}; then
        tMsg 0 "$msg0 Invalid type '${pargs[type]}'."
        return 93
    fi

    # Validate action
    if [[ ! " ${zerg_actions[@]} " =~ " ${pargs[action]} " ]]; then
        tMsg 0 "$msg0 Invalid action '${pargs[action]}'."
        return 92
    fi

    # Check for existing definition and deal
    local def_name="${parser_name}__${refname}"
    if typeset -p "$def_name" &>/dev/null; then
        local disp=${(P)parser_name}[__on_redefine]
        if [[ $disp == error ]]; then
            tMsg 0 "zerg_new: Error: Argument '$def_name' already exists."
            return 98
        elif [[ $disp == ignore ]]; then
            return 0
        elif [[ $disp == warn ]]; then
            tMsg 0 "zerg_new: Warning: Argument '$def_name' already exists."
            unset "$def_name"
        elif [[ $disp == allow ]]; then
            unset "$def_name"
        else
            tMsg 0 "Unknown value '$disp' for --on-redefine."
            return 89
        fi
    fi

    # Create definition as a hidden assoc:
    typeset -ghA "$def_name"

    # Store all metadata in the definition assoc
    aa_set "$def_name" "type" "${pargs[type]}"
    aa_set "$def_name" "action" "${pargs[action]}"
    aa_set "$def_name" "dest" "${pargs[dest]}"
    aa_set "$def_name" "fold" "${pargs[fold]}"
    aa_set "$def_name" "aliases" "$option_names_str"

    for key in required default help choices nargs const format pattern; do
        if [[ -n "${pargs[$key]}" ]]; then
            aa_set "$def_name" "$key" "${pargs[$key]}"
        fi
    done

    # Register all aliases in the parser (they all point to same def_name)
    if [[ ${pargs[action]} != "toggle" ]]; then
        for name in "${option_names[@]}"; do
            aa_set "$parser_name" "$name" "$def_name"
        done
    else
        # TODO Finish toggle
        aa_set $def_name action store_true
        neg_name=${def_name/__/__no_}
        typeset -ghA "$neg_name"
        aa_copy $neg_name $def_name
        aa_set $neg_name action store_false
        for name in "${option_names[@]}"; do
            aa_set "$parser_name" "$name" "$def_name"
            aa_set "$parser_name" "--no-$name" "$neg_name"  # hyphens?
        done
    fi

    # Add refname to __arg_names list
    local existing_list=$(aa_get -q "$parser_name" "__arg_names")
    if [[ -n "$existing_list" ]]; then
        aa_set "$parser_name" "__arg_names" "$existing_list $refname"
    else
        aa_set "$parser_name" "__arg_names" "$refname"
    fi

    return 0
}

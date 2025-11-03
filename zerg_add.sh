#!/bin/zsh
# zerg_add function -- add_argument for the zerg parser.
#
if ! [ $ZERG_SETUP ]; then
    echo "Source zerg_setup.sh first." >&2
    #return ZERR_UNDEF
fi

typeset -A zerg_actions=(
    [store]=1 [store_const]=0 [store_false]=0 [store_true]=0
    [toggle]=0 [count]=0 [help]=0 [version]=0
    [append]=1 [append_const]=0 [extend]=1
)

typeset -A aa_fold_values=( [upper]=1 [lower]=1 [none]=0 )

typeset -a zerg_argdef_fields=(
    arg_names action choices const default dest
    fold format help nargs pattern required type )
    # aliases counter flag on_redefine reset??

zerg_fix_name() {
    if [[ "$1" == "-h" ]]; then
        echo "Turn a hyphenated name (like an option) to an underscored var name."
        return
    fi
    local x="$1"
    x="${${x#-}#-}"
    x=${x//-/_}
    if [[ ! $x =~ '^[a-zA-Z][a-zA-Z0-9_]*$' ]]; then
        tMsg 0 "Invalid name '$x'."
        return ZERR_BAD_NAME
    fi
    echo $x
}

###############################################################################
#
zerg_use() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_use parser_name "full_arg_name"...
Re-use an argument defined in another zerg parser. The parser and its
argumen(s) must still exist.
    parser_name: name of the parser to add to (see zerg_new)
    full_arg_name: another parser name, "__", and a refname from it, to re-use.
    The name and it's aliases (if any) will be the sae in both parsers.
    Multiple of these can be given on the same or different calls to `zerg_use`.
Once all options have been added, use `zerg_parse` to parse the command line.
EOF
            return ;;
        *) break ;;
      esac
      shift
    done

    req_argc 2 99 $# || return ZERR_ARGC
    local pname=$1
    shift

    tMsg 0 "zerg_use not yet fully supported."
    while [ -n "$1" ]; do
        req_sv_type assoc "$1" || return ZERR_SV_TYPE
        ${${pname}["__$1"]}=$1
    done
}

zerg_add() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_add parser_name "arg_names" [options...]
    parser_name: name of the parser to add to (see zerg_new)
    arg_names: space-separated list of aliases (e.g. "--quiet -q")
        First one is the reference name.
    options: --type, --default, --help, etc.
        Most are the same as Python `argparse`.
To re-use an option already defined in another parser, see `zerg_use`.
Once all options have been added, use `zerg_parse` to parse the command line.
EOF
            return ;;
        -q|--quiet) quiet=1;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 99 $# || return ZERR_ARGC

    local parser_name="$1"
    local arg_names_str="$2"
    shift 2

    # Verify parser exists
    if [[ `sv_type "$parser_name"` != assoc ]]; then
        tMsg 0 "zerg_add: Parser '$parser_name' does not exist. Use zerg_new."
        return ZERR_UNDEF
    fi

    local -a arg_names=(${=arg_names_str})  # split on whitespace
    if [[ ${#arg_names} -eq 0 ]]; then
        tMsg 0 "zerg_add: No option name(s) provided."
        return ZERR_BAD_NAME
    fi
    for name in "${arg_names[@]}"; do
        if [[ "$name" != -* ]]; then
            tMsg 0 "zerg_add for '$name': Option name must start with hyphen."
            return ZERR_BAD_NAME
        fi
    done
    # First option name is refname (strip leading dashes)
    local refname=`zerg_fix_name "${arg_names[1]}"`
    local msg0="zerg_add for '$refname':"
    if [[ $? -ne 0 ]]; then
        tMsg 0 "$msg0 Bad option name '${arg_names[1]}'."
        return ZERR_BAD_NAME
    fi

    #local types="${(k)zerg_types}"
    #local lcTypeExpr="--""$types:gs/ /|--/"
    #local acts="${(k)zerg_actions}"
    #local lcActionExpr="--""$acts:gs/ /|--/"
    #tMsg 0 "lcTypeExpr: $lcTypeExpr"

    # Parse options for this argument definition
    # NOTE: case appears not to accept a variable ref for the expr.
    # That's why the long literals for types and actions.
    local -A pargs=( [arg_names]="$arg_names" [dest]="$refname" )
    while [[ $# -gt 0 ]]; do
        #tMsg 0 "In case for token '$1'."
        case "$1:l" in
            --type|-t)
                req_aa_has zerg_types "$2:l" || return ZERR_ENUM
                pargs[type]="$2:l"
                shift 2 ;;

            --action|-a)
                req_aa_has zerg_actions "$2:l" || return ZERR_ENUM
                pargs[action]="$2:l"
                shift 2 ;;
            --epoch|--idents|--anyint|--char|--logprob|--float|--hexint|--format|--prob|--path|--url|--int|--ident|--bool|--uident|--str|--datetime|--duration|--complex|--time|--date|--lang|--regex|--uidents|--octint)
                local tname=$1:l
                pargs[type]="$tname[3,-1]"
                shift ;;

--store|--store_const|--store_false|--store_true|--toggle|--count|--version|--append|--append_const|--extend)
                local aname=$1:l
                pargs[action]="$aname[3,-1]"
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
                req_zerg_type idents "$2" || return ZERR_ZERG_TVALUE
                pargs[choices]="$2"
                shift 2 ;;
            --const|-k)
                pargs[const]="$2"  # Type-check at end
                shift 2 ;;
            --default|-d)
                pargs[default]="$2"  # Type-check at end
                shift 2 ;;
            --dest|-v)
                req_zerg_type ident "$2" || return ZERR_ZERG_TVALUE
                pargs[dest]="$2"
                shift 2 ;;
            --fold)
                #req_aa_has aa_fold_values "$2:l" || return ZERR_ENUM
                pargs[fold]="$2:l"
                shift 2 ;;
            --format)
                req_zerg_type format "$2" || return ZERR_ZERG_TVALUE
                pargs[format]="$2"  # TODO Check
                shift 2 ;;
            --help|-h)
                pargs[help]="$2"
                shift 2 ;;
            --metavar)
                req_zerg_type ident "$2" || return ZERR_ZERG_TVALUE
                pargs[metavar]="$2"
                shift 2 ;;
            --nargs|-n)
                [[ $2 == remainder ]] || req_zerg_type int "$2" || return ZERR_ZERG_TVALUE
                pargs[nargs]="$2"
                shift 2 ;;
            --pattern|-x)
                req_zerg_type regex "$2" || return ZERR_ZERG_TVALUE
                pargs[pattern]="$2"
                shift 2 ;;
            --required|-r)
                pargs[required]="1"
                shift ;;
            -*)
                tMsg 0 "$msg0 Unknown option '$1'."
                return ZERR_BAD_OPTION ;;
            *)
                tMsg 0 "$msg0 Unexpected positional argument '$1'."
                return ZERR_BAD_OPTION ;;
        esac
    done

    # Apply defaults
    [[ -z "${pargs[type]}" ]] && pargs[type]="str"
    [[ -z "${pargs[action]}" ]] && pargs[action]="store"
    [[ -z "${pargs[fold]}" ]] && pargs[fold]="none"

    # Check type of default and const if provided and typed.
    if [ $pargs[type] ]; then
        if [ $pargs[const] ]; then
            req_zerg_type $pargs[type] $pargs[const] || return ZERR_ZERG_TVALUE
        fi
        if [ $pargs[default] ]; then
            req_zerg_type $pargs[type] $pargs[default] || return ZERR_ZERG_TVALUE
        fi
    fi

    # Check for existing definition and deal
    local def_name="${parser_name}__${refname}"
    if typeset -p "$def_name" &>/dev/null; then
        local disp=${${(P)parser_name}[__on_redefine]}
        if [[ $disp == error ]]; then
            tMsg 0 "zerg_new: Error: Argument '$def_name' already exists."
            return ZERR_DUPLICATE
        elif [[ $disp == ignore ]]; then
            return 0
        elif [[ $disp == warn ]]; then
            tMsg 0 "zerg_new: Warning: Argument '$def_name' already exists."
            unset "$def_name"
        elif [[ $disp == allow ]]; then
            unset "$def_name"
        else
            tMsg 0 "add: For --on-redefine: Unknown value '$disp'."
            return ZERR_ENUM
        fi
    fi

    # Store all metadata in the argument definition assoc
    typeset -ghA "$def_name"
    for key in zerg_argdef_fields; do
        [ "${pargs[$key]}" ] && aa_set "$def_name" "$key" "${pargs[$key]}"
    done

    # Register aliases in the parser (they all point to same def_name)
    if [[ ${pargs[action]} == "toggle" ]]; then
        # TODO Finish action=toggle
        aa_set $def_name action store_true
        neg_name=${def_name/__/__no_}
        typeset -ghA "$neg_name"
        aa_copy $neg_name $def_name
        aa_set $neg_name action store_false
        for name in "${arg_names[@]}"; do
            aa_set "$parser_name" "$name" "$def_name"
            aa_set "$parser_name" "--no-$name" "$neg_name"  # hyphens?
        done
    else
        for name in "${arg_names[@]}"; do
            #tMsg 0 "Saving alias '$name' -> '$def_name'."
            aa_set "$parser_name" "$name" "$def_name"
        done
    fi

    # Add refname to arg_names_list (used by ___)  TODO fill in
    local existing_list=$(aa_get -q "$parser_name" "arg_names_list")
    tMsg 0 "Adding refnames, prior = '$existing_list'."
    if [[ -n "$existing_list" ]]; then
        aa_set "$parser_name" "arg_names_list" "$existing_list $refname"
    else
        aa_set "$parser_name" "arg_names_list" "$refname"
    fi

    return 0
}

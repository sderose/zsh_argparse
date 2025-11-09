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
    #  counter flag on_redefine reset??

_zerg_argdef_init() {
    # Check for existing definition and deal  ### TODO Factor out, move up?
    local def_name="$1" arg_names="$2"
    local priorType=`sv_type $def_name`
    if [[ $priorType == ^(scalar|integer|float|array)$ ]]; then
        tMsg 0 "Cannot create zerg parser arg '$def_name', variable already exists."
        return ZERR_DUPLICATE
    elif [[ $priorType == "assoc" ]]; then
        local parser_name=${def_name/__*/}
        local disp=$(aa_get "$parser_name" "on_redefine")
        if [[ $disp == allow ]] || [[ $disp == "" ]]; then
            unset "$def_name"
        elif [[ $disp == ignore ]]; then
            return 0
        elif [[ $disp == warn ]]; then
            tMsg 0 "Warning: Argument def '$def_name' already exists."
            unset "$def_name"
        elif [[ $disp == error ]]; then
            tMsg 0 "Error: Argument '$def_name' already exists."
            return ZERR_DUPLICATE
        else
            tMsg 0 "Unknown value '$disp' for --on-redefine."
            return ZERR_ENUM
        fi
    fi

    # Create assoc to store the argdef, and apply defaults
    typeset -gHA $def_name
    aa_set $def_name "$ZERG_MAGIC_TYPE" "ZERG_ARG_DEF"
    aa_set $def_name action "store"
    aa_set $def_name arg_names "$2"
    aa_set $def_name const ""
    aa_set $def_name default ""
    aa_set $def_name dest ""
    aa_set $def_name fold "none"
    aa_set $def_name required ""
    aa_set $def_name type "str"
}


###############################################################################
#
zerg_add() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_add [-q] parser_name "arg_names" [argOptions...]
    -q: Suppress message from the zerg_add operation itself
    parser_name: name of the parser to add to (see zerg_new)
    arg_names: space-separated list of aliases (e.g. "--quiet -q --silent")
        The first one is the reference name.
    argOptions: Options that determine the treatment of the argument being defined.
        Most are the same as Python `argparse`, such as --type, --default, --help...

parser_name must be an already-existing associative array, typically created by
`zerg_new`. `zerg_add` creates another associative array for the definition, named as
parser_name plus "__" plus the argument's reference name. For example, "PAR1__quiet".
The reference and other names are also added to "arg_names" in parser_name, with
each value being the full name of that argument's associative array.

To re-use an option already defined in another parser, see `zerg_use` (no new
associative array is created in that case -- the current parsers entry(s) for
the argument name(s) simply point to the old one (which must still exist).

Once all arguments have been added to the parser (whether by zerg_add or zerg_use),
parse the command line like (be careful how you refer to "$*", so the user's
actual arguments to you shell function don't get re-parsed):
     zerg_parse parser_name "$*"
EOF
            return ;;
        -q|--quiet) quiet=1;;
        *) tMsg 0 "Unrecognized option '$1'."; return ZERR_BAD_OPTION ;;
      esac
      shift
    done

    req_argc 2 99 $# || return ZERR_ARGC
    req_sv_type assoc "$1" || return ZERR_SV_TYPE

    # Process the parser name and quoted list of this arg's names/aliases
    local parser_name="$1"
    local -a arg_names=(${=2})  # split on whitespace
    if [[ ${#arg_names} -eq 0 ]]; then
        [ $quiet ] || tMsg 0 "No option name(s) provided."
        return ZERR_BAD_NAME
    fi
    for name in "${arg_names[@]}"; do
        if [[ "$name" != -* ]]; then
            [ $quiet ] || tMsg 0 "Option '$name' must start with hyphen."
            return ZERR_BAD_NAME
        fi
    done
    local ref_name=$arg_names[1]  # E.g. "--quiet -q --silent-ly" --> "--quiet"
    local def_name="${parser_name}__"`zerg_opt_to_var "$ref_name"`  # E.g. "silent_ly"
    #echo "Aliases '${arg_names[@]}', ref_name '$ref_name', def_name '$def_name'."
    shift 2

    _zerg_argdef_init "$def_name" "${arg_names[@]}" || return $?

    # Parse options making up this argument definition
    # NOTE: 'case' doesn't fully like variable refs.
    # But try like https://unix.stackexchange.com/questions/446374/\
    #    $~pattern)
    # That's why the long literals for types and actions.
    while [[ $# -gt 0 ]]; do
        case "$1:l" in
            --type|-t)
                aa_has zerg_types "$2:l" || return ZERR_ENUM
                aa_set $def_name type "$2:l"; shift ;;

            --action|-a)
                aa_has zerg_actions "$2:l" || return ZERR_ENUM
                aa_set $def_name action "$2:l"; shift ;;
            --bool|--anyint|--binint|--octint|--int|--hexint|--pid|--float|--prob|--logprob|--complex|--str|--char|--ident|--idents|--argname|--cmdname|--uident|--uidents|--path|--url|--format|--pid|--lang|--regex--datetime|--time|--date|--duration|--epoch)
                local tname=$1:l
                aa_set $def_name type "$tname[3,-1]" ;;

--store|--store_const|--store_false|--store_true|--toggle|--count|--version|--append|--append_const|--extend)
                local aname=$1:l
                aa_set $def_name action "$aname[3,-1]" ;;

            # Convenient combo shorthands
            --flag)
                aa_set $def_name type "bool"
                aa_set $def_name action "store_true" ;;
            --counter)
                aa_set $def_name type "int"
                aa_set $def_name action "count" ;;

            # Other options
            --choices|-c)
                req_zerg_type idents "$2" || return ZERR_ZERG_TVALUE
                aa_set $def_name choices "$2"; shift ;;
            --const|-k)
                aa_set $def_name const "$2"; shift ;;  # Type-check at end
            --default|-d)
                aa_set $def_name default "$2"; shift ;;  # Type-check at end
            --dest|-v)
                req_zerg_type ident "$2" || return ZERR_ZERG_TVALUE
                aa_set $def_name dest "$2"; shift ;;
            --fold)
                #aa_has aa_fold_values "$2:l" || return ZERR_ENUM
                aa_set $def_name fold "$2:l"; shift ;;
            --format)
                req_zerg_type format "$2" || return ZERR_ZERG_TVALUE
                aa_set $def_name format "$2"; shift ;;  # TODO Check
            --help|-h)
                aa_set $def_name help "$2"; shift ;;
            --metavar)
                req_zerg_type ident "$2" || return ZERR_ZERG_TVALUE
                aa_set $def_name metavar "$2"; shift ;;
            --nargs|-n)
                [[ $2 == remainder ]] || req_zerg_type int "$2" || return ZERR_ZERG_TVALUE
                aa_set $def_name nargs "$2"; shift ;;
            --pattern|-x)
                req_zerg_type regex "$2" || return ZERR_ZERG_TVALUE
                aa_set $def_name pattern "$2"; shift ;;
            --required|-r)
                aa_set $def_name required "1" ;;
            -*)
                [ $quiet ] || tMsg 0 "Unknown option '$1'."
                return ZERR_BAD_OPTION ;;
            *)
                [ $quiet ] || tMsg 0 "Unexpected positional argument '$1'."
                return ZERR_BAD_OPTION ;;
        esac
        shift;
    done

    # Check type of default and const if provided and typed.
    local type=`aa_get -q $def_name type`
    local const=`aa_get -q $def_name const`
    local default=`aa_get -q $def_name default`
    local required=`aa_get -q $def_name required`

    if [ -n "$type" ]; then
        if [ -n "$const" ]; then
            req_zerg_type "$type" "$const" || return ZERR_ZERG_TVALUE
        fi
        if [ -n "$default" ]; then
            req_zerg_type $type $default || return ZERR_ZERG_TVALUE
        fi
    fi
    #echo "After parse/default: "`typeset -p def_name`

    if ! [ `aa_get -q "$parser_name" "export"` ]; then
        export -n $def_name
    fi

    # Register aliases in the parser (they all point to same def_name)
    tMsg 1 "Adding '$arg_names' to parser arg_names."
    aa_append_value "$parser_name" "all_arg_names" " $arg_names"
    if [ $required ]; then
        aa_append_value "$parser_name" "required_arg_names" "$ref_name"
    fi

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

    return 0
}


###############################################################################
#
zerg_use() {
    local quiet
    while [[ "$1" == -* ]]; do case "$1" in
        (${~HELP_OPTION_EXPR}) cat <<'EOF'
Usage: zerg_use parser_name "full_arg_name"...
Re-use an argument(s) defined in another zerg parser. The parser and its
argumen(s) must still exist.
    parser_name: name of the parser to add to (see zerg_new)
    full_arg_name: the name of an assoc holding an argument definition created
    by another parser. This consists of the parser name, "__", and a ref_name.
    The name and it's aliases (if any) will be the same in both parsers.
    Multiple of these can be given on the same or different calls to `zerg_use`.
Once all options have been added, use `zerg_parse` to parse the command line.
EOF
            return ;;
        -q) quiet="-q" ;;
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
        local arg_names=`aa_get $1 "arg_names"`
        aa_append_value "$pname" "all_arg_names" " $arg_names"
        local req=`aa_get $1 "required"`
        [ $req ] && aa_append_value "$pname" "required_arg_names" " $arg_names"
        shift
    done
}
